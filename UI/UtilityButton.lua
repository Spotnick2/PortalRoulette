-- ============================================================
-- UtilityButton: the launcher as a button on Glass Action Bars' Utility
-- bar (GlassActionBars#52, its docs/PUBLIC-API.md version 2; ours #9).
--
-- A Glass UI suite feature: it is offered only when Glass UI is loaded
-- (ns.GlassUI:Present()) AND Glass Action Bars speaks version 2. Without
-- either, nothing registers and the floating launcher behaves as before.
--
-- GAB builds an insecure button that calls our toggle. The button is off
-- until the player ticks it on the Utility bar's page. While it is shown
-- there, GAB calls OnHosted(true) and the floating launcher (and its
-- "drag the macro" prompt) stays hidden; OnHosted(false) gives it back,
-- still under the macro-on-a-bar rule.
-- ============================================================

local _, ns = ...

local UtilityButton = {}
ns.UtilityButton = UtilityButton

UtilityButton.ID = "portalroulette"
local GAB_API = 2

-- Glass Action Bars when the integration applies, else nil.
function UtilityButton:Host()
    if not (ns.GlassUI and ns.GlassUI:Present()) then
        return nil
    end
    local GAB = rawget(_G, "GlassActionBars")
    if type(GAB) ~= "table" or rawget(GAB, "PUBLIC_API_VERSION") ~= GAB_API
        or type(rawget(GAB, "RegisterButton")) ~= "function" then
        return nil
    end
    return GAB
end

local function fillTooltip(tooltip)
    tooltip:SetText("Portal Roulette", 0.8, 0.9, 1)
    tooltip:AddLine("Click: open the wheel", 1, 1, 1)
    if InCombatLockdown() then
        tooltip:AddLine("Not in combat", 1, 0.45, 0.45)
    end
end

-- Mages only (called from Init after the launcher exists).
function UtilityButton:Initialize()
    if self.registered ~= nil then
        return
    end
    self.registered = false
    local GAB = self:Host()
    if not GAB then
        return
    end
    local ok, accepted, reason = pcall(GAB.RegisterButton, {
        id = self.ID,
        label = "Portal Roulette",
        icon = ns.Media.LAUNCHER_PORTAL,
        binding = "PORTALROULETTE_TOGGLE",
        tooltip = fillTooltip,
        OnClick = function()
            PortalRoulette_Toggle()
        end,
        -- The wheel's root is the protected parent of secure buttons: it
        -- cannot be shown in combat.
        IsEnabled = function()
            return not InCombatLockdown()
        end,
        OnHosted = function(hosted)
            ns.LauncherButton:SetHosted(hosted)
        end,
    })
    if ok and accepted then
        self.registered = true
    else
        self.failure = tostring(ok and reason or accepted)
    end
end

-- One line for the options page, or nil when the integration doesn't apply.
function UtilityButton:StatusText()
    if self.registered then
        if ns.LauncherButton.hosted then
            return "Utility bar: on Glass Action Bars' Utility bar"
        end
        return "Utility bar: tick Portal Roulette in Glass Action Bars' Utility options"
    end
    if self.failure then
        return "Utility bar: refused (" .. self.failure .. ")"
    end
    return nil
end
