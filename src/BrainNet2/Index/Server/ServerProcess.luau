--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Output = require(script.Parent.Parent.Utilities.Output)
local TableKit = require(script.Parent.Parent.Utilities.TableKit)
local wallyInstanceManager = require(script.Parent.Parent.Utilities.InstanceManager)
local Types = require(script.Parent.Parent.Types.Types)
local Spawn = require(script.Parent.Parent.Utilities.Spawn)
local ServerIdentifiers = require(script.Parent.ServerIdentifiers)
local Constants = require(script.Parent.Parent.Constants)

local playerList: Types.Set<Player> = {}
local loadingPlayers: Types.Map<Player, number?> = {}
local loadingPlayersQueue: Types.Map<Player, Types.Map<Types.Identifier, Types.Array<Types.Content>>> = {}

local outboundQueue: Types.Array<Types.ServerOutboundPacket> = {}
local inboundQueue: Types.Map<Player, Types.Array<Types.Array<Types.Content>>> = {}

local callbackMap: Types.Map<Types.Identifier, Types.Array<Types.ServerConnectionCallback>> = {}

local function playerAdded(player)
	playerList[player] = true
	loadingPlayers[player] = 0
	loadingPlayersQueue[player] = {}
	inboundQueue[player] = {}
end

local function HandleInvalidPlayer(plr: Player)
	Output.warn(string.format(Constants.INVALID_PACKET_MESSAGE, plr.Name, plr.UserId))
end

local function BinarySearch<T>(Array: {T}, Value: T, compare: (T, T) -> number): number?
	local Low: number = 1
	local High: number = #Array

	while Low <= High do
		local Middle: number = Low + math.floor((High - Low) / 2)
		local MiddleValue: T = Array[Middle]
		local cmp: number = compare(Value, MiddleValue)
		if cmp < 0 then
			High = Middle - 1
		elseif cmp > 0 then
			Low = Middle + 1
		else
			while Middle >= 1 and compare(Array[Middle], Value) == 0 do
				Middle = Middle - 1
			end
			return Middle + 1
		end
	end

	return nil
end

local function callbackComparator(a: Types.ServerConnectionCallback, b: Types.ServerConnectionCallback): number
	local sa: string = tostring(a)
	local sb: string = tostring(b)
	if sa < sb then
		return -1
	elseif sa > sb then
		return 1
	else
		return 0
	end
end

local ServerProcess = {}

