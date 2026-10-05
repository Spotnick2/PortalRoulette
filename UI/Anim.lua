-- ============================================================
-- Anim: AnimationGroup factories. Everything animated is a NON-secure
-- visual frame or texture; secure buttons never move or scale.
-- ============================================================

local _, ns = ...

local Anim = {}
ns.Anim = Anim

local function intensity()
    local db = ns.db
    if not db or db.animationsEnabled == false then
        return 0
    end
    return tonumber(db.animationIntensity) or 1
end
Anim.Intensity = intensity

function Anim.Enabled(kind)
    local db = ns.db
    if not db or db.animationsEnabled == false then
        return false
    end
    if kind == "idle" then
        return db.idleAnimationsEnabled ~= false
    elseif kind == "hover" then
        return db.hoverAnimationsEnabled ~= false
    end
    return true
end

-- Fade + scale in from `fromScale`, after `delay`.
function Anim.Appear(region, duration, fromScale, delay)
    local group = region:CreateAnimationGroup()
    local fade = group:CreateAnimation("Alpha")
    fade:SetFromAlpha(0)
    fade:SetToAlpha(1)
    fade:SetDuration(duration)
    fade:SetSmoothing("OUT")
    local scale = group:CreateAnimation("Scale")
    scale:SetScaleFrom(fromScale or 0.85, fromScale or 0.85)
    scale:SetScaleTo(1, 1)
    scale:SetDuration(duration)
    scale:SetSmoothing("OUT")
    if delay and delay > 0 then
        fade:SetStartDelay(delay)
        scale:SetStartDelay(delay)
    end
    group:SetToFinalAlpha(true)
    return group
end

-- Fade + scale out; OnFinished set by the caller.
function Anim.Disappear(region, duration, toScale)
    local group = region:CreateAnimationGroup()
    local fade = group:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(0)
    fade:SetDuration(duration)
    fade:SetSmoothing("IN")
    local scale = group:CreateAnimation("Scale")
    scale:SetScaleFrom(1, 1)
    scale:SetScaleTo(toScale or 0.9, toScale or 0.9)
    scale:SetDuration(duration)
    scale:SetSmoothing("IN")
    group:SetToFinalAlpha(true)
    return group
end

-- Endless rotation (negative seconds spins counter-clockwise).
function Anim.Spin(region, seconds)
    local group = region:CreateAnimationGroup()
    local rotation = group:CreateAnimation("Rotation")
    rotation:SetDegrees(seconds < 0 and 360 or -360)
    rotation:SetDuration(math.abs(seconds))
    group:SetLooping("REPEAT")
    return group
end

-- A gentle alpha breathing between `low` and 1.
function Anim.Pulse(region, seconds, low)
    local group = region:CreateAnimationGroup()
    local fade = group:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(low or 0.6)
    fade:SetDuration(seconds / 2)
    fade:SetSmoothing("IN_OUT")
    group:SetLooping("BOUNCE")
    return group
end

-- Hover: scale a visual to `to` and back, as a pair of one-shot groups.
function Anim.HoverPair(region, to, duration)
    local grow = region:CreateAnimationGroup()
    local up = grow:CreateAnimation("Scale")
    up:SetScaleFrom(1, 1)
    up:SetScaleTo(to, to)
    up:SetDuration(duration)
    up:SetSmoothing("OUT")
    grow:SetToFinalAlpha(true)
    local shrink = region:CreateAnimationGroup()
    local down = shrink:CreateAnimation("Scale")
    down:SetScaleFrom(to, to)
    down:SetScaleTo(1, 1)
    down:SetDuration(duration)
    down:SetSmoothing("OUT")
    -- Scale animations reset on finish: hold the grown size with the
    -- region's own scale while hovered.
    grow:SetScript("OnFinished", function() region:SetScale(to) end)
    shrink:SetScript("OnPlay", function() region:SetScale(1) end)
    return grow, shrink
end

-- Stop every group in a list and snap regions to their resting state.
function Anim.StopAll(groups)
    for _, group in ipairs(groups or {}) do
        if group and group.Stop then
            group:Stop()
        end
    end
end
