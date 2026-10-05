local _, ns = ...

local LauncherButton = {}
ns.LauncherButton = LauncherButton

local MACRO_NAME = "Portal Roulette"
local MACRO_BODY = "/pr"
local MACRO_ICON = "achievement_dungeon_outland_dungeonmaster"
local BASE_BUTTON_SIZE = 52
local TEX_COORD_MIN = 0.12
local TEX_COORD_MAX = 0.88
local MAX_ACTION_SLOTS = 180

local THEME_KEY_ARCANE = "arcane"
local THEME_KEY_FIRE = "fire"
local THEME_KEY_FROST = "frost"
local THEME_LABEL_BY_KEY = {
    [THEME_KEY_ARCANE] = "Arcane",
    [THEME_KEY_FIRE] = "Fire",
    [THEME_KEY_FROST] = "Frost",
}

local launcherThemes = {
    [THEME_KEY_ARCANE] = {
        normal = ns.Media.LAUNCHER_ARCANE_NORMAL,
        hover = ns.Media.LAUNCHER_ARCANE_HOVER,
        pushed = ns.Media.LAUNCHER_ARCANE_PUSHED,
        macroIcon = MACRO_ICON,
        color = { 0.64, 0.38, 1.0 },
    },
    [THEME_KEY_FIRE] = {
        normal = ns.Media.LAUNCHER_FIRE_NORMAL,
        hover = ns.Media.LAUNCHER_FIRE_HOVER,
        pushed = ns.Media.LAUNCHER_FIRE_PUSHED,
        macroIcon = MACRO_ICON,
        color = { 1.0, 0.42, 0.16 },
    },
    [THEME_KEY_FROST] = {
        normal = ns.Media.LAUNCHER_FROST_NORMAL,
        hover = ns.Media.LAUNCHER_FROST_HOVER,
        pushed = ns.Media.LAUNCHER_FROST_PUSHED,
        macroIcon = MACRO_ICON,
        color = { 0.38, 0.68, 1.0 },
    },
}

local function round(value)
    if value >= 0 then
        return math.floor(value + 0.5)
    end
    return math.ceil(value - 0.5)
end

-- Forever has no talent tabs (GetTalentTabInfo is gone and
-- C_SpecializationInfo reports a single "Mage" spec, measured on 70205), so
-- the theme is a choice in the options. "auto" is Arcane.
local function getDesiredThemeKey()
    local key = ns.db and ns.db.launcherTheme
    if launcherThemes[key] then
        return key
    end
    return THEME_KEY_ARCANE
end

function LauncherButton:GetActiveTheme()
    local key = self.themeKey or THEME_KEY_ARCANE
    return launcherThemes[key] or launcherThemes[THEME_KEY_ARCANE]
end

function LauncherButton:ApplyTheme(themeKey)
    if not self.button then
        return
    end
    local resolvedKey = themeKey or THEME_KEY_ARCANE
    local theme = launcherThemes[resolvedKey] or launcherThemes[THEME_KEY_ARCANE]
    self.themeKey = resolvedKey
    local button = self.button
    button.art:SetTexture(button.hovered and theme.hover or theme.normal)
    local c = theme.color or { 0.64, 0.38, 1.0 }
    ns.Skin:SetRimColor(button.glass, c[1], c[2], c[3], 0.9)
    button.glow:SetVertexColor(c[1], c[2], c[3])
end

function LauncherButton:PositionPrompt()
    if not self.prompt or not self.button then
        return
    end

    self.prompt:ClearAllPoints()
    self.prompt:SetPoint("BOTTOM", self.button, "TOP", 0, 12)
end

function LauncherButton:RefreshSpecTheme()
    self:ApplyTheme(getDesiredThemeKey())
end

function LauncherButton:GetDesiredMacroIcon()
    local theme = self:GetActiveTheme()
    return theme.macroIcon or MACRO_ICON
end

function LauncherButton:IsLauncherMacroOnActionBar()
    if type(GetActionInfo) ~= "function" or type(GetMacroInfo) ~= "function" then
        return false
    end

    for slot = 1, MAX_ACTION_SLOTS do
        local actionType, actionId = GetActionInfo(slot)
        if actionType == "macro" and actionId then
            local macroName = GetMacroInfo(actionId)
            if macroName == MACRO_NAME then
                return true, slot
            end
        end
    end
    return false