function ServerProcess.start()
	task.spawn(function()
		debug.setmemorycategory("BrainNet2")

		local metaRemoteEvent: RemoteEvent
		local dataRemoteEvent: RemoteEvent

		local potentialMetaRemoteEvent = wallyInstanceManager.get(script.Parent.Parent.Parent, "metaRemoteEvent")
		if potentialMetaRemoteEvent then
			metaRemoteEvent = potentialMetaRemoteEvent
		else
			metaRemoteEvent = Instance.new("RemoteEvent")
			metaRemoteEvent.Name = "metaRemoteEvent"
			wallyInstanceManager.add(script.Parent.Parent.Parent, metaRemoteEvent)
		end

		local potentialDataRemoteEvent = wallyInstanceManager.get(script.Parent.Parent.Parent, "dataRemoteEvent")
		if potentialDataRemoteEvent then
			dataRemoteEvent = potentialDataRemoteEvent
		else
			dataRemoteEvent = Instance.new("RemoteEvent")
			dataRemoteEvent.Name = "dataRemoteEvent"
			wallyInstanceManager.add(script.Parent.Parent.Parent, dataRemoteEvent)
		end

		Players.PlayerAdded:Connect(playerAdded)

		Players.PlayerRemoving:Connect(function(plr: Player)
			playerList[plr] = nil
			loadingPlayers[plr] = nil
			loadingPlayersQueue[plr] = nil
			inboundQueue[plr] = nil
		end)

		metaRemoteEvent.OnServerEvent:Connect(function(plr: Player, meta: Types.MetaMessage)
			if meta == "1" then
				loadingPlayers[plr] = nil
				dataRemoteEvent:FireClient(plr, loadingPlayersQueue[plr])
				loadingPlayersQueue[plr] = nil
			end
		end)

		dataRemoteEvent.OnServerEvent:Connect(function(plr: Player, tbl: any)
			if typeof(tbl) ~= "table" then
				HandleInvalidPlayer(plr)
				return
			end

			inboundQueue[plr][#inboundQueue[plr] + 1] = tbl
		end)

		local sendStructure: { [Player]: { [Types.Identifier]: { Types.Content } } } = {}

		local function addContentToQueue(player: Player, identifier: Types.Identifier, content: Types.Content)
			local playerContentQueue: { [Types.Identifier]: { Types.Content } } = sendStructure[player]
			if not playerContentQueue then
				sendStructure[player] = { [identifier] = { content } }
			else
				if not playerContentQueue[identifier] then
					playerContentQueue[identifier] = { content }
				else
					local arr: {Types.Content} = playerContentQueue[identifier]
					arr[#arr + 1] = content
				end
			end
		end

		RunService.Heartbeat:Connect(function()
			debug.profilebegin("BrainNet2")

			debug.profilebegin("BrainNet2:Send")
			for _, outbound in outboundQueue do
				local containerKind = outbound.playerContainer.kind
				local containerValue = outbound.playerContainer.value

				local identifier: string = outbound.id
				local content: unknown = outbound.content

				if containerKind == "single" then
					local player = containerValue :: Player
					addContentToQueue(player, identifier, content)
				elseif containerKind == "all" then
					for player in playerList do
						addContentToQueue(player, identifier, content)
					end
				elseif containerKind == "except" then
					for _, plr in containerValue :: { [number]: Player } do
						playerList[plr] = false
					end

					for player, shouldAddContent in playerList do
						if shouldAddContent then
							addContentToQueue(player, identifier, content)
						else
							playerList[player] = true
						end
					end
				elseif containerKind == "set" then
					for _, player in containerValue :: { [number]: Player } do
						addContentToQueue(player, identifier, content)
					end
				end
			end

			for player, contentQueue in sendStructure do
				if loadingPlayers[player] then
					if not loadingPlayersQueue[player] then
						loadingPlayersQueue[player] = contentQueue
					else
						for identifier, content in contentQueue do
							if not loadingPlayersQueue[player][identifier] then
								loadingPlayersQueue[player][identifier] = content
							else
								loadingPlayersQueue[player][identifier] =
									TableKit.MergeArrays(loadingPlayersQueue[player][identifier], content)
							end
						end
					end
				else
					dataRemoteEvent:FireClient(player, contentQueue)
				end
				sendStructure[player] = nil
			end

			table.clear(outboundQueue)
			debug.profileend()

			debug.profilebegin("BrainNet2:Receive")
			for plr, queuedPackets in inboundQueue do
				for _, packet in queuedPackets do
					for i = 1, #packet, 2 do
						local content: Types.Content = packet[i] :: Types.Content
						local identifier: Types.Identifier = packet[i + 1] :: Types.Identifier
						if typeof(identifier) ~= "string" then
							HandleInvalidPlayer(plr)
							break
						end
						local callbacks = callbackMap[identifier]
						if not callbacks then
							continue
						end

						for _, callback in callbacks do
							debug.profilebegin(tostring(ServerIdentifiers.deser(identifier)))
							Spawn(callback, plr, content)
							debug.profileend()
						end
					end
				end
				table.clear(inboundQueue[plr])
			end
			debug.profileend()
			debug.profileend()
		end)
		Output.log("Loaded")
	end)
end

function ServerProcess.addToQueue(
	playerContainer: Types.PlayerContainer,
	identifier: Types.Identifier,
	content: Types.Content
): ()
	outboundQueue[#outboundQueue + 1] = {
		playerContainer = playerContainer,
		id = identifier,
		content = content,
	}
end

function ServerProcess.setInvalidPlayerFunction(func: (plr: Player) -> ())
	HandleInvalidPlayer = func
end

function ServerProcess.registerBridge(identifier: string)
	if not callbackMap[identifier] then
		callbackMap[identifier] = {}
	end
end

function ServerProcess.connect(identifier: string, callback: Types.ServerConnectionCallback): () -> ()
	local callbacks: {Types.ServerConnectionCallback} = callbackMap[identifier] or {}
	callbackMap[identifier] = callbacks

	local posMaybe: number? = BinarySearch(callbacks, callback, callbackComparator)
	local pos: number = posMaybe or (#callbacks + 1)
	local n: number = #callbacks
	for i = n, pos, -1 do
		callbacks[i + 1] = callbacks[i]
	end
	callbacks[pos] = callback

	return function(): ()
		local index: number? = BinarySearch(callbacks, callback, callbackComparator)
		if index then
			local last: number = #callbacks
			callbacks[index] = callbacks[last]
			callbacks[last] = nil
		end
	end
end

return ServerProcess