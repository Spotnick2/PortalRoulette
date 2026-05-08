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

local function setTeleportAction(button, teleportSpellName)
    if not clearAction(button) then
        return false
    end

    if teleportSpellName and teleportSpellName ~= "" then
        button:SetAttribute("type", "spell")
        button:SetAttribute("spell", teleportSpellName)
    end

    return true
end

local function applyHoverState(button, isHover)
    if isHover and button.visualEnabled then
        button.hoverTexture:SetAlpha(0.8)
        if button.iconHoverTexture and button.iconHoverTexturePath then
            button.iconHoverTexture:SetAlpha(1)
        end
        if button.nameplateHoverTexture and button.nameplateHoverTexturePath then
            button.nameplateHoverTexture:SetAlpha(1)
        end
        if button.linkTexture and button.linkHoverTexturePath then
            button.linkTexture:SetTexture(button.linkHoverTexturePath)
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
        end
    end
end

function DestinationNode:Create(parent, size)
    local button = CreateFrame("Button", nil, parent, "SecureActionButtonTemplate")
    button:SetSize(size or 64, size or 64)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:EnableMouse(true)

    button.baseTexture = button:CreateTexture(nil, "BACKGROUND")
    button.baseTexture:SetAllPoints()
    button.baseTexture:SetTexture(ns.Media.NODE_NORMAL)

    button.iconTexture = button:CreateTexture(nil, "ARTWORK")
    button.iconTexture:SetSize(56, 56)
    button.iconTexture:SetPoint("CENTER", button, "CENTER", 0, 1)
    button.iconTexture:SetAlpha(0)

    button.iconHoverTexture = button:CreateTexture(nil, "OVERLAY")
    button.iconHoverTexture:SetSize(56, 56)
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
    button.leftActionAvailable = false
    button.rightActionAvailable = false
    button.isKarazhanNode = false
    button.visualEnabled = true
    button.linkTexture = nil
    button.linkNormalTexturePath = nil
    button.linkHoverTexturePath = nil
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
        GameTooltip:AddLine("|cFFFFCC55Left-click:|r Teleport   |cFF88CCFFRight-click:|r Portal", 0.68, 0.68, 0.68)
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function()
        applyHoverState(button, false)
        GameTooltip:Hide()
    end)

    button:SetScript("OnClick", function(self, mouseButton)
        if mouseButton == "RightButton" then
            if self.rightActionAvailable and ns.Sound then
                ns.Sound:Play("NodeClick")
            elseif ns.Sound then
                ns.Sound:Play("Error")
            end

            if InCombatLockdown() then
                return
            end

            if self.portalSpellName and self.portalSpellName ~= "" then
                CastSpellByName(self.portalSpellName)
            elseif self.portalMacroText and self.portalMacroText ~= "" then
                RunMacroText(self.portalMacroText)
            end
        elseif mouseButton == "LeftButton" then
            if self.leftActionAvailable and ns.Sound then
                ns.Sound:Play("NodeClick")
            elseif ns.Sound then
                ns.Sound:Play("Error")
            end
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
    button.leftActionAvailable = state.leftActionAvailable and true or false
    button.rightActionAvailable = state.rightActionAvailable and true or false
    button.isKarazhanNode = state.isKarazhan and true or false

    local applied
    if state.disableActions then
        applied = setMacroAction(button, nil)
    elseif state.karazhanMacro then
        applied = setMacroAction(button, state.karazhanMacro)
    else
        applied = setTeleportAction(button, button.teleportSpellName)
    end

    if not applied then
        button.pendingState = state
        return false
    end

    button.pendingState = nil
    button.visualEnabled = (state.enabled and not state.disableActions) and true or false
    button.tooltipTitle  = state.tooltipTitle or state.label or ""
    button.tooltipDetail = state.tooltipDetail
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
    else
        button.baseTexture:SetTexture(state.disabledTexture or state.normalTexture or ns.Media.NODE_DISABLED)
        button.baseTexture:SetVertexColor(1, 1, 1, 0.68)
        button.iconTexture:SetDesaturated(true)
        button.nameplateTexture:SetDesaturated(true)
    end

    return true
end