end

function LauncherButton:ShouldShowLauncher()
    return not self:IsLauncherMacroOnActionBar()
end

function LauncherButton:RefreshVisibility()
    if not self.button then
        return
    end

    if self:ShouldShowLauncher() then
        self.button:Show()
        self:RefreshPromptVisibility()
        return
    end

    self.button:Hide()
    if self.prompt then
        self.prompt:Hide()
    end
    if GameTooltip and GameTooltip.Hide then
        GameTooltip:Hide()
    end
end

function LauncherButton:ScheduleVisibilityRefresh()
    self._visibilityRefreshToken = (self._visibilityRefreshToken or 0) + 1
    local token = self._visibilityRefreshToken

    if C_Timer and C_Timer.After then
        C_Timer.After(0.05, function()
            if LauncherButton._visibilityRefreshToken ~= token then
                return
            end
            LauncherButton:RefreshVisibility()
        end)
        return
    end

    self:RefreshVisibility()
end

function LauncherButton:RegisterActionBarEvents()
    if self.eventFrame then
        return
    end

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
    eventFrame:RegisterEvent("UPDATE_MACROS")
    eventFrame:SetScript("OnEvent", function()
        LauncherButton:ScheduleVisibilityRefresh()
    end)
    self.eventFrame = eventFrame
end

local function isMissingMacroIcon(iconTexture)
    if type(iconTexture) ~= "string" or iconTexture == "" then
        return true
    end
    return string.find(string.lower(iconTexture), "questionmark", 1, true) ~= nil
end

function LauncherButton:CreateOrUpdateMacro()
    if type(GetMacroIndexByName) ~= "function" then
        return nil, "api"
    end
    if InCombatLockdown and InCombatLockdown() then
        return nil, "combat"
    end

    local desiredIcon = self:GetDesiredMacroIcon() or MACRO_ICON
    local macroIndex = GetMacroIndexByName(MACRO_NAME)
    if not macroIndex or macroIndex == 0 then
        if type(CreateMacro) ~= "function" then
            return nil, "api"
        end

        macroIndex = CreateMacro(MACRO_NAME, desiredIcon, MACRO_BODY, true)
        if not macroIndex then
            ns.Print("Unable to create character macro '" .. MACRO_NAME .. "'. Macro slots may be full. Create it manually with body '/pr'.")
            return nil, "limit"
        end
    elseif type(EditMacro) == "function" then
        local globalCount = type(GetNumMacros) == "function" and (select(1, GetNumMacros()) or 0) or 0
        local isCharacterMacro = macroIndex > globalCount
        EditMacro(macroIndex, MACRO_NAME, desiredIcon, MACRO_BODY, isCharacterMacro)
    end

    if type(GetMacroInfo) == "function" and type(EditMacro) == "function" then
        local _, iconTexture = GetMacroInfo(macroIndex)
        if isMissingMacroIcon(iconTexture) then
            local globalCount = type(GetNumMacros) == "function" and (select(1, GetNumMacros()) or 0) or 0
            local isCharacterMacro = macroIndex > globalCount
            EditMacro(macroIndex, MACRO_NAME, MACRO_ICON, MACRO_BODY, isCharacterMacro)
        end
    end

    return macroIndex
end

function LauncherButton:PickupLauncherMacro()
    if InCombatLockdown and InCombatLockdown() then
        ns.Print("Cannot place the Portal Roulette macro while in combat.")
        return
    end

    local macroIndex, reason = self:CreateOrUpdateMacro()
    if not macroIndex then
        if reason ~= "limit" and reason ~= "combat" then
            ns.Print("Unable to prepare the Portal Roulette macro.")
        end
        return
    end

    if type(PickupMacro) == "function" then
        PickupMacro(macroIndex)
    end
    self:ScheduleVisibilityRefresh()
end

