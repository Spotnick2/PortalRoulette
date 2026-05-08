local _, ns = ...

local RouletteFrame = {
    mode = ns.Mode.TELEPORT,
    nodeButtons = {},
}
ns.RouletteFrame = RouletteFrame

local atan2 = math.atan2
if not atan2 then
    atan2 = function(y, x)
        if x > 0 then
            return math.atan(y / x)
        elseif x < 0 and y >= 0 then
            return math.atan(y / x) + math.pi
        elseif x < 0 and y < 0 then
            return math.atan(y / x) - math.pi
        elseif x == 0 and y > 0 then
            return math.pi * 0.5
        elseif x == 0 and y < 0 then
            return -math.pi * 0.5
        end
        return 0
    end
end

local function round(value)
    if value >= 0 then
        return math.floor(value + 0.5)
    end
    return math.ceil(value - 0.5)
end

local function getPositionForAngle(angleDeg, radius)
    local radians = math.rad(angleDeg)
    local x = math.cos(radians) * radius
    local y = math.sin(radians) * radius
    return x, y
end

local function setTextureLine(lineTexture, parent, startX, startY, endX, endY)
    if not lineTexture then
        return
    end

    local dx = endX - startX
    local dy = endY - startY
    local length = math.sqrt((dx * dx) + (dy * dy))
    local angle = atan2(dy, dx)

    lineTexture:ClearAllPoints()
    lineTexture:SetPoint("CENTER", parent, "CENTER", (startX + endX) * 0.5, (startY + endY) * 0.5)
    lineTexture:SetSize(length, 3)
    if lineTexture.SetRotation then
        lineTexture:SetRotation(angle)
    end
end

local function createTab(parent, mode, xOffset, texCoordLeft, texCoordRight)
    local tab = CreateFrame("Button", nil, parent)
    tab:SetSize(108, 54)
    tab:SetPoint("TOP", parent.frameRef.wheel, "TOP", xOffset, 22)

    tab.bg = tab:CreateTexture(nil, "BACKGROUND")
    tab.bg:SetAllPoints()
    tab.bg:SetTexCoord(texCoordLeft, texCoordRight, 0, 1)

    tab.mode = mode
    tab.tcLeft = texCoordLeft
    tab.tcRight = texCoordRight
    return tab
end

local function positionLabelForAngle(button, angleDeg)
    local angle = angleDeg % 360
    button.label:ClearAllPoints()

    if angle >= 330 or angle <= 30 then
        button.label:SetPoint("LEFT", button, "RIGHT", 8, 0)
        button.label:SetJustifyH("LEFT")
        button.label:SetWidth(112)
    elseif angle >= 150 and angle <= 210 then
        button.label:SetPoint("RIGHT", button, "LEFT", -8, 0)
        button.label:SetJustifyH("RIGHT")
        button.label:SetWidth(112)
    elseif angle > 30 and angle < 150 then
        button.label:SetPoint("BOTTOM", button, "TOP", 0, 8)
        button.label:SetJustifyH("CENTER")
        button.label:SetWidth(98)
    else
        button.label:SetPoint("TOP", button, "BOTTOM", 0, -8)
        button.label:SetJustifyH("CENTER")
        button.label:SetWidth(112)
    end

    if button.labelBackdrop then
        button.labelBackdrop:SetPoint("CENTER", button.label, "CENTER")
        button.labelBackdrop:SetSize(button.label:GetWidth() + 10, 15)
    end
end

local function getSpellKnown(spellID)
    if not spellID then
        return false
    end
    if IsSpellKnown then
        return IsSpellKnown(spellID)
    end
    local spellName = GetSpellInfo(spellID)
    if spellName then
        return IsUsableSpell(spellName)
    end
    return false
end

local function playFade(frame, fromAlpha, toAlpha, duration)
    if not frame then
        return
    end
    local scale = 1
    if frame.GetScale then
        scale = frame:GetScale()
    end
    ns.Animations:Play(frame, fromAlpha, toAlpha, scale, scale, duration)
