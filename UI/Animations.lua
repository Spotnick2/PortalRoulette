local _, ns = ...

local Animations = {
    active = {},
}
ns.Animations = Animations

local runner = CreateFrame("Frame")

local function smoothStep(progress)
    return progress * progress * (3 - 2 * progress)
end

local function setScale(frame, value)
    if frame and frame.SetScale then
        frame:SetScale(value)
    end
end

runner:SetScript("OnUpdate", function(_, elapsed)
    for index = #Animations.active, 1, -1 do
        local animation = Animations.active[index]
        if not animation.frame then
            table.remove(Animations.active, index)
        else
            animation.elapsed = animation.elapsed + elapsed
            local progress = animation.elapsed / animation.duration
            if progress > 1 then
                progress = 1
            end

            local eased = smoothStep(progress)
            local alpha = animation.fromAlpha + (animation.toAlpha - animation.fromAlpha) * eased
            local scale = animation.fromScale + (animation.toScale - animation.fromScale) * eased

            animation.frame:SetAlpha(alpha)
            setScale(animation.frame, scale)

            if progress >= 1 then
                if animation.onFinish then
                    animation.onFinish(animation.frame)
                end
                table.remove(Animations.active, index)
            end
        end
    end
end)

function Animations:Stop(frame)
    for index = #self.active, 1, -1 do
        if self.active[index].frame == frame then
            table.remove(self.active, index)
        end
    end
end

function Animations:Play(frame, fromAlpha, toAlpha, fromScale, toScale, duration, onFinish)
    if not frame then
        return
    end

    self:Stop(frame)
    self.active[#self.active + 1] = {
        frame = frame,
        fromAlpha = fromAlpha or frame:GetAlpha(),
        toAlpha = toAlpha or frame:GetAlpha(),
        fromScale = fromScale or frame:GetScale(),
        toScale = toScale or frame:GetScale(),
        duration = duration or 0.2,
        elapsed = 0,
        onFinish = onFinish,
    }
end

function Animations:Reset(frame, alpha, scale)
    if not frame then
        return
    end
    self:Stop(frame)
    if alpha ~= nil and frame.SetAlpha then
        frame:SetAlpha(alpha)
    end
    if scale ~= nil and frame.SetScale then
        frame:SetScale(scale)
    end
end

function Animations:Pulse(frame, scaleUp, duration)
    if not frame then
        return
    end
    local baseScale = frame:GetScale()
    self:Play(frame, frame:GetAlpha(), frame:GetAlpha(), baseScale, scaleUp or (baseScale * 1.04), (duration or 0.16) * 0.5, function()
        self:Play(frame, frame:GetAlpha(), frame:GetAlpha(), frame:GetScale(), baseScale, (duration or 0.16) * 0.5)
    end)
end

function Animations:PlayOpen(frame)
    if not frame then
        return
    end
    frame:SetAlpha(0)
    frame:SetScale((ns.db and ns.db.uiScale or 1) * 0.96)
    self:Play(frame, 0, 1, frame:GetScale(), (ns.db and ns.db.uiScale or 1), 0.22)
end

function Animations:PlayClose(frame, onFinish)
    if not frame then
        return
    end
    local currentScale = frame:GetScale()
    self:Play(frame, frame:GetAlpha(), 0, currentScale, currentScale * 0.96, 0.16, onFinish)
end
