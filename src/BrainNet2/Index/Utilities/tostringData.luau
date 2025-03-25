--!strict
local TableKit = require(script.Parent.TableKit)

type ValidTypes = { [any]: ValidTypes }

local function isCFrame(value: any): boolean
    return typeof(value) == "CFrame"
end

local function isVector3(value: any): boolean
    return typeof(value) == "Vector3"
end

return function <T>(data: T & ValidTypes): string
    if typeof(data) == "table" then
        if TableKit.IsArray(data :: any) then
            return TableKit.ToArrayString(data)
        else
            return TableKit.ToString(data)
        end
    else
        local prefix = ""
        local suffix = ""
        
        if isCFrame(data) then
            prefix = "CFrame("
            suffix = ")"
        elseif isVector3(data) then
            prefix = "Vector3("
            suffix = ")"
        end
        
        return `{prefix}{tostring(data)}{suffix}`
	end
end