local _, ns = ...

local OptionsPanel = {
    utilityButtons = {},
}
ns.OptionsPanel = OptionsPanel

local function registerOptionsCategory(panel)
    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name or "Portal Roulette")
        if Settings.RegisterAddOnCategory then
            Settings.RegisterAddOnCategory(category)
        end
        return category
    end

    if InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
        return panel
    end

    return nil
end

local function openOptionsCategory(panel, categoryRef)
    if Settings and Settings.OpenToCategory and categoryRef then
        local categoryID = categoryRef
        if type(categoryRef) == "table" and categoryRef.GetID then
            categoryID = categoryRef:GetID()
        end
        if categoryID then
            Settings.OpenToCategory(categoryID)
            Settings.OpenToCategory(categoryID)
            return
        end
    end

    if Settings and Settings.OpenToCategory then
        return
    end

    if InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory(panel)
        InterfaceOptionsFrame_OpenToCategory(panel)
    end
end

local utilityLabelByMode = {
    [ns.UtilityMode.HEARTHSTONE] = "Hearthstone",
    [ns.UtilityMode.DARK_PORTAL] = "Dark Portal",
    [ns.UtilityMode.NAARU_EMBRACE] = "Naaru's Embrace",
    [ns.UtilityMode.RANDOM] = "Random",
}

local function createSectionHeader(parent, text, x, y)
    local header = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    header:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    header:SetText(text)
    header:SetTextColor(0.92, 0.78, 1.0)
    return header
end

local function createCheckbox(parent, text, x, y)
    local checkbox = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
    checkbox:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    local textRegion = checkbox.Text
    if not textRegion then
        textRegion = checkbox:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        textRegion:SetPoint("LEFT", checkbox, "RIGHT", 2, 0)
        checkbox.Text = textRegion
    end
    textRegion:SetText(text)
    return checkbox
end

local function createRadio(parent, text, x, y)
    local radio = CreateFrame("CheckButton", nil, parent, "UIRadioButtonTemplate")
    radio:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    local textRegion = radio.text or radio.Text
    if not textRegion then
        textRegion = radio:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        textRegion:SetPoint("LEFT", radio, "RIGHT", 4, 0)
        radio.Text = textRegion
    end
    textRegion:SetText(text)
    return radio
end

local function applyAllSettings()
    if ns.LauncherButton then
        ns.LauncherButton:ApplySettings()
    end
    if ns.MinimapButton then
        ns.MinimapButton:RefreshVisibility()
        ns.MinimapButton:UpdatePosition()
    end
    if ns.RouletteFrame then
        ns.RouletteFrame:ApplyScale()
        ns.RouletteFrame:ApplyPosition()
        ns.RouletteFrame:RefreshAll()
    end
    if ns.UtilityButton then
        ns.UtilityButton:Refresh()
    end
end

