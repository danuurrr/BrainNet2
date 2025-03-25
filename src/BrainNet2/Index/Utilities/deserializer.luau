--!strict
local idToSignal = {}

local deserializer = {}

local function createSignal()
	local self = { listeners = {} }

	function self:fire(...)
		for _, listener in ipairs(self.listeners) do
			listener(...)
		end
	end

	function self:connect(listener)
		table.insert(self.listeners, listener)
	end

	return self
end

function deserializer.exists(id: number)
	return idToSignal[id] ~= nil
end

function deserializer.registerId(id: number)
	idToSignal[id] = createSignal()
	return idToSignal[id]
end

function deserializer.fetchEventSignal(id: number)
	return idToSignal[id]
end

function deserializer.decode(events: { [number]: { unknown } }, buff: buffer, player: Player?)
	if player then
		for index, calls in events do
			local id = buffer.readu8(buff, index - 1)
			local eventSignal = idToSignal[id]
			if not eventSignal then
				warn("todo: handle this case")
				continue
			end

			for _, value in calls do
				eventSignal:fire(player, value)
			end
		end
	else
		for index, calls in events do
			local id = buffer.readu8(buff, index - 1)
			local eventSignal = idToSignal[id]
			if not eventSignal then
				warn("todo: handle this case")
				continue
			end

			for _, value in calls do
				eventSignal:fire(value)
			end
		end
	end
end

return deserializer
