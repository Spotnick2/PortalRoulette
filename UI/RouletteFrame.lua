local _, ns = ...

local RouletteFrame = {
    mode = ns.Mode.TELEPORT,
    nodeButtons = {},
}
ns.RouletteFrame = RouletteFrame

local WHEEL_SIZE = 368
local WHEEL_OFFSET_X = 30
local WHEEL_OFFSET_Y = -166
local HEADER_GAP = 46
local NODE_SIZE = 66
local NODE_RADIUS = 128
local NODE_NAMEPLATE_W = 108
local NODE_NAMEPLATE_H = 27
local KARAZHAN_SIZE = 92
local KARAZHAN_RADIUS = 232
local KARAZHAN_ATTACH_RADIUS = 164
local KARAZHAN_ANGLE = 334

local atan2 = math.atan2
if not atan2 then
    atan2 = function(y, x)
        if x > 0 then
            return math.atan(y / x)
        elseif x < 0 and y >= 0 then
            return math.atan(y / x) + math.pi
        elseif x < 0 and y < 0 then
            return math.atan(y / x) - math.pi
        elseif x == 0 and y > 0 then
            return math.pi * 0.5
        elseif x == 0 and y < 0 then
            return -math.pi * 0.5
        end
        return 0
    end
end

local function round(value)
    if value >= 0 then
        return math.floor(value + 0.5)
    end
    return math.ceil(value - 0.5)
end

local function getPositionForAngle(angleDeg, radius)
    local radians = math.rad(angleDeg)
    local x = math.cos(radians) * radius
    local y = math.sin(radians) * radius
    return x, y
end

local function setTextureLine(lineTexture, parent, startX, startY, endX, endY)
    if not lineTexture then
        return
    end

    local dx = endX - startX
    local dy = endY - startY
    local length = math.sqrt((dx * dx) + (dy * dy))
    local angle = atan2(dy, dx)

    lineTexture:ClearAllPoints()
    lineTexture:SetPoint("CENTER", parent, "CENTER", (startX + endX) * 0.5, (startY + endY) * 0.5)
    lineTexture:SetSize(length, 8)
    if lineTexture.SetRotation then
        lineTexture:SetRotation(angle)
    end
end

local function getLinkSlotForAngle(angleDeg)
    local angle = angleDeg % 360
    if angle == 90 then
        return "top"
    elseif angle == 150 then
        return "upper_left"
    elseif angle == 30 then
        return "upper_right"
    elseif angle == 210 then
        return "lower_left"
    elseif angle == 270 then
        return "bottom"
    elseif angle == 330 then
        return "lower_right"
    end
    return "top"
end

local linkTexturesBySlot = {
    top = { normal = ns.Media.LINK_TOP_NORMAL, hover = ns.Media.LINK_TOP_HOVER },
    upper_left = { normal = ns.Media.LINK_UPPER_LEFT_NORMAL, hover = ns.Media.LINK_UPPER_LEFT_HOVER },
    upper_right = { normal = ns.Media.LINK_UPPER_RIGHT_NORMAL, hover = ns.Media.LINK_UPPER_RIGHT_HOVER },
    lower_left = { normal = ns.Media.LINK_LOWER_LEFT_NORMAL, hover = ns.Media.LINK_LOWER_LEFT_HOVER },
    bottom = { normal = ns.Media.LINK_BOTTOM_NORMAL, hover = ns.Media.LINK_BOTTOM_HOVER },
    lower_right = { normal = ns.Media.LINK_LOWER_RIGHT_NORMAL, hover = ns.Media.LINK_LOWER_RIGHT_HOVER },
    extension_right = { normal = ns.Media.LINK_EXTENSION_RIGHT_NORMAL, hover = ns.Media.LINK_EXTENSION_RIGHT_HOVER },
}

local function applySecureMacro(button, macroText)
    if InCombatLockdown() then
        return false
    end
    button:SetAttribute("type", nil)
    button:SetAttribute("spell", nil)
    button:SetAttribute("item", nil)
    button:SetAttribute("macrotext", nil)
    if macroText and macroText ~= "" then
        button:SetAttribute("type", "macro")
        button:SetAttribute("macrotext", macroText)
    end
    return true
end

local function applySecureUtilityAction(button, source)
    if InCombatLockdown() then
        return false
    end

    button:SetAttribute("type", nil)
    button:SetAttribute("item", nil)
    button:SetAttribute("macrotext", nil)

    if not source then
        return true
    end

    if source.actionType == "item" and source.actionValue then
        button:SetAttribute("type", "item")
        button:SetAttribute("item", source.actionValue)
    elseif source.actionType == "macro" and source.actionValue then
        button:SetAttribute("type", "macro")
        button:SetAttribute("macrotext", source.actionValue)
    elseif source.macro then
        button:SetAttribute("type", "macro")
        button:SetAttribute("macrotext", source.macro)
    end

    return true
end

local function setCooldown(cooldown, start, duration, enable)
    if not cooldown then
        return
    end
    if CooldownFrame_Set then
        CooldownFrame_Set(cooldown, start or 0, duration or 0, enable and 1 or 0)
    elseif cooldown.SetCooldown then
        cooldown:SetCooldown(start or 0, duration or 0)
        if cooldown.SetShown then
            cooldown:SetShown(enable and true or false)
        end
    end
end

local function setFrameAlpha(frame, alpha)
    if not frame or not frame.SetAlpha then
        return false
    end
    return pcall(frame.SetAlpha, frame, alpha)
end

local function getFrameAlpha(frame)
    if not frame or not frame.GetAlpha then
        return nil
    end
    local ok, alpha = pcall(frame.GetAlpha, frame)
    if ok then
        return alpha
    end
    return nil
end

function RouletteFrame:HideGameUI()
    if UIParent and UIParent.GetAlpha then
        self._savedUIParentAlpha = UIParent:GetAlpha()
    end

    if SetUIVisibility then
        SetUIVisibility(false)
    elseif UIParent and UIParent.SetAlpha then
        UIParent:SetAlpha(0)
    end
end

function RouletteFrame:RestoreGameUI()
    if SetUIVisibility then
        SetUIVisibility(true)
    end
    if UIParent and UIParent.SetAlpha then
        UIParent:SetAlpha(self._savedUIParentAlpha or 1.0)
    end
    self._savedUIParentAlpha = nil
end

local function createTab(parent, mode, xOffset, label)
    local tab = CreateFrame("Button", nil, parent)
    tab:SetSize(104, 28)
    tab:SetPoint("BOTTOM", parent.frameRef.wheel, "TOP", xOffset, 10)

    tab.bg = tab:CreateTexture(nil, "BACKGROUND")
    tab.bg:SetAllPoints()

    tab.label = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tab.label:SetPoint("CENTER", tab, "CENTER", 0, 1)
    tab.label:SetText(label)
    tab.label:SetJustifyH("CENTER")

    tab.mode = mode
    return tab
end

local function isPlayerCastingOrChanneling()
    return (UnitCastingInfo and UnitCastingInfo("player"))
        or (UnitChannelInfo and UnitChannelInfo("player"))
end

local function getUtilityCooldown(source)
    if not source then
        return 0, 0, false
    end

    local start, duration = 0, 0
    if source.itemID then
        if ns.UtilityItems and ns.UtilityItems.GetItemCooldownByID then
            start, duration = ns.UtilityItems:GetItemCooldownByID(source.itemID)
        elseif GetItemCooldown then
            start, duration = GetItemCooldown(source.itemID)
        end
    end

    local active = start and duration and duration > 1 and (start + duration) > GetTime()
    if (not active) and GetSpellCooldown and (source.spellName or source.label) then
        local spellStart, spellDuration = GetSpellCooldown(source.spellName or source.label)
        if spellStart and spellDuration and spellDuration > 1 and (spellStart + spellDuration) > GetTime() then
            start, duration = spellStart, spellDuration
            active = true
        end
    elseif source.spellName and GetSpellCooldown then
        start, duration = GetSpellCooldown(source.spellName)
        active = start and duration and duration > 1 and (start + duration) > GetTime()
    end
    return start or 0, duration or 0, active and true or false
end

