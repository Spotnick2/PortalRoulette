local _, ns = ...

local LauncherButton = {}
ns.LauncherButton = LauncherButton

local MACRO_NAME = "Portal Roulette"
local MACRO_BODY = "/pr"
local MACRO_ICON = "achievement_dungeon_outland_dungeonmaster"
local BASE_BUTTON_SIZE = 64
local ICON_SIZE = 72
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

local function createSolid(parent, layer, r, g, b, a)
    local texture = parent:CreateTexture(nil, layer or "BACKGROUND")
    texture:SetTexture("Interface\\Buttons\\WHITE8X8")
    texture:SetVertexColor(r or 1, g or 1, b or 1, a or 1)
    return texture
end

local function addBorder(parent, r, g, b, a)
    local top = createSolid(parent, "BORDER", r, g, b, a)
    top:SetPoint("TOPLEFT", parent, "TOPLEFT", 1, -1)
    top:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -1, -1)
    top:SetHeight(1)

    local bottom = createSolid(parent, "BORDER", r, g, b, a)
    bottom:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 1, 1)
    bottom:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -1, 1)
    bottom:SetHeight(1)

    local left = createSolid(parent, "BORDER", r, g, b, a)
    left:SetPoint("TOPLEFT", parent, "TOPLEFT", 1, -1)
    left:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 1, 1)
    left:SetWidth(1)

    local right = createSolid(parent, "BORDER", r, g, b, a)
    right:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -1, -1)
    right:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -1, 1)
    right:SetWidth(1)
    return top, bottom, left, right
end

local function round(value)
    if value >= 0 then
        return math.floor(value + 0.5)
    end
    return math.ceil(value - 0.5)
end

local function getTalentTabInfoValues(tabIndex)
    if type(GetTalentTabInfo) ~= "function" then
        return nil
    end
    return { GetTalentTabInfo(tabIndex) }
end

local function getTalentTabName(tabIndex)
    local values = getTalentTabInfoValues(tabIndex)
    return values and values[1]
end

local function getTalentTabSpentPoints(tabIndex)
    local spent = 0
    if type(GetNumTalents) == "function" and type(GetTalentInfo) == "function" then
        local numTalents = GetNumTalents(tabIndex) or 0
        for talentIndex = 1, numTalents do
            local _, _, _, _, currentRank = GetTalentInfo(tabIndex, talentIndex)
            spent = spent + (tonumber(currentRank) or 0)
        end
        return spent
    end

    local values = getTalentTabInfoValues(tabIndex)
    if values then
        for _, index in ipairs({ 3, 5, 4 }) do
            local points = tonumber(values[index])
            if points then
                return points
            end
        end
    end
    return 0
end

local function scoreTalentTreesByName()
    if type(GetNumTalentTabs) ~= "function" or type(GetTalentTabInfo) ~= "function" then
        return {}
    end

    local scores = {}
    local numTabs = GetNumTalentTabs() or 0
    for tabIndex = 1, numTabs do
        local tabName = getTalentTabName(tabIndex)
        local pointsSpent = getTalentTabSpentPoints(tabIndex)
        if type(tabName) == "string" then
            local lowered = string.lower(tabName)
            if string.find(lowered, "arcane", 1, true) then
                scores[THEME_KEY_ARCANE] = pointsSpent
            elseif string.find(lowered, "fire", 1, true) then
                scores[THEME_KEY_FIRE] = pointsSpent
            elseif string.find(lowered, "frost", 1, true) then
                scores[THEME_KEY_FROST] = pointsSpent
            end
        end
    end
    return scores
end

local function scoreTalentTreesByIndex()
    if type(GetNumTalentTabs) ~= "function" or type(GetTalentTabInfo) ~= "function" then
        return {}
    end

    local scores = {}
    local numTabs = GetNumTalentTabs() or 0
    if numTabs >= 3 then
        scores[THEME_KEY_ARCANE] = getTalentTabSpentPoints(1)
        scores[THEME_KEY_FIRE] = getTalentTabSpentPoints(2)
        scores[THEME_KEY_FROST] = getTalentTabSpentPoints(3)
    end
    return scores
end

local function chooseThemeKeyFromScores(scores)
    local bestKey
    local bestPoints = -1
    local tied = false

    for _, key in ipairs({ THEME_KEY_ARCANE, THEME_KEY_FIRE, THEME_KEY_FROST }) do
        local points = tonumber(scores[key])
        if points then
            if points > bestPoints then
                bestPoints = points
                bestKey = key
                tied = false
            elseif points == bestPoints then
                tied = true
            end
        end
    end

    if not bestKey or bestPoints <= 0 or tied then
        return THEME_KEY_ARCANE
    end
    return bestKey
end

