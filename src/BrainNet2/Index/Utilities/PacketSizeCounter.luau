local REMOTE_OVERHEAD = 9
local BYTE_OVERHEAD = 1

local Float64 = 8
local Float32 = 4
local Float16 = 2
local Int32 = 4
local Int16 = 2
local Int8 = 1

local COLOR3_BYTES = 3 * Float32
local VECTOR3_BYTES = 3 * Float32

local TypeByteSizes: { [string]: number } = {
	["nil"] = 0,
	EnumItem = Int32,
	boolean = 1,
	number = Float64,
	UDim = Float32 + Int32,
	UDim2 = 2 * (Float32 + Int32),
	Ray = 6 * Float32,
	Faces = 6,
	Axes = 6,
	BrickColor = Int32,
	Color3 = COLOR3_BYTES,
	Vector2 = 2 * Float32,
	Vector3 = VECTOR3_BYTES,

	Instance = Int32,
	Vector2int16 = 2 * Int16,
	Vector3int16 = 3 * Int16,
	NumberSequenceKeypoint = 3 * Float32,
	ColorSequenceKeypoint = 4 * Float32,
	NumberRange = 2 * Float32,
	Rect = 2 * (2 * Float32),
	PhysicalProperties = 5 * Float32,
	Color3uint8 = 3 * Int8,
}

local CFrameSpecialCases = {
	[CFrame.Angles(0, 0, 0)] = true,
	[CFrame.Angles(0, math.rad(180), math.rad(0))] = true,
	[CFrame.Angles(math.rad(90), 0, 0)] = true,
	[CFrame.Angles(math.rad(-90), math.rad(-180), math.rad(0))] = true,
	[CFrame.Angles(0, math.rad(180), math.rad(180))] = true,
	[CFrame.Angles(0, math.rad(0), math.rad(180))] = true,
	[CFrame.Angles(math.rad(-90), 0, 0)] = true,
	[CFrame.Angles(math.rad(90), math.rad(180), math.rad(0))] = true,
	[CFrame.Angles(0, math.rad(180), math.rad(90))] = true,
	[CFrame.Angles(0, math.rad(0), math.rad(-90))] = true,
	[CFrame.Angles(0, math.rad(90), math.rad(90))] = true,
	[CFrame.Angles(0, math.rad(-90), math.rad(-90))] = true,
	[CFrame.Angles(0, 0, math.rad(90))] = true,
	[CFrame.Angles(0, math.rad(-180), math.rad(-90))] = true,
	[CFrame.Angles(0, math.rad(-90), math.rad(90))] = true,
	[CFrame.Angles(0, math.rad(90), math.rad(-90))] = true,
	[CFrame.Angles(math.rad(-90), math.rad(-90), 0)] = true,
	[CFrame.Angles(math.rad(90), math.rad(90), 0)] = true,
	[CFrame.Angles(0, math.rad(-90), 0)] = true,
	[CFrame.Angles(0, math.rad(90), 0)] = true,
	[CFrame.Angles(math.rad(90), math.rad(-90), 0)] = true,
	[CFrame.Angles(math.rad(-90), math.rad(90), 0)] = true,
	[CFrame.Angles(0, math.rad(90), math.rad(180))] = true,
	[CFrame.Angles(0, math.rad(-90), math.rad(180))] = true,
}

local function GetDataByteSize(Data: any, AlreadyTraversed: { [{ [any]: any }]: boolean })
	local DataType = typeof(Data)
	if TypeByteSizes[DataType] then
		return TypeByteSizes[DataType]
	elseif DataType == "string" then
		return #Data + 2
	elseif DataType == "table" then
		if AlreadyTraversed[Data] then
			return 0
		end
		AlreadyTraversed[Data] = true

		local KeyTotal = 0
		local ValueTotal = 0

		local Index = 1
		local IsOrdered = true
		for Key, Value in next, Data do
			if Key ~= Index then
				IsOrdered = false
			else
				Index += 1
			end

			KeyTotal += GetDataByteSize(Key, AlreadyTraversed) + BYTE_OVERHEAD
			ValueTotal += GetDataByteSize(Value, AlreadyTraversed) + BYTE_OVERHEAD
		end

		return 1 + (IsOrdered and #Data + ValueTotal or KeyTotal + ValueTotal)
	elseif DataType == "CFrame" then
		local IsSpecialCase = false
		for SpecialCase in next, CFrameSpecialCases do
			if SpecialCase == Data.Rotation then
				IsSpecialCase = true
				break
			end
		end

		if IsSpecialCase then
			return 1 + VECTOR3_BYTES
		else
			return 1 + VECTOR3_BYTES + 4 * Float16
		end
	elseif DataType == "NumberSequence" or DataType == "ColorSequence" then
		local Total = 4
		for _, Keypoint in next, Data.Keypoints do
			Total += GetDataByteSize(Keypoint, AlreadyTraversed)
		end

		return Total
	else
		warn("Unsupported data type: " .. DataType)
		return 0
	end
end

local PacketSizeCounter = {}

PacketSizeCounter.RemoteOverhead = REMOTE_OVERHEAD
PacketSizeCounter.TypeOverhead = BYTE_OVERHEAD

function PacketSizeCounter.GetPacketSize(CounterData: {
	IgnoreRemoteOffset: boolean?,
	PacketData: { any },
}): number
	local Total = CounterData.IgnoreRemoteOffset and 0 or REMOTE_OVERHEAD
	local AlreadyTraversed = {}

	for _, Data in ipairs(CounterData.PacketData) do
		Total += GetDataByteSize(Data, AlreadyTraversed) + BYTE_OVERHEAD
	end

	return Total
end

function PacketSizeCounter.GetDataByteSize(Data: any): number
	return GetDataByteSize(Data, {})
end

table.freeze(PacketSizeCounter)
return PacketSizeCounter