end

local function playFadeScale(frame, fromAlpha, toAlpha, fromScale, toScale, duration)
    if not frame then
        return
    end
    local startScale = fromScale or ((frame.GetScale and frame:GetScale()) or 1)
    local endScale = toScale or startScale
    ns.Animations:Play(frame, fromAlpha, toAlpha, startScale, endScale, duration)
end

function RouletteFrame:RunAfter(delay, callback)
    local token = self.presentationToken
    if not C_Timer or not C_Timer.After then
        callback()
        return
    end
    C_Timer.After(delay, function()
        if not self.frame or not self.frame:IsShown() then
            return
        end
        if token ~= self.presentationToken then
            return
        end
        callback()
    end)
end

function RouletteFrame:SetNodeVisualAlpha(alpha)
    for _, line in ipairs(self.nodeLines or {}) do
        line:SetAlpha(alpha)
    end
    for _, button in ipairs(self.nodeButtons or {}) do
        button:SetAlpha(alpha)
    end
    if self.karazhanLine then
        self.karazhanLine:SetAlpha(alpha)
    end
    if self.karazhanButton then
        self.karazhanButton:SetAlpha(alpha)
    end
    if self.karazhanSubtitle then
        self.karazhanSubtitle:SetAlpha(alpha)
    end
end

function RouletteFrame:PlayOpenPresentation()
    if not self.frame then
        return
    end

    self.presentationToken = (self.presentationToken or 0) + 1
    local frame = self.frame

    frame.dimmer:Show()
    frame.dimmer:SetAlpha(0)

    frame.headerGroup:SetAlpha(0)
    frame.headerGroup:SetScale(0.985)
    frame.wheel:SetAlpha(0)
    frame.wheel:SetScale(0.962)
    frame.sideGroup:SetAlpha(0)
    frame.sideGroup:SetScale(0.99)
    frame.lowerGroup:SetAlpha(0)
    frame.lowerGroup:SetScale(0.99)
    self:SetNodeVisualAlpha(0)

    playFade(frame.dimmer, 0, 0.86, 0.2)

    self:RunAfter(0.03, function()
        playFadeScale(frame.headerGroup, 0, 1, 0.985, 1, 0.16)
    end)
    self:RunAfter(0.08, function()
        playFadeScale(frame.wheel, 0, 1, 0.962, 1, 0.18)
    end)
    self:RunAfter(0.12, function()
        for _, line in ipairs(self.nodeLines or {}) do
            playFade(line, 0, 1, 0.12)
        end
        for _, button in ipairs(self.nodeButtons or {}) do
            playFade(button, 0, 1, 0.12)
        end
        if self.karazhanLine then
            playFade(self.karazhanLine, 0, 1, 0.12)
        end
        if self.karazhanButton then
            playFade(self.karazhanButton, 0, 1, 0.12)
        end
        if self.karazhanSubtitle then
            playFade(self.karazhanSubtitle, 0, 1, 0.12)
        end
    end)
    self:RunAfter(0.16, function()
        playFadeScale(frame.sideGroup, 0, 1, 0.99, 1, 0.14)
    end)
    self:RunAfter(0.2, function()
        playFadeScale(frame.lowerGroup, 0, 1, 0.99, 1, 0.14)
    end)
end

