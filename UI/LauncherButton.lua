local _, ns = ...

local LauncherButton = {}
ns.LauncherButton = LauncherButton

local function round(value)
    if value >= 0 then
        return math.floor(value + 0.5)
    end
    return math.ceil(value - 0.5)
end

function LauncherButton:Create()
    if self.button then
        return
    end

    local button = CreateFrame("Button", "PortalRouletteLauncherButton", UIParent)
    button:SetSize(46, 46)
    button:SetMovable(true)
    button:EnableMouse(true)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")

    button.back = button:CreateTexture(nil, "BACKGROUND")
    button.back:SetAllPoints()
    button.back:SetTexture("Interface\\Buttons\\WHITE8X8")
    button.back:SetVertexColor(0.05, 0.05, 0.1, 0.45)

    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetSize(38, 38)
    button.icon:SetPoint("CENTER", button, "CENTER")
    button.icon:SetTexture(ns.Media.ICON_MINIMAP)
    button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    button.border = button:CreateTexture(nil, "OVERLAY")
    button.border:SetAllPoints()
    button.border:SetTexture(ns.Media.NODE_NORMAL)
    button.border:SetVertexColor(0.42, 0.6, 1, 0.8)

    button.highlight = button:CreateTexture(nil, "HIGHLIGHT")
    button.highlight:SetAllPoints()
    button.highlight:SetTexture("Interface\\Buttons\\WHITE8X8")
    button.highlight:SetBlendMode("ADD")
    button.highlight:SetVertexColor(0.35, 0.55, 1, 0.2)

    button:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "RightButton" then
            ns.RouletteFrame:Toggle(ns.Mode.PORTAL)
        else
            ns.RouletteFrame:Toggle(ns.Mode.TELEPORT)
        end
    end)

    button:SetScript("OnDragStart", function(selfButton)
        if ns.db.lockLauncher then
            return
        end
        selfButton:StartMoving()
    end)

    button:SetScript("OnDragStop", function(selfButton)
        selfButton:StopMovingOrSizing()
        local point, _, _, x, y = selfButton:GetPoint(1)
        ns.db.launcher.point = point
        ns.db.launcher.x = round(x)
        ns.db.launcher.y = round(y)
    end)

    button:SetScript("OnEnter", function(selfButton)
        GameTooltip:SetOwner(selfButton, "ANCHOR_RIGHT")
        GameTooltip:SetText("Portal Roulette", 0.8, 0.95, 1)
        GameTooltip:AddLine("Left-click: Teleports", 0.85, 0.85, 0.85)
        GameTooltip:AddLine("Right-click: Portals", 0.85, 0.85, 0.85)
        if ns.db.lockLauncher then
            GameTooltip:AddLine("Launcher is locked.", 1, 0.4, 0.4)
        else
            GameTooltip:AddLine("Drag to move.", 0.7, 0.95, 0.7)
        end
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    self.button = button
end

function LauncherButton:ApplyPosition()
    if not self.button then
        return
    end
    self.button:ClearAllPoints()
    self.button:SetPoint(ns.db.launcher.point or "CENTER", UIParent, ns.db.launcher.point or "CENTER", ns.db.launcher.x or 0, ns.db.launcher.y or 0)
end

function LauncherButton:ApplySettings()
    if not self.button then
        return
    end
    self:ApplyPosition()
end

function LauncherButton:Initialize()
    if not ns.isMage then
        return
    end
    self:Create()
    self:ApplySettings()
    self.button:Show()
end
