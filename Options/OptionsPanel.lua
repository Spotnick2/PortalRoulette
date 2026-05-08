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

    self.scaleSlider:SetValue(ns.db.uiScale or 1)
    self.scaleValueText:SetText(string.format("%.2f", ns.db.uiScale or 1))
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

    local slider = CreateFrame("Slider", "PortalRouletteScaleSlider", panel, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -410)
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