local function positionNameplateForAngle(button, angleDeg, isKarazhan)
    local angle = angleDeg % 360
    if isKarazhan then
        ns.DestinationNode:SetNameplateAnchor(button, "TOP", "BOTTOM", 0, -3, 100, 46)
        return
    end

    if angle == 90 then
        ns.DestinationNode:SetNameplateAnchor(button, "BOTTOM", "TOP", 0, 2, NODE_NAMEPLATE_W, NODE_NAMEPLATE_H)
    elseif angle == 270 then
        ns.DestinationNode:SetNameplateAnchor(button, "TOP", "BOTTOM", 0, -4, NODE_NAMEPLATE_W, NODE_NAMEPLATE_H)
    elseif angle == 30 or angle == 150 then
        ns.DestinationNode:SetNameplateAnchor(button, "TOP", "BOTTOM", 0, -2, NODE_NAMEPLATE_W, NODE_NAMEPLATE_H)
    elseif angle == 210 or angle == 330 then
        ns.DestinationNode:SetNameplateAnchor(button, "TOP", "BOTTOM", 0, -4, NODE_NAMEPLATE_W, NODE_NAMEPLATE_H)
    else
        ns.DestinationNode:SetNameplateAnchor(button, "TOP", "BOTTOM", 0, -3, NODE_NAMEPLATE_W, NODE_NAMEPLATE_H)
    end
end

local function getSpellKnown(spellID)
    if not spellID then
        return false
    end
    if IsSpellKnown then
        return IsSpellKnown(spellID)
    end
    local spellName = GetSpellInfo(spellID)
    if spellName then
        return IsUsableSpell(spellName)
    end
    return false
end

local function playFade(frame, fromAlpha, toAlpha, duration)
    if not frame then
        return
    end
    local scale = 1
    if frame.GetScale then
        scale = frame:GetScale()
    end
    ns.Animations:Play(frame, fromAlpha, toAlpha, scale, scale, duration)
end

local function playFadeScale(frame, fromAlpha, toAlpha, fromScale, toScale, duration)
    if not frame then
        return
    end
    local startScale = fromScale or ((frame.GetScale and frame:GetScale()) or 1)
    local endScale = toScale or startScale
    ns.Animations:Play(frame, fromAlpha, toAlpha, startScale, endScale, duration)
end

local function clampAnimationIntensity()
    local db = ns.db or {}
    local value = tonumber(db.animationIntensity) or 1
    if value < 0 then
        return 0
    elseif value > 1 then
        return 1
    end
    return value
end

local function animationEnabled(key)
    local db = ns.db or {}
    if db.animationsEnabled == false then
        return false
    end
    if key and db[key] == false then
        return false
    end
    return clampAnimationIntensity() > 0
end

local function clampVortexIntensity()
    local db = ns.db or {}
    local value = tonumber(db.portalVortexIntensity) or 1
    if value < 0 then
        return 0
    elseif value > 1 then
        return 1
    end
    return value
end

local function vortexEnabled()
    local db = ns.db or {}
    if db.animationsEnabled == false or db.portalVortexEnabled == false then
        return false
    end
    return clampVortexIntensity() > 0
end

local function resetVisual(frame, alpha, scale)
    if ns.Animations and ns.Animations.Reset then
        ns.Animations:Reset(frame, alpha, scale)
        return
    end
    if frame then
        if alpha ~= nil and frame.SetAlpha then
            frame:SetAlpha(alpha)
        end
        if scale ~= nil and frame.SetScale then
            frame:SetScale(scale)
        end
    end
end

local function resetTextureVisual(texture, alpha, scale, rotation)
    resetVisual(texture, alpha, scale)
    if texture and texture.SetRotation and rotation then
        texture:SetRotation(rotation)
    end
end

function RouletteFrame:RunAfter(delay, callback)
    local token = self.presentationToken
    if not C_Timer or not C_Timer.After then
        callback()
        return
    end
    C_Timer.After(delay, function()
        if not self.frame or not self.frame:IsShown() then
            return
        end
        if token ~= self.presentationToken then
            return
        end
        callback()
    end)
end

function RouletteFrame:SetNodeVisualAlpha(alpha)
    for _, line in ipairs(self.nodeLines or {}) do
        line:SetAlpha(alpha)
    end
    for _, button in ipairs(self.nodeButtons or {}) do
        button:SetAlpha(alpha)
    end
    if self.karazhanLine then
        self.karazhanLine:SetAlpha(alpha)
    end
    if self.karazhanButton then
        self.karazhanButton:SetAlpha(alpha)
    end
end

function RouletteFrame:ResetPresentationState()
    if not self.frame then
        return
    end

    local frame = self.frame
    resetVisual(frame.headerGroup, 1, 1)
    resetVisual(frame.wheel, 1, 1)
    resetVisual(frame.sideGroup, 1, 1)
    resetVisual(frame.lowerGroup, 1, 1)
    if frame.dimmer then
        resetVisual(frame.dimmer, 0.86, 1)
        frame.dimmer:Show()
    end
    self:ResetVortexState(false)

    for _, line in ipairs(self.nodeLines or {}) do
        resetVisual(line, 1, nil)
    end
    for _, button in ipairs(self.nodeButtons or {}) do
        resetVisual(button, 1, 1)
    end
    if self.karazhanLine then
        resetVisual(self.karazhanLine, 1, nil)
    end
    if self.karazhanButton then
        resetVisual(self.karazhanButton, 1, 1)
    end
end

function RouletteFrame:ResetVortexState(visible)
    local vortex = self.vortex
    if not vortex then
        return
    end

    local alpha = visible and 1 or 0
    resetTextureVisual(vortex.backSmoke, 0.18 * alpha, 1, 0)
    resetTextureVisual(vortex.outerWisps, 0.22 * alpha, 1, 0)
    resetTextureVisual(vortex.innerSpiral, 0.24 * alpha, 1, 0)
    resetTextureVisual(vortex.glowBloom, 0.14 * alpha, 1, 0)
    resetTextureVisual(vortex.motes, 0.18 * alpha, 1, 0)
    vortex.outerAngle = 0
    vortex.innerAngle = 0
    vortex.moteAngle = 0
    vortex.collapseBoost = 0
end

function RouletteFrame:PlayVortexOpen()
    if not vortexEnabled() or not self.vortex then
        self:ResetVortexState(false)
        return
    end

    local vortex = self.vortex
    local intensity = clampVortexIntensity()
    resetTextureVisual(vortex.backSmoke, 0, 0.28, 0)
    resetTextureVisual(vortex.outerWisps, 0, 0.36, 0)
    resetTextureVisual(vortex.innerSpiral, 0.10 * intensity, 0.22, -0.18)
    resetTextureVisual(vortex.glowBloom, 0, 0.18, 0)
    resetTextureVisual(vortex.motes, 0, 0.85, 0)

    ns.Animations:Play(vortex.innerSpiral, 0.10 * intensity, 0.24 * intensity, 0.22, 1.0, 0.48)
    ns.Animations:Play(vortex.backSmoke, 0, 0.18 * intensity, 0.28, 1.0, 0.56)
    ns.Animations:Play(vortex.outerWisps, 0, 0.20 * intensity, 0.36, 1.0, 0.62)
    ns.Animations:Play(vortex.glowBloom, 0, 0.16 * intensity, 0.18, 1.0, 0.30, function()
        ns.Animations:Play(vortex.glowBloom, vortex.glowBloom:GetAlpha(), 0.10 * intensity, 1.0, 0.96, 0.22)
    end)
    if ns.db and ns.db.portalVortexMotesEnabled ~= false then
        ns.Animations:Play(vortex.motes, 0, 0.14 * intensity, 0.85, 1.0, 0.54)
    end
end

function RouletteFrame:FadeVortexOut(duration)
    if not self.vortex then
        return
    end
    for _, texture in pairs(self.vortex) do
        if type(texture) == "table" and texture.GetAlpha then
            ns.Animations:Play(texture, texture:GetAlpha(), 0, texture.GetScale and texture:GetScale() or 1, texture.GetScale and texture:GetScale() or 1, duration or 0.16)
        end
    end
end

