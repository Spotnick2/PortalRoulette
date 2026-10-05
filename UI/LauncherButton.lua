local _, ns = ...

local LauncherButton = {}
ns.LauncherButton = LauncherButton

local MACRO_NAME = "Portal Roulette"
local MACRO_BODY = "/pr"
-- Macro pickup needs a client-resolved icon. The custom TGA is valid on our
-- own textures but leaves the macro icon unset on Forever (owner test).
-- The macro icon: a Forever client icon (file ID; macro icons cannot be
-- addon textures). Chosen by the owner, 2026-10-05.
local MACRO_ICON = 5929586
-- Icons earlier versions set on the /pr macro, upgraded to MACRO_ICON.
local PREVIOUS_DEFAULT_ICONS = { [135748] = true } -- Portal: Stormwind's texture
local BASE_BUTTON_SIZE = 52
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
        color = { 0.64, 0.38, 1.0 },
    },
    [THEME_KEY_FIRE] = {
        color = { 1.0, 0.42, 0.16 },
    },
    [THEME_KEY_FROST] = {
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
    button.art:SetTexture(ns.Media.LAUNCHER_PORTAL)
    local c = theme.color or { 0.64, 0.38, 1.0 }
    ns.Skin:SetRimColor(button.glass, 0.65 + c[1] * 0.35, 0.65 + c[2] * 0.35, 0.65 + c[3] * 0.35, 0.8)
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
    return MACRO_ICON
end

-- An icon that needs replacing: none, an invalid ID, the question mark
-- (134400), or our own addon texture path in any spelling the client might
-- hand back (case, slashes, with or without .tga). Macro icons cannot be
-- addon textures, so those show as a question mark.
local QUESTION_MARK = 134400
local function needsMacroIcon(icon)
    if icon == nil or icon == "" or icon == QUESTION_MARK then
        return true
    end
    if type(icon) == "number" then
        return icon <= 0 or PREVIOUS_DEFAULT_ICONS[icon] == true
    end
    return type(icon) == "string" and icon:lower():find("portalroulette", 1, true) ~= nil
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
    ns.API.RegisterEvents(eventFrame, "PLAYER_ENTERING_WORLD", "ACTIONBAR_SLOT_CHANGED", "UPDATE_MACROS", "PLAYER_REGEN_ENABLED")
    eventFrame:SetScript("OnEvent", function(_, event)
        -- Macros may not be loaded at login: retry the icon repair once they
        -- are, and after combat if it was deferred.
        if event == "UPDATE_MACROS" or event == "PLAYER_ENTERING_WORLD"
            or (event == "PLAYER_REGEN_ENABLED" and LauncherButton.pendingMacroIcon) then
            LauncherButton:RefreshExistingMacroIcon()
        end
        LauncherButton:ScheduleVisibilityRefresh()
    end)
    self.eventFrame = eventFrame
end

-- Repair our previously exported custom icon once, preserving user-selected
-- icons and macro bodies. Defer writes until out of combat.
function LauncherButton:RefreshExistingMacroIcon()
    if InCombatLockdown() then
        self.pendingMacroIcon = true
        return
    end
    self.pendingMacroIcon = nil
    if type(GetMacroIndexByName) ~= "function" or type(GetMacroInfo) ~= "function" then return end
    local index = GetMacroIndexByName(MACRO_NAME)
    if not index or index == 0 then return end
    local name, icon, body = GetMacroInfo(index)
    if name == MACRO_NAME and body == MACRO_BODY and needsMacroIcon(icon) then
        -- Guarded: a refused edit must not abort the launcher's setup.
        if type(EditMacro) == "function" then pcall(EditMacro, index, nil, self:GetDesiredMacroIcon()) end
    end
end

function LauncherButton:CreateOrUpdateMacro()
    if type(GetMacroIndexByName) ~= "function" then
        return nil, "api"
    end
    if InCombatLockdown and InCombatLockdown() then
        return nil, "combat"
    end

    local desiredIcon = self:GetDesiredMacroIcon()
    local macroIndex = GetMacroIndexByName(MACRO_NAME)
    if not macroIndex or macroIndex == 0 then
        if type(CreateMacro) ~= "function" then
            return nil, "api"
        end

        local ok, index = pcall(CreateMacro, MACRO_NAME, desiredIcon, MACRO_BODY, true)
        macroIndex = ok and index or nil
        if not macroIndex or macroIndex == 0 then
            ns.Print("Unable to create character macro '" .. MACRO_NAME .. "'. Macro slots may be full. Create it manually with body '/pr'.")
            return nil, "limit"
        end
    elseif type(EditMacro) == "function" then
        local _, icon, body = GetMacroInfo(macroIndex)
        local repairIcon = needsMacroIcon(icon)
        if repairIcon or body ~= MACRO_BODY then
            -- FrameXML uses four arguments and retains the returned index:
            -- editing can reorder macros. Never infer a bank from its count.
            local ok, index = pcall(EditMacro, macroIndex, nil, repairIcon and desiredIcon or nil, MACRO_BODY)
            if not ok then
                ns.Print("Unable to update the launcher macro: " .. tostring(index))
                return nil, "reported"
            end
            macroIndex = index or GetMacroIndexByName(MACRO_NAME)
        end
    end
    if not macroIndex or macroIndex == 0 then return nil, "api" end
    return macroIndex
end

function LauncherButton:PickupLauncherMacro()
    if InCombatLockdown and InCombatLockdown() then
        ns.Print("Cannot place the Portal Roulette macro while in combat.")
        return
    end

    local macroIndex, reason = self:CreateOrUpdateMacro()
    if not macroIndex then
        if reason ~= "limit" and reason ~= "combat" and reason ~= "reported" then
            ns.Print("Unable to prepare the Portal Roulette macro.")
        end
        return
    end

    if type(PickupMacro) == "function" then
        local ok, err = pcall(PickupMacro, macroIndex)
        if not ok then
            ns.Print("Unable to pick up the launcher macro: " .. tostring(err))
        elseif GetCursorInfo() ~= "macro" then
            ns.Print("The client did not put the launcher macro on the cursor. Open /macro and drag 'Portal Roulette' from there.")
        end
    end
    self:ScheduleVisibilityRefresh()
end

function LauncherButton:CreatePrompt()
    if self.prompt or not self.button then
        return
    end
    local Skin = ns.Skin
    local prompt = CreateFrame("Frame", nil, UIParent)
    prompt:SetSize(184, 46)
    -- The launcher's own strata, just above it: DIALOG would draw over the
    -- Settings panel and other windows.
    prompt:SetFrameStrata(self.button:GetFrameStrata())
    prompt:SetFrameLevel(self.button:GetFrameLevel() + 5)
    prompt.glass = Skin:Pill(prompt)
    if prompt.glass.grain then prompt.glass.grain:SetAlpha(0.04) end
    if prompt.glass.wash then prompt.glass.wash:SetAlpha(0.3) end
    local top = prompt.glass.top or prompt

    local pointer = prompt:CreateTexture(nil, "BACKGROUND")
    pointer:SetSize(16, 8)
    pointer:SetPoint("TOP", prompt, "BOTTOM", 0, 1)
    pointer:SetTexture(ns.Media.LAUNCHER_POINTER)
    pointer:SetVertexColor(0.58, 0.72, 0.92, 0.65)
    prompt.pointer = pointer

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
    subtitle:SetText("Drag onto an action bar")
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
        self:RefreshAttention()
        return
    end
    self:PositionPrompt()
    self.prompt:Show()
    self:RefreshAttention()
end

-- Blue action-button attention, like ForeverCombatAssistant. A visual-only
-- child pulses while the placement hint or hover tooltip is showing.
function LauncherButton:RefreshAttention()
    local button = self.button
    if not button then return end
    local active = button:IsShown() and (button.hovered or (self.prompt and self.prompt:IsShown()))
    button.attention:SetShown(active and true or false)
    local intensity = ns.Anim.Intensity()
    button.attention:SetAlpha(0.45 + 0.4 * intensity)
    if active and ns.Anim.Enabled("idle") and intensity > 0 then
        if not button.attentionPulse:IsPlaying() then button.attentionPulse:Play() end
    else
        button.attentionPulse:Stop()
    end
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

-- A recognizable action-bar border inside a glass surround. Decoration
-- never handles the mouse: the framed button owns click and drag.
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
    glow:SetPoint("TOPLEFT", -10, 10)
    glow:SetPoint("BOTTOMRIGHT", 10, -10)
    glow:SetTexture(ns.Media.GLOW) -- generated by Tools/make_art.py
    glow:SetBlendMode("ADD")
    glow:SetAlpha(0)
    button.glow = glow

    button.glass = Skin:Pill(button)
    if button.glass.top then button.glass.top:EnableMouse(false) end
    local art = button:CreateTexture(nil, "ARTWORK", nil, 1)
    art:SetPoint("TOPLEFT", 6, -6)
    art:SetPoint("BOTTOMRIGHT", -6, 6)
    button.art = art
    local border = (button.glass.top or button):CreateTexture(nil, "OVERLAY", nil, 4)
    border:SetAllPoints(button)
    -- The action-bar icon frame atlas (Mainline FrameXML); not probed on
    -- 70205, so fall back to no frame rather than a missing-texture square.
    local hasAtlas = C_Texture and C_Texture.GetAtlasExists and C_Texture.GetAtlasExists("UI-HUD-ActionBar-IconFrame")
    if hasAtlas then
        border:SetAtlas("UI-HUD-ActionBar-IconFrame")
    else
        border:Hide()
    end
    button.border = border
    local highlight = button:CreateTexture(nil, "ARTWORK", nil, 2)
    highlight:SetAllPoints(art)
    highlight:SetTexture(ns.Media.WHITE)
    highlight:SetVertexColor(0.65, 0.8, 1)
    highlight:SetAlpha(0)
    if button.glass.mask then highlight:AddMaskTexture(button.glass.mask) end
    button.highlight = highlight
    if button.glass.rim then button.glass.rim:SetAlpha(0.65) end

    local attention = CreateFrame("Frame", nil, button)
    attention:SetPoint("TOPLEFT", -2, 2)
    attention:SetPoint("BOTTOMRIGHT", 2, -2)
    attention:SetFrameLevel(button:GetFrameLevel() + 12)
    attention:EnableMouse(false)
    local light = CreateFrame("Frame", nil, attention)
    light:SetAllPoints()
    light:EnableMouse(false)
    for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local edge = light:CreateTexture(nil, "OVERLAY")
        edge:SetColorTexture(0.25, 0.62, 1, 0.95)
        if side == "TOP" or side == "BOTTOM" then
            edge:SetHeight(2)
            edge:SetPoint(side .. "LEFT")
            edge:SetPoint(side .. "RIGHT")
        else
            edge:SetWidth(2)
            edge:SetPoint("TOP" .. side)
            edge:SetPoint("BOTTOM" .. side)
        end
    end
    button.attention = attention
    button.attentionPulse = ns.Anim.Pulse(light, 1.6, 0.3)

    button:SetScript("OnClick", function(_, mouseButton)
        if button.dragged then return end
        if mouseButton == "RightButton" and IsShiftKeyDown() then
            if ns.Options then ns.Options:Open() end
            return
        end
        ns.Roulette:Toggle()
    end)

    button:SetScript("OnDragStart", function(selfButton)
        selfButton.dragged = true
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
        glow:SetAlpha(0.3 * ns.Anim.HoverStrength())
        highlight:SetAlpha(0.08 * ns.Anim.HoverStrength())
        if selfButton.glass.rim then selfButton.glass.rim:SetAlpha(0.85) end
        LauncherButton:ApplyTheme(LauncherButton.themeKey)
        showTooltip(selfButton)
        LauncherButton:RefreshAttention()
    end)

    button:SetScript("OnLeave", function(selfButton)
        selfButton.hovered = false
        glow:SetAlpha(0)
        highlight:SetAlpha(0)
        art:SetVertexColor(1, 1, 1)
        if selfButton.glass.rim then selfButton.glass.rim:SetAlpha(0.65) end
        LauncherButton:ApplyTheme(LauncherButton.themeKey)
        GameTooltip:Hide()
        LauncherButton:RefreshAttention()
    end)

    button:SetScript("OnMouseDown", function()
        button.dragged = false
        art:SetVertexColor(0.78, 0.82, 0.9)
    end)
    button:SetScript("OnMouseUp", function()
        art:SetVertexColor(1, 1, 1)
    end)
    -- The launcher hides with UIParent while the wheel owns the screen:
    -- only touch the tooltip if it is ours, and bring the attention border
    -- back when the button shows again.
    button:SetScript("OnHide", function(selfButton)
        selfButton.hovered = false
        selfButton.attentionPulse:Stop()
        selfButton.attention:Hide()
        if GameTooltip:IsOwned(selfButton) then GameTooltip:Hide() end
    end)
    button:SetScript("OnShow", function()
        LauncherButton:RefreshAttention()
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
    self:RefreshExistingMacroIcon()
    self:ApplySettings()
    self:ScheduleSpecThemeRefresh()
    self:RefreshVisibility()
end
