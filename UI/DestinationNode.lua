local _, ns = ...

local DestinationNode = {}
ns.DestinationNode = DestinationNode

-- Set the LEFT-CLICK (teleport) secure attribute. Only the default "type"/"spell"
-- pair is used — numbered attributes (type1, type2) are unreliable in TBC Classic
-- Anniversary. Right-click portal is handled via OnClick below.
local function setTeleportAction(button, spellName)
    if InCombatLockdown() then
        return false
    end
    button:SetAttribute("type", nil)
    button:SetAttribute("spell", nil)
    button:SetAttribute("macrotext", nil)
    if spellName and spellName ~= "" then
        button:SetAttribute("type", "spell")
        button:SetAttribute("spell", spellName)
    end
    return true
end

local function setMacroAction(button, macroText)
    if InCombatLockdown() then
        return false
    end
    button:SetAttribute("type", nil)
    button:SetAttribute("spell", nil)
    button:SetAttribute("macrotext", nil)
    if macroText and macroText ~= "" then
        button:SetAttribute("type", "macro")
        button:SetAttribute("macrotext", macroText)
    end
    return true
end

function DestinationNode:Create(parent, size)
    local button = CreateFrame("Button", nil, parent, "SecureActionButtonTemplate")
    button:SetSize(size or 64, size or 64)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:EnableMouse(true)

    -- Left click → teleport (via SecureActionButtonTemplate type/spell attribute)
    -- Right click → portal (via OnClick CastSpellByName, safe out-of-combat)
    -- Addon can only be opened out of combat so right-click path is always available.
    button:SetScript("OnClick", function(self, mouseButton)
        if mouseButton == "RightButton" and not InCombatLockdown() then
            if self.portalSpellName and self.portalSpellName ~= "" then
                CastSpellByName(self.portalSpellName)
            elseif self.portalMacroText and self.portalMacroText ~= "" then
                -- Karazhan / Atiesh path uses the macro for both clicks already;
                -- right-click here is a no-op since SecureHandler covers it.
            end
        end
    end)

    button.baseTexture = button:CreateTexture(nil, "BACKGROUND")
    button.baseTexture:SetAllPoints()
    button.baseTexture:SetTexture(ns.Media.NODE_NORMAL)

    button.iconTexture = button:CreateTexture(nil, "ARTWORK")
    button.iconTexture:SetSize(40, 40)
    button.iconTexture:SetPoint("CENTER", button, "CENTER", 0, 1)
    button.iconTexture:SetAlpha(0)

    button.hoverTexture = button:CreateTexture(nil, "OVERLAY")
    button.hoverTexture:SetAllPoints()
    button.hoverTexture:SetTexture(ns.Media.NODE_HOVER)
    button.hoverTexture:SetBlendMode("ADD")
    button.hoverTexture:SetAlpha(0)

    button.labelBackdrop = button:CreateTexture(nil, "BORDER")
    button.labelBackdrop:SetTexture("Interface\\Buttons\\WHITE8X8")
    button.labelBackdrop:SetVertexColor(0.03, 0.04, 0.09, 0.7)
    button.labelBackdrop:SetSize(104, 15)

    button.label = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    button.label:SetPoint("TOP", button, "BOTTOM", 0, -6)
    button.label:SetWidth(100)
    button.label:SetJustifyH("CENTER")
    button.labelBackdrop:SetPoint("CENTER", button.label, "CENTER")

    button.tooltipTitle = nil
    button.tooltipDetail = nil
    button.teleportSpellName = nil
    button.portalSpellName = nil
    button.portalMacroText = nil
    button.visualEnabled = true

    button:SetScript("OnEnter", function(self)
        if self.visualEnabled then
            self.hoverTexture:SetAlpha(0.85)
        end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.tooltipTitle or self.label:GetText() or "", 0.95, 0.97, 1)
        if self.tooltipDetail and self.tooltipDetail ~= "" then
            GameTooltip:AddLine(self.tooltipDetail, 0.78, 0.82, 0.92, true)
        end
        GameTooltip:AddLine("|cFFFFCC55Left-click:|r Teleport   |cFF88CCFFRight-click:|r Portal", 0.68, 0.68, 0.68)
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function()
        button.hoverTexture:SetAlpha(0)
        GameTooltip:Hide()
    end)

    return button
end

function DestinationNode:ApplyState(button, state)
    -- Always keep the button interactable. WoW's own cast system will report
    -- errors (no reagent, spell not learned, etc.) naturally.
    button.teleportSpellName = state.teleportSpellName or ""
    button.portalSpellName   = state.portalSpellName   or ""
    button.portalMacroText   = state.portalMacroText   or ""

    local applied
    if state.karazhanMacro then
        -- Karazhan: macro fires for left-click (no teleport exists); right-click
        -- is handled by the same macro via SecureActionButtonTemplate.
        applied = setMacroAction(button, state.karazhanMacro)
    else
        applied = setTeleportAction(button, state.teleportSpellName)
    end

    if not applied then
        button.pendingState = state
        return false
    end

    button.pendingState = nil
    button.visualEnabled = state.enabled and true or false
    -- Do NOT call SetEnabled(false) — always keep the button clickable.
    button.label:SetText(state.label or "")
    button.tooltipTitle  = state.tooltipTitle or state.label
    button.tooltipDetail = state.tooltipDetail
    button.hoverTexture:SetAlpha(0)

    if state.icon then
        button.iconTexture:SetTexture(state.icon)
        button.iconTexture:SetTexCoord(0, 1, 0, 1)
        button.iconTexture:SetAlpha(1)
    else
        button.iconTexture:SetTexture(nil)
        button.iconTexture:SetAlpha(0)
    end

    if button.visualEnabled then
        button.baseTexture:SetTexture(state.normalTexture or ns.Media.NODE_NORMAL)
        button.baseTexture:SetVertexColor(1, 1, 1, 1)
        button.iconTexture:SetDesaturated(false)
        button.label:SetTextColor(0.98, 0.93, 0.83)
        button.labelBackdrop:SetVertexColor(0.03, 0.04, 0.09, 0.78)
    else
        button.baseTexture:SetTexture(state.disabledTexture or state.normalTexture or ns.Media.NODE_DISABLED)
        button.baseTexture:SetVertexColor(1, 1, 1, 0.68)
        button.iconTexture:SetDesaturated(true)
        button.label:SetTextColor(0.58, 0.58, 0.58)
        button.labelBackdrop:SetVertexColor(0.03, 0.04, 0.09, 0.5)
    end

    return true
end