function RouletteFrame:PlayClosePresentation(onFinish)
    if not self.frame then
        return
    end

    self.presentationToken = (self.presentationToken or 0) + 1
    local token = self.presentationToken
    local frame = self.frame

    playFade(frame.lowerGroup, frame.lowerGroup:GetAlpha(), 0, 0.12)
    playFade(frame.sideGroup, frame.sideGroup:GetAlpha(), 0, 0.1)
    for _, button in ipairs(self.nodeButtons or {}) do
        playFade(button, button:GetAlpha(), 0, 0.1)
    end
    for _, line in ipairs(self.nodeLines or {}) do
        playFade(line, line:GetAlpha(), 0, 0.1)
    end
    if self.karazhanLine then
        playFade(self.karazhanLine, self.karazhanLine:GetAlpha(), 0, 0.1)
    end
    if self.karazhanButton then
        playFade(self.karazhanButton, self.karazhanButton:GetAlpha(), 0, 0.1)
    end
    if self.karazhanSubtitle then
        playFade(self.karazhanSubtitle, self.karazhanSubtitle:GetAlpha(), 0, 0.1)
    end
    playFade(frame.wheel, frame.wheel:GetAlpha(), 0, 0.12)
    playFade(frame.headerGroup, frame.headerGroup:GetAlpha(), 0, 0.12)
    playFade(frame.dimmer, frame.dimmer:GetAlpha(), 0, 0.15)

    if not C_Timer or not C_Timer.After then
        if onFinish then
            onFinish()
        end
        return
    end

    C_Timer.After(0.17, function()
        if token ~= self.presentationToken then
            return
        end
        if onFinish then
            onFinish()
        end
    end)
end

function RouletteFrame:CreateMainFrame()
    if self.frame then
        return
    end

    local frame = CreateFrame("Frame", "PortalRouletteMainFrame", UIParent)
    frame:SetSize(780, 760)
    frame:SetFrameStrata("FULLSCREEN")
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetClampedToScreen(true)
    -- Critical: ignore UIParent alpha so we remain visible while UIParent is
    -- faded to 0 (Narcissus-style UI hiding). Without this our addon would
    -- inherit the UIParent alpha and disappear along with the WoW UI.
    if frame.SetIgnoreParentAlpha then
        frame:SetIgnoreParentAlpha(true)
    end

    -- Dimmer is ALSO parented to UIParent but ignores parent alpha, so it
    -- remains visible. With UIParent itself at alpha 0, all standard + addon
    -- UI is hidden; the dimmer just provides a dark backdrop over the 3D world.
    frame.dimmer = CreateFrame("Frame", nil, UIParent)
    frame.dimmer:SetAllPoints(UIParent)
    frame.dimmer:SetFrameStrata("FULLSCREEN")
    frame.dimmer:SetFrameLevel(1)
    frame.dimmer:EnableMouse(false)
    if frame.dimmer.SetIgnoreParentAlpha then
        frame.dimmer:SetIgnoreParentAlpha(true)
    end
    frame.dimmer.texture = frame.dimmer:CreateTexture(nil, "BACKGROUND")
    frame.dimmer.texture:SetAllPoints()
    frame.dimmer.texture:SetTexture("Interface\\Buttons\\WHITE8X8")
    -- Horizontal gradient: left side stays clear (character visible) and right
    -- side is heavily dimmed (where the wheel/reagent/UI sit). Modern API
    -- prefers SetGradient with ColorMixin objects; fall back to SetGradientAlpha
    -- on clients that only have the older API.
    local minR, minG, minB, minA = 0.02, 0.02, 0.04, 0.0
    local maxR, maxG, maxB, maxA = 0.02, 0.02, 0.04, 0.92
    if frame.dimmer.texture.SetGradient and CreateColor then
        local ok = pcall(function()
            frame.dimmer.texture:SetGradient(
                "HORIZONTAL",
                CreateColor(minR, minG, minB, minA),
                CreateColor(maxR, maxG, maxB, maxA)
            )
        end)
        if not ok and frame.dimmer.texture.SetGradientAlpha then
            frame.dimmer.texture:SetGradientAlpha(
                "HORIZONTAL",
                minR, minG, minB, minA,
                maxR, maxG, maxB, maxA
            )
        end
    elseif frame.dimmer.texture.SetGradientAlpha then
        frame.dimmer.texture:SetGradientAlpha(
            "HORIZONTAL",
            minR, minG, minB, minA,
            maxR, maxG, maxB, maxA
        )
    else
        -- Last-resort fallback: solid dim if no gradient API is available.
        frame.dimmer.texture:SetVertexColor(maxR, maxG, maxB, maxA)
    end
    frame.dimmer:Hide()

    frame.headerGroup = CreateFrame("Frame", nil, frame)
    frame.headerGroup:SetAllPoints()
    frame.headerGroup.frameRef = frame

    frame.sideGroup = CreateFrame("Frame", nil, frame)
    frame.sideGroup:SetAllPoints()

    frame.lowerGroup = CreateFrame("Frame", nil, frame)
    frame.lowerGroup:SetAllPoints()

    frame:SetScript("OnDragStart", function(selfFrame)
        if not ns.db or InCombatLockdown() then
            return
        end
        if not IsAltKeyDown() then
            return
        end
        selfFrame:StartMoving()
    end)

    frame:SetScript("OnDragStop", function(selfFrame)
        selfFrame:StopMovingOrSizing()
        local point, _, _, x, y = selfFrame:GetPoint(1)
        ns.db.roulette.point = point
        ns.db.roulette.x = round(x)
        ns.db.roulette.y = round(y)
    end)

    frame:SetScript("OnShow", function()
        RouletteFrame:RefreshAll()
        -- Narcissus-style UI hiding: fade UIParent itself to 0. This hides ALL
        -- standard WoW UI AND every addon UI parented to UIParent in one step.
        -- Our own frames have SetIgnoreParentAlpha(true) so they stay visible.
        if UIParent and UIParent.GetAlpha then
            RouletteFrame._savedUIParentAlpha = UIParent:GetAlpha()
            UIParent:SetAlpha(0)
        end
        if ns.db and ns.db.cinematicCamera then
            ns.CameraMode:Enter()
        end
        RouletteFrame:PlayOpenPresentation()
    end)

    frame:SetScript("OnHide", function()
        frame.dimmer:Hide()
        ns.CameraMode:Exit()
        RouletteFrame.presentationToken = (RouletteFrame.presentationToken or 0) + 1
        -- Restore UIParent alpha so the normal WoW UI returns.
        if UIParent and UIParent.SetAlpha then
            UIParent:SetAlpha(RouletteFrame._savedUIParentAlpha or 1.0)
            RouletteFrame._savedUIParentAlpha = nil
        end
    end)

    frame:SetScript("OnUpdate", function(_, elapsed)
        RouletteFrame.outerAngle = (RouletteFrame.outerAngle or 0) + elapsed * 0.055
        RouletteFrame.innerAngle = (RouletteFrame.innerAngle or 0) - elapsed * 0.04

        if RouletteFrame.outerRing and RouletteFrame.outerRing.SetRotation then
            RouletteFrame.outerRing:SetRotation(RouletteFrame.outerAngle)
        end
        if RouletteFrame.innerRing and RouletteFrame.innerRing.SetRotation then
            RouletteFrame.innerRing:SetRotation(RouletteFrame.innerAngle)
        end
        if RouletteFrame.centerCore then
            local pulse = 0.84 + (math.sin(GetTime() * 1.95) * 0.12)
            RouletteFrame.centerCore:SetAlpha(pulse)
        end
    end)

    self.frame = frame
    tinsert(UISpecialFrames, frame:GetName())
