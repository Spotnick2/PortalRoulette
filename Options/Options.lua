-- ============================================================
-- Options: a Settings canvas category (Options > AddOns > Portal Roulette).
--
-- Registered at PLAYER_LOGIN, hidden right after creation (a page shown
-- once at creation renders blank on its first visit), built on first show
-- and re-read on every show. Plain template widgets measured on Forever:
-- UICheckButtonTemplate, UIPanelButtonTemplate. No UIDropDownMenu: choices
-- cycle on a button; numbers use - / + steppers.
-- ============================================================

local _, ns = ...

local Options = {}
ns.Options = Options

local panel
local controls = {}

local function set(key, value)
    ns.db[key] = value
    if ns.Options.OnChanged then
        ns.Options.OnChanged(key, value)
    end
end

local function checkbox(parent, label)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(24, 24)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    fs:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    fs:SetJustifyH("LEFT")
    fs:SetText(label)
    cb.label = fs
    return cb
end

local function button(parent, text, width)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width or 24, 22)
    b:SetText(text)
    return b
end

local function heading(parent, text, anchor, x, y)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    if anchor then
        fs:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", x or 0, y or -16)
    end
    fs:SetText(text)
    return fs
end

local function toggle(parent, anchor, key, label, invert)
    local cb = checkbox(parent, label)
    cb:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -4)
    cb:SetScript("OnClick", function(self)
        local on = self:GetChecked() == true
        if invert then on = not on end
        set(key, on)
    end)
    controls[#controls + 1] = function()
        local v = ns.db[key] == true
        if invert then v = not v end
        cb:SetChecked(v)
    end
    return cb
end

-- choices = { { value, text }, ... }
local function cycle(parent, anchor, key, label, choices)
    local b = button(parent, "", 170)
    b:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -6)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    fs:SetPoint("LEFT", b, "RIGHT", 8, 0)
    fs:SetText(label)
    local function refresh()
        for _, c in ipairs(choices) do
            if c[1] == ns.db[key] then b:SetText(c[2]) return end
        end
        b:SetText(choices[1][2])
    end
    b:SetScript("OnClick", function()
        local nextIndex = 1
        for i, c in ipairs(choices) do
            if c[1] == ns.db[key] then nextIndex = i % #choices + 1 break end
        end
        set(key, choices[nextIndex][1])
        refresh()
    end)
    controls[#controls + 1] = refresh
    return b
end

local function stepper(parent, anchor, key, label, minV, maxV, step, fmt)
    local minus = button(parent, "-")
    minus:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -6)
    local value = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    value:SetWidth(48)
    value:SetPoint("LEFT", minus, "RIGHT", 2, 0)
    local plus = button(parent, "+")
    plus:SetPoint("LEFT", value, "RIGHT", 2, 0)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    fs:SetPoint("LEFT", plus, "RIGHT", 8, 0)
    fs:SetText(label)
    local function refresh() value:SetText(string.format(fmt, tonumber(ns.db[key]) or minV)) end
    local function bump(sign)
        local v = (tonumber(ns.db[key]) or minV) + sign * step
        v = math.max(minV, math.min(maxV, math.floor(v / step + 0.5) * step))
        set(key, v)
        refresh()
    end
    minus:SetScript("OnClick", function() bump(-1) end)
    plus:SetScript("OnClick", function() bump(1) end)
    controls[#controls + 1] = refresh
    return minus
end

local function build()
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Portal Roulette")
    local sub = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    sub:SetWidth(620)
    sub:SetJustifyH("LEFT")
    sub:SetText("Left-click a destination to teleport, right-click to open a portal. /pr opens the wheel, /pr options this page.")

    -- Left column.
    local h = heading(panel, "Wheel", sub, 0, -18)
    local a = cycle(panel, h, "utilityMode", "Center orb", {
        { "hearthstone", "Hearthstone" }, { "random", "Random owned hearth" } })
    a = cycle(panel, a, "reagentDisplay", "Reagent counts", {
        { "auto", "Auto" }, { "show", "Always show" }, { "hide", "Hide" } })
    a = toggle(panel, a, "showUnavailableKarazhan", "Show Karazhan without Atiesh")
    a = toggle(panel, a, "confirmGroupedTeleport", "Confirm teleports while grouped")
    a = stepper(panel, a, "uiScale", "Wheel scale", 0.6, 1.6, 0.05, "%.2f")

    h = heading(panel, "Animation", a, 0, -18)
    a = toggle(panel, h, "animationsEnabled", "Animations")
    a = toggle(panel, a, "idleAnimationsEnabled", "Idle motion (rune rings, sparks, glows)")
    a = toggle(panel, a, "hoverAnimationsEnabled", "Hover effects")

    h = heading(panel, "Sound", a, 0, -18)
    a = toggle(panel, h, "soundsEnabled", "Sounds")
    a = toggle(panel, a, "hoverSoundsEnabled", "Hover sounds")
    a = cycle(panel, a, "soundTheme", "Sound set", {
        { "addon", "Portal Roulette" }, { "game", "Game UI sounds" } })
    a = cycle(panel, a, "soundChannel", "Volume channel", {
        { "SFX", "Effects" }, { "Master", "Master" }, { "Ambience", "Ambience" }, { "Dialog", "Dialog" } })
    local test = button(panel, "Test", 60)
    test:SetPoint("TOPLEFT", a, "BOTTOMLEFT", 0, -6)
    test:SetScript("OnClick", function() if ns.Sound then ns.Sound:Play("Open") end end)
    a = test

    -- Right column.
    local right = CreateFrame("Frame", nil, panel)
    right:SetSize(1, 1)
    right:SetPoint("TOPLEFT", sub, "BOTTOMLEFT", 330, 0)
    h = heading(panel, "Presentation", right, 0, -18)
    a = toggle(panel, h, "hideGameUI", "Hide the game UI while the wheel is open")
    a = toggle(panel, a, "cinematicCamera", "Cinematic camera (face the character)")
    a = toggle(panel, a, "cameraOrbit", "Slow camera orbit")
    a = toggle(panel, a, "cameraCastAware", "Frame the character while casting")

    h = heading(panel, "Launcher", a, 0, -18)
    a = toggle(panel, h, "lockLauncher", "Lock the launcher")
    a = toggle(panel, a, "showMinimapButton", "Minimap button")
    a = cycle(panel, a, "launcherTheme", "Launcher theme", {
        { "auto", "Auto (Arcane)" }, { "arcane", "Arcane" }, { "fire", "Fire" }, { "frost", "Frost" } })
    a = stepper(panel, a, "launcherScale", "Launcher scale", 0.6, 2.0, 0.05, "%.2f")

    h = heading(panel, "Group broadcast", a, 0, -18)
    a = toggle(panel, h, "broadcastPortals", "Announce portals")
    a = toggle(panel, a, "broadcastTeleports", "Announce teleports")

    local reset = button(panel, "Reset positions", 150)
    reset:SetPoint("TOPLEFT", a, "BOTTOMLEFT", 0, -18)
    reset:SetScript("OnClick", function()
        if InCombatLockdown() then return end
        ns.DB:ResetPositions()
        if ns.Options.OnChanged then ns.Options.OnChanged("positions") end
    end)
    local preview = button(panel, "Toggle preview", 150)
    preview:SetPoint("LEFT", reset, "RIGHT", 8, 0)
    preview:SetScript("OnClick", function()
        if ns.Roulette then ns.Roulette:SetPreview(not ns.Roulette.preview) end
    end)
end

function Options.Refresh()
    for _, refresh in ipairs(controls) do
        refresh()
    end
end

function Options:Register()
    if panel then
        return
    end
    panel = CreateFrame("Frame", "PortalRouletteOptions")
    panel.name = "Portal Roulette"
    panel:Hide()
    local built = false
    panel:SetScript("OnShow", function()
        if not built then
            built = true
            build()
        end
        Options.Refresh()
    end)
    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(category)
        self.category = category
    end
end

function Options:Open()
    if InCombatLockdown() then
        return
    end
    if self.category and Settings and Settings.OpenToCategory then
        pcall(Settings.OpenToCategory, self.category:GetID())
    end
end
