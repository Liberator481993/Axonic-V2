--!strict
-- Axonic V2: bounded diagnostics log; avoids unbounded memory growth.
local Diagnostics = {}
Diagnostics.__index = Diagnostics

export type Entry = {
    time: number,
    level: string,
    message: string,
}

function Diagnostics.new(capacity: number?)
    local self = setmetatable({}, Diagnostics)
    self._capacity = math.max(10, capacity or 100)
    self._entries = {} :: {Entry}
    self._status = "Starting"
    self._lastError = nil :: string?
    self._errorCount = 0
    return self
end

function Diagnostics.Log(self, level: string, message: string)
    local entry: Entry = {
        time = os.time(),
        level = string.upper(level),
        message = tostring(message),
    }
    table.insert(self._entries, entry)
    if #self._entries > self._capacity then
        table.remove(self._entries, 1)
    end
    if entry.level == "ERROR" then
        self._errorCount += 1
        self._lastError = entry.message
    end
end

function Diagnostics.Info(self, message: string)
    self:Log("INFO", message)
end

function Diagnostics.Warn(self, message: string)
    self:Log("WARN", message)
end

function Diagnostics.Error(self, message: string)
    self:Log("ERROR", message)
end

function Diagnostics.SetStatus(self, status: string)
    self._status = tostring(status)
end

function Diagnostics.GetStatus(self)
    return {
        status = self._status,
        errorCount = self._errorCount,
        lastError = self._lastError,
        entries = #self._entries,
    }
end

function Diagnostics.GetRecent(self, count: number?)
    local result = {}
    local limit = math.clamp(count or 20, 1, self._capacity)
    local first = math.max(1, #self._entries - limit + 1)
    for index = first, #self._entries do
        table.insert(result, self._entries[index])
    end
    return result
end

return Diagnostics
