--!optimize 2
--!native
local task = task

local tspawn = task.spawn
local cyield = coroutine.yield

local freeThread: thread? = nil

local function deletedSignalError()
	error("Cannot fire a deleted signal", 2)
end

local errorTable = {
	fire = deletedSignalError,
	connect = deletedSignalError,
	once = deletedSignalError,
	wait = deletedSignalError,
	disconnectAll = deletedSignalError,
}

local function run<T...>(func: (T...) -> (), ...: T...)
	local ref = freeThread
	freeThread = nil

	func(...)

	freeThread = ref
end

local function yieldLoop()
	while true do
		run(cyield())
	end
end

local signal = {}
signal.__index = signal
type InternalIdentity<T...> = setmetatable<{ (T...) -> () }, typeof(signal)>

local function constructor<T...>(): InternalIdentity<T...>
	return setmetatable({}, signal)
end

function signal.connect<T...>(self: InternalIdentity<T...>, callback: (T...) -> ())
	table.insert(self, callback)

	return function()
		local index = table.find(self, callback)

		if index then
			table.remove(self, index)
		end
	end
end

function signal.fire<T...>(self: InternalIdentity<T...>, ...: T...)
	for i = #(self :: any), 1, -1 do
		if not freeThread then
			freeThread = coroutine.create(yieldLoop)
			tspawn(freeThread :: thread)
		end

		-- Type states don't take into account assigning yet
		tspawn(freeThread :: thread, self[i], ...)
	end
end

function signal.once<T...>(self: InternalIdentity<T...>, callback: (T...) -> ())
	local disconnect
	disconnect = self:connect(function(...)
		assert(disconnect ~= nil, "Luau")
		disconnect()

		callback(...)
	end)
end

function signal.wait<T...>(self: InternalIdentity<T...>): T...
	local running = coroutine.running()

	self:once(function(...)
		assert(
			coroutine.status(running) == "suspended",
			":wait() called, then another thread resumed the waiting thread. Please dont do that :("
		)

		tspawn(running, ...)
	end)

	return cyield()
end

function signal.disconnectAll<T...>(self: InternalIdentity<T...>)
	table.clear(self)
end

function signal.delete<T...>(self: InternalIdentity<T...>): ()
	self:disconnectAll()

	setmetatable(self, errorTable)
end

export type Identity<T...> = {
	fire: (self: Identity<T...>, T...) -> (),
	connect: (self: Identity<T...>, callback: (T...) -> ()) -> () -> (),
	once: (self: Identity<T...>, callback: (T...) -> ()) -> () -> (),
	wait: (self: Identity<T...>) -> T...,
	disconnectAll: (self: Identity<T...>) -> (),
	delete: (self: Identity<T...>) -> (),
}

return constructor :: <T...>() -> Identity<T...>
