local _, ns = ...

local function printMessage(message)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff8e7dffPortal Roulette|r: " .. message)
    end
end

ns.Print = printMessage

BINDING_HEADER_PORTALROULETTE = "Portal Roulette"
BINDING_NAME_PORTALROULETTE_TOGGLE = "Open Portal Roulette"
BINDING_NAME_PORTALROULETTE_TELEPORTS = "Open Teleports"
BINDING_NAME_PORTALROULETTE_PORTALS = "Open Portals"

function PortalRoulette_Toggle()
    if ns.RouletteFrame then
        ns.RouletteFrame:Toggle()
    end
end

function PortalRoulette_OpenTeleports()
    if ns.RouletteFrame then
        ns.RouletteFrame:Open(ns.Mode.TELEPORT)
    end
end

function PortalRoulette_OpenPortals()
    if ns.RouletteFrame then
        ns.RouletteFrame:Open(ns.Mode.PORTAL)
    end
end

local function openOptionsPanel()
    if not ns.OptionsPanel or not ns.OptionsPanel.Open then
        return
    end
    ns.OptionsPanel:Open()
end

local function valueToText(value)
    if value == nil then
        return "nil"
    end
    return tostring(value)
end

local function printButtonAttributes(label, button)
    if not button then
        printMessage(label .. ": missing")
        return
    end

    local shown = button:IsShown() and "shown" or "hidden"
    local enabled = button:IsEnabled() and "enabled" or "disabled"
    printMessage(label .. ": " .. shown .. ", " .. enabled)
    printMessage("  type=" .. valueToText(button:GetAttribute("type"))
        .. " type1=" .. valueToText(button:GetAttribute("type1"))
        .. " type2=" .. valueToText(button:GetAttribute("type2")))
    printMessage("  spell=" .. valueToText(button:GetAttribute("spell"))
        .. " spell1=" .. valueToText(button:GetAttribute("spell1"))
        .. " spell2=" .. valueToText(button:GetAttribute("spell2")))
    printMessage("  item=" .. valueToText(button:GetAttribute("item"))
        .. " macro=" .. valueToText(button:GetAttribute("macrotext")))
end

local function printDebugState()
    if not ns.RouletteFrame or not ns.RouletteFrame.frame then
        printMessage("Roulette frame is not created.")
        return
    end

    ns.RouletteFrame:RefreshAll()
    printMessage("Debug: mode=" .. valueToText(ns.RouletteFrame.mode)
        .. " combat=" .. valueToText(InCombatLockdown() and true or false))
    printButtonAttributes("First city", ns.RouletteFrame.nodeButtons and ns.RouletteFrame.nodeButtons[1])
    printButtonAttributes("Center utility", ns.RouletteFrame.frame.centerUtilityButton)
    printButtonAttributes("Lower utility", ns.UtilityButton and ns.UtilityButton.button)
end

local refreshVisualState

local function handleDebugCommand(parts)
    local target = parts[2]
    local value = parts[3]
    if target == "atiesh" then
        if value == "on" or value == "off" or value == "auto" then
            ns.db.debugAtiesh = value
            printMessage("Debug Atiesh override: " .. value)
            refreshVisualState()
        else
            printMessage("Usage: /pr debug atiesh on|off|auto")
        end
        return true
    elseif target == "faction" then
        if value == "horde" then
            ns.db.debugFaction = ns.Constants.FACTION_HORDE
        elseif value == "alliance" then
            ns.db.debugFaction = ns.Constants.FACTION_ALLIANCE
        elseif value == "auto" then
            ns.db.debugFaction = "auto"
        else
            printMessage("Usage: /pr debug faction horde|alliance|auto")
            return true
        end
        printMessage("Debug faction override: " .. tostring(ns.db.debugFaction))
        if ns.RouletteFrame and ns.RouletteFrame.RebuildDestinations then
            ns.RouletteFrame:RebuildDestinations()
        else
            refreshVisualState()
        end
        return true
    elseif target == "state" then
        printMessage("Debug Atiesh: " .. tostring(ns.db.debugAtiesh or "auto"))
        printMessage("Debug faction: " .. tostring(ns.db.debugFaction or "auto"))
        return true
    end
    return false
end

local function registerSlashCommands()
    SLASH_PORTALROULETTE1 = "/portalroulette"
    SLASH_PORTALROULETTE2 = "/proulette"
    SLASH_PORTALROULETTE3 = "/pr"

    SlashCmdList.PORTALROULETTE = function(commandText)
        local text = string.lower((commandText or ""):match("^%s*(.-)%s*$"))
        if text == "options" or text == "config" then
            openOptionsPanel()
            return
        end

        if text == "debug" then
            printDebugState()
            return
        end

        if text:match("^debug%s+") then
            local parts = {}
            for part in text:gmatch("%S+") do
                parts[#parts + 1] = part
            end
            if handleDebugCommand(parts) then
                return
            end
        end

        if text == "reset" then
            ns.DB:ResetPositions()
            if ns.RouletteFrame and ns.RouletteFrame.frame then
                ns.RouletteFrame:ApplyPosition()
            end
            if ns.LauncherButton and ns.LauncherButton.button then
                ns.LauncherButton:ApplyPosition()
            end
            printMessage("Positions reset to defaults.")
            return
        end

        if not ns.RouletteFrame then
            return
        end
        ns.RouletteFrame:Toggle()
    end
end

function refreshVisualState()
    if ns.RouletteFrame then
        ns.RouletteFrame:RefreshAll()
    end
    if ns.MinimapButton then
        ns.MinimapButton:RefreshVisibility()
    end
end

local function initializeForMage()
    ns.OptionsPanel:Initialize()
    ns.RouletteFrame:Initialize()
    ns.LauncherButton:Initialize()
    ns.MinimapButton:Initialize()
    ns.CastTracker:Initialize()
    registerSlashCommands()

    ns.Events:Register("BAG_UPDATE_DELAYED", function()
        refreshVisualState()
    end)

    ns.Events:Register("SPELLS_CHANGED", function()
        if ns.RouletteFrame then
            ns.RouletteFrame:RefreshDestinationNodes()
        end
    end)

    ns.Events:Register("PLAYER_REGEN_ENABLED", function()
        refreshVisualState()
    end)

    ns.Events:Register("PLAYER_REGEN_DISABLED", function()
        if ns.CameraMode then
            ns.CameraMode:Exit()
        end
    end)

    ns.Events:Register("PLAYER_LOGOUT", function()
        if ns.CameraMode then
            ns.CameraMode:Exit()
        end
    end)
end

ns.Events:Register("PLAYER_LOGIN", function()
    ns.DB:Initialize()

    local _, classToken = UnitClass("player")
    ns.isMage = classToken == ns.Constants.CLASS_MAGE
    if not ns.isMage then
        return
    end

    initializeForMage()
    printMessage("Loaded. Left-click launcher for Teleports, right-click for Portals.")
end)