function LauncherButton:CreatePrompt()
    if self.prompt or not self.button then
        return
    end
    local Skin = ns.Skin
    local prompt = CreateFrame("Frame", nil, UIParent)
    prompt:SetSize(196, 46)
    -- The launcher's own strata, just above it: DIALOG would draw over the
    -- Settings panel and other windows.
    prompt:SetFrameStrata(self.button:GetFrameStrata())
    prompt:SetFrameLevel(self.button:GetFrameLevel() + 5)
    prompt.glass = Skin:Pill(prompt)
    local top = prompt.glass.top or prompt

    local function dismissPrompt()
        ns.db.actionBarPromptDismissed = true
        LauncherButton:RefreshPromptVisibility()
        if ns.Options and ns.Options.Refresh then
            ns.Options.Refresh()
        end
    end

    local title = Skin:Font(top, 13, "LEFT")
    title:SetPoint("TOPLEFT", 12, -8)
    title:SetText("Portal Roulette")
    local c = ns.Colors.TELEPORT
    title:SetTextColor(c[1] + 0.25, c[2] + 0.2, 1)
    prompt.title = title

    local subtitle = Skin:Font(top, 12, "LEFT")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)
    subtitle:SetText("Drag me to an action bar.")
    subtitle:SetTextColor(1, 1, 1, 0.7)
    prompt.subtitle = subtitle

    -- A small round glass close button.
    local close = CreateFrame("Button", nil, top)
    close:SetSize(18, 18)
    close:SetPoint("TOPRIGHT", -6, -6)
    local x = Skin:Font(close, 13, "CENTER")
    x:SetPoint("CENTER", 0, 1)
    x:SetText("×")
    x:SetTextColor(1, 1, 1, 0.6)
    close:SetScript("OnEnter", function() x:SetTextColor(1, 1, 1, 1) end)
    close:SetScript("OnLeave", function() x:SetTextColor(1, 1, 1, 0.6) end)
    close:SetScript("OnClick", dismissPrompt)
    prompt.closeButton = close

    self.prompt = prompt
    self:PositionPrompt()
end

function LauncherButton:GetActiveThemeLabel()
    return THEME_LABEL_BY_KEY[self.themeKey] or THEME_LABEL_BY_KEY[THEME_KEY_ARCANE]
end

function LauncherButton:ScheduleSpecThemeRefresh()
    if not (C_Timer and C_Timer.After) then
        return
    end

    self._themeRefreshToken = (self._themeRefreshToken or 0) + 1
    local token = self._themeRefreshToken
    C_Timer.After(0.25, function()
        if LauncherButton._themeRefreshToken ~= token or not LauncherButton.button then
            return
        end
        LauncherButton:RefreshSpecTheme()
    end)
end

function LauncherButton:GetScale()
    return tonumber(ns.db and ns.db.launcherScale) or 1.35
end

function LauncherButton:ApplyScale()
    if not self.button then
        return
    end
    self.button:SetSize(BASE_BUTTON_SIZE, BASE_BUTTON_SIZE)
    self.button:SetScale(self:GetScale())
    self:PositionPrompt()
end

function LauncherButton:RefreshPromptVisibility()
    if not self.prompt then
        return
    end

    if ns.db.actionBarPromptDismissed or not self.button or not self.button:IsShown() then
        self.prompt:Hide()
        return
    end
    self:PositionPrompt()
    self.prompt:Show()
end

local function showTooltip(selfButton)
    local anchor = (LauncherButton.prompt and LauncherButton.prompt:IsShown()) and "ANCHOR_LEFT" or "ANCHOR_RIGHT"
    GameTooltip:SetOwner(selfButton, anchor)
    GameTooltip:SetText("Portal Roulette", 0.8, 0.9, 1)
    GameTooltip:AddLine("Click: open the wheel", 1, 1, 1)
    GameTooltip:AddLine("Drag: place on an action bar", 0.75, 0.8, 0.9)
    if ns.db.lockLauncher then
        GameTooltip:AddLine("Shift-drag: locked", 1, 0.45, 0.45)
    else
        GameTooltip:AddLine("Shift-drag: move", 0.75, 0.8, 0.9)
    end
    GameTooltip:AddLine("Shift-right-click: options", 0.75, 0.8, 0.9)
    local key1 = GetBindingKey("PORTALROULETTE_TOGGLE")
    if key1 then
        GameTooltip:AddLine("Key: " .. (GetBindingText(key1, "KEY_") or key1), 0.75, 0.8, 0.9)
    end
    GameTooltip:Show()
end

