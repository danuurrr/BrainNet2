--!strict
local RunService = game:GetService("RunService")

local PATTERN = "[BrainNet2] "

type allTypes = "string" | "number" | "function" | "table"

export type Output = {
    silent: (info: string) -> (),
    log: (info: string) -> (),
    logAssert: (condition: boolean, info: string) -> (),
    warn: (info: string) -> (),
    warnAssert: (condition: boolean, info: string) -> (),
    typecheck: <T>(expectedType: allTypes, funcName: string, paramName: string, param: T) -> (),
    fatal: (info: string) -> never,
    fatalAssert: (condition: boolean, info: string) -> ()
}

local function silent(info: string): ()
    if RunService:IsStudio() then
        print(`{PATTERN}{info}`)
    end
end

local function log(info: string): ()
    print(`{PATTERN}{info}`)
end

local function logAssert(condition: boolean, info: string): ()
    if not condition then
        log(info)
    end
end

local function warn(info: string): ()
    warn(`{PATTERN}{info}`)
end

local function warnAssert(condition: boolean, info: string): ()
    if not condition then
        warn(info)
    end
end

local function typecheck<T>(expectedType: allTypes, funcName: string, paramName: string, param: T): ()
    local resultType = typeof(param)
    assert(table.find({"string", "number", "function", "table"}, resultType) ~= nil, 
        `Invalid type {resultType}`)
    
    local typedResult: allTypes = resultType :: allTypes

    if typedResult ~= expectedType then
        error(`{PATTERN}{funcName} parameter {paramName} takes {expectedType}, got {typedResult}`, 0)
    end
end

local function fatal(info: string): never
    error(`{PATTERN}{info}`, 0)
end

local function fatalAssert(condition: boolean, info: string): ()
    if not condition then
        error(`{PATTERN}{info}`, 0)
    end
end

local Output: Output = {
    silent = silent,
    log = log,
    logAssert = logAssert,
    warn = warn,
    warnAssert = warnAssert,
    typecheck = typecheck,
    fatal = fatal,
    fatalAssert = fatalAssert,
}

return Output
