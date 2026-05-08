local _, ns = ...

local function printMessage(message)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff8e7dffPortal Roulette|r: " .. message)
    end
end

ns.Print = printMessage

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

local function refreshVisualState()
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
