--!strict
-- Axonic V2: persistent settings with an in-memory fallback.
local HttpService = game:GetService("HttpService")

local Settings = {}

local function cloneTable(source: {[string]: any}): {[string]: any}
    local result = {}
    for key, value in pairs(source) do
        if type(value) == "table" then
            result[key] = cloneTable(value)
        else
            result[key] = value
        end
    end
    return result
end

local function mergeDefaults(defaults: {[string]: any}, loaded: {[string]: any}): {[string]: any}
    local result = cloneTable(defaults)
    for key, value in pairs(loaded) do
        if type(value) == "table" and type(result[key]) == "table" then
            result[key] = mergeDefaults(result[key], value)
        elseif defaults[key] ~= nil and type(value) == type(defaults[key]) then
            result[key] = value
        end
    end
    return result
end

local function getGlobal(name: string): any
    local ok, value = pcall(function()
        return (getgenv and getgenv() or _G)[name]
    end)
    return if ok then value else nil
end

function Settings.Load(defaults: {[string]: any}, fileName: string): {[string]: any}
    local readFile = getGlobal("readfile")
    local isFile = getGlobal("isfile")
    if type(readFile) ~= "function" or type(isFile) ~= "function" then
        return cloneTable(defaults)
    end

    local okExists, exists = pcall(isFile, fileName)
    if not okExists or not exists then
        return cloneTable(defaults)
    end

    local okRead, raw = pcall(readFile, fileName)
    if not okRead or type(raw) ~= "string" then
        return cloneTable(defaults)
    end

    local okDecode, decoded = pcall(function()
        return HttpService:JSONDecode(raw)
    end)
    if not okDecode or type(decoded) ~= "table" then
        return cloneTable(defaults)
    end

    return mergeDefaults(defaults, decoded)
end

function Settings.Save(settings: {[string]: any}, fileName: string): (boolean, string?)
    local writeFile = getGlobal("writefile")
    if type(writeFile) ~= "function" then
        return false, "Executor file API unavailable; settings remain in memory"
    end

    local okEncode, encoded = pcall(function()
        return HttpService:JSONEncode(settings)
    end)
    if not okEncode then
        return false, "Could not encode settings"
    end

    local okWrite, err = pcall(writeFile, fileName, encoded)
    if not okWrite then
        return false, tostring(err)
    end
    return true, nil
end

return Settings