end

function RouletteFrame:CreateWheel()
    local frame = self.frame
    frame.wheel = CreateFrame("Frame", nil, frame)
    frame.wheel:SetSize(432, 432)
    frame.wheel:SetPoint("TOP", frame, "TOP", 82, -122)

    self.wheelBase = frame.wheel:CreateTexture(nil, "BACKGROUND")
    self.wheelBase:SetAllPoints()
    self.wheelBase:SetTexture(ns.Media.RUNE_WHEEL_BASE)
    self.wheelBase:SetAlpha(0.92)

    self.factionAccent = frame.wheel:CreateTexture(nil, "BORDER")
    self.factionAccent:SetAllPoints()
    self.factionAccent:SetBlendMode("ADD")
    self.factionAccent:SetAlpha(0.62)

    self.outerRing = frame.wheel:CreateTexture(nil, "ARTWORK")
    self.outerRing:SetAllPoints()
    self.outerRing:SetTexture(ns.Media.RUNE_WHEEL_OUTER)
    self.outerRing:SetBlendMode("ADD")
    self.outerRing:SetAlpha(0.78)

    self.innerRing = frame.wheel:CreateTexture(nil, "ARTWORK")
    self.innerRing:SetAllPoints()
    self.innerRing:SetTexture(ns.Media.RUNE_WHEEL_INNER)
    self.innerRing:SetBlendMode("ADD")
    self.innerRing:SetAlpha(0.78)

    self.centerCore = frame.wheel:CreateTexture(nil, "OVERLAY")
    self.centerCore:SetSize(164, 164)
    self.centerCore:SetPoint("CENTER", frame.wheel, "CENTER")
    self.centerCore:SetTexture(ns.Media.CORE_VORTEX)
    self.centerCore:SetBlendMode("ADD")
    self.centerCore:SetAlpha(1.0)
