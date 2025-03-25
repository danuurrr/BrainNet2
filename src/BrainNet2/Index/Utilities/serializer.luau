--!strict
type Content = any
type OutgoingEvents = {
	events: { [number]: { Content } },
	buff: buffer,
}

local function serializer(queue: { any }): OutgoingEvents
	local outgoingEvents: OutgoingEvents = {
		events = {},
		buff = buffer.create(0),
	}

	local idToIndex: { [number]: number } = {}
	local indexToId: { number } = {}

	for i = 1, #queue, 2 do
		local id = queue[i] :: number
		local content = queue[i + 1] :: Content
		local index: number? = idToIndex[id]

		if index ~= nil then
			table.insert(outgoingEvents.events[index], content)
		else
			indexToId[#indexToId + 1] = id
			local newIndex: number = #indexToId
			idToIndex[id] = newIndex
			outgoingEvents.events[newIndex] = { content }
		end
	end

	local buff = buffer.create(#indexToId)
	for index, id in ipairs(indexToId) do
		buffer.writeu8(buff, index - 1, id)
	end

	outgoingEvents.buff = buff

	return outgoingEvents
end

return serializer
