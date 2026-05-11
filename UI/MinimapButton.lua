local _, ns = ...

local MinimapButton = {}
ns.MinimapButton = MinimapButton

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

local function toRadians(angle)
    return (angle or 0) * math.pi / 180
end

function MinimapButton:UpdatePosition()
    if not self.button or not Minimap then
        return
    end

    local angle = ns.db.minimap.angle or 220
    local radians = toRadians(angle)
    local radius = (Minimap:GetWidth() * 0.5) + 6
    local x = math.cos(radians) * radius
    local y = math.sin(radians) * radius
    self.button:ClearAllPoints()
    self.button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

function MinimapButton:RefreshVisibility()
    if not self.button then
        return
    end
    if ns.db.showMinimapButton then
        self.button:Show()
    else
        self.button:Hide()
    end
end

function MinimapButton:Create()
    if self.button then
        return
    end

    local button = CreateFrame("Button", "PortalRouletteMinimapButton", Minimap)
    button:SetSize(32, 32)
    button:SetFrameStrata("MEDIUM")
    button:SetMovable(true)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetSize(20, 20)
    background:SetPoint("CENTER", 0, 0)
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    background:SetVertexColor(0.08, 0.08, 0.08, 0.95)

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER")
    icon:SetTexture(ns.Media.ICON_PORTAL_ROULETTE_64 or "Interface\\Icons\\Spell_Arcane_PortalShattrath")
    icon:SetTexCoord(0.06, 0.94, 0.06, 0.94)

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetAllPoints()
    border:SetTexture(nil)
    border:Hide()

    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    highlight:SetBlendMode("ADD")

    button:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "RightButton" then
            ns.OptionsPanel:Open()
        else
            ns.RouletteFrame:Toggle()
        end
    end)

    button:SetScript("OnEnter", function(selfButton)
        GameTooltip:SetOwner(selfButton, "ANCHOR_LEFT")
        GameTooltip:SetText("Portal Roulette", 0.8, 0.95, 1)
        GameTooltip:AddLine("Left-click: Open/Close roulette", 0.85, 0.85, 0.85)
        GameTooltip:AddLine("Right-click: Options", 0.85, 0.85, 0.85)
        GameTooltip:AddLine("Drag: Move around minimap", 0.7, 0.95, 0.7)
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    button:SetScript("OnDragStart", function()
        button:SetScript("OnUpdate", function()
            local cursorX, cursorY = GetCursorPosition()
            local minimapX, minimapY = Minimap:GetCenter()
            local scale = Minimap:GetEffectiveScale()
            cursorX = cursorX / scale
            cursorY = cursorY / scale

            local dx = cursorX - minimapX
            local dy = cursorY - minimapY
            local angle = math.deg(atan2(dy, dx))

            ns.db.minimap.angle = angle
            MinimapButton:UpdatePosition()
        end)
    end)

    button:SetScript("OnDragStop", function()
        button:SetScript("OnUpdate", nil)
    end)

    button.icon = icon
    button.border = border
    button.background = background
    self.button = button
end

function MinimapButton:Initialize()
    if not ns.isMage then
        return
    end

    self:Create()
    self:UpdatePosition()
    self:RefreshVisibility()
end
