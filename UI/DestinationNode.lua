local _, ns = ...

local DestinationNode = {}
ns.DestinationNode = DestinationNode

local function clearAction(button)
    if InCombatLockdown() then
        return false
    end

    button:SetAttribute("type", nil)
    button:SetAttribute("type1", nil)
    button:SetAttribute("type2", nil)
    button:SetAttribute("spell", nil)
    button:SetAttribute("spell1", nil)
    button:SetAttribute("spell2", nil)
    button:SetAttribute("macrotext", nil)
    button:SetAttribute("macrotext1", nil)
    button:SetAttribute("macrotext2", nil)
    return true
end

local function animationIntensity()
    local value = tonumber(ns.db and ns.db.animationIntensity) or 1
    if value < 0 then
        return 0
    elseif value > 1 then
        return 1
    end
    return value
end

local function customAnimationEnabled(setting)
    local db = ns.db or {}
    if db.animationsEnabled == false then
        return false
    end
    if setting and db[setting] == false then
        return false
    end
    return animationIntensity() > 0
end

local function animateNodeScale(button, targetScale, duration)
    if not ns.Animations or not ns.Animations.Play or not button or not button.GetScale then
        if button and button.SetScale then
            button:SetScale(targetScale)
        end
        return
    end
    ns.Animations:Play(button, button:GetAlpha(), button:GetAlpha(), button:GetScale(), targetScale, duration or 0.1)
end

local function pulseNode(button)
    if not ns.Animations or not ns.Animations.Pulse or not button then
        return
    end
    ns.Animations:Pulse(button, button:GetScale() * (1 + (0.035 * animationIntensity())), 0.14)
end

local function flashLink(button)
    if not button or not button.linkTexture or not ns.Animations or not ns.Animations.Play then
        return
    end

    local texture = button.linkTexture
    local normalAlpha = button.linkNormalAlpha or 0.62
    ns.Animations:Play(texture, texture:GetAlpha(), 0.95, 1, 1, 0.06, function()
        local targetAlpha = normalAlpha
        if button.IsMouseOver and button:IsMouseOver() and button.visualEnabled then
            targetAlpha = 0.84
        end
        ns.Animations:Play(texture, texture:GetAlpha(), targetAlpha, 1, 1, 0.12)
    end)
end

local function setMacroAction(button, macroText)
    if not clearAction(button) then
        return false
    end

    if macroText and macroText ~= "" then
        button:SetAttribute("type", "macro")
        button:SetAttribute("macrotext", macroText)
        button:SetAttribute("type1", "macro")
        button:SetAttribute("macrotext1", macroText)
        button:SetAttribute("type2", "macro")
        button:SetAttribute("macrotext2", macroText)
    end
    return true
end

local function setSpellActions(button, leftSpellName, rightSpellName)
    if not clearAction(button) then
        return false
    end

    local hasLeft = leftSpellName and leftSpellName ~= ""
    local hasRight = rightSpellName and rightSpellName ~= ""

    if hasLeft then
        button:SetAttribute("type", "spell")
        button:SetAttribute("spell", leftSpellName)
        button:SetAttribute("type1", "spell")
        button:SetAttribute("spell1", leftSpellName)
    end

    if hasRight then
        button:SetAttribute("type2", "spell")
        button:SetAttribute("spell2", rightSpellName)
        if not hasLeft then
            button:SetAttribute("type", "spell")
            button:SetAttribute("spell", rightSpellName)
        end
    end

    return true
end

local function setRightMacroAction(button, macroText)
    if not clearAction(button) then
        return false
    end

    if macroText and macroText ~= "" then
        button:SetAttribute("type2", "macro")
        button:SetAttribute("macrotext2", macroText)
    end
    return true
end