function OptionsPanel:RefreshControls()
    if not self.panel then
        return
    end

    for mode, button in pairs(self.utilityButtons) do
        button:SetChecked(ns.db.utilityMode == mode)
    end

    self.showKarazhanCheckbox:SetChecked(ns.db.showUnavailableKarazhan)
    self.cameraModeCheckbox:SetChecked(ns.db.cinematicCamera)
    self.lockLauncherCheckbox:SetChecked(ns.db.lockLauncher)
    self.minimapVisibilityCheckbox:SetChecked(ns.db.showMinimapButton)
    self.showOptionsButtonCheckbox:SetChecked(ns.db.showOptionsButton ~= false)
    self.showCloseButtonCheckbox:SetChecked(ns.db.showCloseButton ~= false)
    self.showReagentPanelCheckbox:SetChecked(ns.db.showReagentPanel ~= false)
    self.soundsEnabledCheckbox:SetChecked(ns.db.soundsEnabled)
    self.hoverSoundsEnabledCheckbox:SetChecked(ns.db.hoverSoundsEnabled)
    self.wheelAnimationCheckbox:SetChecked(ns.db.enableWheelAnimation)
    self.animationsEnabledCheckbox:SetChecked(ns.db.animationsEnabled)
    self.openCloseAnimationsCheckbox:SetChecked(ns.db.openCloseAnimationsEnabled)
    self.idleAnimationsCheckbox:SetChecked(ns.db.idleAnimationsEnabled)
    self.hoverAnimationsCheckbox:SetChecked(ns.db.hoverAnimationsEnabled)
    self.clickPulseCheckbox:SetChecked(ns.db.clickPulseEnabled)
    self.nodeStaggerCheckbox:SetChecked(ns.db.nodeStaggerEnabled)
    self.broadcastPortalsCheckbox:SetChecked(ns.db.broadcastPortals)
    self.broadcastTeleportsCheckbox:SetChecked(ns.db.broadcastTeleports)
    self.broadcastStartCheckbox:SetChecked(ns.db.broadcastOnStart)
    self.broadcastSuccessCheckbox:SetChecked(ns.db.broadcastOnSuccess)
    self.confirmTeleportCheckbox:SetChecked(ns.db.confirmGroupedTeleport)

    self.scaleSlider:SetValue(ns.db.uiScale or 1)
    self.scaleValueText:SetText(string.format("%.2f", ns.db.uiScale or 1))
    self.animationIntensitySlider:SetValue(ns.db.animationIntensity or 1)
    self.animationIntensityValueText:SetText(string.format("%.2f", ns.db.animationIntensity or 1))
end