end

function RouletteFrame:CreateHeader()
    local frame = self.frame
    local parent = frame.headerGroup

    parent.headerTex = parent:CreateTexture(nil, "ARTWORK")
    parent.headerTex:SetSize(300, 60)
    parent.headerTex:SetPoint("BOTTOM", frame.wheel, "TOP", 0, 82)
    parent.headerTex:SetTexture(ns.Media.HEADER_TITLE)

    frame.headerTex = parent.headerTex
end

function RouletteFrame:CreateTabs()
    local frame = self.frame
    local parent = frame.headerGroup

    parent.teleportTab = createTab(parent, ns.Mode.TELEPORT, -54, 0, 0.5)
    parent.portalTab = createTab(parent, ns.Mode.PORTAL, 54, 0.5, 1.0)

    parent.teleportTab:SetScript("OnClick", function()
        RouletteFrame:SetMode(ns.Mode.TELEPORT)
    end)
    parent.portalTab:SetScript("OnClick", function()
        RouletteFrame:SetMode(ns.Mode.PORTAL)
    end)

    parent.gearButton = CreateFrame("Button", nil, parent)
    parent.gearButton:SetSize(40, 40)
    parent.gearButton:SetPoint("LEFT", parent.portalTab, "RIGHT", 8, 0)

    parent.gearButton.bg = parent.gearButton:CreateTexture(nil, "BACKGROUND")
    parent.gearButton.bg:SetAllPoints()
    parent.gearButton.bg:SetTexture(ns.Media.ICON_GEAR)
    parent.gearButton.bg:SetTexCoord(0.04, 0.96, 0.04, 0.96)

    parent.gearButton.highlight = parent.gearButton:CreateTexture(nil, "HIGHLIGHT")
    parent.gearButton.highlight:SetAllPoints()
    parent.gearButton.highlight:SetTexture("Interface\\Buttons\\WHITE8X8")
    parent.gearButton.highlight:SetBlendMode("ADD")
    parent.gearButton.highlight:SetVertexColor(1, 1, 1, 0.14)
    parent.gearButton.highlight:SetAlpha(0)

    parent.gearButton:SetScript("OnClick", function()
        -- Close the roulette first so UIParent alpha is restored, otherwise the
        -- standard options panel would be hidden by our UIParent fade.
        RouletteFrame:Close()
        if C_Timer and C_Timer.After then
            C_Timer.After(0.18, function() ns.OptionsPanel:Open() end)
        else
            ns.OptionsPanel:Open()
        end
    end)
    parent.gearButton:SetScript("OnMouseDown", function(selfButton)
        selfButton.bg:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    end)
    parent.gearButton:SetScript("OnMouseUp", function(selfButton)
        selfButton.bg:SetTexCoord(0.04, 0.96, 0.04, 0.96)
    end)
    parent.gearButton:SetScript("OnEnter", function(selfButton)
        selfButton.highlight:SetAlpha(1)
        GameTooltip:SetOwner(selfButton, "ANCHOR_RIGHT")
        GameTooltip:SetText("Options", 0.8, 0.95, 1)
        GameTooltip:Show()
    end)
    parent.gearButton:SetScript("OnLeave", function(selfButton)
        selfButton.highlight:SetAlpha(0)
        GameTooltip:Hide()
    end)

    frame.teleportTab = parent.teleportTab
    frame.portalTab = parent.portalTab
    frame.gearButton = parent.gearButton
