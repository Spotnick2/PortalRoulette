local _, ns = ...

-- While /pr debug runs, its lines are also kept (PortalRouletteDB.lastDebug)
-- so they can be read from SavedVariables even if chat was hidden.
local debugLog

local function printMessage(message)
    if debugLog then
        debugLog[#debugLog + 1] = message
    end
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff8e7dffPortal Roulette|r: " .. message)
    end
end

ns.Print = printMessage

BINDING_NAME_PORTALROULETTE_TOGGLE = "Open Portal Roulette"

function PortalRoulette_Toggle()
    if ns.Roulette then
        ns.Roulette:Toggle()
    end
end

local function valueToText(value)
    if value == nil then
        return "nil"
    end
    if not ns.API.Readable(value) then
        return "<secret>"
    end
    return tostring(value)
end

local function printButtonAttributes(label, button)
    if not button then
        printMessage(label .. ": missing")
        return
    end
    local parts = {}
    for _, family in ipairs(ns.SecureAction.FAMILIES) do
        for _, suffix in ipairs(ns.SecureAction.SUFFIXES) do
            local v = button:GetAttribute(family .. suffix)
            if v ~= nil then
                parts[#parts + 1] = family .. suffix .. "=" .. valueToText(v)
            end
        end
    end
    printMessage(label .. " (" .. (button:IsShown() and "shown" or "hidden") .. "): "
        .. (#parts > 0 and table.concat(parts, " ") or "no action"))
end

local function printDebugState()
    local R = ns.Roulette
    printMessage("build " .. valueToText(ns.API.ClientBuild()) .. ", combat=" .. valueToText(InCombatLockdown())
        .. ", preview=" .. valueToText(R.preview) .. ", faction=" .. ns.Destinations:GetPlayerFaction())
    if #ns.API.eventFailures > 0 then
        printMessage("events refused: " .. table.concat(ns.API.eventFailures, ", "))
    end
    if not R.root then
        printMessage("The wheel has not been opened yet.")
        return
    end
    R:Refresh()
    printMessage("reagents: " .. valueToText(R.reagentState) .. ", hearth: "
        .. valueToText(R.hearthSource and R.hearthSource.id))
    for _, node in ipairs(R.slots) do
        local resolved = R.assigned and R.assigned[node]
        printButtonAttributes((resolved and resolved.name or "empty") .. " @" .. node.clock, node.button)
    end
    printButtonAttributes("Hearth orb", R.orb.button)
    -- Animations actually running (to tell "too subtle" from "not playing").
    local ticker = ns.Disc.ticker
    local links, comets = 0, 0
    for _, link in pairs(R.disc.links) do
        if link.line:IsShown() then links = links + 1 end
        if link.comet:IsShown() then comets = comets + 1 end
    end
    printMessage("effects: updater " .. ((ticker and ticker:GetScript("OnUpdate")) and "running" or "stopped")
        .. ", t=" .. string.format("%.1f", R.disc.time or 0) .. "s, links " .. links .. ", comets in flight " .. comets
        .. " (open=" .. valueToText(R.open) .. ", animations=" .. valueToText(ns.db.animationsEnabled)
        .. ", idle=" .. valueToText(ns.db.idleAnimationsEnabled) .. ")")
end

local function handleDebugCommand(parts)
    local target, value = parts[2], parts[3]
    if target == "trace" then
        if value == "on" or value == "off" then
            ns.db.debugTrace = value == "on"
            if value == "on" then ns.db.trace = {} end
        end
        printMessage("Close trace " .. (ns.db.debugTrace and "on" or "off")
            .. " (PortalRouletteDB.trace, read after /reload). /pr debug trace on|off")
        return
    end
    if target == "faction" then
        if value == "horde" then
            ns.db.debugFaction = ns.Constants.FACTION_HORDE
        elseif value == "alliance" then
            ns.db.debugFaction = ns.Constants.FACTION_ALLIANCE
        elseif value == "auto" then
            ns.db.debugFaction = "auto"
        else
            printMessage("Usage: /pr debug faction horde|alliance|auto")
            return
        end
        printMessage("Faction override: " .. tostring(ns.db.debugFaction))
        if ns.Roulette.root and not InCombatLockdown() then
            ns.Roulette:Refresh()
        end
        return
    end
    debugLog = { "at " .. date("%Y-%m-%d %H:%M:%S") }
    local ok, err = pcall(printDebugState)
    if not ok then
        printMessage("debug failed: " .. tostring(err))
    end
    ns.db.lastDebug = debugLog
    debugLog = nil
end

local function registerSlashCommands()
    SLASH_PORTALROULETTE1 = "/portalroulette"
    SLASH_PORTALROULETTE2 = "/proulette"
    SLASH_PORTALROULETTE3 = "/pr"

    SlashCmdList.PORTALROULETTE = function(commandText)
        local text = string.lower((commandText or ""):match("^%s*(.-)%s*$"))
        local parts = {}
        for part in text:gmatch("%S+") do
            parts[#parts + 1] = part
        end
        local cmd = parts[1] or ""
        if cmd == "options" or cmd == "config" then
            ns.Options:Open()
        elseif cmd == "preview" then
            ns.Roulette:SetPreview(not ns.Roulette.preview)
            if ns.Roulette.preview and not ns.Roulette.open then
                ns.Roulette:Open()
            end
        elseif cmd == "debug" then
            handleDebugCommand(parts)
        elseif cmd == "reset" then
            if InCombatLockdown() then
                printMessage("Not in combat.")
                return
            end
            ns.DB:ResetPositions()
            ns.Roulette:ApplyPosition()
            ns.LauncherButton:ApplyPosition()
            printMessage("Positions reset to defaults.")
        elseif cmd == "" then
            ns.Roulette:Toggle()
        else
            printMessage("/pr | options | preview | reset | debug | debug faction horde|alliance|auto")
        end
    end
end

-- A setting changed in the options page.
local function onOptionChanged(key)
    local R = ns.Roulette
    if key == "uiScale" or key == "positions" then
        R:ApplyScale()
        R:ApplyPosition()
        ns.LauncherButton:ApplySettings()
    elseif key == "launcherScale" or key == "lockLauncher" or key == "launcherGlow" then
        ns.LauncherButton:ApplySettings()
    elseif key == "showMinimapButton" then
        ns.Minimap:RefreshVisibility()
    end
    if R.root then
        R:Refresh()
    end
end

local function initializeForMage()
    ns.SecureAction.Initialize()
    ns.Roulette:Initialize()
    ns.LauncherButton:Initialize()
    ns.Minimap:Initialize()
    ns.CastTracker:Initialize()
    ns.Options:Register()
    ns.Options.OnChanged = onOptionChanged
    registerSlashCommands()
end

ns.Events:Register("PLAYER_LOGIN", function()
    ns.DB:Initialize()

    local _, classToken = UnitClass("player")
    ns.isMage = classToken == ns.Constants.CLASS_MAGE
    if not ns.isMage then
        return
    end

    initializeForMage()
end)
