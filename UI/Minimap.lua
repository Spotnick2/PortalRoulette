-- ============================================================
-- Minimap: a LibDataBroker launcher shown by LibDBIcon (vendored in Libs\)
-- plus an Addon Compartment entry. db.minimap = { minimapPos, hide }.
-- ============================================================

local _, ns = ...

local Minimap = {}
ns.Minimap = Minimap

local NAME = "PortalRoulette"

local function onClick(_, mouseButton)
    if mouseButton == "RightButton" then
        if ns.Options then ns.Options:Open() end
    elseif ns.Roulette then
        ns.Roulette:Toggle()
    end
end

local function onTooltip(tooltip)
    tooltip:AddLine("Portal Roulette", 0.8, 0.9, 1)
    tooltip:AddLine("Left-click: open the wheel", 1, 1, 1)
    tooltip:AddLine("Right-click: options", 1, 1, 1)
end

function Minimap:Initialize()
    local stub = _G.LibStub
    local LDB = stub and stub("LibDataBroker-1.1", true)
    local icon = stub and stub("LibDBIcon-1.0", true)
    if LDB and icon and not self.object then
        self.object = LDB:NewDataObject(NAME, {
            type = "launcher",
            text = "Portal Roulette",
            icon = ns.Media.LAUNCHER_PORTAL,
            OnClick = onClick,
            OnTooltipShow = onTooltip,
        })
        icon:Register(NAME, self.object, ns.db.minimap)
        self.icon = icon
    end

    if AddonCompartmentFrame and AddonCompartmentFrame.RegisterAddon and not self.compartment
        and ns.db.showCompartment ~= false then
        local ok = pcall(AddonCompartmentFrame.RegisterAddon, AddonCompartmentFrame, {
            text = "Portal Roulette",
            icon = ns.Media.LAUNCHER_PORTAL,
            notCheckable = true,
            func = function(_, _, _, _, mouseButton) onClick(nil, mouseButton) end,
            funcOnEnter = function(button)
                GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
                onTooltip(GameTooltip)
                GameTooltip:Show()
            end,
            funcOnLeave = function() GameTooltip:Hide() end,
        })
        self.compartment = ok
    end
    self:RefreshVisibility()
end

function Minimap:RefreshVisibility()
    if not self.icon then
        return
    end
    ns.db.minimap.hide = not ns.db.showMinimapButton
    if ns.db.minimap.hide then
        self.icon:Hide(NAME)
    else
        self.icon:Show(NAME)
    end
end
