--!strict
local Types = require(script.Parent.Parent.Types.Types)
local Output = require(script.Parent.Parent.Utilities.Output)

local ALL_PLAYERS = table.freeze({ kind = "all", value = nil } :: Types.PlayerContainer)

local function All(...): Types.PlayerContainer
	Output.warnAssert(select("#", ...) == 0, "incorrect number of arguments passed to player container")
	return ALL_PLAYERS
end

local function Except(excludedPlayers: Types.Array<Player>, ...): Types.PlayerContainer
	Output.warnAssert(select("#", ...) == 0, "incorrect number of arguments passed to player container")
	return { kind = "except", value = excludedPlayers }
end

local function Players(players: Types.Array<Player>, ...): Types.PlayerContainer
	Output.warnAssert(select("#", ...) == 0, "incorrect number of arguments passed to player container")

	return { kind = "set", value = players }
end

local function Single(player: Player, ...): Types.PlayerContainer
	Output.warnAssert(select("#", ...) == 0, "incorrect number of arguments passed to player container")

	return { kind = "single", value = player }
end

return {
	All = All,
	Except = Except,
	Players = Players,
	Single = Single,
} :: Types.PlayerContainerIndexes
