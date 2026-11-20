--!strict
-- Axonic V2: cancellable tween movement. Does not disable collisions or alter physics flags.
local TweenService = game:GetService("TweenService")

local Movement = {}
Movement.__index = Movement

function Movement.new(characterManager: any, statistics: any?, diagnostics: any?)
    return setmetatable({
        _characters = characterManager,
        _statistics = statistics,
        _diagnostics = diagnostics,
        _activeTween = nil :: Tween?,
        _token = 0,
        _destroyed = false,
    }, Movement)
end

function Movement.Cancel(self)
    self._token += 1
    if self._activeTween then
        pcall(function()
            self._activeTween:Cancel()
        end)
        self._activeTween = nil
    end
end

function Movement.MoveTo(self, destination: CFrame, speed: number?, maxSegment: number?)
    if self._destroyed then return false, "Movement controller destroyed" end
    self:Cancel()
    local token = self._token
    local studsPerSecond = math.clamp(speed or 75, 16, 180)
    local segmentLength = math.clamp(maxSegment or 180, 40, 300)

    while token == self._token do
        local _, humanoid, root = self._characters:Get()
        if not humanoid or not root then
            return false, "Character unavailable"
        end

        local offset = destination.Position - root.Position
        local distance = offset.Magnitude
        if distance <= 5 then
            return true
        end

        local stepDistance = math.min(distance, segmentLength)
        local nextPosition = root.Position + offset.Unit * stepDistance
        local finalStep = stepDistance >= distance - 0.01
        local nextCFrame = if finalStep then destination else CFrame.new(nextPosition) * destination.Rotation
        local duration = math.max(0.12, stepDistance / studsPerSecond)

        local tween = TweenService:Create(
            root,
            TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
            { CFrame = nextCFrame }
        )
        self._activeTween = tween
        tween:Play()
        local playbackState = tween.Completed:Wait()

        if self._activeTween == tween then
            self._activeTween = nil
        end

        if token ~= self._token then
            return false, "Cancelled"
        end
        if playbackState ~= Enum.PlaybackState.Completed then
            return false, "Tween interrupted"
        end

        if self._statistics then
            self._statistics:RecordDistance(stepDistance)
        end
    end

    return false, "Cancelled"
end

function Movement.Destroy(self)
    self:Cancel()
    self._destroyed = true
end

return Movement
