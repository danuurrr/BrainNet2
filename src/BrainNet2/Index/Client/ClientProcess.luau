--!strict
local RunService = game:GetService("RunService")

local wallyInstanceManager = require(script.Parent.Parent.Utilities.InstanceManager)
local Types = require(script.Parent.Parent.Types.Types)
local Output = require(script.Parent.Parent.Utilities.Output)
local Spawn = require(script.Parent.Parent.Utilities.Spawn)

local outboundQueue: { string | any } = {}
local outboundQueueLength: number = 0
local inboundQueue: { { [string]: { { [any]: any } } } } = {}
local callbackMap: { [string]: { (object: any) -> () } } = {}

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

local ClientProcess = {}

function ClientProcess.start()
	debug.setmemorycategory("BrainNet2")

	local DataRemoteEvent: RemoteEvent = wallyInstanceManager.expectInstance(script.Parent.Parent.Parent, "dataRemoteEvent", 1)
	local MetaRemoteEvent: RemoteEvent = wallyInstanceManager.expectInstance(script.Parent.Parent.Parent, "metaRemoteEvent", 1)

	DataRemoteEvent.OnClientEvent:Connect(function(receivedData)
		table.insert(inboundQueue, receivedData)
	end)

	RunService.Heartbeat:Connect(function()
		debug.profilebegin("BrainNet2")
		if outboundQueueLength > 0 then
			DataRemoteEvent:FireServer({ table.unpack(outboundQueue, 1, outboundQueueLength) })
			outboundQueueLength = 0
			table.clear(outboundQueue)
		end

		debug.profilebegin("BrainNet2:Receive")
		for i = 1, #inboundQueue do
			local incomingPacket = inboundQueue[i]
			for identifier, data in pairs(incomingPacket) do
				local calls = callbackMap[identifier]
				if calls then
					local numCalls = #calls
					local numData = #data

					if numData == 0 then
						if numCalls == 1 then
							Spawn(calls[1])
						else
							for j = 1, numCalls do
								Spawn(calls[j])
							end
						end
					else
						if numCalls == 1 then
							local callback = calls[1]
							for j = 1, numData do
								Spawn(callback, data[j])
							end
						else
							for j = 1, numCalls do
								local callback = calls[j]
								for k = 1, numData do
									Spawn(callback, data[k])
								end
							end
						end
					end
				end
			end
		end
		table.clear(inboundQueue)
		debug.profileend()
	end)

	task.spawn(function()
		for _ = 1, 15 do
			task.wait()
		end
		MetaRemoteEvent:FireServer("1")
	end)

	Output.log("Loaded")
end

function ClientProcess.registerBridge(identifier: Types.Identifier)
	if not callbackMap[identifier] then
		callbackMap[identifier] = {}
	end
end

function ClientProcess.addToQueue(identifier: Types.Identifier, object: any)
	outboundQueue[outboundQueueLength + 1] = object
	outboundQueue[outboundQueueLength + 2] = identifier
	outboundQueueLength += 2
end

function ClientProcess.connect(identifier: Types.Identifier, callback: (Types.Content) -> ()): () -> ()
	local callbacks = callbackMap[identifier] or {}
	callbackMap[identifier] = callbacks

	local posMaybe: number? = BinarySearch(callbacks, callback, callbackComparator)
	local pos: number = posMaybe or (#callbacks + 1)

	local n: number = #callbacks
	for i = n, pos, -1 do
		callbacks[i + 1] = callbacks[i]
	end
	callbacks[pos] = callback

	return function()
		local index = BinarySearch(callbacks, callback, callbackComparator)
		if index then
			callbacks[index] = callbacks[#callbacks]
			table.remove(callbacks, #callbacks)
		end
	end
end

return ClientProcess