function OptionsPanel:Create()
    if self.panel then
        return
    end

    local panel = CreateFrame("Frame", "PortalRouletteOptionsPanel")
    panel.name = "Portal Roulette"

    panel.icon = panel:CreateTexture(nil, "ARTWORK")
    panel.icon:SetSize(28, 28)
    panel.icon:SetPoint("TOPLEFT", 16, -16)
    panel.icon:SetTexture(ns.Media.ICON_PORTAL_ROULETTE or ns.Media.ICON_PORTAL_ROULETTE_64 or ns.Media.ICON_RUNE_TELEPORT_CUSTOM)
    panel.icon:SetTexCoord(0.06, 0.94, 0.06, 0.94)

    panel.title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    panel.title:SetPoint("LEFT", panel.icon, "RIGHT", 10, 4)
    panel.title:SetText("Portal Roulette")

    panel.subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    panel.subtitle:SetPoint("TOPLEFT", panel.title, "BOTTOMLEFT", 0, -4)
    panel.subtitle:SetText("Mage-only floating teleport/portal roulette.")

    -- Scrollable content area (panel chrome may be shorter than full content)
    local scroll = CreateFrame("ScrollFrame", "PortalRouletteOptionsScroll", panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -56)
    scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -28, 48)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(560, 720)
    scroll:SetScrollChild(content)

    -- Layout constants (anchored inside `content`)
    local LEFT_X, RIGHT_X = 16, 312
    local INDENT = 16
    local TOP = -12
    local SECTION_GAP = 16
    local ROW_GAP = 26
    local HEADER_TO_ROW = 24

    -- ============= LEFT COLUMN =============
    local leftY = TOP

    createSectionHeader(content, "Utility Button", LEFT_X, leftY)
    leftY = leftY - HEADER_TO_ROW

    local modeOrder = ns.UtilityItems:GetModeOrder()
    for _, mode in ipairs(modeOrder) do
        local radio = createRadio(content, utilityLabelByMode[mode], LEFT_X + INDENT, leftY)
        radio:SetScript("OnClick", function(selfButton)
            ns.db.utilityMode = mode
            OptionsPanel:RefreshControls()
            applyAllSettings()
            if not selfButton:GetChecked() then
                selfButton:SetChecked(true)
            end
        end)
        self.utilityButtons[mode] = radio
        leftY = leftY - ROW_GAP
    end

    leftY = leftY - SECTION_GAP
    createSectionHeader(content, "Group Broadcasts", LEFT_X, leftY)
    leftY = leftY - HEADER_TO_ROW

    self.broadcastPortalsCheckbox = createCheckbox(content, "Broadcast portals to group", LEFT_X + INDENT, leftY)
    self.broadcastPortalsCheckbox:SetScript("OnClick", function(selfButton)
        ns.db.broadcastPortals = selfButton:GetChecked() and true or false
    end)
    leftY = leftY - ROW_GAP

    self.broadcastTeleportsCheckbox = createCheckbox(content, "Broadcast teleports to group", LEFT_X + INDENT, leftY)
    self.broadcastTeleportsCheckbox:SetScript("OnClick", function(selfButton)
        ns.db.broadcastTeleports = selfButton:GetChecked() and true or false
    end)
    leftY = leftY - ROW_GAP

    self.broadcastStartCheckbox = createCheckbox(content, "Broadcast when cast starts", LEFT_X + INDENT, leftY)
    self.broadcastStartCheckbox:SetScript("OnClick", function(selfButton)
        ns.db.broadcastOnStart = selfButton:GetChecked() and true or false
    end)
    leftY = leftY - ROW_GAP

    self.broadcastSuccessCheckbox = createCheckbox(content, "Broadcast when cast succeeds", LEFT_X + INDENT, leftY)
    self.broadcastSuccessCheckbox:SetScript("OnClick", function(selfButton)
        ns.db.broadcastOnSuccess = selfButton:GetChecked() and true or false
    end)
    leftY = leftY - ROW_GAP

    self.confirmTeleportCheckbox = createCheckbox(content, "Confirm teleports while grouped", LEFT_X + INDENT, leftY)
    self.confirmTeleportCheckbox:SetScript("OnClick", function(selfButton)
        ns.db.confirmGroupedTeleport = selfButton:GetChecked() and true or false
    end)
    leftY = leftY - ROW_GAP

    -- ============= RIGHT COLUMN =============
    local rightY = TOP

    createSectionHeader(content, "Visibility & Behavior", RIGHT_X, rightY)
    rightY = rightY - HEADER_TO_ROW

    self.showKarazhanCheckbox = createCheckbox(content, "Show unavailable Karazhan node", RIGHT_X + INDENT, rightY)
    self.showKarazhanCheckbox:SetScript("OnClick", function(selfButton)
        ns.db.showUnavailableKarazhan = selfButton:GetChecked() and true or false
        applyAllSettings()
    end)
    rightY = rightY - ROW_GAP

    self.cameraModeCheckbox = createCheckbox(content, "Enable cinematic camera mode", RIGHT_X + INDENT, rightY)
    self.cameraModeCheckbox:SetScript("OnClick", function(selfButton)
        ns.db.cinematicCamera = selfButton:GetChecked() and true or false
        applyAllSettings()
    end)
    rightY = rightY - ROW_GAP

    self.lockLauncherCheckbox = createCheckbox(content, "Lock launcher button", RIGHT_X + INDENT, rightY)
    self.lockLauncherCheckbox:SetScript("OnClick", function(selfButton)
        ns.db.lockLauncher = selfButton:GetChecked() and true or false
    end)
    rightY = rightY - ROW_GAP

    self.minimapVisibilityCheckbox = createCheckbox(content, "Show minimap button", RIGHT_X + INDENT, rightY)
    self.minimapVisibilityCheckbox:SetScript("OnClick", function(selfButton)
        ns.db.showMinimapButton = selfButton:GetChecked() and true or false
        applyAllSettings()
    end)
    rightY = rightY - ROW_GAP

    self.showOptionsButtonCheckbox = createCheckbox(content, "Show options (gear) button", RIGHT_X + INDENT, rightY)
    self.showOptionsButtonCheckbox:SetScript("OnClick", function(selfButton)
        ns.db.showOptionsButton = selfButton:GetChecked() and true or false
        applyAllSettings()
    end)
    rightY = rightY - ROW_GAP

    self.showCloseButtonCheckbox = createCheckbox(content, "Show close button", RIGHT_X + INDENT, rightY)
    self.showCloseButtonCheckbox:SetScript("OnClick", function(selfButton)
        ns.db.showCloseButton = selfButton:GetChecked() and true or false
        applyAllSettings()
    end)
    rightY = rightY - ROW_GAP

    self.showReagentPanelCheckbox = createCheckbox(content, "Show reagent panel", RIGHT_X + INDENT, rightY)
    self.showReagentPanelCheckbox:SetScript("OnClick", function(selfButton)
        ns.db.showReagentPanel = selfButton:GetChecked() and true or false
        applyAllSettings()
    end)
    rightY = rightY - ROW_GAP

    self.soundsEnabledCheckbox = createCheckbox(content, "Enable addon sounds", RIGHT_X + INDENT, rightY)
    self.soundsEnabledCheckbox:SetScript("OnClick", function(selfButton)
        ns.db.soundsEnabled = selfButton:GetChecked() and true or false
    end)
    rightY = rightY - ROW_GAP

    self.hoverSoundsEnabledCheckbox = createCheckbox(content, "Enable hover sounds", RIGHT_X + INDENT, rightY)
    self.hoverSoundsEnabledCheckbox:SetScript("OnClick", function(selfButton)
        ns.db.hoverSoundsEnabled = selfButton:GetChecked() and true or false
    end)
    rightY = rightY - ROW_GAP

    self.wheelAnimationCheckbox = createCheckbox(content, "Enable subtle wheel animation", RIGHT_X + INDENT, rightY)
    self.wheelAnimationCheckbox:SetScript("OnClick", function(selfButton)
        ns.db.enableWheelAnimation = selfButton:GetChecked() and true or false
    end)
    rightY = rightY - ROW_GAP

    rightY = rightY - SECTION_GAP
    createSectionHeader(content, "Animation Polish", RIGHT_X, rightY)
    rightY = rightY - HEADER_TO_ROW

    self.animationsEnabledCheckbox = createCheckbox(content, "Enable animations", RIGHT_X + INDENT, rightY)
    self.animationsEnabledCheckbox:SetScript("OnClick", function(selfButton)
        ns.db.animationsEnabled = selfButton:GetChecked() and true or false
        applyAllSettings()
    end)
    rightY = rightY - ROW_GAP

    self.openCloseAnimationsCheckbox = createCheckbox(content, "Opening/closing animation", RIGHT_X + INDENT, rightY)
    self.openCloseAnimationsCheckbox:SetScript("OnClick", function(selfButton)
        ns.db.openCloseAnimationsEnabled = selfButton:GetChecked() and true or false
    end)
    rightY = rightY - ROW_GAP

    self.idleAnimationsCheckbox = createCheckbox(content, "Idle wheel animation", RIGHT_X + INDENT, rightY)
    self.idleAnimationsCheckbox:SetScript("OnClick", function(selfButton)
        ns.db.idleAnimationsEnabled = selfButton:GetChecked() and true or false
        ns.db.enableWheelAnimation = ns.db.idleAnimationsEnabled
        OptionsPanel:RefreshControls()
        applyAllSettings()
    end)
    rightY = rightY - ROW_GAP

    self.hoverAnimationsCheckbox = createCheckbox(content, "Hover animation", RIGHT_X + INDENT, rightY)
    self.hoverAnimationsCheckbox:SetScript("OnClick", function(selfButton)
        ns.db.hoverAnimationsEnabled = selfButton:GetChecked() and true or false
    end)
    rightY = rightY - ROW_GAP

    self.clickPulseCheckbox = createCheckbox(content, "Click pulse", RIGHT_X + INDENT, rightY)
    self.clickPulseCheckbox:SetScript("OnClick", function(selfButton)
        ns.db.clickPulseEnabled = selfButton:GetChecked() and true or false
    end)
    rightY = rightY - ROW_GAP

    self.nodeStaggerCheckbox = createCheckbox(content, "Stagger node reveal", RIGHT_X + INDENT, rightY)
    self.nodeStaggerCheckbox:SetScript("OnClick", function(selfButton)
        ns.db.nodeStaggerEnabled = selfButton:GetChecked() and true or false
    end)
    rightY = rightY - ROW_GAP

    -- ============= SCALES (full width) =============
    local scalesY = math.min(leftY, rightY) - SECTION_GAP
    createSectionHeader(content, "Scales", LEFT_X, scalesY)
    local sliderY = scalesY - 32

    local scaleSlider = CreateFrame("Slider", "PortalRouletteScaleSlider", content, "OptionsSliderTemplate")
    scaleSlider:SetPoint("TOPLEFT", content, "TOPLEFT", LEFT_X + 4, sliderY)
    scaleSlider:SetWidth(220)
    scaleSlider:SetMinMaxValues(0.75, 1.35)
    scaleSlider:SetValueStep(0.01)
    if scaleSlider.SetObeyStepOnDrag then
        scaleSlider:SetObeyStepOnDrag(true)
    end
    _G[scaleSlider:GetName() .. "Low"]:SetText("0.75")
    _G[scaleSlider:GetName() .. "High"]:SetText("1.35")
    _G[scaleSlider:GetName() .. "Text"]:SetText("UI Scale")

    self.scaleValueText = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    self.scaleValueText:SetPoint("LEFT", scaleSlider, "RIGHT", 12, 0)

    scaleSlider:SetScript("OnValueChanged", function(_, value)
        ns.db.uiScale = value
        OptionsPanel.scaleValueText:SetText(string.format("%.2f", value))
        if ns.RouletteFrame then
            ns.RouletteFrame:ApplyScale()
        end
    end)
    self.scaleSlider = scaleSlider

    local intensitySlider = CreateFrame("Slider", "PortalRouletteAnimationIntensitySlider", content, "OptionsSliderTemplate")
    intensitySlider:SetPoint("TOPLEFT", content, "TOPLEFT", RIGHT_X + 4, sliderY)
    intensitySlider:SetWidth(220)
    intensitySlider:SetMinMaxValues(0, 1)
    intensitySlider:SetValueStep(0.05)
    if intensitySlider.SetObeyStepOnDrag then
        intensitySlider:SetObeyStepOnDrag(true)
    end
    _G[intensitySlider:GetName() .. "Low"]:SetText("0.00")
    _G[intensitySlider:GetName() .. "High"]:SetText("1.00")
    _G[intensitySlider:GetName() .. "Text"]:SetText("Animation Intensity")

    self.animationIntensityValueText = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    self.animationIntensityValueText:SetPoint("LEFT", intensitySlider, "RIGHT", 12, 0)

    intensitySlider:SetScript("OnValueChanged", function(_, value)
        ns.db.animationIntensity = value
        OptionsPanel.animationIntensityValueText:SetText(string.format("%.2f", value))
    end)
    self.animationIntensitySlider = intensitySlider

    -- ============= RESET BUTTON (fixed at panel bottom, outside scroll) =============
    local resetButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetButton:SetSize(180, 24)
    resetButton:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 16, 14)
    resetButton:SetText("Reset Positions")
    resetButton:SetScript("OnClick", function()
        ns.DB:ResetPositions()
        applyAllSettings()
    end)

    panel:SetScript("OnShow", function()
        OptionsPanel:RefreshControls()
    end)

    self.panel = panel
    self.categoryRef = registerOptionsCategory(panel)
end

function OptionsPanel:Open()
    if not self.panel then
        return
    end
    openOptionsCategory(self.panel, self.categoryRef)
end

function OptionsPanel:Initialize()
    self:Create()
end
