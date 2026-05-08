local _, ns = ...

local UtilityButton = {}
ns.UtilityButton = UtilityButton

-- Final-pack assets are 2172x724 (3:1) for the button and 1254x1254 for the orb.
-- Display sizes preserve aspect ratio.
local BUTTON_W, BUTTON_H = 420, 140
local ORB_SIZE = 156

local function applySecureMacro(button, action)
    if InCombatLockdown() then
        return false
    end
    button:SetAttribute("type", nil)
    button:SetAttribute("item", nil)
    button:SetAttribute("macrotext", nil)
    if not action then
        return true
    end
    if action.type == "macro" and action.value then
        button:SetAttribute("type", "macro")
        button:SetAttribute("macrotext", action.value)
    elseif action.type == "item" and action.value then
        button:SetAttribute("type", "item")
        button:SetAttribute("item", action.value)
    end
    return true
end

local function setOrbState(button, state)
    if not button.orb then
        return
    end
    if state == "pressed" then
        button.orb:SetTexture(ns.Media.HEARTHSTONE_ORB_PRESSED)
    elseif state == "hover" then
        button.orb:SetTexture(ns.Media.HEARTHSTONE_ORB_HOVER)
    else
        button.orb:SetTexture(ns.Media.HEARTHSTONE_ORB_NORMAL)
    end
end

function UtilityButton:Create(parent)
    local button = CreateFrame("Button", nil, parent, "SecureActionButtonTemplate")
    button:SetSize(BUTTON_W, BUTTON_H)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:EnableMouse(true)

    -- Standard button state textures (frame art).
    button:SetNormalTexture(ns.Media.HEARTHSTONE_BUTTON_NORMAL)
    button:SetHighlightTexture(ns.Media.HEARTHSTONE_BUTTON_HOVER, "BLEND")
    button:SetPushedTexture(ns.Media.HEARTHSTONE_BUTTON_PRESSED)
    button:SetDisabledTexture(ns.Media.HEARTHSTONE_BUTTON_NORMAL)

    local n = button:GetNormalTexture(); if n then n:SetAlpha(1) end
    local h = button:GetHighlightTexture(); if h then h:SetAlpha(0.6) end
    local p = button:GetPushedTexture(); if p then p:SetAlpha(1) end
    local d = button:GetDisabledTexture(); if d then d:SetDesaturated(true); d:SetAlpha(0.6) end

    -- Orb on the left of the button. The art is square but visually round; we
    -- size it slightly larger than the button height so it overhangs and
    -- reads as a prominent interactive element.
    button.orb = button:CreateTexture(nil, "OVERLAY")
    button.orb:SetSize(ORB_SIZE, ORB_SIZE)
    button.orb:SetPoint("LEFT", button, "LEFT", -8, 0)
    button.orb:SetTexture(ns.Media.HEARTHSTONE_ORB_NORMAL)

    button.tooltipDetail = nil
    button.pendingAction = nil

    button:SetScript("OnEnter", function(self)
        setOrbState(self, "hover")
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(self.tooltipTitle or "Utility", 0.95, 0.97, 1)
        if self.tooltipDetail then
            GameTooltip:AddLine(self.tooltipDetail, 0.82, 0.86, 0.95, true)
        end
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function(self)
        setOrbState(self, "normal")
        GameTooltip:Hide()
    end)

    button:SetScript("OnMouseDown", function(self)
        setOrbState(self, "pressed")
    end)

    button:SetScript("OnMouseUp", function(self)
        if self:IsMouseOver() then
            setOrbState(self, "hover")
        else
            setOrbState(self, "normal")
        end
    end)

    button:SetScript("PostClick", function()
        if ns.db and ns.db.utilityMode == ns.UtilityMode.RANDOM and not InCombatLockdown() then
            UtilityButton:Refresh()
        end
    end)

    self.button = button
    self:Refresh()
    return button
end

function UtilityButton:Refresh()
    local button = self.button
    if not button or not ns.db then
        return
    end

    local source = ns.UtilityItems:GetSourceForMode(ns.db.utilityMode)
    local enabled = source and source.available and true or false

    if source and source.label then
        button.tooltipTitle = source.label
    else
        button.tooltipTitle = "Hearthstone"
    end
    button.tooltipDetail = enabled and "Click to use selected utility." or "Selected utility is unavailable."

    local action
    if source and source.macro then
        action = { type = "macro", value = source.macro }
    end

    -- Always set the macro even when unavailable so the button always fires.
    -- WoW's own cast system reports errors (item not in bags, etc.) naturally.
    local applied = applySecureMacro(button, action)
    if not applied then
        button.pendingAction = action
    else
        button.pendingAction = nil
    end

    -- Never disable — keep the button interactable.
    setOrbState(button, "normal")
end

function UtilityButton:ApplyPendingAction()
    local button = self.button
    if not button or not button.pendingAction then
        return
    end
    if applySecureMacro(button, button.pendingAction) then
        button.pendingAction = nil
    end
end
