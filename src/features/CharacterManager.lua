--!strict
-- Axonic V2: central character references and respawn notifications.
local Players = game:GetService("Players")

local CharacterManager = {}
CharacterManager.__index = CharacterManager

function CharacterManager.new(onRespawn: ((Model, Humanoid, BasePart) -> ())?, diagnostics: any?)
    local self = setmetatable({}, CharacterManager)
    self.player = Players.LocalPlayer
    self.character = nil :: Model?
    self.humanoid = nil :: Humanoid?
    self.root = nil :: BasePart?
    self._onRespawn = onRespawn
    self._diagnostics = diagnostics
    self._connections = {}
    self._destroyed = false

    table.insert(self._connections, self.player.CharacterAdded:Connect(function(character)
        self:_bind(character)
    end))

    table.insert(self._connections, self.player.CharacterRemoving:Connect(function()
        self.character = nil
        self.humanoid = nil
        self.root = nil
    end))

    if self.player.Character then
        task.spawn(function()
            self:_bind(self.player.Character)
        end)
    end

    return self
end

function CharacterManager._bind(self, character: Model)
    if self._destroyed then return end

    local humanoid = character:WaitForChild("Humanoid", 10)
    local root = character:WaitForChild("HumanoidRootPart", 10)
    if not humanoid or not root then
        if self._diagnostics then
            self._diagnostics:Warn("Character spawned without Humanoid or HumanoidRootPart")
        end
        return
    end

    self.character = character
    self.humanoid = humanoid :: Humanoid
    self.root = root :: BasePart

    if self._diagnostics then
        self._diagnostics:Info("Character ready")
    end

    if self._onRespawn then
        task.spawn(self._onRespawn, character, humanoid :: Humanoid, root :: BasePart)
    end
end

function CharacterManager.Get(self)
    local character = self.character
    local humanoid = self.humanoid
    local root = self.root

    if not character or not character.Parent or not humanoid or humanoid.Health <= 0
        or not root or not root.Parent then
        return nil, nil, nil
    end
    return character, humanoid, root
end

function CharacterManager.Wait(self, timeout: number?)
    local deadline = os.clock() + (timeout or 10)
    repeat
        if self._destroyed then return nil, nil, nil end
        local character, humanoid, root = self:Get()
        if character then return character, humanoid, root end
        task.wait(0.1)
    until os.clock() >= deadline
    return nil, nil, nil
end

function CharacterManager.Destroy(self)
    self._destroyed = true
    for _, connection in ipairs(self._connections) do
        connection:Disconnect()
    end
    table.clear(self._connections)
    self.character = nil
    self.humanoid = nil
    self.root = nil
end

return CharacterManager
