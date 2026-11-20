--!strict
-- Axonic V2: compact, touch-friendly draggable window.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local MobileWindow = {}
MobileWindow.__index = MobileWindow

local COLORS = {
    background = Color3.fromRGB(17, 19, 29),
    panel = Color3.fromRGB(25, 28, 42),
    panel2 = Color3.fromRGB(32, 36, 53),
    accent = Color3.fromRGB(139, 104, 255),
    accentDark = Color3.fromRGB(91, 67, 177),
    text = Color3.fromRGB(240, 241, 248),
    muted = Color3.fromRGB(155, 160, 180),
    green = Color3.fromRGB(76, 205, 145),
    red = Color3.fromRGB(231, 94, 105),
}

local function make(className: string, properties: {[string]: any}, parent: Instance): Instance
    local object = Instance.new(className)
    for key, value in pairs(properties) do
        (object :: any)[key] = value
    end
    object.Parent = parent
    return object
end

local function corner(parent: Instance, radius: number)
    make("UICorner", { CornerRadius = UDim.new(0, radius) }, parent)
end

local function stroke(parent: Instance, color: Color3, transparency: number?)
    make("UIStroke", {
        Color = color,
        Transparency = transparency or 0,
        Thickness = 1,
    }, parent)
end

function MobileWindow.new(options: {[string]: any})
    local player = Players.LocalPlayer
    local playerGui = player:WaitForChild("PlayerGui")
    local self = setmetatable({}, MobileWindow)
    self._connections = {}
    self._options = options
    self._toggles = {}
    self._destroyed = false
    self._minimized = false

    local screen = make("ScreenGui", {
        Name = "AxonicV2",
        ResetOnSpawn = false,
        IgnoreGuiInset = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 80,
    }, playerGui)
    self._screen = screen

    local root = make("Frame", {
        Name = "Window",
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = COLORS.background,
        BorderSizePixel = 0,
        Position = UDim2.fromScale(0.5, 0.53),
        Size = UDim2.fromOffset(340, 310),
    }, screen)
    corner(root, 14)
    stroke(root, COLORS.accent, 0.35)
    self._root = root

    local top = make("Frame", {
        Name = "Topbar",
        BackgroundColor3 = COLORS.panel,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 48),
    }, root)
    corner(top, 14)
    self._top = top

    make("TextLabel", {
        Name = "Title",
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(14, 0),
        Size = UDim2.new(1, -112, 1, 0),
        Font = Enum.Font.GothamBold,
        Text = "AXONIC  /  V2",
        TextColor3 = COLORS.text,
        TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, top)

    local minimize = make("TextButton", {
        Name = "Minimize",
        BackgroundColor3 = COLORS.panel2,
        BorderSizePixel = 0,
        Position = UDim2.new(1, -76, 0, 9),
        Size = UDim2.fromOffset(28, 28),
        Font = Enum.Font.GothamBold,
        Text = "—",
        TextColor3 = COLORS.text,
        TextSize = 16,
        AutoButtonColor = true,
    }, top)
    corner(minimize, 8)

    local close = make("TextButton", {
        Name = "Close",
        BackgroundColor3 = COLORS.red,
        BorderSizePixel = 0,
        Position = UDim2.new(1, -40, 0, 9),
        Size = UDim2.fromOffset(28, 28),
        Font = Enum.Font.GothamBold,
        Text = "×",
        TextColor3 = Color3.new(1, 1, 1),
        TextSize = 18,
        AutoButtonColor = true,
    }, top)
    corner(close, 8)

    local body = make("Frame", {
        Name = "Body",
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(12, 58),
        Size = UDim2.new(1, -24, 1, -70),
    }, root)
    self._body = body

    local status = make("TextLabel", {
        Name = "Status",
        BackgroundColor3 = COLORS.panel,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 34),
        Font = Enum.Font.Gotham,
        Text = "STATUS  •  READY",
        TextColor3 = COLORS.green,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, body)
    corner(status, 8)
    make("UIPadding", {
        PaddingLeft = UDim.new(0, 10),
        PaddingRight = UDim.new(0, 10),
    }, status)
    self._status = status

    local toggleHolder = make("Frame", {
        Name = "Toggles",
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(0, 44),
        Size = UDim2.new(1, 0, 0, 132),
    }, body)
    make("UIListLayout", {
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, toggleHolder)

    local function addToggle(key: string, label: string, initial: boolean, order: number)
        local button = make("TextButton", {
            Name = key,
            BackgroundColor3 = COLORS.panel,
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 0, 36),
            Font = Enum.Font.GothamSemibold,
            Text = "",
            AutoButtonColor = true,
            LayoutOrder = order,
        }, toggleHolder)
        corner(button, 8)

        local title = make("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(10, 0),
            Size = UDim2.new(1, -84, 1, 0),
            Font = Enum.Font.GothamMedium,
            Text = label,
            TextColor3 = COLORS.text,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
        }, button)

        local state = make("TextLabel", {
            BackgroundColor3 = if initial then COLORS.accentDark else COLORS.panel2,
            BorderSizePixel = 0,
            Position = UDim2.new(1, -66, 0.5, -11),
            Size = UDim2.fromOffset(56, 22),
            Font = Enum.Font.GothamBold,
            Text = if initial then "ON" else "OFF",
            TextColor3 = COLORS.text,
            TextSize = 10,
        }, button)
        corner(state, 7)

        self._toggles[key] = { value = initial, state = state, label = title }
        table.insert(self._connections, button.Activated:Connect(function()
            if self._destroyed then return end
            local item = self._toggles[key]
            item.value = not item.value
            state.Text = if item.value then "ON" else "OFF"
            state.BackgroundColor3 = if item.value then COLORS.accentDark else COLORS.panel2
            local callback = self._options["on" .. key]
            if type(callback) == "function" then
                local ok, err = pcall(callback, item.value)
                if not ok then
                    self:SetStatus("UI CALLBACK ERROR", true)
                    warn("[Axonic V2] " .. tostring(err))
                end
            end
        end))
    end

    addToggle("AutoFarm", "Auto Farm", options.autoFarm == true, 1)
    addToggle("AutoQuest", "Auto Quest", options.autoQuest ~= false, 2)
    addToggle("AutoRespawn", "Auto Respawn Recovery", options.autoRespawn ~= false, 3)

    local stats = make("TextLabel", {
        Name = "Stats",
        BackgroundColor3 = COLORS.panel,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(0, 184),
        Size = UDim2.new(1, 0, 0, 42),
        Font = Enum.Font.Gotham,
        Text = "KILLS  0     QUESTS  0     DEATHS  0",
        TextColor3 = COLORS.muted,
        TextSize = 10,
        TextWrapped = true,
    }, body)
    corner(stats, 8)
    self._stats = stats

    make("TextLabel", {
        Name = "Footer",
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 0, 1, -20),
        Size = UDim2.new(1, 0, 0, 18),
        Font = Enum.Font.Gotham,
        Text = "Mobile-ready  •  Drag the top bar to move",
        TextColor3 = COLORS.muted,
        TextSize = 9,
    }, body)

    table.insert(self._connections, minimize.Activated:Connect(function()
        self._minimized = not self._minimized
        body.Visible = not self._minimized
        root.Size = if self._minimized then UDim2.fromOffset(root.AbsoluteSize.X, 48)
            else UDim2.fromOffset(root.AbsoluteSize.X, 310)
        minimize.Text = if self._minimized then "+" else "—"
    end))

    table.insert(self._connections, close.Activated:Connect(function()
        local callback = self._options.onClose
        if type(callback) == "function" then
            pcall(callback)
        end
        self:Destroy()
    end))

    -- Drag support for both mouse and touch, restricted to the top bar.
    local dragging = false
    local dragInput: InputObject? = nil
    local dragStart = Vector2.zero
    local startPosition = root.Position

    table.insert(self._connections, top.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPosition = root.Position
            dragInput = input
        end
    end))

    table.insert(self._connections, top.InputEnded:Connect(function(input)
        if input == dragInput or input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
            dragInput = nil
        end
    end))

    table.insert(self._connections, UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement
            and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end
        local delta = input.Position - dragStart
        root.Position = UDim2.new(
            startPosition.X.Scale,
            startPosition.X.Offset + delta.X,
            startPosition.Y.Scale,
            startPosition.Y.Offset + delta.Y
        )
    end))

    local function fitToViewport()
        if self._destroyed then return end
        local camera = workspace.CurrentCamera
        if not camera then return end
        local viewport = camera.ViewportSize
        local width = math.clamp(viewport.X - 24, 280, 380)
        local height = math.clamp(viewport.Y - 40, 250, 340)
        local actualHeight = if self._minimized then 48 else height
        root.Size = UDim2.fromOffset(width, actualHeight)
        body.Size = UDim2.new(1, -24, 1, -70)
        body.Visible = not self._minimized
        if root.AbsolutePosition.X + width > viewport.X then
            root.Position = UDim2.new(0, math.max(12, viewport.X - width - 12), root.Position.Y.Scale, root.Position.Y.Offset)
        end
        if root.AbsolutePosition.Y + actualHeight > viewport.Y then
            root.Position = UDim2.new(root.Position.X.Scale, root.Position.X.Offset, 0, math.max(12, viewport.Y - actualHeight - 12))
        end
    end

    local camera = workspace.CurrentCamera
    if camera then
        table.insert(self._connections, camera:GetPropertyChangedSignal("ViewportSize"):Connect(fitToViewport))
    end
    fitToViewport()

    return self
