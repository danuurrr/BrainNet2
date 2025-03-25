--!strict
local wallyInstanceManager = require(script.Parent.Parent.Utilities.InstanceManager)
local Types = require(script.Parent.Parent.Types.Types)
local Output = require(script.Parent.Parent.Utilities.Output)

local identifierStorage
local fullIdentifierMap = {}
local compressedIdentifierMap = {}
local yieldingThreads = {}

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

local function numberComparator(a: number, b: number): number
	if a < b then
		return -1
	elseif a > b then
		return 1
	else
		return 0
	end
end

local ClientIdentifiers = {}

function ClientIdentifiers.start()
	identifierStorage = wallyInstanceManager.waitForInstance(script.Parent.Parent.Parent, "identifierStorage", 1)
	assert(identifierStorage, "identifierStorage not found!")

	for identifier, value in identifierStorage:GetAttributes() do
		fullIdentifierMap[identifier] = value
		compressedIdentifierMap[value] = identifier
		ClientIdentifiers.loadIdentifier(identifier, value)
	end

	identifierStorage.AttributeChanged:Connect(function(id: string)
		local packed: string = identifierStorage:GetAttribute(id)

		if packed then
			fullIdentifierMap[id] = packed
			compressedIdentifierMap[packed] = id

			ClientIdentifiers.loadIdentifier(id, packed)
		else
			local oldValue = fullIdentifierMap[id]
			fullIdentifierMap[id] = nil
			compressedIdentifierMap[oldValue] = nil
		end
	end)

	ClientIdentifiers.ref("NIL_VALUE", 3, false)
	ClientIdentifiers.ref("REQUEST", 3, false)
end

function ClientIdentifiers.loadIdentifier(identifierName: string, value: string)
	if not yieldingThreads[identifierName] then
		return
	end

	local indexes: {number} = {}

	for index, thread in ipairs(yieldingThreads[identifierName]) do
		task.spawn(thread, value)
		local posMaybe: number? = BinarySearch(indexes, index, numberComparator)
		local pos: number = posMaybe or (#indexes + 1)
		local n: number = #indexes
		for j = n, pos, -1 do
			indexes[j + 1] = indexes[j]
		end
		indexes[pos] = index
	end

	local threads = yieldingThreads[identifierName]
	local currentLength: number = #threads
	for i = #indexes, 1, -1 do
		local idx: number = indexes[i]
		threads[idx] = threads[currentLength]
		threads[currentLength] = nil
		currentLength = currentLength - 1
	end
end

function ClientIdentifiers.waitForIdentifier(identifierName: string, timeout: number, bridgeCall: boolean): any
	timeout = timeout or 1

	local identifier = fullIdentifierMap[identifierName]
	if identifier then
		return identifier
	end

	if not yieldingThreads[identifierName] then
		yieldingThreads[identifierName] = {}
	end

	local threads: {thread} = yieldingThreads[identifierName]
	local runningThread: thread = coroutine.running()

	threads[#threads + 1] = runningThread

	task.delay(timeout, function()
		local found: boolean = false
		for i = 1, #threads do
			if threads[i] == runningThread then
				found = true
				break
			end
		end
		if found then
			Output.fatal(
				`reached max wait time for {if bridgeCall then "bridge" else "identifier"} {identifierName}, broke yield. Did you forget to implement it on the server?`
			)
		end
	end)

	return coroutine.yield()
end

function ClientIdentifiers.ref(identifierName: string, maxWaitTime: number?, bridgeCall: boolean)
	Output.typecheck("string", "ReferenceIdentifier", "identifierName", identifierName)

	if maxWaitTime ~= nil then
		Output.typecheck("number", "ReferenceIdentifier", "maxWaitTime", maxWaitTime)
	end
	local maxWaitTimeArg = maxWaitTime or 1

	local identifier = fullIdentifierMap[identifierName]
	if identifier then
		return identifier
	end

	return ClientIdentifiers.waitForIdentifier(identifierName, maxWaitTimeArg, bridgeCall)
end

function ClientIdentifiers.deser(compressedIdentifier: Types.Identifier): Types.Identifier?
	Output.fatalAssert(
		typeof(compressedIdentifier) == "string",
		string.format("Deserialize takes string, got %*", typeof(compressedIdentifier))
	)
	return compressedIdentifierMap[compressedIdentifier]
end

function ClientIdentifiers.ser(identifierName: Types.Identifier): Types.Identifier?
	Output.fatalAssert(
		typeof(identifierName) == "string",
		string.format("Serialize takes string, got %*", typeof(identifierName))
	)
	return fullIdentifierMap[identifierName]
end

return ClientIdentifiers