end

function RouletteFrame:CreatePanels()
    local frame = self.frame

    frame.hintFrame = CreateFrame("Frame", nil, frame.lowerGroup)
    frame.hintFrame:SetSize(336, 64)
    frame.hintFrame:SetPoint("TOP", frame.wheel, "BOTTOM", 0, -8)

    frame.hintBg = frame.hintFrame:CreateTexture(nil, "ARTWORK")
    frame.hintBg:SetAllPoints()
    frame.hintBg:SetTexture(ns.Media.HINT_PANEL)
    frame.hintBg:SetAlpha(1.0)

    frame.hintText = frame.hintFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.hintText:SetPoint("CENTER", frame.hintFrame, "CENTER")
    frame.hintText:SetWidth(316)
    frame.hintText:SetJustifyH("CENTER")
    frame.hintText:SetText("|cFFFFCC55Left Click:|r Teleport  \124  |cFF88CCFFRight Click:|r Portal\n|cFF99AABBReagents are shared for all options.|r")
    frame.hintText:SetTextColor(0.90, 0.95, 1.0)

    ns.ReagentPanel:Create(frame.sideGroup)
    ns.ReagentPanel.frame:SetPoint("RIGHT", frame.wheel, "LEFT", -14, 14)

    ns.UtilityButton:Create(frame.lowerGroup)
    ns.UtilityButton.button:SetPoint("TOP", frame.hintFrame, "BOTTOM", 0, -9)

    frame.helpButton = CreateFrame("Button", nil, frame.lowerGroup)
    frame.helpButton:SetSize(18, 18)
    frame.helpButton:SetPoint("RIGHT", frame.hintFrame, "RIGHT", -8, 0)
    frame.helpButton:SetNormalTexture(ns.Media.ICON_HELP)
    frame.helpButton:SetHighlightTexture(ns.Media.ICON_HELP, "ADD")
    frame.helpButton:SetScript("OnClick", function()
        ns.Print("Use /pr options to open settings. ALT-drag the wheel to move it.")
    end)
end

function RouletteFrame:CreateDestinationNodes()
    local wheel = self.frame.wheel
    local destinations = ns.Destinations:GetPlayerDestinations()
    self.nodeButtons = {}
    self.nodeLines = {}

    for index, destination in ipairs(destinations) do
        local button = ns.DestinationNode:Create(wheel, 64)
        local x, y = getPositionForAngle(destination.angleDeg, 152)
        button:SetPoint("CENTER", wheel, "CENTER", x, y)
        button.destination = destination
        positionLabelForAngle(button, destination.angleDeg)
        self.nodeButtons[index] = button

        local line = wheel:CreateTexture(nil, "BACKGROUND")
        line:SetTexture("Interface\\Buttons\\WHITE8X8")
        line:SetVertexColor(0.44, 0.66, 1, 0.76)
        setTextureLine(line, wheel, 0, 0, x, y)
        self.nodeLines[index] = line
    end
end

function RouletteFrame:CreateKarazhanNode()
    local wheel = self.frame.wheel
    local karazhan = ns.Destinations:GetKarazhanNode()

    self.karazhanButton = ns.DestinationNode:Create(wheel, 54)
    self.karazhanButton.baseTexture:SetTexture(ns.Media.KARAZHAN_NODE)
    self.karazhanButton.hoverTexture:SetTexture(ns.Media.KARAZHAN_NODE)

    local x, y = getPositionForAngle(karazhan.angleDeg, karazhan.radius)
    self.karazhanButton:SetPoint("CENTER", wheel, "CENTER", x, y)
    self.karazhanButton.destination = karazhan
    positionLabelForAngle(self.karazhanButton, karazhan.angleDeg)

    self.karazhanSubtitle = wheel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    self.karazhanSubtitle:SetPoint("TOP", self.karazhanButton.label, "BOTTOM", 0, -2)
    self.karazhanSubtitle:SetText("Atiesh only")
    self.karazhanSubtitle:SetTextColor(0.82, 0.68, 1)

    self.karazhanLine = wheel:CreateTexture(nil, "BACKGROUND")
    self.karazhanLine:SetTexture("Interface\\Buttons\\WHITE8X8")
    self.karazhanLine:SetVertexColor(0.74, 0.52, 1, 0.84)

    local attachX, attachY = getPositionForAngle(karazhan.angleDeg, karazhan.ringAttachRadius)
    setTextureLine(self.karazhanLine, wheel, attachX, attachY, x, y)