local function applyHoverState(button, isHover)
    if isHover and button.visualEnabled then
        button.hoverTexture:SetAlpha(0.5)
        if button.iconHoverTexture and button.iconHoverTexturePath then
            button.iconHoverTexture:SetAlpha(1)
        end
        if button.nameplateHoverTexture and button.nameplateHoverTexturePath then
            button.nameplateHoverTexture:SetAlpha(1)
        end
        if button.linkTexture and button.linkHoverTexturePath then
            button.linkTexture:SetTexture(button.linkHoverTexturePath)
            button.linkTexture:SetVertexColor(0.58, 0.78, 1.0, 1)
            button.linkTexture:SetAlpha(0.78)
            if customAnimationEnabled("hoverAnimationsEnabled") then
                ns.Animations:Play(button.linkTexture, 0.78, 0.84, 1, 1, 0.12)
            end
        end
        if customAnimationEnabled("hoverAnimationsEnabled") then
            local scaleUp = 1 + (0.045 * animationIntensity())
            if button.isKarazhanNode then
                scaleUp = 1 + (0.035 * animationIntensity())
            end
            animateNodeScale(button, scaleUp, 0.12)
        end
    else
        button.hoverTexture:SetAlpha(0)
        if button.iconHoverTexture then
            button.iconHoverTexture:SetAlpha(0)
        end
        if button.nameplateHoverTexture then
            button.nameplateHoverTexture:SetAlpha(0)
        end
        if button.linkTexture and button.linkNormalTexturePath then
            button.linkTexture:SetTexture(button.linkNormalTexturePath)
            button.linkTexture:SetVertexColor(0.54, 0.70, 1.0, 1)
            if customAnimationEnabled("hoverAnimationsEnabled") then
                ns.Animations:Play(button.linkTexture, button.linkTexture:GetAlpha(), button.linkNormalAlpha or 0.62, 1, 1, 0.1)
            else
                button.linkTexture:SetAlpha(button.linkNormalAlpha or 0.62)
            end
        end
        if customAnimationEnabled("hoverAnimationsEnabled") then
            animateNodeScale(button, 1, 0.1)
        elseif button.SetScale then
            button:SetScale(1)
        end
    end
end

function DestinationNode:Create(parent, size)
    local buttonSize = size or 64
    local iconSize = math.max(buttonSize - 8, 34)
    local button = CreateFrame("Button", nil, parent, "SecureActionButtonTemplate")
    button:SetSize(buttonSize, buttonSize)
    button:RegisterForClicks("AnyDown", "AnyUp")
    button:EnableMouse(true)

    button.baseTexture = button:CreateTexture(nil, "BACKGROUND")
    button.baseTexture:SetAllPoints()
    button.baseTexture:SetTexture(ns.Media.NODE_NORMAL)

    button.iconTexture = button:CreateTexture(nil, "ARTWORK")
    button.iconTexture:SetSize(iconSize, iconSize)
    button.iconTexture:SetPoint("CENTER", button, "CENTER", 0, 1)
    button.iconTexture:SetAlpha(0)

    button.iconHoverTexture = button:CreateTexture(nil, "OVERLAY")
    button.iconHoverTexture:SetSize(iconSize, iconSize)
    button.iconHoverTexture:SetPoint("CENTER", button, "CENTER", 0, 1)
    button.iconHoverTexture:SetAlpha(0)

    button.nameplateTexture = button:CreateTexture(nil, "BORDER")
    button.nameplateTexture:SetSize(118, 30)
    button.nameplateTexture:SetAlpha(0)

    button.nameplateHoverTexture = button:CreateTexture(nil, "OVERLAY")
    button.nameplateHoverTexture:SetSize(118, 30)
    button.nameplateHoverTexture:SetAlpha(0)

    button.hoverTexture = button:CreateTexture(nil, "OVERLAY")
    button.hoverTexture:SetAllPoints()
    button.hoverTexture:SetTexture(ns.Media.NODE_HOVER)
    button.hoverTexture:SetBlendMode("ADD")
    button.hoverTexture:SetAlpha(0)

    button.tooltipTitle = nil
    button.tooltipDetail = nil
    button.teleportSpellName = nil
    button.portalSpellName = nil
    button.portalMacroText = nil
    button.leftSpellName = nil
    button.rightSpellName = nil
    button.leftActionAvailable = false
    button.rightActionAvailable = false
    button.isKarazhanNode = false
    button.visualEnabled = true
    button.linkTexture = nil
    button.linkNormalTexturePath = nil
    button.linkHoverTexturePath = nil
    button.linkNormalAlpha = 0.62
    button.iconHoverTexturePath = nil
    button.nameplateHoverTexturePath = nil

    button:SetScript("OnEnter", function(self)
        applyHoverState(self, true)
        if ns.Sound and self.visualEnabled then
            if self.isKarazhanNode then
                ns.Sound:Play("KarazhanHover", { hover = true })
            else
                ns.Sound:Play("NodeHover", { hover = true })
            end
        end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.tooltipTitle or "", 0.95, 0.97, 1)
        if self.tooltipDetail and self.tooltipDetail ~= "" then
            GameTooltip:AddLine(self.tooltipDetail, 0.78, 0.82, 0.92, true)
        end
        GameTooltip:AddLine(self.tooltipClickText or "|cFFFFCC55Left-click:|r Teleport   |cFF88CCFFRight-click:|r Portal", 0.68, 0.68, 0.68)
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function()
        applyHoverState(button, false)
        GameTooltip:Hide()
    end)

    button:SetScript("OnMouseUp", function(self, mouseButton)
        if ns.RouletteFrame and ns.RouletteFrame.HandleDestinationMouseUp then
            ns.RouletteFrame:HandleDestinationMouseUp(self, mouseButton)
        end
        if self.visualEnabled and customAnimationEnabled("clickPulseEnabled") then
            pulseNode(self)
            flashLink(self)
        end
    end)

    return button
