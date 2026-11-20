--!strict
-- Axonic V2: thin adapter for Blox Fruits client objects.
-- Quest route data stays separate in QuestRoutes.lua.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameAdapter = {}
GameAdapter.__index = GameAdapter

local SEA_PLACE_IDS = {
    [1] = { 2753915549 },
    [2] = { 4442272183 },
    [3] = { 7449423635 },
}

local function isAlive(model: Instance?): boolean
    if not model or not model:IsA("Model") then return false end
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
    return humanoid ~= nil and humanoid.Health > 0 and root ~= nil
end

function GameAdapter.new(diagnostics: any?)
    local self = setmetatable({}, GameAdapter)
    self.player = Players.LocalPlayer
    self._diagnostics = diagnostics
    self._lastAttack = 0
    self._commF = nil

    local ok, remote = pcall(function()
        return ReplicatedStorage:WaitForChild("Remotes", 10):WaitForChild("CommF_", 10)
    end)
    if ok then
        self._commF = remote
    elseif diagnostics then
        diagnostics:Warn("CommF_ remote was not found during initialization")
    end

    return self
end

function GameAdapter.GetLevel(self): number
    local data = self.player:FindFirstChild("Data")
    local level = data and data:FindFirstChild("Level")
    return if level and level:IsA("ValueBase") then level.Value else 1
end

function GameAdapter.GetSea(self): number?
    for sea, placeIds in pairs(SEA_PLACE_IDS) do
        if table.find(placeIds, game.PlaceId) then
            return sea
        end
    end
    return nil
end

function GameAdapter.HasQuest(self, route: {[string]: any}): boolean
    local playerGui = self.player:FindFirstChildOfClass("PlayerGui")
    local main = playerGui and playerGui:FindFirstChild("Main")
    local quest = main and main:FindFirstChild("Quest")
    if not quest or not quest:IsA("GuiObject") or not quest.Visible then
        return false
    end

    local targetName = string.lower(tostring(route.mobName or ""))
    if targetName == "" then return true end

    for _, descendant in ipairs(quest:GetDescendants()) do
        if descendant:IsA("TextLabel") or descendant:IsA("TextButton") then
            local text = string.lower(descendant.Text)
            if string.find(text, targetName, 1, true) then
                return true
            end
        end
    end

    return false
end

function GameAdapter.StartQuest(self, route: {[string]: any}): (boolean, string?)
    if not self._commF then
        return false, "CommF_ remote unavailable"
    end
    if type(route.questId) ~= "string" or type(route.questIndex) ~= "number" then
        return false, "Route is missing questId or questIndex"
    end

    local ok, result = pcall(function()
        return self._commF:InvokeServer("StartQuest", route.questId, route.questIndex)
    end)
    if not ok then
        return false, tostring(result)
    end
    return true, nil
end

function GameAdapter.FindMob(self, route: {[string]: any}): Model?
    local enemies = workspace:FindFirstChild("Enemies")
    if not enemies then return nil end

    local targetName = string.lower(tostring(route.mobName or ""))
    if targetName == "" then return nil end

    local _, _, playerRoot = nil, nil, nil
    local character = self.player.Character
    playerRoot = character and character:FindFirstChild("HumanoidRootPart")

    local closest: Model? = nil
    local closestDistance = math.huge

    for _, candidate in ipairs(enemies:GetChildren()) do
        if candidate:IsA("Model") and isAlive(candidate) then
            local candidateName = string.lower(candidate.Name)
            if candidateName == targetName or string.find(candidateName, targetName, 1, true) then
                local root = candidate:FindFirstChild("HumanoidRootPart") or candidate.PrimaryPart
                local distance = if playerRoot and root then (root.Position - playerRoot.Position).Magnitude else 0
                if distance < closestDistance then
                    closest = candidate
                    closestDistance = distance
                end
            end
        end
    end

    return closest
end

function GameAdapter.GetMobRoot(self, mob: Model): BasePart?
    local root = mob:FindFirstChild("HumanoidRootPart") or mob.PrimaryPart or mob:FindFirstChild("UpperTorso")
    return if root and root:IsA("BasePart") then root else nil
end

function GameAdapter.EquipMelee(self): boolean
    local character = self.player.Character
    local backpack = self.player:FindFirstChildOfClass("Backpack")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not character or not humanoid or not backpack then return false end

    local equipped = character:FindFirstChildOfClass("Tool")
    if equipped and equipped.ToolTip == "Melee" then
        return true
    end

    for _, tool in ipairs(backpack:GetChildren()) do
        if tool:IsA("Tool") and tool.ToolTip == "Melee" then
            local ok = pcall(function()
                humanoid:EquipTool(tool)
            end)
            return ok
        end
    end

    return false
end

function GameAdapter.Attack(self, mob: Model)
    if not isAlive(mob) then return end
    local now = os.clock()
    if now - self._lastAttack < 0.32 then return end

    local character = self.player.Character
    local tool = character and character:FindFirstChildOfClass("Tool")
    if not tool or tool.ToolTip ~= "Melee" then return end

    self._lastAttack = now
    local ok, err = pcall(function()
        tool:Activate()
    end)
    if not ok and self._diagnostics then
        self._diagnostics:Warn("Tool activation failed: " .. tostring(err))
    end
end

return GameAdapter
