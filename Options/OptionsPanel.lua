local _, ns = ...

local OptionsPanel = {
    utilityButtons = {},
}
ns.OptionsPanel = OptionsPanel

local function registerOptionsCategory(panel)
    if InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
        return panel
    end

    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name or "Portal Roulette")
        if Settings.RegisterAddOnCategory then
            Settings.RegisterAddOnCategory(category)
        end
        return category
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
            return
        end
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
    self.soundsEnabledCheckbox:SetChecked(ns.db.soundsEnabled)
    self.hoverSoundsEnabledCheckbox:SetChecked(ns.db.hoverSoundsEnabled)
    self.wheelAnimationCheckbox:SetChecked(ns.db.enableWheelAnimation)
    self.animationsEnabledCheckbox:SetChecked(ns.db.animationsEnabled)
    self.openCloseAnimationsCheckbox:SetChecked(ns.db.openCloseAnimationsEnabled)
    self.idleAnimationsCheckbox:SetChecked(ns.db.idleAnimationsEnabled)
    self.hoverAnimationsCheckbox:SetChecked(ns.db.hoverAnimationsEnabled)
    self.clickPulseCheckbox:SetChecked(ns.db.clickPulseEnabled)
    self.nodeStaggerCheckbox:SetChecked(ns.db.nodeStaggerEnabled)
    self.portalVortexCheckbox:SetChecked(ns.db.portalVortexEnabled)
    self.portalVortexIdleCheckbox:SetChecked(ns.db.portalVortexIdleEnabled)
    self.portalVortexMotesCheckbox:SetChecked(ns.db.portalVortexMotesEnabled)
    self.broadcastPortalsCheckbox:SetChecked(ns.db.broadcastPortals)
    self.broadcastTeleportsCheckbox:SetChecked(ns.db.broadcastTeleports)
    self.broadcastStartCheckbox:SetChecked(ns.db.broadcastOnStart)
    self.broadcastSuccessCheckbox:SetChecked(ns.db.broadcastOnSuccess)
    self.confirmTeleportCheckbox:SetChecked(ns.db.confirmGroupedTeleport)

    self.scaleSlider:SetValue(ns.db.uiScale or 1)
    self.scaleValueText:SetText(string.format("%.2f", ns.db.uiScale or 1))
    self.animationIntensitySlider:SetValue(ns.db.animationIntensity or 1)
    self.animationIntensityValueText:SetText(string.format("%.2f", ns.db.animationIntensity or 1))
    self.portalVortexIntensitySlider:SetValue(ns.db.portalVortexIntensity or 1)
    self.portalVortexIntensityValueText:SetText(string.format("%.2f", ns.db.portalVortexIntensity or 1))
end

