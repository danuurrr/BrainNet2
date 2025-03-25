--!strict
local RunService = game:GetService("RunService")

local Client = require(script.Client)
local PublicTypes = require(script.Types.PublicTypes)
local Server = require(script.Server)
local MockBridge = require(script.Studio.MockBridge)
local Output = require(script.Utilities.Output)

local isServer = RunService:IsServer()

local function isEditMode()
	return RunService:IsRunning() == false and RunService:IsStudio() == true
end

task.spawn(function()
	if not isEditMode() then
		if isServer then
			Server.start()
		else
			Client.start()
		end
	end
end)

local BrainNet2 = {
	ReferenceIdentifier = if isServer then Server.makeIdentifier else Client.makeIdentifier,
	Deserialize = if isServer then Server.deser else Client.deser,
	Serialize = if isServer then Server.ser else Client.ser,

	AllPlayers = Server.playerContainers().All,

	PlayersExcept = Server.playerContainers().Except,

	Players = Server.playerContainers().Players,
	
	Types = script.Types.ExportedTypes,

	ReferenceBridge = if isServer then Server.makeBridge else Client.makeBridge,
	ServerBridge = if isServer then Server.makeBridge else nil,
	ClientBridge = if not isServer then Client.makeBridge else nil,

	HandleInvalidPlayer = function(handler: (player: Player) -> ())
		Output.fatalAssert(isServer, "Cannot call from client")

		Server.invalidPlayerhandler(handler)
	end,
}

if isEditMode() then
	Output.log("running BrainNet2 in mock mode")

	BrainNet2.ClientBridge = MockBridge
	BrainNet2.ServerBridge = nil
	BrainNet2.ReferenceBridge = MockBridge

	function BrainNet2.ReferenceIdentifier(identifier)
		return identifier
	end

	function BrainNet2.Serialize(identifier)
		return identifier
	end

	function BrainNet2.Deserialize(identifier)
		return identifier
	end
end

table.freeze(BrainNet2)

return (BrainNet2 :: {}) :: PublicTypes.BrainNet2