local function getDesiredThemeKey()
    local byName = scoreTalentTreesByName()
    if next(byName) then
        return chooseThemeKeyFromScores(byName)
    end
    return chooseThemeKeyFromScores(scoreTalentTreesByIndex())
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

    self.button:SetNormalTexture(theme.normal)
    self.button:SetHighlightTexture(theme.hover)
    self.button:SetPushedTexture(theme.pushed)
    local color = theme.color or { 0.64, 0.38, 1.0 }
    if self.button.accent then
        self.button.accent:SetVertexColor(color[1], color[2], color[3], 0.28)
        self.button.accent:SetAlpha(0.22)
    end
    if self.button.innerGlow then
        self.button.innerGlow:SetVertexColor(color[1], color[2], color[3], 0.13)
    end

    local normal = self.button:GetNormalTexture()
    if normal then
        normal:ClearAllPoints()
        normal:SetSize(ICON_SIZE, ICON_SIZE)
        normal:SetPoint("CENTER", self.button, "CENTER", 0, 0)
        normal:SetTexCoord(TEX_COORD_MIN, TEX_COORD_MAX, TEX_COORD_MIN, TEX_COORD_MAX)
        normal:SetVertexColor(0.92, 0.92, 0.96, 1)
    end

    local highlight = self.button:GetHighlightTexture()
    if highlight then
        highlight:ClearAllPoints()
        highlight:SetSize(52, 52)
        highlight:SetPoint("CENTER", self.button, "CENTER", 0, 0)
        highlight:SetBlendMode("ADD")
        highlight:SetTexCoord(0.18, 0.82, 0.18, 0.82)
        highlight:SetAlpha(0.68)
    end

    local pushed = self.button:GetPushedTexture()
    if pushed then
        pushed:ClearAllPoints()
        pushed:SetSize(ICON_SIZE, ICON_SIZE)
        pushed:SetPoint("CENTER", self.button, "CENTER", 1, -1)
        pushed:SetTexCoord(TEX_COORD_MIN, TEX_COORD_MAX, TEX_COORD_MIN, TEX_COORD_MAX)
        pushed:SetVertexColor(0.78, 0.78, 0.84, 1)
    end
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

    local prompt = CreateFrame("Frame", nil, UIParent)
    prompt:SetSize(184, 48)
    prompt:SetFrameStrata("DIALOG")

    local shadow = createSolid(prompt, "BACKGROUND", 0, 0, 0, 0)
    shadow:SetPoint("TOPLEFT", prompt, "TOPLEFT", 3, -3)
    shadow:SetPoint("BOTTOMRIGHT", prompt, "BOTTOMRIGHT", 3, -3)
    shadow:Hide()
    prompt.shadow = shadow

    local background = createSolid(prompt, "BACKGROUND", 0.018, 0.016, 0.014, 0.84)
    background:SetAllPoints()
    prompt.background = background
    addBorder(prompt, 0.63, 0.50, 0.29, 0.62)

    local topSheen = createSolid(prompt, "BORDER", 0.82, 0.70, 0.46, 0.14)
    topSheen:SetPoint("TOPLEFT", prompt, "TOPLEFT", 3, -3)
    topSheen:SetPoint("TOPRIGHT", prompt, "TOPRIGHT", -3, -3)
    topSheen:SetHeight(11)
    prompt.topSheen = topSheen

    local pointer = prompt:CreateTexture(nil, "ARTWORK")
    pointer:SetTexture("Interface\\Buttons\\WHITE8X8")
    pointer:SetVertexColor(0.63, 0.50, 0.29, 0.68)
    pointer:SetSize(7, 7)
    pointer:SetPoint("BOTTOM", prompt, "BOTTOM", 0, -3)
    if pointer.SetRotation then
        pointer:SetRotation(0.785)
    end
    prompt.pointer = pointer

    local function dismissPrompt()
        ns.db.actionBarPromptDismissed = true
        LauncherButton:RefreshPromptVisibility()
        if ns.OptionsPanel and ns.OptionsPanel.RefreshControls then
            ns.OptionsPanel:RefreshControls()
        end
    end

    local title = prompt:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    title:SetPoint("TOPLEFT", prompt, "TOPLEFT", 10, -7)
    title:SetText("Portal Roulette unlocked")
    title:SetTextColor(0.94, 0.78, 0.36)
    prompt.title = title

    local subtitle = prompt:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    subtitle:SetPoint("RIGHT", prompt, "RIGHT", -22, 0)
    subtitle:SetJustifyH("LEFT")
    subtitle:SetText("Drag to an action bar.")
    subtitle:SetTextColor(0.82, 0.80, 0.74)
    prompt.subtitle = subtitle

    local closeButton = CreateFrame("Button", nil, prompt, "UIPanelCloseButton")
    closeButton:SetSize(15, 15)
    closeButton:SetPoint("TOPRIGHT", prompt, "TOPRIGHT", -3, -3)
    closeButton:SetScript("OnClick", dismissPrompt)
    prompt.closeButton = closeButton

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

