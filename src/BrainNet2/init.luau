local RunService = game:GetService("RunService")
local Index = require(script.Index);

export type Listener = ((player: Player, ...any) -> ()) | ((...any) -> ())

export type BrainNet = {
	_bridge: any,
	send: (self: BrainNet, ...any) -> (),
	sends: (self: BrainNet, player: Player, ...any) -> (),
	sendTo: (self: BrainNet, players: { Player }, ...any) -> (),
	sendExcept: (self: BrainNet, excludePlayers: { Player }, ...any) -> (),
	destroy: (self: BrainNet) -> (),
	listen: (self: BrainNet, callback: Listener) -> BrainNet,
}

local BrainNet = {}
BrainNet.__index = BrainNet

function BrainNet.new(name: string): BrainNet
	assert(type(name) == "string", "Name must be a string.")
	local self = setmetatable({
		_bridge = Index.ReferenceBridge(name),
	}, BrainNet)
	return self :: BrainNet
end

function BrainNet:send(...: any): ()
	if RunService:IsServer() then
		self._bridge:Fire(Index.AllPlayers(), { ... })
	else
		self._bridge:Fire({ ... })
	end
end

function BrainNet:sends(player: Player, ...: any): ()
	self._bridge:Fire(Index.Players({ player }), { ... })
end

function BrainNet:sendTo(players: { Player }, ...: any): ()
	self._bridge:Fire(Index.Players(players), { ... })
end

function BrainNet:sendExcept(excludePlayers: { Player }, ...: any): ()
	self._bridge:Fire(Index.PlayersExcept(excludePlayers), { ... })
end

function BrainNet:destroy(): ()
	if self._bridge and self._bridge.Destroy then
		self._bridge:Destroy()
	end
end

function BrainNet:listen(callback: Listener): BrainNet
	if RunService:IsServer() then
		local serverCallback = callback :: (Player, ...any) -> ()
		self._bridge:Connect(function(player: Player, args: {any})
			serverCallback(player, table.unpack(args))
		end)
	else
		local clientCallback = callback :: (...any) -> ()
		self._bridge:Connect(function(args: {any})
			clientCallback(table.unpack(args))
		end)
	end
	return self
end

return BrainNet