function RouletteFrame:PlayVortexCollapse()
    if not self.vortex then
        return
    end

    local vortex = self.vortex
    local intensity = vortexEnabled() and clampVortexIntensity() or 0
    vortex.collapseBoost = 0.32 * (intensity > 0 and intensity or 1)

    if intensity <= 0 then
        self:ResetVortexState(false)
        return
    end

    local function collapse(texture, alpha, scale, duration)
        if texture then
            ns.Animations:Play(texture, texture:GetAlpha(), alpha, texture.GetScale and texture:GetScale() or 1, scale, duration)
        end
    end

    collapse(vortex.motes, 0, 0.36, 0.12)
    collapse(vortex.outerWisps, 0.16 * intensity, 0.42, 0.22)
    collapse(vortex.backSmoke, 0.14 * intensity, 0.34, 0.24)
    collapse(vortex.innerSpiral, 0.30 * intensity, 0.20, 0.26)
    collapse(vortex.glowBloom, 0.18 * intensity, 0.26, 0.20)

    self:RunAfter(0.24, function()
        if not self.vortex then
            return
        end
        collapse(vortex.outerWisps, 0, 0.08, 0.10)
        collapse(vortex.backSmoke, 0, 0.06, 0.10)
        collapse(vortex.glowBloom, 0, 0.08, 0.10)
        collapse(vortex.innerSpiral, 0.08 * intensity, 0.04, 0.08)
    end)
    self:RunAfter(0.34, function()
        self:ResetVortexState(false)
    end)
end

