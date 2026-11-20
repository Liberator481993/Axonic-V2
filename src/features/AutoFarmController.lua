--!strict
-- Axonic V2: game-independent farm state machine.
-- Game-specific quest names/positions and interaction details are injected through deps.
local AutoFarmController = {}
AutoFarmController.__index = AutoFarmController

export type Dependencies = {
    characters: any,
    movement: any,
    diagnostics: any,
    statistics: any,
    getLevel: () -> number,
    getSea: () -> number,
    getRoute: (number, number) -> any?,
    hasQuest: (any) -> boolean,
    startQuest: (any) -> (boolean, string?),
    findMob: (any) -> Model?,
    getMobRoot: (Model) -> BasePart?,
    equipMelee: () -> boolean,
    attack: (Model) -> (),
    onStatus: ((string) -> ())?,
    autoQuestEnabled: (() -> boolean)?,
}

function AutoFarmController.new(deps: Dependencies)
    assert(type(deps) == "table", "dependencies required")
    assert(type(deps.getRoute) == "function", "getRoute dependency required")
    assert(type(deps.findMob) == "function", "findMob dependency required")
    return setmetatable({
        _deps = deps,
        _running = false,
        _destroyed = false,
        _loopToken = 0,
        _currentMob = nil :: Model?,
    }, AutoFarmController)
end

function AutoFarmController._status(self, message: string)
    local deps = self._deps
    if deps.diagnostics then
        deps.diagnostics:SetStatus(message)
    end
    if deps.onStatus then
        pcall(deps.onStatus, message)
    end
end

function AutoFarmController._wait(self, seconds: number, token: number): boolean
    local deadline = os.clock() + seconds
    while os.clock() < deadline do
        if not self._running or token ~= self._loopToken or self._destroyed then
            return false
        end
        task.wait(math.min(0.1, deadline - os.clock()))
    end
    return self._running and token == self._loopToken and not self._destroyed
end

function AutoFarmController._step(self, token: number)
    local deps = self._deps
    local _, humanoid, root = deps.characters:Get()
    if not humanoid or not root then
        self:_status("Waiting for character")
        self:_wait(0.5, token)
        return
    end

    local level = deps.getLevel()
    local sea = deps.getSea()
    local route = deps.getRoute(level, sea)
    if not route then
        self:_status("No route configured for this level")
        self:_wait(1.5, token)
        return
    end

    if deps.autoQuestEnabled and deps.autoQuestEnabled() and not deps.hasQuest(route) then
        self:_status("Moving to quest giver")
        local questPosition = route.questCFrame
        if questPosition then
            local moved, reason = deps.movement:MoveTo(questPosition, route.moveSpeed)
            if not moved and reason ~= "Cancelled" then
                deps.diagnostics:Warn("Quest travel interrupted: " .. tostring(reason))
                self:_wait(0.5, token)
                return
            end
        end

        if token ~= self._loopToken or not self._running then return end
        local ok, reason = deps.startQuest(route)
        if ok then
            deps.statistics:RecordQuest()
            self:_status("Quest accepted: " .. tostring(route.mobName))
        else
            deps.diagnostics:Warn("Quest not started: " .. tostring(reason))
        end
        self:_wait(0.8, token)
        return
    end

    local mob = deps.findMob(route)
    if not mob then
        self._currentMob = nil
        self:_status("Searching for " .. tostring(route.mobName))
        if route.mobCFrame then
            deps.movement:MoveTo(route.mobCFrame, route.moveSpeed)
        end
        self:_wait(0.7, token)
        return
    end

    local mobHumanoid = mob:FindFirstChildOfClass("Humanoid")
    local mobRoot = deps.getMobRoot(mob)
    if not mobHumanoid or mobHumanoid.Health <= 0 or not mobRoot then
        self:_wait(0.2, token)
        return
    end

    self._currentMob = mob
    local attackOffset = route.attackOffset or CFrame.new(0, 8, 0)
    local targetCFrame = mobRoot.CFrame * attackOffset

    if (root.Position - targetCFrame.Position).Magnitude > (route.attackRange or 12) then
        self:_status("Approaching " .. tostring(route.mobName))
        deps.movement:MoveTo(targetCFrame, route.moveSpeed)
    end

    if token ~= self._loopToken or not self._running then return end
    if deps.equipMelee() then
        self:_status("Farming " .. tostring(route.mobName))
        deps.attack(mob)
    else
        self:_status("Waiting for a melee tool")
        deps.diagnostics:Warn("No tool with ToolTip='Melee' is available")
    end

    self:_wait(0.15, token)
end

function AutoFarmController._run(self, token: number)
    self:_status("Auto Farm running")
    while self._running and token == self._loopToken and not self._destroyed do
        local ok, err = xpcall(function()
            self:_step(token)
        end, debug.traceback)

        if not ok then
            self._deps.diagnostics:Error("Farm loop: " .. tostring(err))
            self:_status("Runtime error — see Diagnostics")
            if not self:_wait(1, token) then break end
        end
    end
    if not self._destroyed then
        self:_status("Auto Farm stopped")
    end
end

function AutoFarmController.Start(self)
    if self._destroyed or self._running then return false end
    self._running = true
    self._loopToken += 1
    local token = self._loopToken
    task.spawn(function()
        self:_run(token)
    end)
    return true
end

function AutoFarmController.Stop(self)
    if not self._running then return end
    self._running = false
    self._loopToken += 1
    self._currentMob = nil
    self._deps.movement:Cancel()
    self:_status("Auto Farm stopped")
end

function AutoFarmController.Destroy(self)
    self:Stop()
    self._destroyed = true
end

function AutoFarmController.IsRunning(self): boolean
    return self._running
end

return AutoFarmController
