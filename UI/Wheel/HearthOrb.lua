-- ============================================================
-- HearthOrb: the center utility. A stationary secure button (left click
-- uses the current hearth source) with a mouse-disabled glass visual, a
-- circular cooldown sweep and the bind-location pill under it.
-- ============================================================

local _, ns = ...

local Skin = ns.Skin
local Anim = ns.Anim
local Layout = ns.Layout
local SA = ns.SecureAction

local HearthOrb = {}
ns.HearthOrb = HearthOrb

function HearthOrb.Create(root)
    local orb = {}
    local size = Layout.ORB

    local button = SA.Create(root, "PortalRouletteHearthOrb")
    button:SetSize(size, size)
    button:SetPoint("CENTER", root, "CENTER", 0, Layout.DISC_Y)
    button:SetFrameLevel(root:GetFrameLevel() + 20)
    orb.button = button

    -- LibGlass's Disc needs a sized, square host at build time.
    local visual = CreateFrame("Frame", nil, button)
    visual:SetSize(size, size)
    visual:SetPoint("CENTER")
    visual:EnableMouse(false)
    orb.visual = visual
    local halo = visual:CreateTexture(nil, "BACKGROUND", nil, -8)
    halo:SetPoint("TOPLEFT", -size * 0.3, size * 0.3)
    halo:SetPoint("BOTTOMRIGHT", size * 0.3, -size * 0.3)
    halo:SetTexture(ns.Media.GLOW)
    halo:SetBlendMode("ADD")
    halo:SetVertexColor(0.42, 0.62, 1)
    halo:SetAlpha(0.5)
    orb.halo = halo -- steady: the orb is the permanent focal point

    -- The TBC orb art: a gold ring around the blue hearthstone, with
    -- normal / hover / pressed states.
    local art = visual:CreateTexture(nil, "ARTWORK", nil, 0)
    art:SetAllPoints()
    art:SetTexture(ns.Media.HEARTH_ORB_NORMAL)
    orb.art = art

    -- Another hearth source (Crumbling Hearthstone, a toy) shows its own
    -- icon inside the ring, over the stone.
    local inset = size * 0.2
    local iconHost = CreateFrame("Frame", nil, visual)
    iconHost:SetPoint("TOPLEFT", inset, -inset)
    iconHost:SetPoint("BOTTOMRIGHT", -inset, inset)
    local icon = Skin:RoundTexture(iconHost, "ARTWORK", 2)
    -- Item icons carry a dark square border: crop it so the circle mask
    -- shows only the art.
    icon:SetTexCoord(0.12, 0.88, 0.12, 0.88)
    icon:Hide()
    orb.icon = icon

    local cooldown = CreateFrame("Cooldown", nil, visual, "CooldownFrameTemplate")
    cooldown:SetPoint("TOPLEFT", inset, -inset)
    cooldown:SetPoint("BOTTOMRIGHT", -inset, inset)
    cooldown:SetSwipeTexture(ns.Media.CIRCLE_MASK)
    cooldown:SetSwipeColor(0.42, 0.58, 1.0, 0.35)
    if cooldown.SetUseCircularEdge then
        cooldown:SetUseCircularEdge(true)
    end
    orb.cooldown = cooldown

    local bind = CreateFrame("Frame", nil, visual)
    bind:SetSize(120, 20)
    bind:SetPoint("TOP", visual, "BOTTOM", 0, -6)
    orb.bindGlass = Skin:Pill(bind)
    orb.bindText = Skin:Font(orb.bindGlass.top or bind, 12, "CENTER")
    orb.bindText:SetPoint("CENTER")
    orb.bind = bind

    orb.hoverGrow, orb.hoverShrink = Anim.HoverPair(visual, 1.06, 0.12)
    orb.appear = Anim.Appear(visual, 0.24, 0.5, 0.04)
    orb.disappear = Anim.Disappear(visual, 0.15, 0.8)
    button:SetScript("OnMouseDown", function() art:SetTexture(ns.Media.HEARTH_ORB_PRESSED) end)
    button:SetScript("OnMouseUp", function()
        art:SetTexture(button:IsMouseOver() and ns.Media.HEARTH_ORB_HOVER or ns.Media.HEARTH_ORB_NORMAL)
    end)
    button:SetScript("OnEnter", function()
        art:SetTexture(ns.Media.HEARTH_ORB_HOVER)
        if Anim.Enabled("hover") then orb.hoverShrink:Stop() orb.hoverGrow:Play() end
        if ns.Sound then ns.Sound:Play("HearthstoneHover") end
        if ns.Roulette then ns.Roulette:OnOrbEnter(orb) end
    end)
    button:SetScript("OnLeave", function()
        art:SetTexture(ns.Media.HEARTH_ORB_NORMAL)
        if Anim.Enabled("hover") then orb.hoverGrow:Stop() orb.hoverShrink:Play() end
        if ns.Roulette then ns.Roulette:OnOrbLeave(orb) end
    end)
    button:SetScript("PostClick", function(_, mouseButton, down)
        if down then return end
        if ns.Roulette then ns.Roulette:OnOrbClick(orb, mouseButton) end
    end)
    return orb
end

function HearthOrb.Update(orb, source)
    orb.source = source
    local isHearthstone = source and source.id == ns.Constants.ITEM_HEARTHSTONE
    orb.icon:SetShown(source ~= nil and not isHearthstone)
    if source and not isHearthstone then
        orb.icon:SetTexture(source.icon or ns.Media.ICON_HEARTHSTONE_CUSTOM)
    end
    orb.art:SetDesaturated(source == nil)
    local where = ns.Hearth:BindLocation()
    orb.bindText:SetText(where or "")
    orb.bind:SetShown(where ~= nil and where ~= "")
    if source then
        SA.ApplyItemCooldown(orb.cooldown, source.id)
    else
        orb.cooldown:Clear()
    end
end

function HearthOrb.Actions(source, preview)
    if preview or not source then
        return {}
    end
    return { [1] = source.action }
end