end

function RouletteFrame:Create()
    self:CreateMainFrame()
    self:CreateWheel()
    self:CreateHeader()
    self:CreateTabs()
    self:CreatePanels()
    self:CreateDestinationNodes()
    self:CreateKarazhanNode()
    self:ApplyScale()
    self:ApplyPosition()
    self:SetMode(ns.db.lastMode or ns.Mode.TELEPORT)
    self.frame:Hide()
end

function RouletteFrame:ApplyScale()
    if self.frame and ns.db then
        self.frame:SetScale(ns.db.uiScale or 1)
    end
end

function RouletteFrame:ApplyPosition()
    if not self.frame or not ns.db then
        return
    end
    self.frame:ClearAllPoints()
    self.frame:SetPoint(ns.db.roulette.point or "CENTER", UIParent, ns.db.roulette.point or "CENTER", ns.db.roulette.x or 0, ns.db.roulette.y or 0)
end

function RouletteFrame:UpdateTabVisuals()
    if not self.frame then
        return
    end
    local teleportActive = self.mode == ns.Mode.TELEPORT
    local tabTex = teleportActive and ns.Media.TABS_TELEPORT_ACTIVE or ns.Media.TABS_PORTAL_ACTIVE
    self.frame.teleportTab.bg:SetTexture(tabTex)
    self.frame.teleportTab.bg:SetTexCoord(0, 0.5, 0, 1)
    self.frame.portalTab.bg:SetTexture(tabTex)
    self.frame.portalTab.bg:SetTexCoord(0.5, 1.0, 0, 1)
end

function RouletteFrame:SetMode(mode)
    if mode ~= ns.Mode.TELEPORT and mode ~= ns.Mode.PORTAL then
        mode = ns.Mode.TELEPORT
    end

    if InCombatLockdown() then
        ns.Print("Cannot switch modes in combat.")
        return
    end

    self.mode = mode
    ns.db.lastMode = mode
    self:UpdateTabVisuals()
    self:RefreshDestinationNodes()
end

function RouletteFrame:BuildNodeState(destination)
    local teleportSpellID, teleportSpellName = ns.Destinations:GetSpellForMode(destination, ns.Mode.TELEPORT)
    local portalSpellID, portalSpellName = ns.Destinations:GetSpellForMode(destination, ns.Mode.PORTAL)
    local icon, _ = ns.Destinations:GetIconForDestination(destination, self.mode)

    -- Visual enabled = spells known AND reagents available (for desaturation/label only;
    -- buttons are always interactable and WoW reports errors naturally).
    local teleportKnown = getSpellKnown(teleportSpellID)
    local portalKnown = getSpellKnown(portalSpellID)
    local teleportReagents = GetItemCount(ns.Constants.ITEM_RUNE_TELEPORTATION, false, false) or 0
    local portalReagents   = GetItemCount(ns.Constants.ITEM_RUNE_PORTALS, false, false) or 0
    local enabled = (teleportKnown and teleportReagents > 0) or (portalKnown and portalReagents > 0)

    local detail
    if not teleportKnown then
        detail = "Spell not known."
    elseif teleportReagents == 0 then
        detail = "Missing reagent."
    else
        detail = teleportSpellName
    end

    return {
        label             = destination.label,
        icon              = icon,
        enabled           = enabled,
        tooltipTitle      = destination.label,
        tooltipDetail     = detail,
        -- Spell names provided unconditionally so OnClick always has a target.
        teleportSpellName = teleportSpellName or "",
        portalSpellName   = portalSpellName   or "",
    }