function RouletteFrame:PlayOpenPresentation()
    if not self.frame then
        return
    end

    self.presentationToken = (self.presentationToken or 0) + 1
    local frame = self.frame
    local intensity = clampAnimationIntensity()

    if not animationEnabled("openCloseAnimationsEnabled") then
        self:ResetPresentationState()
        return
    end

    self:PlayVortexOpen()

    frame.dimmer:Show()
    frame.dimmer:SetAlpha(0)

    frame.headerGroup:SetAlpha(0)
    frame.headerGroup:SetScale(1 - (0.015 * intensity))
    frame.wheel:SetAlpha(0)
    frame.wheel:SetScale(1 - (0.08 * intensity))
    frame.sideGroup:SetAlpha(0)
    frame.sideGroup:SetScale(1 - (0.01 * intensity))
    frame.lowerGroup:SetAlpha(0)
    frame.lowerGroup:SetScale(1 - (0.01 * intensity))
    self:SetNodeVisualAlpha(0)
    for _, button in ipairs(self.nodeButtons or {}) do
        resetVisual(button, 0, 1 - (0.04 * intensity))
    end
    if self.karazhanButton then
        resetVisual(self.karazhanButton, 0, 1 - (0.04 * intensity))
    end

    playFade(frame.dimmer, 0, 0.86, 0.2)

    self:RunAfter(0.03, function()
        playFadeScale(frame.headerGroup, 0, 1, 1 - (0.015 * intensity), 1, 0.16)
    end)
    self:RunAfter(0.08, function()
        playFadeScale(frame.wheel, 0, 1, 1 - (0.08 * intensity), 1, 0.2)
        if frame.centerUtilityButton and ns.Animations and ns.Animations.Pulse then
            ns.Animations:Pulse(frame.centerUtilityButton, 1 + (0.035 * intensity), 0.22)
        end
    end)
    self:RunAfter(0.12, function()
        for _, line in ipairs(self.nodeLines or {}) do
            playFade(line, 0, 1, 0.14)
        end
    end)

    local stagger = 0.03 * intensity
    if ns.db and ns.db.nodeStaggerEnabled == false then
        stagger = 0
    end
    for index, button in ipairs(self.nodeButtons or {}) do
        self:RunAfter(0.14 + ((index - 1) * stagger), function()
            playFadeScale(button, 0, 1, 1 - (0.04 * intensity), 1, 0.13)
        end)
    end

    local karazhanDelay = 0.14 + (#(self.nodeButtons or {}) * stagger) + (0.04 * intensity)
    self:RunAfter(karazhanDelay, function()
        if self.karazhanLine then
            playFade(self.karazhanLine, 0, 1, 0.12)
        end
        if self.karazhanButton then
            playFadeScale(self.karazhanButton, 0, 1, 1 - (0.035 * intensity), 1, 0.13)
        end
    end)
    self:RunAfter(0.16, function()
        playFadeScale(frame.sideGroup, 0, 1, 1 - (0.01 * intensity), 1, 0.14)
    end)
    self:RunAfter(0.2, function()
        playFadeScale(frame.lowerGroup, 0, 1, 1 - (0.01 * intensity), 1, 0.14)
    end)
end

function RouletteFrame:PlayClosePresentation(onFinish)
    if not self.frame then
        return
    end

    self.presentationToken = (self.presentationToken or 0) + 1
    local token = self.presentationToken
    local frame = self.frame
    local intensity = clampAnimationIntensity()
    local vortexIntensity = clampVortexIntensity()

    if not animationEnabled("openCloseAnimationsEnabled") then
        self:ResetVortexState(false)
        if onFinish then
            onFinish()
        end
        return
    end

    playFade(frame.lowerGroup, frame.lowerGroup:GetAlpha(), 0, 0.12)
    playFade(frame.sideGroup, frame.sideGroup:GetAlpha(), 0, 0.1)
    self:PlayVortexCollapse()
    for _, button in ipairs(self.nodeButtons or {}) do
        playFadeScale(button, button:GetAlpha(), 0, button:GetScale(), 1 - (0.10 * intensity), 0.16)
    end
    for _, line in ipairs(self.nodeLines or {}) do
        playFade(line, line:GetAlpha(), 0, 0.12)
    end
    if self.karazhanLine then
        playFade(self.karazhanLine, self.karazhanLine:GetAlpha(), 0, 0.1)
    end
    if self.karazhanButton then
        playFadeScale(self.karazhanButton, self.karazhanButton:GetAlpha(), 0, self.karazhanButton:GetScale(), 1 - (0.10 * intensity), 0.14)
    end
    if frame.centerUtilityButton and ns.Animations and ns.Animations.Pulse then
        ns.Animations:Pulse(frame.centerUtilityButton, 1 + (0.035 * intensity), 0.12)
    end
    playFadeScale(frame.wheel, frame.wheel:GetAlpha(), 0, frame.wheel:GetScale(), 1 - ((0.12 + (0.04 * vortexIntensity)) * intensity), 0.32)
    playFade(frame.headerGroup, frame.headerGroup:GetAlpha(), 0, 0.12)
    playFade(frame.dimmer, frame.dimmer:GetAlpha(), 0, 0.15)

    if not C_Timer or not C_Timer.After then
        if onFinish then
            onFinish()
        end
        return
    end

    C_Timer.After(0.38, function()
        if token ~= self.presentationToken then
            return
        end
        if onFinish then
            onFinish()
        end
    end)
end

function RouletteFrame:CreateMainFrame()
    if self.frame then
        return
    end

    local overlayParent = WorldFrame or UIParent
    local frame = CreateFrame("Frame", "PortalRouletteMainFrame", overlayParent)
    frame:SetSize(780, 760)
    frame:SetFrameStrata("FULLSCREEN")
    frame:EnableMouse(false)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetClampedToScreen(true)
    if frame.SetIgnoreParentAlpha then
        frame:SetIgnoreParentAlpha(true)
    end

    frame.dimmer = CreateFrame("Frame", nil, overlayParent)
    frame.dimmer:SetAllPoints(overlayParent)
    frame.dimmer:SetFrameStrata("FULLSCREEN")
    frame.dimmer:SetFrameLevel(1)
    frame.dimmer:EnableMouse(false)
    if frame.dimmer.SetIgnoreParentAlpha then
        frame.dimmer:SetIgnoreParentAlpha(true)
    end
    frame.dimmer.texture = frame.dimmer:CreateTexture(nil, "BACKGROUND")
    frame.dimmer.texture:SetAllPoints()
    frame.dimmer.texture:SetTexture("Interface\\Buttons\\WHITE8X8")
    -- Horizontal gradient: left side stays clear (character visible) and right
    -- side is heavily dimmed (where the wheel/reagent/UI sit). Modern API
    -- prefers SetGradient with ColorMixin objects; fall back to SetGradientAlpha
    -- on clients that only have the older API.
    local minR, minG, minB, minA = 0.02, 0.02, 0.04, 0.0
    local maxR, maxG, maxB, maxA = 0.02, 0.02, 0.04, 0.92
    if frame.dimmer.texture.SetGradient and CreateColor then
        local ok = pcall(function()
            frame.dimmer.texture:SetGradient(
                "HORIZONTAL",
                CreateColor(minR, minG, minB, minA),
                CreateColor(maxR, maxG, maxB, maxA)
            )
        end)
        if not ok and frame.dimmer.texture.SetGradientAlpha then
            frame.dimmer.texture:SetGradientAlpha(
                "HORIZONTAL",
                minR, minG, minB, minA,
                maxR, maxG, maxB, maxA
            )
        end
    elseif frame.dimmer.texture.SetGradientAlpha then
        frame.dimmer.texture:SetGradientAlpha(
            "HORIZONTAL",
            minR, minG, minB, minA,
            maxR, maxG, maxB, maxA
        )
    else
        -- Last-resort fallback: solid dim if no gradient API is available.
        frame.dimmer.texture:SetVertexColor(maxR, maxG, maxB, maxA)
    end
    frame.dimmer:Hide()

    frame.cancelButton = CreateFrame("Button", "PortalRouletteCancelCastButton", frame, "SecureActionButtonTemplate")
    frame.cancelButton:SetSize(1, 1)
    frame.cancelButton:SetPoint("TOPLEFT", frame, "TOPLEFT", -10, 10)
    frame.cancelButton:RegisterForClicks("AnyDown", "AnyUp")
    frame.cancelButton:Hide()
    frame.cancelButton:SetAttribute("type", "macro")
    frame.cancelButton:SetAttribute("macrotext", "/stopcasting")
    frame.cancelButton:SetAttribute("type2", "macro")
    frame.cancelButton:SetAttribute("macrotext2", "/stopcasting")
    frame.cancelButton:SetScript("PreClick", function(button, _, down)
        if down then
            button.wasCasting = isPlayerCastingOrChanneling() and true or false
            button.wasTargeting = SpellIsTargeting and SpellIsTargeting()
        end
    end)
    frame.cancelButton:SetScript("PostClick", function(button, mouseButton, down)
        if down then return end
        if mouseButton == "LeftButton" and not button.wasCasting and not button.wasTargeting then
            RouletteFrame:Close()
        end
    end)

    frame.headerGroup = CreateFrame("Frame", nil, frame)
    frame.headerGroup:SetAllPoints()
    frame.headerGroup.frameRef = frame

    frame.sideGroup = CreateFrame("Frame", nil, frame)
    frame.sideGroup:SetAllPoints()

    frame.lowerGroup = CreateFrame("Frame", nil, frame)
    frame.lowerGroup:SetAllPoints()

    frame:SetScript("OnDragStart", function(selfFrame)
        if not ns.db or InCombatLockdown() then
            return
        end
        if not IsAltKeyDown() then
            return
        end
        selfFrame:StartMoving()
    end)

    frame:SetScript("OnDragStop", function(selfFrame)
        selfFrame:StopMovingOrSizing()
        local point, _, _, x, y = selfFrame:GetPoint(1)
        ns.db.roulette.point = point
        ns.db.roulette.x = round(x)
        ns.db.roulette.y = round(y)
    end)

    frame:EnableKeyboard(false)

    frame:SetScript("OnShow", function()
        if frame.cancelButton then
            frame.cancelButton:Show()
        end
        if SetOverrideBindingClick then
            SetOverrideBindingClick(frame, true, "ESCAPE", "PortalRouletteCancelCastButton", "LeftButton")
            SetOverrideBindingClick(frame, true, "SPACE", "PortalRouletteCancelCastButton", "RightButton")
        end
        RouletteFrame:RefreshAll()
        RouletteFrame:HideGameUI()
        if ns.db and ns.db.cinematicCamera then
            ns.CameraMode:Enter()
        end
        RouletteFrame:PlayOpenPresentation()
    end)

    frame:SetScript("OnHide", function()
        if ClearOverrideBindings then
            ClearOverrideBindings(frame)
        end
        if frame.cancelButton then
            frame.cancelButton:Hide()
        end
        frame.dimmer:Hide()
        ns.CameraMode:Exit()
        RouletteFrame.presentationToken = (RouletteFrame.presentationToken or 0) + 1
        RouletteFrame:RestoreGameUI()
    end)

    frame:SetScript("OnUpdate", function(_, elapsed)
        local idleEnabled = animationEnabled("idleAnimationsEnabled") and not (ns.db and ns.db.enableWheelAnimation == false)
        local intensity = clampAnimationIntensity()
        local vortexIdle = vortexEnabled() and not (ns.db and ns.db.portalVortexIdleEnabled == false)
        local vortexIntensity = clampVortexIntensity()

        if idleEnabled then
            local speed = 0.35 + (0.65 * intensity)
            RouletteFrame.outerAngle = (RouletteFrame.outerAngle or 0) + elapsed * 0.07 * speed
            RouletteFrame.innerAngle = (RouletteFrame.innerAngle or 0) - elapsed * 0.045 * speed
            RouletteFrame.idlePulse = (RouletteFrame.idlePulse or 0) + elapsed

            if RouletteFrame.outerRing and RouletteFrame.outerRing.SetRotation then
                RouletteFrame.outerRing:SetRotation(RouletteFrame.outerAngle)
            end
            if RouletteFrame.innerRing and RouletteFrame.innerRing.SetRotation then
                RouletteFrame.innerRing:SetRotation(RouletteFrame.innerAngle)
            end
            if RouletteFrame.factionAccent then
                RouletteFrame.factionAccent:SetAlpha(0.18 + (math.sin(RouletteFrame.idlePulse * 1.25) * 0.025 * intensity))
            end
            if RouletteFrame.centerCore then
                RouletteFrame.centerCore:SetAlpha(0.10 + (math.sin(RouletteFrame.idlePulse * 1.8) * 0.025 * intensity))
            end
        else
            if RouletteFrame.factionAccent then
                RouletteFrame.factionAccent:SetAlpha(0.18)
            end
            if RouletteFrame.centerCore then
                RouletteFrame.centerCore:SetAlpha(0.10)
            end
        end

        if RouletteFrame.vortex then
            local vortex = RouletteFrame.vortex
            if vortexIdle then
                local boost = vortex.collapseBoost or 0
                vortex.outerAngle = (vortex.outerAngle or 0) + elapsed * (0.035 + boost)
                vortex.innerAngle = (vortex.innerAngle or 0) - elapsed * (0.050 + boost * 1.2)
                vortex.moteAngle = (vortex.moteAngle or 0) + elapsed * (0.022 + boost * 0.45)

                if vortex.outerWisps and vortex.outerWisps.SetRotation then
                    vortex.outerWisps:SetRotation(vortex.outerAngle)
                end
                if vortex.innerSpiral and vortex.innerSpiral.SetRotation then
                    vortex.innerSpiral:SetRotation(vortex.innerAngle)
                end
                if vortex.motes and vortex.motes.SetRotation then
                    vortex.motes:SetRotation(vortex.moteAngle)
                end
                if vortex.glowBloom then
                    local breath = 0.08 + (math.sin((RouletteFrame.idlePulse or 0) * 1.45) * 0.018)
                    vortex.glowBloom:SetAlpha(breath * vortexIntensity)
                end
                if vortex.motes and ns.db and ns.db.portalVortexMotesEnabled == false then
                    vortex.motes:SetAlpha(0)
                end
            elseif not vortexEnabled() then
                RouletteFrame:ResetVortexState(false)
            end
        end
        if RouletteFrame.castBarStart then
            RouletteFrame:UpdateCastBar()
        end
        RouletteFrame.utilityRefreshElapsed = (RouletteFrame.utilityRefreshElapsed or 0) + (elapsed or 0)
        if RouletteFrame.utilityRefreshElapsed >= 0.25 then
            RouletteFrame.utilityRefreshElapsed = 0
            if not (InCombatLockdown and InCombatLockdown()) then
                RouletteFrame:RefreshCenterUtility()
            end
        end
    end)

    self.frame = frame
end

function RouletteFrame:CreateWheel()
    local frame = self.frame
    frame.wheel = CreateFrame("Frame", nil, frame)
    frame.wheel:SetSize(WHEEL_SIZE, WHEEL_SIZE)
    frame.wheel:SetPoint("TOP", frame, "TOP", WHEEL_OFFSET_X, WHEEL_OFFSET_Y)

    self.vortex = {
        outerAngle = 0,
        innerAngle = 0,
        moteAngle = 0,
        collapseBoost = 0,
    }

    local function createVortexTexture(path, size, layer, blendMode, color)
        local texture = frame.wheel:CreateTexture(nil, layer or "BACKGROUND")
        texture:SetSize(size, size)
        texture:SetPoint("CENTER", frame.wheel, "CENTER")
        texture:SetTexture(path)
        texture:SetAlpha(0)
        if blendMode then
            texture:SetBlendMode(blendMode)
        end
        if color then
            texture:SetVertexColor(color[1], color[2], color[3], color[4])
        end
        return texture
    end

    self.vortex.backSmoke = createVortexTexture(ns.Media.PORTAL_VORTEX_BACK_SMOKE, WHEEL_SIZE + 72, "BACKGROUND", "BLEND", { 0.55, 0.66, 1.0, 1 })
    self.vortex.outerWisps = createVortexTexture(ns.Media.PORTAL_VORTEX_OUTER_WISPS, WHEEL_SIZE + 82, "BACKGROUND", "ADD", { 0.45, 0.58, 1.0, 1 })
    self.vortex.innerSpiral = createVortexTexture(ns.Media.PORTAL_VORTEX_INNER_SPIRAL, WHEEL_SIZE + 18, "BACKGROUND", "ADD", { 0.48, 0.66, 1.0, 1 })
    self.vortex.glowBloom = createVortexTexture(ns.Media.PORTAL_VORTEX_GLOW_BLOOM, WHEEL_SIZE - 70, "BACKGROUND", "ADD", { 0.42, 0.70, 1.0, 1 })
    self.vortex.motes = createVortexTexture(ns.Media.PORTAL_VORTEX_MOTES, WHEEL_SIZE + 54, "BACKGROUND", "ADD", { 0.62, 0.72, 1.0, 1 })

    self.wheelBase = frame.wheel:CreateTexture(nil, "BACKGROUND")
    self.wheelBase:SetAllPoints()
    self.wheelBase:SetTexture(ns.Media.WHEEL_LAYER_NORMAL or ns.Media.RUNE_WHEEL_BASE)
    self.wheelBase:SetVertexColor(0.58, 0.70, 1.0, 1)
    self.wheelBase:SetAlpha(0.72)

    self.wheelHover = frame.wheel:CreateTexture(nil, "BORDER")
    self.wheelHover:SetAllPoints()
    self.wheelHover:SetTexture(ns.Media.WHEEL_LAYER_HOVER)
    self.wheelHover:SetBlendMode("ADD")
    self.wheelHover:SetVertexColor(0.46, 0.68, 1.0, 1)
    self.wheelHover:SetAlpha(0)

    self.factionAccent = frame.wheel:CreateTexture(nil, "BORDER")
    self.factionAccent:SetAllPoints()
    self.factionAccent:SetBlendMode("ADD")
    self.factionAccent:SetVertexColor(0.40, 0.60, 1.0, 1)
    self.factionAccent:SetAlpha(0.18)

    self.outerRing = frame.wheel:CreateTexture(nil, "ARTWORK")
    self.outerRing:SetAllPoints()
    self.outerRing:SetTexture(ns.Media.RUNE_WHEEL_OUTER)
    self.outerRing:SetBlendMode("ADD")
    self.outerRing:SetVertexColor(0.42, 0.62, 1.0, 1)
    self.outerRing:SetAlpha(0.48)

    self.innerRing = frame.wheel:CreateTexture(nil, "ARTWORK")
    self.innerRing:SetAllPoints()
    self.innerRing:SetTexture(ns.Media.RUNE_WHEEL_INNER)
    self.innerRing:SetBlendMode("ADD")
    self.innerRing:SetVertexColor(0.46, 0.68, 1.0, 1)
    self.innerRing:SetAlpha(0.52)

    self.centerCore = frame.wheel:CreateTexture(nil, "OVERLAY")
    self.centerCore:SetSize(138, 138)
    self.centerCore:SetPoint("CENTER", frame.wheel, "CENTER")
    self.centerCore:SetTexture(ns.Media.CORE_VORTEX)
    self.centerCore:SetBlendMode("ADD")
    self.centerCore:SetVertexColor(0.36, 0.64, 1.0, 1)
    self.centerCore:SetAlpha(0.10)

    frame.centerUtilityButton = CreateFrame("Button", nil, frame.wheel, "SecureActionButtonTemplate")
    frame.centerUtilityButton:SetSize(104, 104)
    frame.centerUtilityButton:SetPoint("CENTER", frame.wheel, "CENTER")
    frame.centerUtilityButton:RegisterForClicks("AnyDown", "AnyUp")
    frame.centerUtilityButton:EnableMouse(true)

    frame.centerUtilityButton:SetNormalTexture(ns.Media.HEARTHSTONE_ORB_NORMAL)
    frame.centerUtilityButton:SetHighlightTexture(ns.Media.HEARTHSTONE_ORB_HOVER, "BLEND")
    frame.centerUtilityButton:SetPushedTexture(ns.Media.HEARTHSTONE_ORB_PRESSED)

    frame.centerUtilityButton.cooldown = CreateFrame("Cooldown", nil, frame.centerUtilityButton, "CooldownFrameTemplate")
    frame.centerUtilityButton.cooldown:SetAllPoints(frame.centerUtilityButton)
    frame.centerUtilityButton.cooldown:SetFrameLevel(frame.centerUtilityButton:GetFrameLevel() + 5)
    if frame.centerUtilityButton.cooldown.SetDrawSwipe then
        frame.centerUtilityButton.cooldown:SetDrawSwipe(false)
    end
    if frame.centerUtilityButton.cooldown.SetDrawEdge then
        frame.centerUtilityButton.cooldown:SetDrawEdge(false)
    end
    if frame.centerUtilityButton.cooldown.SetSwipeColor then
        frame.centerUtilityButton.cooldown:SetSwipeColor(0, 0, 0, 0.72)
    end

    frame.centerUtilityButton.cooldownText = frame.centerUtilityButton:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.centerUtilityButton.cooldownText:SetPoint("CENTER", frame.centerUtilityButton, "CENTER", 0, 0)
    frame.centerUtilityButton.cooldownText:SetTextColor(1, 1, 1, 1)
    frame.centerUtilityButton.cooldownText:SetShadowColor(0, 0, 0, 1)
    frame.centerUtilityButton.cooldownText:SetShadowOffset(1, -1)
    frame.centerUtilityButton.cooldownText:Hide()

    local highlight = frame.centerUtilityButton:GetHighlightTexture()
    if highlight then
        highlight:SetAlpha(0.9)
    end

    frame.centerUtilityButton.tooltipTitle = "Utility"
    frame.centerUtilityButton.tooltipDetail = nil
    frame.centerUtilityButton.pendingMacroText = nil
    frame.centerUtilityButton.utilityEnabled = false
    frame.centerUtilityButton:SetScript("OnEnter", function(button)
        if ns.Sound and RouletteFrame.mode == ns.Mode.TELEPORT and button.utilityEnabled then
            ns.Sound:Play("HearthstoneHover", { hover = true })
        end
        RouletteFrame:RefreshCenterUtility()
        RouletteFrame:ShowUtilityTooltip()
    end)
    frame.centerUtilityButton:SetScript("OnLeave", function()
        RouletteFrame:HideUtilityTooltip()
    end)
    frame.centerUtilityButton:SetScript("OnUpdate", function(button)
        if button:IsMouseOver() then
            RouletteFrame:RefreshCenterUtility()
            RouletteFrame:UpdateUtilityTooltip()
        end
    end)
    frame.wheel:SetScript("OnEnter", function()
        if RouletteFrame.wheelHover then
            RouletteFrame.wheelHover:SetAlpha(0.24)
        end
    end)
    frame.wheel:SetScript("OnLeave", function()
        if RouletteFrame.wheelHover then
            RouletteFrame.wheelHover:SetAlpha(0)
        end
    end)
end

function RouletteFrame:CreateHeader()
    local frame = self.frame
    local parent = frame.headerGroup

    parent.headerText = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    parent.headerText:SetPoint("BOTTOM", frame.wheel, "TOP", 0, HEADER_GAP)
    parent.headerText:SetText("PORTAL ROULETTE")
    parent.headerText:SetTextColor(0.90, 0.88, 1.0)
    parent.headerText:SetShadowColor(0.26, 0.05, 0.66, 0.78)
    parent.headerText:SetShadowOffset(0, -2)

    parent.headerLeft = parent:CreateTexture(nil, "OVERLAY")
    parent.headerLeft:SetSize(18, 18)
    parent.headerLeft:SetPoint("RIGHT", parent.headerText, "LEFT", -13, 0)
    parent.headerLeft:SetTexture("Interface\\Cooldown\\star4")
    parent.headerLeft:SetBlendMode("ADD")
    parent.headerLeft:SetVertexColor(0.52, 0.58, 1.0, 0.82)

    parent.headerRight = parent:CreateTexture(nil, "OVERLAY")
    parent.headerRight:SetSize(18, 18)
    parent.headerRight:SetPoint("LEFT", parent.headerText, "RIGHT", 13, 0)
    parent.headerRight:SetTexture("Interface\\Cooldown\\star4")
    parent.headerRight:SetBlendMode("ADD")
    parent.headerRight:SetVertexColor(0.52, 0.58, 1.0, 0.82)

    frame.headerText = parent.headerText
end

local function isGrouped()
    return IsInGroup and IsInGroup()
end

local function isTeleportConfirmArmed(self, destinationID, mouseButton)
    return self.teleportConfirmDestination == destinationID
        and self.teleportConfirmButton == mouseButton
        and self.teleportConfirmExpires
        and self.teleportConfirmExpires > GetTime()
end

function RouletteFrame:CreateHeaderControls()
    local frame = self.frame
    local parent = frame.headerGroup

    parent.gearButton = CreateFrame("Button", nil, parent)
    parent.gearButton:SetSize(32, 32)
    parent.gearButton:SetPoint("LEFT", parent.headerText, "RIGHT", 32, -14)

    parent.gearButton.bg = parent.gearButton:CreateTexture(nil, "BACKGROUND")
    parent.gearButton.bg:SetAllPoints()
    parent.gearButton.bg:SetTexture(ns.Media.ICON_GEAR)
    parent.gearButton.bg:SetTexCoord(0.04, 0.96, 0.04, 0.96)

    parent.gearButton:SetScript("OnClick", function()
        -- Close the roulette first so UIParent alpha is restored, otherwise the
        -- standard options panel would be hidden by our UIParent fade.
        RouletteFrame:Close()
        if C_Timer and C_Timer.After then
            C_Timer.After(0.18, function() ns.OptionsPanel:Open() end)
        else
            ns.OptionsPanel:Open()
        end
    end)
    parent.gearButton:SetScript("OnMouseDown", function(selfButton)
        selfButton.bg:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    end)
    parent.gearButton:SetScript("OnMouseUp", function(selfButton)
        selfButton.bg:SetTexCoord(0.04, 0.96, 0.04, 0.96)
    end)
    parent.gearButton:SetScript("OnEnter", function(selfButton)
        selfButton.bg:SetVertexColor(1.08, 1.02, 1.16, 1)
        GameTooltip:SetOwner(selfButton, "ANCHOR_RIGHT")
        GameTooltip:SetText("Options", 0.8, 0.95, 1)
        GameTooltip:Show()
    end)
    parent.gearButton:SetScript("OnLeave", function(selfButton)
        selfButton.bg:SetVertexColor(1, 1, 1, 1)
        GameTooltip:Hide()
    end)

    frame.gearButton = parent.gearButton

    parent.closeButton = CreateFrame("Button", nil, parent)
    parent.closeButton:SetSize(20, 20)
    parent.closeButton:SetPoint("LEFT", parent.gearButton, "RIGHT", 6, 0)
    parent.closeButton:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
    parent.closeButton:SetPushedTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down")
    parent.closeButton:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight", "ADD")
    parent.closeButton:SetScript("OnClick", function()
        RouletteFrame:Close()
    end)
    parent.closeButton:SetScript("OnEnter", function(selfButton)
        GameTooltip:SetOwner(selfButton, "ANCHOR_RIGHT")
        GameTooltip:SetText("Close", 0.8, 0.95, 1)
        GameTooltip:Show()
    end)
    parent.closeButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    frame.closeButton = parent.closeButton
end

function RouletteFrame:CreatePanels()
    local frame = self.frame

    frame.hintFrame = CreateFrame("Frame", nil, frame.lowerGroup)
    frame.hintFrame:SetSize(356, 70)
    frame.hintFrame:SetPoint("TOP", frame.wheel, "BOTTOM", 0, -40)

    frame.hintBg = frame.hintFrame:CreateTexture(nil, "ARTWORK")
    frame.hintBg:SetAllPoints()
    frame.hintBg:SetTexture(ns.Media.HINT_PANEL)
    frame.hintBg:SetAlpha(1.0)

    frame.hintText = frame.hintFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.hintText:SetPoint("CENTER", frame.hintFrame, "CENTER", 0, 3)
    frame.hintText:SetWidth(334)
    frame.hintText:SetJustifyH("CENTER")
    frame.hintText:SetText("|cFFFFCC55Left Click:|r Teleport  \124  |cFF88CCFFRight Click:|r Portal\n|cFF99AABBReagents are shared for all options.|r")
    frame.hintText:SetTextColor(0.90, 0.95, 1.0)
    if frame.hintText.SetSpacing then
        frame.hintText:SetSpacing(3)
    end

    frame.castBar = CreateFrame("Frame", nil, frame.lowerGroup)
    frame.castBar:SetSize(286, 22)
    frame.castBar:SetPoint("TOP", frame.wheel, "BOTTOM", 0, -6)
    frame.castBar:Hide()

    frame.castBar.bg = frame.castBar:CreateTexture(nil, "BACKGROUND")
    frame.castBar.bg:SetAllPoints()
    frame.castBar.bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    frame.castBar.bg:SetVertexColor(0.02, 0.025, 0.04, 0.72)

    frame.castBar.fill = frame.castBar:CreateTexture(nil, "ARTWORK")
    frame.castBar.fill:SetPoint("LEFT", frame.castBar, "LEFT", 1, 0)
    frame.castBar.fill:SetHeight(18)
    frame.castBar.fill:SetWidth(1)
    frame.castBar.fill:SetTexture("Interface\\Buttons\\WHITE8X8")
    frame.castBar.fill:SetVertexColor(0.35, 0.65, 1.0, 0.72)

    frame.castBar.text = frame.castBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.castBar.text:SetPoint("CENTER", frame.castBar, "CENTER")

    frame.utilityTooltip = CreateFrame("Frame", nil, frame.lowerGroup)
    frame.utilityTooltip:SetSize(220, 54)
    frame.utilityTooltip:SetPoint("BOTTOM", frame.wheel, "CENTER", 0, 62)
    frame.utilityTooltip:SetFrameLevel(frame:GetFrameLevel() + 40)
    frame.utilityTooltip:Hide()
    frame.utilityTooltip.bg = frame.utilityTooltip:CreateTexture(nil, "BACKGROUND")
    frame.utilityTooltip.bg:SetAllPoints()
    frame.utilityTooltip.bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    frame.utilityTooltip.bg:SetVertexColor(0.02, 0.025, 0.04, 0.88)
    frame.utilityTooltip.title = frame.utilityTooltip:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.utilityTooltip.title:SetPoint("TOP", frame.utilityTooltip, "TOP", 0, -8)
    frame.utilityTooltip.detail = frame.utilityTooltip:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.utilityTooltip.detail:SetPoint("TOP", frame.utilityTooltip.title, "BOTTOM", 0, -4)
    frame.utilityTooltip.detail:SetWidth(202)
    frame.utilityTooltip.detail:SetJustifyH("CENTER")

    ns.ReagentPanel:Create(frame.sideGroup)
    ns.ReagentPanel.frame:SetPoint("RIGHT", frame.wheel, "LEFT", -26, -2)

    ns.UtilityButton:Create(frame.lowerGroup)
    ns.UtilityButton.button:SetPoint("TOP", frame.hintFrame, "BOTTOM", 0, -9)

end

function RouletteFrame:CreateDestinationNodes()
    local wheel = self.frame.wheel
    local destinations = ns.Destinations:GetPlayerDestinations()
    self.nodeButtons = {}
    self.nodeLines = {}

    for index, destination in ipairs(destinations) do
        local button = ns.DestinationNode:Create(wheel, NODE_SIZE)
        local x, y = getPositionForAngle(destination.angleDeg, NODE_RADIUS)
        button:SetPoint("CENTER", wheel, "CENTER", x, y)
        button.destination = destination
        positionNameplateForAngle(button, destination.angleDeg, false)
        self.nodeButtons[index] = button

        local slot = getLinkSlotForAngle(destination.angleDeg)
        local slotTextures = linkTexturesBySlot[slot] or linkTexturesBySlot.top
        local line = wheel:CreateTexture(nil, "ARTWORK")
        line:SetTexture(slotTextures.normal)
        line:SetVertexColor(0.42, 0.62, 1.0, 1)
        line:SetAlpha(0.44)
        setTextureLine(line, wheel, 0, 0, x, y)
        self.nodeLines[index] = line
        ns.DestinationNode:SetLinkedTexture(button, line, slotTextures.normal, slotTextures.hover)
    end
end

function RouletteFrame:CreateKarazhanNode()
    local wheel = self.frame.wheel
    local karazhan = ns.Destinations:GetKarazhanNode()

    self.karazhanButton = ns.DestinationNode:Create(wheel, KARAZHAN_SIZE)
    self.karazhanButton.baseTexture:SetTexture(ns.Media.KARAZHAN_NODE)
    self.karazhanButton.hoverTexture:SetTexture(ns.Media.KARAZHAN_NODE)

    local x, y = getPositionForAngle(KARAZHAN_ANGLE, KARAZHAN_RADIUS)
    self.karazhanButton:SetPoint("CENTER", wheel, "CENTER", x, y)
    self.karazhanButton.destination = karazhan
    positionNameplateForAngle(self.karazhanButton, karazhan.angleDeg, true)

    local karazhanLinkTextures = linkTexturesBySlot.extension_right
    self.karazhanLine = wheel:CreateTexture(nil, "ARTWORK")
    self.karazhanLine:SetTexture(karazhanLinkTextures.normal)
    self.karazhanLine:SetVertexColor(0.42, 0.62, 1.0, 1)
    self.karazhanLine:SetAlpha(0.52)

    local attachX, attachY = getPositionForAngle(KARAZHAN_ANGLE, KARAZHAN_ATTACH_RADIUS)
    setTextureLine(self.karazhanLine, wheel, attachX, attachY, x, y)
    ns.DestinationNode:SetLinkedTexture(self.karazhanButton, self.karazhanLine, karazhanLinkTextures.normal, karazhanLinkTextures.hover)
end

function RouletteFrame:Create()
    self:CreateMainFrame()
    self:CreateWheel()
    self:CreateHeader()
    self:CreateHeaderControls()
    self:CreatePanels()
    self:CreateDestinationNodes()
    self:CreateKarazhanNode()
    self:ApplyScale()
    self:ApplyPosition()
    self:SetMode(ns.db.lastMode or ns.Mode.TELEPORT)
    self.frame:Hide()
end

function RouletteFrame:ApplyScale()
    if self.frame and ns.db then
        self.frame:SetScale(ns.db.uiScale or 1)
    end
end

function RouletteFrame:ApplyPosition()
    if not self.frame or not ns.db then
        return
    end
    self.frame:ClearAllPoints()
    self.frame:SetPoint(ns.db.roulette.point or "CENTER", UIParent, ns.db.roulette.point or "CENTER", ns.db.roulette.x or 0, ns.db.roulette.y or 0)
end

function RouletteFrame:UpdateTabVisuals()
    if not self.frame then
        return
    end
    if self.frame.hintText then
        self.frame.hintText:SetText("|cFFFFCC55Left Click:|r Teleport  \124  |cFF88CCFFRight Click:|r Portal\n|cFF99AABBReagents are shared for all options.|r")
    end
end

function RouletteFrame:SetMode(mode)
    if InCombatLockdown() then
        return
    end

    self.mode = ns.Mode.TELEPORT
    if ns.db then
        ns.db.lastMode = ns.Mode.TELEPORT
    end
    self:UpdateTabVisuals()
    self:UpdateUtilityModeVisuals()
    self:RefreshDestinationNodes()
end

function RouletteFrame:BuildNodeState(destination, faction)
    local teleportSpellID, teleportSpellName = ns.Destinations:GetSpellForMode(destination, ns.Mode.TELEPORT)
    local portalSpellID, portalSpellName = ns.Destinations:GetSpellForMode(destination, ns.Mode.PORTAL)
    local visuals = ns.Destinations:GetVisualsForDestination(destination, faction)
    local icon, _ = ns.Destinations:GetIconForDestination(destination, self.mode)

    -- Visual enabled = spells known AND reagents available (for desaturation/label only;
    -- buttons are always interactable and WoW reports errors naturally).
    local teleportKnown = getSpellKnown(teleportSpellID)
    local portalKnown = getSpellKnown(portalSpellID)
    local teleportReagents = GetItemCount(ns.Constants.ITEM_RUNE_TELEPORTATION, false, false) or 0
    local portalReagents   = GetItemCount(ns.Constants.ITEM_RUNE_PORTALS, false, false) or 0
    local leftSpellName = teleportSpellName
    local rightSpellName = portalSpellName
    local leftActionAvailable = teleportKnown and teleportReagents > 0
    local rightActionAvailable = portalKnown and portalReagents > 0
    local enabled = (teleportKnown and teleportReagents > 0) or (portalKnown and portalReagents > 0)

    local leftLabel = "Teleport"
    local rightLabel = "Portal"
    local teleportMouseButton = "LeftButton"
    local needsTeleportConfirm = ns.db and ns.db.confirmGroupedTeleport and isGrouped()
        and not isTeleportConfirmArmed(self, destination.id, teleportMouseButton)
    if needsTeleportConfirm then
        leftSpellName = ""
        leftActionAvailable = false
    end
    local detail = "Left-click: " .. leftLabel .. " - " .. (leftSpellName or "Unavailable")
        .. "   Right-click: " .. rightLabel .. " - " .. (rightSpellName or "Unavailable")

    return {
        label             = destination.label,
        icon              = icon,
        iconNormalTexture = visuals and visuals.iconNormal or icon,
        iconHoverTexture  = visuals and visuals.iconHover or nil,
        nameplateNormalTexture = visuals and visuals.nameplateNormal or nil,
        nameplateHoverTexture = visuals and visuals.nameplateHover or nil,
        enabled           = enabled,
        tooltipTitle      = destination.label,
        tooltipDetail     = detail,
        teleportSpellName = teleportSpellName or "",
        portalSpellName   = portalSpellName   or "",
        leftSpellName     = leftSpellName or "",
        rightSpellName    = rightSpellName or "",
        leftActionAvailable = leftActionAvailable,
        rightActionAvailable = rightActionAvailable,
        tooltipClickText = "|cFFFFCC55Left-click:|r Teleport   |cFF88CCFFRight-click:|r Portal",
        isKarazhan = false,
    }
end

StaticPopupDialogs = StaticPopupDialogs or {}
StaticPopupDialogs.PORTALROULETTE_CONFIRM_TELEPORT = {
    text = "Teleport to %s while grouped?",
    button1 = YES,
    button2 = NO,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    OnAccept = function(_, data)
        if ns.RouletteFrame then
            ns.RouletteFrame.teleportConfirmDestination = data.destinationID
            ns.RouletteFrame.teleportConfirmButton = data.mouseButton
            ns.RouletteFrame.teleportConfirmExpires = GetTime() + 8
            ns.RouletteFrame:RefreshDestinationNodes()
            ns.Print("Teleport armed for " .. data.label .. ". Click again to cast.")
        end
    end,
}

function RouletteFrame:HandleDestinationMouseUp(button, mouseButton)
    if not button or not button.destination or not ns.db or not ns.db.confirmGroupedTeleport or not isGrouped() then
        return
    end
    local teleportMouseButton = "LeftButton"
    if mouseButton ~= teleportMouseButton then
        return
    end
    if isTeleportConfirmArmed(self, button.destination.id, mouseButton) then
        return
    end
    if StaticPopup_Show then
        StaticPopup_Show("PORTALROULETTE_CONFIRM_TELEPORT", button.destination.label, nil, {
            destinationID = button.destination.id,
            mouseButton = mouseButton,
            label = button.destination.label,
        })
    end
end

function RouletteFrame:BuildKarazhanState(faction)
    local hasAtiesh = ns.UtilityItems:HasItem(ns.Constants.ITEM_ATIESH)
    local showDisabled = ns.db.showUnavailableKarazhan
    if (not hasAtiesh) and (not showDisabled) then
        return nil, false
    end

    local enabled = hasAtiesh
    local detail = enabled and "Use Atiesh to open a portal to Karazhan." or "Requires Atiesh."
    local karazhanDestination = ns.Destinations:GetKarazhanNode()
    local visuals = ns.Destinations:GetVisualsForDestination(karazhanDestination, faction)
    local icon, _ = ns.Destinations:GetIconForDestination(karazhanDestination, self.mode)

    return {
        label           = "Karazhan",
        icon            = icon,
        iconNormalTexture = visuals and visuals.iconNormal or icon,
        iconHoverTexture = visuals and visuals.iconHover or nil,
        nameplateNormalTexture = visuals and visuals.nameplateNormal or nil,
        nameplateHoverTexture = visuals and visuals.nameplateHover or nil,
        enabled         = enabled,
        tooltipTitle    = "Karazhan (Atiesh only)",
        tooltipDetail   = detail,
        rightMacroText  = "/use item:" .. ns.Constants.ITEM_ATIESH,
        teleportSpellName = "",
        portalSpellName   = "",
        leftActionAvailable = false,
        rightActionAvailable = enabled,
        tooltipClickText = "|cFF777777Left-click:|r No teleport   |cFF88CCFFRight-click:|r Portal",
        isKarazhan = true,
        normalTexture   = ns.Media.KARAZHAN_NODE,
        disabledTexture = ns.Media.KARAZHAN_NODE,
        disableActions  = not enabled,
    }, true
end

function RouletteFrame:RefreshDestinationNodes()
    if not self.frame then
        return
    end

    local faction = ns.Destinations:GetPlayerFaction()
    self.factionAccent:SetTexture((faction == ns.Constants.FACTION_HORDE) and ns.Media.FACTION_HORDE or ns.Media.FACTION_ALLIANCE)

    for _, button in ipairs(self.nodeButtons) do
        local state = self:BuildNodeState(button.destination, faction)
        ns.DestinationNode:ApplyState(button, state)
    end

    local karazhanState, shouldShowKarazhan = self:BuildKarazhanState(faction)
    self.karazhanButton:SetShown(shouldShowKarazhan)
    self.karazhanLine:SetShown(shouldShowKarazhan)
    if shouldShowKarazhan and karazhanState then
        ns.DestinationNode:ApplyState(self.karazhanButton, karazhanState)
    end
end

function RouletteFrame:RebuildDestinations()
    if not self.frame or not self.nodeButtons then
        return
    end
    local destinations = ns.Destinations:GetPlayerDestinations()
    for index, button in ipairs(self.nodeButtons) do
        button.destination = destinations[index]
    end
    self:RefreshDestinationNodes()
end

function RouletteFrame:ShowCastBar(info, startMS, endMS)
    if not self.frame or not self.frame.castBar then
        return
    end
    local startTime = (startMS and startMS / 1000) or GetTime()
    local endTime = (endMS and endMS / 1000) or (startTime + 1.5)
    self.castBarStart = startTime
    self.castBarEnd = endTime
    self.frame.castBar.text:SetText((info.spellName or "Casting") .. " - " .. (info.destination or ""))
    self.frame.castBar:Show()
    self:UpdateCastBar()
end

function RouletteFrame:UpdateCastBar()
    if not self.frame or not self.frame.castBar or not self.castBarStart or not self.castBarEnd then
        return
    end
    local duration = math.max(self.castBarEnd - self.castBarStart, 0.01)
    local progress = math.min(math.max((GetTime() - self.castBarStart) / duration, 0), 1)
    self.frame.castBar.fill:SetWidth(math.max(1, 284 * progress))
end

function RouletteFrame:HideCastBar()
    if self.frame and self.frame.castBar then
        self.frame.castBar:Hide()
    end
    self.castBarStart = nil
    self.castBarEnd = nil
end

function RouletteFrame:UpdateUtilityTooltip()
    if not self.frame or not self.frame.utilityTooltip or not self.frame.centerUtilityButton then
        return
    end
    local button = self.frame.centerUtilityButton
    self.frame.utilityTooltip.title:SetText(button.tooltipTitle or "Utility")
    self.frame.utilityTooltip.detail:SetText(button.tooltipDetail or "")
end

function RouletteFrame:ShowUtilityTooltip()
    if not self.frame or not self.frame.utilityTooltip then
        return
    end
    self:UpdateUtilityTooltip()
    self.frame.utilityTooltip:Show()
end

function RouletteFrame:HideUtilityTooltip()
    if self.frame and self.frame.utilityTooltip then
        self.frame.utilityTooltip:Hide()
    end
end

function RouletteFrame:RefreshCenterUtility()
    if not self.frame or not self.frame.centerUtilityButton or not ns.db then
        return
    end

    local centerButton = self.frame.centerUtilityButton
    local source = ns.UtilityItems:GetSourceForMode(ns.db.utilityMode)
    local enabled = source and source.available and true or false
    local cooldownStart, cooldownDuration, cooldownActive = getUtilityCooldown(source)

    centerButton:Show()
    centerButton:EnableMouse(true)
    centerButton.utilityEnabled = enabled
    centerButton.tooltipTitle = (source and source.label) or "Hearthstone"
    if source and source.itemID == ns.Constants.ITEM_HEARTHSTONE and GetBindLocation then
        local bindLocation = GetBindLocation()
        centerButton.tooltipDetail = bindLocation and ("Teleport to " .. bindLocation .. ".") or "Hearthstone bind location unavailable."
    else
        centerButton.tooltipDetail = enabled and "Click to use selected utility." or "Selected utility is unavailable."
    end
    if cooldownActive then
        centerButton.tooltipDetail = (centerButton.tooltipDetail or "") .. "\nOn cooldown."
    end
    centerButton:SetAlpha(enabled and 1 or 0.55)
    setCooldown(centerButton.cooldown, cooldownStart, cooldownDuration, cooldownActive)
    if not (InCombatLockdown and InCombatLockdown()) then
        if enabled and not cooldownActive then
            centerButton:Enable()
        else
            centerButton:Disable()
        end
    end
    local normalTex = centerButton:GetNormalTexture()
    local highlightTex = centerButton:GetHighlightTexture()
    if cooldownActive then
        if normalTex then normalTex:SetVertexColor(0.45, 0.45, 0.55, 1) end
        if highlightTex then highlightTex:SetAlpha(0) end
        centerButton.cooldown:Show()
        if centerButton.cooldownText then
            local remaining = math.max(0, (cooldownStart + cooldownDuration) - GetTime())
            if remaining >= 60 then
                centerButton.cooldownText:SetText(math.ceil(remaining / 60) .. "m")
            else
                centerButton.cooldownText:SetText(math.ceil(remaining))
            end
            centerButton.cooldownText:Show()
        end
    else
        if normalTex then normalTex:SetVertexColor(1, 1, 1, 1) end
        if highlightTex then highlightTex:SetAlpha(0.9) end
        centerButton.cooldown:Hide()
        if centerButton.cooldownText then
            centerButton.cooldownText:Hide()
        end
    end

    if not enabled or cooldownActive then
        source = nil
    end

    local applied = applySecureUtilityAction(centerButton, source)
    if not applied then
        centerButton.pendingMacroText = source
    else
        centerButton.pendingMacroText = nil
    end
    if centerButton:IsMouseOver() then
        self:UpdateUtilityTooltip()
    end
end

function RouletteFrame:UpdateUtilityModeVisuals()
    if not self.frame then
        return
    end

    if ns.UtilityButton and ns.UtilityButton.button then
        ns.UtilityButton.button:Hide()
    end

    if self.centerCore then
        self.centerCore:SetAlpha(0)
    end

    self:RefreshCenterUtility()
end

function RouletteFrame:RefreshAll()
    if not self.frame then
        return
    end
    self:ApplyScale()
    self:UpdateTabVisuals()
    self:UpdateUtilityModeVisuals()
    self:RefreshDestinationNodes()
    self:RefreshCenterUtility()
    ns.ReagentPanel:Refresh()
    ns.UtilityButton:Refresh()
end

function RouletteFrame:IsShown()
    return self.frame and self.frame:IsShown()
end

function RouletteFrame:Open(mode)
    local wasShown = self:IsShown()
    if not self.frame then
        self:Create()
    end
    if InCombatLockdown() then
        ns.Print("Cannot open roulette in combat.")
        if ns.Sound then
            ns.Sound:Play("Error")
        end
        return
    end
    if mode then
        self:SetMode(mode)
    end
    self.frame:Show()
    if not wasShown and ns.Sound then
        ns.Sound:Play("Open")
    end
end

function RouletteFrame:Close()
    if not self.frame or not self.frame:IsShown() then
        return
    end
    if ns.Sound then
        ns.Sound:Play("Close")
    end

    self:PlayClosePresentation(function()
        if self.frame then
            self.frame:Hide()
            self.frame:SetAlpha(1)
            self.frame:SetScale(ns.db and (ns.db.uiScale or 1) or 1)
            self.frame.wheel:SetScale(1)
            self.frame.headerGroup:SetScale(1)
            self.frame.sideGroup:SetScale(1)
            self.frame.lowerGroup:SetScale(1)
        end
    end)
end

function RouletteFrame:Toggle(mode)
    if self:IsShown() then
        self:Close()
    else
        self:Open(mode)
    end
end

function RouletteFrame:Initialize()
    if not ns.isMage then
        return
    end
    self:Create()
end