-- A glass bead: the theme's rune art masked to a circle inside a small
-- glass disc, a soft accent glow on hover, a press nudge.
function LauncherButton:Create()
    if self.button then
        return
    end
    local Skin = ns.Skin
    local button = CreateFrame("Button", "PortalRouletteLauncherButton", UIParent)
    button:SetSize(BASE_BUTTON_SIZE, BASE_BUTTON_SIZE)
    button:SetMovable(true)
    button:EnableMouse(true)
    button:SetClampedToScreen(true)
    -- Not a secure button: one edge is fine here.
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")

    local glow = button:CreateTexture(nil, "BACKGROUND", nil, -8)
    glow:SetPoint("TOPLEFT", -12, 12)
    glow:SetPoint("BOTTOMRIGHT", 12, -12)
    glow:SetTexture(ns.Media.GLOW) -- generated by Tools/make_art.py
    glow:SetBlendMode("ADD")
    glow:SetAlpha(0)
    button.glow = glow

    button.glass = Skin:Disc(button, "disc_small")
    local artHost = CreateFrame("Frame", nil, button)
    artHost:SetPoint("TOPLEFT", 4, -4)
    artHost:SetPoint("BOTTOMRIGHT", -4, 4)
    local art = Skin:RoundTexture(artHost, "ARTWORK", 1)
    art:SetTexCoord(TEX_COORD_MIN, TEX_COORD_MAX, TEX_COORD_MIN, TEX_COORD_MAX)
    button.art, button.artHost = art, artHost

    button:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "RightButton" and IsShiftKeyDown() then
            if ns.Options then ns.Options:Open() end
            return
        end
        ns.Roulette:Toggle()
    end)

    button:SetScript("OnDragStart", function(selfButton)
        if IsShiftKeyDown() then
            if ns.db.lockLauncher or InCombatLockdown() then
                return
            end
            LauncherButton.isMoving = true
            selfButton:StartMoving()
            return
        end
        LauncherButton:PickupLauncherMacro()
    end)

    button:SetScript("OnDragStop", function(selfButton)
        if not LauncherButton.isMoving then
            return
        end
        LauncherButton.isMoving = false
        selfButton:StopMovingOrSizing()
        local point, _, _, x, y = selfButton:GetPoint(1)
        ns.db.launcher.point = point
        ns.db.launcher.x = round(x)
        ns.db.launcher.y = round(y)
        LauncherButton:PositionPrompt()
    end)

    button:SetScript("OnEnter", function(selfButton)
        selfButton.hovered = true
        glow:SetAlpha(0.55)
        if selfButton.glass.rim then selfButton.glass.rim:SetAlpha(1) end
        LauncherButton:ApplyTheme(LauncherButton.themeKey)
        showTooltip(selfButton)
    end)

    button:SetScript("OnLeave", function(selfButton)
        selfButton.hovered = false
        glow:SetAlpha(0)
        if selfButton.glass.rim then selfButton.glass.rim:SetAlpha(0.7) end
        LauncherButton:ApplyTheme(LauncherButton.themeKey)
        GameTooltip:Hide()
    end)

    button:SetScript("OnMouseDown", function()
        artHost:SetPoint("TOPLEFT", 5, -5)
        artHost:SetPoint("BOTTOMRIGHT", -3, 3)
    end)
    button:SetScript("OnMouseUp", function()
        artHost:SetPoint("TOPLEFT", 4, -4)
        artHost:SetPoint("BOTTOMRIGHT", -4, 4)
    end)

    self.button = button
    self:RefreshSpecTheme()
    self:CreatePrompt()
end

function LauncherButton:ApplyPosition()
    if not self.button then
        return
    end
    self.button:ClearAllPoints()
    self.button:SetPoint(ns.db.launcher.point or "CENTER", UIParent, ns.db.launcher.point or "CENTER", ns.db.launcher.x or 0, ns.db.launcher.y or 0)
    self:PositionPrompt()
end

function LauncherButton:ApplySettings()
    if not self.button then
        return
    end
    self:ApplyScale()
    self:ApplyPosition()
    self:RefreshSpecTheme()
    self:RefreshVisibility()
end

function LauncherButton:Initialize()
    if not ns.isMage then
        return
    end
    self:Create()
    self:RegisterActionBarEvents()
    self:ApplySettings()
    self:ScheduleSpecThemeRefresh()
    self:RefreshVisibility()
end