function OptionsPanel:Create()
    if self.panel then
        return
    end

    local panel = CreateFrame("Frame", "PortalRouletteOptionsPanel")
    panel.name = "Portal Roulette"

    panel.icon = panel:CreateTexture(nil, "ARTWORK")
    panel.icon:SetSize(20, 20)
    panel.icon:SetPoint("TOPLEFT", 16, -16)
    panel.icon:SetTexture(ns.Media.ICON_PORTAL_ROULETTE or ns.Media.ICON_PORTAL_ROULETTE_64 or ns.Media.ICON_RUNE_TELEPORT_CUSTOM)
    panel.icon:SetTexCoord(0.06, 0.94, 0.06, 0.94)

    panel.title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    panel.title:SetPoint("LEFT", panel.icon, "RIGHT", 8, 0)
    panel.title:SetText("Portal Roulette")

    panel.subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    panel.subtitle:SetPoint("TOPLEFT", panel.title, "BOTTOMLEFT", 0, -8)
    panel.subtitle:SetText("Mage-only floating teleport/portal roulette.")

    local utilityTitle = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    utilityTitle:SetPoint("TOPLEFT", panel.subtitle, "BOTTOMLEFT", 0, -16)
    utilityTitle:SetText("Utility button mode")

    for index, mode in ipairs(ns.UtilityItems:GetModeOrder()) do
        local check = createCheckbox(panel, utilityLabelByMode[mode], 28, -86 - ((index - 1) * 28))
        check:SetScript("OnClick", function(selfButton)
            ns.db.utilityMode = mode
            OptionsPanel:RefreshControls()
            applyAllSettings()
            if not selfButton:GetChecked() then
                selfButton:SetChecked(true)
            end
        end)
        self.utilityButtons[mode] = check
    end

    self.showKarazhanCheckbox = createCheckbox(panel, "Show unavailable Karazhan node", 16, -218)
    self.showKarazhanCheckbox:SetScript("OnClick", function(selfButton)
        ns.db.showUnavailableKarazhan = selfButton:GetChecked() and true or false
        applyAllSettings()
    end)

    self.cameraModeCheckbox = createCheckbox(panel, "Enable cinematic camera mode", 16, -246)
    self.cameraModeCheckbox:SetScript("OnClick", function(selfButton)
        ns.db.cinematicCamera = selfButton:GetChecked() and true or false
        applyAllSettings()
    end)

    self.lockLauncherCheckbox = createCheckbox(panel, "Lock launcher button", 16, -274)
    self.lockLauncherCheckbox:SetScript("OnClick", function(selfButton)
        ns.db.lockLauncher = selfButton:GetChecked() and true or false
    end)

    self.minimapVisibilityCheckbox = createCheckbox(panel, "Show minimap button", 16, -302)
    self.minimapVisibilityCheckbox:SetScript("OnClick", function(selfButton)
        ns.db.showMinimapButton = selfButton:GetChecked() and true or false
        applyAllSettings()
    end)

    self.soundsEnabledCheckbox = createCheckbox(panel, "Enable addon sounds", 16, -330)
    self.soundsEnabledCheckbox:SetScript("OnClick", function(selfButton)
        ns.db.soundsEnabled = selfButton:GetChecked() and true or false
    end)

    self.hoverSoundsEnabledCheckbox = createCheckbox(panel, "Enable hover sounds", 16, -358)
    self.hoverSoundsEnabledCheckbox:SetScript("OnClick", function(selfButton)
        ns.db.hoverSoundsEnabled = selfButton:GetChecked() and true or false
    end)

    self.wheelAnimationCheckbox = createCheckbox(panel, "Enable subtle wheel animation", 16, -386)
    self.wheelAnimationCheckbox:SetScript("OnClick", function(selfButton)
        ns.db.enableWheelAnimation = selfButton:GetChecked() and true or false
    end)

    local animationTitle = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    animationTitle:SetPoint("TOPLEFT", panel, "TOPLEFT", 300, -218)
    animationTitle:SetText("Animation polish")

    self.animationsEnabledCheckbox = createCheckbox(panel, "Enable animations", 300, -246)
    self.animationsEnabledCheckbox:SetScript("OnClick", function(selfButton)
        ns.db.animationsEnabled = selfButton:GetChecked() and true or false
        applyAllSettings()
    end)

    self.openCloseAnimationsCheckbox = createCheckbox(panel, "Opening/closing animation", 300, -274)
    self.openCloseAnimationsCheckbox:SetScript("OnClick", function(selfButton)
        ns.db.openCloseAnimationsEnabled = selfButton:GetChecked() and true or false
    end)

    self.idleAnimationsCheckbox = createCheckbox(panel, "Idle wheel animation", 300, -302)
    self.idleAnimationsCheckbox:SetScript("OnClick", function(selfButton)
        ns.db.idleAnimationsEnabled = selfButton:GetChecked() and true or false
        ns.db.enableWheelAnimation = ns.db.idleAnimationsEnabled
        OptionsPanel:RefreshControls()
        applyAllSettings()
    end)

    self.hoverAnimationsCheckbox = createCheckbox(panel, "Hover animation", 300, -330)
    self.hoverAnimationsCheckbox:SetScript("OnClick", function(selfButton)
        ns.db.hoverAnimationsEnabled = selfButton:GetChecked() and true or false
    end)

    self.clickPulseCheckbox = createCheckbox(panel, "Click pulse", 300, -358)
    self.clickPulseCheckbox:SetScript("OnClick", function(selfButton)
        ns.db.clickPulseEnabled = selfButton:GetChecked() and true or false
    end)

    self.nodeStaggerCheckbox = createCheckbox(panel, "Stagger node reveal", 300, -386)
    self.nodeStaggerCheckbox:SetScript("OnClick", function(selfButton)
        ns.db.nodeStaggerEnabled = selfButton:GetChecked() and true or false
    end)

    local intensitySlider = CreateFrame("Slider", "PortalRouletteAnimationIntensitySlider", panel, "OptionsSliderTemplate")
    intensitySlider:SetPoint("TOPLEFT", panel, "TOPLEFT", 304, -434)
    intensitySlider:SetWidth(180)
    intensitySlider:SetMinMaxValues(0, 1)
    intensitySlider:SetValueStep(0.05)
    if intensitySlider.SetObeyStepOnDrag then
        intensitySlider:SetObeyStepOnDrag(true)
    end
    _G[intensitySlider:GetName() .. "Low"]:SetText("0")
    _G[intensitySlider:GetName() .. "High"]:SetText("1")
    _G[intensitySlider:GetName() .. "Text"]:SetText("Animation intensity")

    self.animationIntensityValueText = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    self.animationIntensityValueText:SetPoint("LEFT", intensitySlider, "RIGHT", 16, 0)

    intensitySlider:SetScript("OnValueChanged", function(_, value)
        ns.db.animationIntensity = value
        OptionsPanel.animationIntensityValueText:SetText(string.format("%.2f", value))
    end)
    self.animationIntensitySlider = intensitySlider

    local vortexTitle = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    vortexTitle:SetPoint("TOPLEFT", panel, "TOPLEFT", 300, -482)
    vortexTitle:SetText("Portal vortex")

    self.portalVortexCheckbox = createCheckbox(panel, "Enable portal vortex", 300, -510)
    self.portalVortexCheckbox:SetScript("OnClick", function(selfButton)
        ns.db.portalVortexEnabled = selfButton:GetChecked() and true or false
        applyAllSettings()
    end)

    self.portalVortexIdleCheckbox = createCheckbox(panel, "Idle vortex motion", 300, -538)
    self.portalVortexIdleCheckbox:SetScript("OnClick", function(selfButton)
        ns.db.portalVortexIdleEnabled = selfButton:GetChecked() and true or false
    end)

    self.portalVortexMotesCheckbox = createCheckbox(panel, "Vortex motes", 300, -566)
    self.portalVortexMotesCheckbox:SetScript("OnClick", function(selfButton)
        ns.db.portalVortexMotesEnabled = selfButton:GetChecked() and true or false
    end)

    local vortexIntensitySlider = CreateFrame("Slider", "PortalRouletteVortexIntensitySlider", panel, "OptionsSliderTemplate")
    vortexIntensitySlider:SetPoint("TOPLEFT", panel, "TOPLEFT", 304, -614)
    vortexIntensitySlider:SetWidth(180)
    vortexIntensitySlider:SetMinMaxValues(0, 1)
    vortexIntensitySlider:SetValueStep(0.05)
    if vortexIntensitySlider.SetObeyStepOnDrag then
        vortexIntensitySlider:SetObeyStepOnDrag(true)
    end
    _G[vortexIntensitySlider:GetName() .. "Low"]:SetText("0")
    _G[vortexIntensitySlider:GetName() .. "High"]:SetText("1")
    _G[vortexIntensitySlider:GetName() .. "Text"]:SetText("Vortex intensity")

    self.portalVortexIntensityValueText = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    self.portalVortexIntensityValueText:SetPoint("LEFT", vortexIntensitySlider, "RIGHT", 16, 0)

    vortexIntensitySlider:SetScript("OnValueChanged", function(_, value)
        ns.db.portalVortexIntensity = value
        OptionsPanel.portalVortexIntensityValueText:SetText(string.format("%.2f", value))
    end)
    self.portalVortexIntensitySlider = vortexIntensitySlider

    self.broadcastPortalsCheckbox = createCheckbox(panel, "Broadcast portals to group", 16, -414)
    self.broadcastPortalsCheckbox:SetScript("OnClick", function(selfButton)
        ns.db.broadcastPortals = selfButton:GetChecked() and true or false
    end)

    self.broadcastTeleportsCheckbox = createCheckbox(panel, "Broadcast teleports to group", 16, -442)
    self.broadcastTeleportsCheckbox:SetScript("OnClick", function(selfButton)
        ns.db.broadcastTeleports = selfButton:GetChecked() and true or false
    end)

    self.broadcastStartCheckbox = createCheckbox(panel, "Broadcast when cast starts", 16, -470)
    self.broadcastStartCheckbox:SetScript("OnClick", function(selfButton)
        ns.db.broadcastOnStart = selfButton:GetChecked() and true or false
    end)

    self.broadcastSuccessCheckbox = createCheckbox(panel, "Broadcast when cast succeeds", 16, -498)
    self.broadcastSuccessCheckbox:SetScript("OnClick", function(selfButton)
        ns.db.broadcastOnSuccess = selfButton:GetChecked() and true or false
    end)

    self.confirmTeleportCheckbox = createCheckbox(panel, "Confirm teleports while grouped", 16, -526)
    self.confirmTeleportCheckbox:SetScript("OnClick", function(selfButton)
        ns.db.confirmGroupedTeleport = selfButton:GetChecked() and true or false
    end)

    local slider = CreateFrame("Slider", "PortalRouletteScaleSlider", panel, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -578)
    slider:SetWidth(220)
    slider:SetMinMaxValues(0.75, 1.35)
    slider:SetValueStep(0.01)
    if slider.SetObeyStepOnDrag then
        slider:SetObeyStepOnDrag(true)
    end
    _G[slider:GetName() .. "Low"]:SetText("0.75")
    _G[slider:GetName() .. "High"]:SetText("1.35")
    _G[slider:GetName() .. "Text"]:SetText("UI Scale")

    self.scaleValueText = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    self.scaleValueText:SetPoint("LEFT", slider, "RIGHT", 16, 0)

    slider:SetScript("OnValueChanged", function(_, value)
        ns.db.uiScale = value
        OptionsPanel.scaleValueText:SetText(string.format("%.2f", value))
        if ns.RouletteFrame then
            ns.RouletteFrame:ApplyScale()
        end
    end)
    self.scaleSlider = slider

    local resetButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetButton:SetSize(180, 24)
    resetButton:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 0, -18)
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
