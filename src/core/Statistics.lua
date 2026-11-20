--!strict
-- Axonic V2: session-only farming statistics.
local Statistics = {}
Statistics.__index = Statistics

function Statistics.new()
    return setmetatable({
        startedAt = os.clock(),
        kills = 0,
        questsStarted = 0,
        deaths = 0,
        distanceTravelled = 0,
    }, Statistics)
end

function Statistics.RecordKill(self, amount: number?)
    self.kills += math.max(1, math.floor(amount or 1))
end

function Statistics.RecordQuest(self)
    self.questsStarted += 1
end

function Statistics.RecordDeath(self)
    self.deaths += 1
end

function Statistics.RecordDistance(self, studs: number)
    if studs > 0 and studs < 100000 then
        self.distanceTravelled += studs
    end
end

function Statistics.Snapshot(self)
    local elapsed = math.max(0, os.clock() - self.startedAt)
    return {
        elapsedSeconds = math.floor(elapsed),
        kills = self.kills,
        questsStarted = self.questsStarted,
        deaths = self.deaths,
        distanceTravelled = math.floor(self.distanceTravelled),
        killsPerMinute = if elapsed > 0 then math.floor((self.kills / elapsed) * 60 * 10) / 10 else 0,
    }
end

function Statistics.Reset(self)
    self.startedAt = os.clock()
    self.kills = 0
    self.questsStarted = 0
    self.deaths = 0
    self.distanceTravelled = 0
end

return Statistics