end

function RouletteFrame:BuildKarazhanState()
    local hasAtiesh = ns.UtilityItems:HasItem(ns.Constants.ITEM_ATIESH)
    local showDisabled = ns.db.showUnavailableKarazhan
    local isPortalMode = self.mode == ns.Mode.PORTAL

    if not isPortalMode then
        return nil, false
    end
    if (not hasAtiesh) and (not showDisabled) then
        return nil, false
    end

    local enabled = hasAtiesh
    local detail = enabled and "Use Atiesh to open a portal to Karazhan." or "Requires Atiesh."
    local icon, _ = ns.Destinations:GetIconForDestination(ns.Destinations:GetKarazhanNode(), self.mode)

    return {
        label           = "Karazhan",
        icon            = icon,
        enabled         = enabled,
        tooltipTitle    = "Karazhan (Atiesh only)",
        tooltipDetail   = detail,
        -- Karazhan only has the Atiesh macro path (no teleport spell exists).
        -- karazhanMacro triggers SecureActionButtonTemplate for both clicks.
        karazhanMacro   = "/use item:" .. ns.Constants.ITEM_ATIESH,
        teleportSpellName = "",
        portalSpellName   = "",
        normalTexture   = ns.Media.KARAZHAN_NODE,
        disabledTexture = ns.Media.KARAZHAN_NODE,
    }, true
end

function RouletteFrame:RefreshDestinationNodes()
    if not self.frame then
        return
    end

    local faction = UnitFactionGroup("player")
    self.factionAccent:SetTexture((faction == ns.Constants.FACTION_HORDE) and ns.Media.FACTION_HORDE or ns.Media.FACTION_ALLIANCE)

    for _, button in ipairs(self.nodeButtons) do
        local state = self:BuildNodeState(button.destination)
        ns.DestinationNode:ApplyState(button, state)
    end

    local karazhanState, shouldShowKarazhan = self:BuildKarazhanState()
    self.karazhanButton:SetShown(shouldShowKarazhan)
    self.karazhanLine:SetShown(shouldShowKarazhan)
    self.karazhanSubtitle:SetShown(shouldShowKarazhan)
    if shouldShowKarazhan and karazhanState then
        ns.DestinationNode:ApplyState(self.karazhanButton, karazhanState)
    end
end

function RouletteFrame:RefreshAll()
    if not self.frame then
        return
    end
    self:ApplyScale()
    self:UpdateTabVisuals()
    self:RefreshDestinationNodes()
    ns.ReagentPanel:Refresh()
    ns.UtilityButton:Refresh()
end

function RouletteFrame:IsShown()
    return self.frame and self.frame:IsShown()
end

function RouletteFrame:Open(mode)
    if not self.frame then
        self:Create()
    end
    if InCombatLockdown() then
        ns.Print("Cannot open roulette in combat.")
        return
    end
    if mode then
        self:SetMode(mode)
    end
    self.frame:Show()
end

function RouletteFrame:Close()
    if not self.frame or not self.frame:IsShown() then
        return
    end

    self:PlayClosePresentation(function()
        if self.frame then
            self.frame:Hide()
            self.frame:SetAlpha(1)
            self.frame:SetScale(ns.db and (ns.db.uiScale or 1) or 1)
            self.frame.wheel:SetScale(1)
            self.frame.headerGroup:SetScale(1)
            self.frame.sideGroup:SetScale(1)
            self.frame.lowerGroup:SetScale(1)
        end
    end)
end

function RouletteFrame:Toggle(mode)
    if self:IsShown() then
        self:Close()
    else
        self:Open(mode)
    end
end

function RouletteFrame:Initialize()
    if not ns.isMage then
        return
    end
    self:Create()
end