end

function DestinationNode:SetLinkedTexture(button, texture, normalPath, hoverPath)
    button.linkTexture = texture
    button.linkNormalTexturePath = normalPath
    button.linkHoverTexturePath = hoverPath
    if texture and normalPath then
        texture:SetTexture(normalPath)
        button.linkNormalAlpha = texture:GetAlpha()
    end
end

function DestinationNode:SetNameplateAnchor(button, point, relativePoint, x, y, width, height)
    button.nameplateTexture:ClearAllPoints()
    button.nameplateHoverTexture:ClearAllPoints()
    button.nameplateTexture:SetPoint(point, button, relativePoint, x or 0, y or 0)
    button.nameplateHoverTexture:SetPoint(point, button, relativePoint, x or 0, y or 0)
    if width and height then
        button.nameplateTexture:SetSize(width, height)
        button.nameplateHoverTexture:SetSize(width, height)
    end
end

function DestinationNode:ApplyState(button, state)
    button.teleportSpellName = state.teleportSpellName or ""
    button.portalSpellName   = state.portalSpellName   or ""
    button.portalMacroText   = state.portalMacroText   or ""
    button.leftSpellName     = state.leftSpellName or button.teleportSpellName
    button.rightSpellName    = state.rightSpellName or button.portalSpellName
    button.leftActionAvailable = state.leftActionAvailable and true or false
    button.rightActionAvailable = state.rightActionAvailable and true or false
    button.isKarazhanNode = state.isKarazhan and true or false

    local applied
    if state.disableActions then
        applied = setMacroAction(button, nil)
    elseif state.rightMacroText then
        applied = setRightMacroAction(button, state.rightMacroText)
    elseif state.karazhanMacro then
        applied = setMacroAction(button, state.karazhanMacro)
    else
        applied = setSpellActions(button, button.leftSpellName, button.rightSpellName)
    end

    if not applied then
        button.pendingState = state
        return false
    end

    button.pendingState = nil
    button.visualEnabled = (state.enabled and not state.disableActions) and true or false
    button.tooltipTitle  = state.tooltipTitle or state.label or ""
    button.tooltipDetail = state.tooltipDetail
    button.tooltipClickText = state.tooltipClickText
    applyHoverState(button, false)

    if state.iconNormalTexture or state.icon then
        button.iconTexture:SetTexture(state.iconNormalTexture or state.icon)
        button.iconTexture:SetTexCoord(0, 1, 0, 1)
        button.iconTexture:SetAlpha(1)
    else
        button.iconTexture:SetTexture(nil)
        button.iconTexture:SetAlpha(0)
    end

    if state.iconHoverTexture then
        button.iconHoverTexture:SetTexture(state.iconHoverTexture)
        button.iconHoverTexturePath = state.iconHoverTexture
        button.iconHoverTexture:SetAlpha(0)
    else
        button.iconHoverTexture:SetTexture(nil)
        button.iconHoverTexturePath = nil
        button.iconHoverTexture:SetAlpha(0)
    end

    if state.nameplateNormalTexture then
        button.nameplateTexture:SetTexture(state.nameplateNormalTexture)
        button.nameplateTexture:SetAlpha(1)
    else
        button.nameplateTexture:SetTexture(nil)
        button.nameplateTexture:SetAlpha(0)
    end

    if state.nameplateHoverTexture then
        button.nameplateHoverTexture:SetTexture(state.nameplateHoverTexture)
        button.nameplateHoverTexturePath = state.nameplateHoverTexture
        button.nameplateHoverTexture:SetAlpha(0)
    else
        button.nameplateHoverTexture:SetTexture(nil)
        button.nameplateHoverTexturePath = nil
        button.nameplateHoverTexture:SetAlpha(0)
    end

    button:Enable()

    if button.visualEnabled then
        button.baseTexture:SetTexture(state.normalTexture or ns.Media.NODE_NORMAL)
        button.baseTexture:SetVertexColor(1, 1, 1, 1)
        button.iconTexture:SetDesaturated(false)
        button.nameplateTexture:SetDesaturated(false)
        button.iconTexture:SetAlpha(1)
        button.nameplateTexture:SetAlpha(state.nameplateNormalTexture and 1 or 0)
    else
        button.baseTexture:SetTexture(state.normalTexture or ns.Media.NODE_NORMAL)
        button.baseTexture:SetVertexColor(0.72, 0.72, 0.78, 0.68)
        button.iconTexture:SetDesaturated(false)
        button.nameplateTexture:SetDesaturated(false)
        button.iconTexture:SetAlpha(0.56)
        button.nameplateTexture:SetAlpha(state.nameplateNormalTexture and 0.62 or 0)
    end

    return true
end