function LauncherButton:Create()
    if self.button then
        return
    end

    local button = CreateFrame("Button", "PortalRouletteLauncherButton", UIParent)
    button:SetSize(BASE_BUTTON_SIZE, BASE_BUTTON_SIZE)
    button:SetMovable(true)
    button:EnableMouse(true)
    button:SetClampedToScreen(true)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")

    button.shadow = button:CreateTexture(nil, "BACKGROUND")
    button.shadow:SetTexture("Interface\\Buttons\\WHITE8X8")
    button.shadow:SetVertexColor(0, 0, 0, 0)
    button.shadow:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
    button.shadow:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 2, -2)
    button.shadow:Hide()

    button.innerGlow = button:CreateTexture(nil, "BACKGROUND")
    button.innerGlow:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    button.innerGlow:SetBlendMode("ADD")
    button.innerGlow:SetPoint("CENTER", button, "CENTER")
    button.innerGlow:SetSize(42, 42)

    button.frameTexture = button:CreateTexture(nil, "OVERLAY")
    button.frameTexture:SetTexture("Interface\\Buttons\\UI-Quickslot2")
    button.frameTexture:SetAllPoints()
    button.frameTexture:SetVertexColor(0.82, 0.72, 0.54, 0.22)

    button.accent = button:CreateTexture(nil, "OVERLAY")
    button.accent:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    button.accent:SetBlendMode("ADD")
    button.accent:SetPoint("CENTER", button, "CENTER")
    button.accent:SetSize(48, 48)
    button.accent:SetAlpha(0.22)

    button:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "RightButton" then
            ns.RouletteFrame:Toggle(ns.Mode.PORTAL)
        else
            ns.RouletteFrame:Toggle(ns.Mode.TELEPORT)
        end
    end)

    button:SetScript("OnDragStart", function(selfButton)
        if IsShiftKeyDown() then
            if ns.db.lockLauncher then
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
        if selfButton.frameTexture then
            if selfButton.IsMouseOver and selfButton:IsMouseOver() then
                selfButton.frameTexture:SetVertexColor(1.0, 0.84, 0.52, 0.44)
            else
                selfButton.frameTexture:SetVertexColor(0.82, 0.72, 0.54, 0.22)
            end
        end
        if selfButton.accent then
            selfButton.accent:SetAlpha(0.52)
        end
        if LauncherButton.prompt and LauncherButton.prompt:IsShown() then
            GameTooltip:SetOwner(selfButton, "ANCHOR_LEFT")
        else
            GameTooltip:SetOwner(selfButton, "ANCHOR_RIGHT")
        end
        GameTooltip:SetText("Portal Roulette", 0.8, 0.95, 1)
        GameTooltip:AddLine("Click: Open Portal Roulette.", 0.85, 0.85, 0.85)
        GameTooltip:AddLine("Theme: " .. LauncherButton:GetActiveThemeLabel(), 0.7, 0.95, 0.7)
        GameTooltip:AddLine("Drag: Place action bar macro.", 0.7, 0.95, 0.7)
        local key1, key2 = GetBindingKey("PORTALROULETTE_TOGGLE")
        if key1 then
            local bindingText = GetBindingText(key1, "KEY_") or key1
            if key2 then
                bindingText = bindingText .. " / " .. (GetBindingText(key2, "KEY_") or key2)
            end
            GameTooltip:AddLine("Keybind: " .. bindingText, 0.7, 0.95, 0.7)
        end
        if ns.db.lockLauncher then
            GameTooltip:AddLine("Shift-drag to move is locked.", 1, 0.4, 0.4)
        else
            GameTooltip:AddLine("Shift-drag: Move launcher.", 0.7, 0.95, 0.7)
        end
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function()
        if button.frameTexture then
            button.frameTexture:SetVertexColor(0.82, 0.72, 0.54, 0.22)
        end
        if button.accent then
            button.accent:SetAlpha(0.22)
        end
        GameTooltip:Hide()
    end)

    button:SetScript("OnMouseDown", function(selfButton)
        local normal = selfButton:GetNormalTexture()
        if normal then
            normal:ClearAllPoints()
            normal:SetPoint("CENTER", selfButton, "CENTER", 1, -1)
        end
        if selfButton.frameTexture then
            selfButton.frameTexture:SetVertexColor(0.64, 0.54, 0.38, 0.32)
        end
    end)

    button:SetScript("OnMouseUp", function(selfButton)
        local normal = selfButton:GetNormalTexture()
        if normal then
            normal:ClearAllPoints()
            normal:SetPoint("CENTER", selfButton, "CENTER", 0, 0)
        end
        if selfButton.frameTexture then
            if selfButton.IsMouseOver and selfButton:IsMouseOver() then
                selfButton.frameTexture:SetVertexColor(1.0, 0.84, 0.52, 0.44)
            else
                selfButton.frameTexture:SetVertexColor(0.82, 0.72, 0.54, 0.22)
            end
        end
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