end

function MobileWindow.SetStatus(self, message: string, isError: boolean?)
    if self._destroyed or not self._status then return end
    self._status.Text = "STATUS  •  " .. string.upper(tostring(message))
    self._status.TextColor3 = if isError then COLORS.red else COLORS.green
end

function MobileWindow.SetToggle(self, key: string, value: boolean)
    local item = self._toggles[key]
    if not item then return end
    item.value = value
    item.state.Text = if value then "ON" else "OFF"
    item.state.BackgroundColor3 = if value then COLORS.accentDark else COLORS.panel2
end

function MobileWindow.GetToggle(self, key: string): boolean?
    local item = self._toggles[key]
    return if item then item.value else nil
end

function MobileWindow.SetStats(self, snapshot: {[string]: any})
    if self._destroyed or not self._stats then return end
    self._stats.Text = string.format(
        "KILLS  %d     QUESTS  %d     DEATHS  %d",
        snapshot.kills or 0,
        snapshot.questsStarted or 0,
        snapshot.deaths or 0
    )
end

function MobileWindow.Destroy(self)
    if self._destroyed then return end
    self._destroyed = true
    for _, connection in ipairs(self._connections) do
        pcall(function() connection:Disconnect() end)
    end
    table.clear(self._connections)
    if self._screen then
        self._screen:Destroy()
    end
end

return MobileWindow
