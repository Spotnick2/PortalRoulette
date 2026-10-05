-- ============================================================
-- Node: one destination bead.
--
-- node.button  SecureActionButtonTemplate, stationary, the ONLY mouse-
--              enabled frame in the bead's footprint. Left = teleport,
--              right = portal (numbered attribute families, via SecureAction).
-- node.visual  non-secure child, mouse disabled: glass bead, icon, plate,
--              pip and cooldown. All animation happens here.
-- ============================================================

local _, ns = ...

local Skin = ns.Skin
local Anim = ns.Anim
local Layout = ns.Layout
local SA = ns.SecureAction

local Node = {}
ns.Node = Node

-- Every label sits under its bead, as in the mockup.
local function plateAnchor(plate, visual)
    plate:ClearAllPoints()
    plate:SetPoint("TOP", visual, "BOTTOM", 0, 6)
end

function Node.Create(root, index, size)
    local node = { index = index, size = size }

    local button = SA.Create(root, "PortalRouletteNode" .. index)
    button:SetSize(size, size)
    button:SetFrameLevel(root:GetFrameLevel() + 20)
    node.button = button

    local visual = CreateFrame("Frame", nil, button)
    visual:SetSize(size, size)
    visual:SetPoint("CENTER")
    visual:EnableMouse(false)
    node.visual = visual

    -- Glass and light: a wide, very faint feathered halo behind the bead,
    -- a thin cool luminous edge over it, a small specular glint at the
    -- upper left. Hover brightens the edge and widens the halo (smoothed
    -- per frame by Roulette:UpdateNodes); the icon itself stays untouched.
    local halo = visual:CreateTexture(nil, "BACKGROUND", nil, -8)
    halo:SetPoint("CENTER")
    halo:SetTexture(ns.Media.GLOW)
    halo:SetBlendMode("ADD")
    node.halo = halo
    node.hover, node.hoverTarget = 0, 0

    node.glass = Skin:Disc(visual, "disc_small")
    local icon = Skin:RoundTexture(visual, "ARTWORK", 1)
    icon:ClearAllPoints()
    icon:SetPoint("TOPLEFT", 4, -4)
    icon:SetPoint("BOTTOMRIGHT", -4, 4)
    node.icon = icon

    local cooldown = CreateFrame("Cooldown", nil, visual, "CooldownFrameTemplate")
    cooldown:SetPoint("TOPLEFT", 4, -4)
    cooldown:SetPoint("BOTTOMRIGHT", -4, 4)
    cooldown:SetSwipeTexture(ns.Media.CIRCLE_MASK)
    cooldown:SetSwipeColor(0, 0, 0, 0.6)
    if cooldown.SetUseCircularEdge then
        cooldown:SetUseCircularEdge(true)
    end
    cooldown:SetHideCountdownNumbers(false)
    node.cooldown = cooldown

    -- Plate: a glass pill under (or above, at 12) the bead.
    local plate = CreateFrame("Frame", nil, visual)
    plate:SetSize(size + 24, Layout.PLATE_H)
    node.plateGlass = Skin:Pill(plate)
    local label = Skin:Font(node.plateGlass.top or plate, 13, "CENTER")
    label:SetPoint("CENTER", 0, 0)
    node.plate, node.label = plate, label
    local sub = Skin:Font(node.plateGlass.top or plate, 10, "CENTER")
    sub:SetPoint("TOP", plate, "BOTTOM", 0, -1)
    sub:SetTextColor(1, 1, 1, 0.6)
    node.sub = sub

    local top = node.glass.top or visual
    local ring = top:CreateTexture(nil, "OVERLAY", nil, 2)
    ring:SetPoint("TOPLEFT", -size * 0.08, size * 0.08)
    ring:SetPoint("BOTTOMRIGHT", size * 0.08, -size * 0.08)
    ring:SetTexture(ns.Media.NODE_RING)
    ring:SetBlendMode("ADD")
    node.ring = ring
    local spec = top:CreateTexture(nil, "OVERLAY", nil, 3)
    spec:SetAllPoints(visual)
    spec:SetTexture(ns.Media.SPECULAR)
    spec:SetBlendMode("ADD")
    spec:SetVertexColor(1, 1, 1, 0.55)
    node.spec = spec
    node.sparkle = Anim.Sparkle(top, 22, -size * 0.31, size * 0.31,
        1.1 + index * 1.35, 7.8 + index * 0.73)

    -- Missing-reagent pip, top right of the bead.
    local pip = (node.glass.top or visual):CreateTexture(nil, "OVERLAY", nil, 7)
    pip:SetSize(16, 16)
    pip:SetPoint("TOPRIGHT", 2, 2)
    pip:SetTexture("Interface\\DialogFrame\\UI-Dialog-Icon-AlertNew")
    pip:Hide()
    node.pip = pip


    button:SetScript("OnEnter", function()
        Node.SetHover(node, true)
        if ns.Roulette then ns.Roulette:OnNodeEnter(node) end
    end)
    button:SetScript("OnLeave", function()
        Node.SetHover(node, false)
        if ns.Roulette then ns.Roulette:OnNodeLeave(node) end
    end)
    -- Insecure PostClick: runs after the secure action (or none). Used for
    -- preview messages, the grouped-teleport confirmation and sounds.
    button:SetScript("PostClick", function(_, mouseButton, down)
        if down then return end
        if ns.Roulette then ns.Roulette:OnNodeClick(node, mouseButton) end
    end)

    return node
end

-- Secure buttons anchor to the (stationary) root, never to an animated frame.
function Node.Place(node, root, clock, radius)
    node.clock = clock
    local x, y = Layout.ClockOffset(clock, radius)
    node.button:ClearAllPoints()
    node.button:SetPoint("CENTER", root, "CENTER", x, y + Layout.DISC_Y)
    plateAnchor(node.plate, node.visual)
    node.appear = Anim.Appear(node.visual, 0.3, 0.4, 0.12 + (node.index - 1) * 0.07)
    node.disappear = Anim.Disappear(node.visual, 0.15, 0.8)
end

function Node.SetHover(node, on)
    node.hovered = on
    node.hoverTarget = on and 1 or 0
    node.hover = Anim.ApproachHover(node.hover, node.hoverTarget, 0)
    Node.PaintGlow(node)
end

-- Paint the edge and halo for the current hover amount (0..1).
-- Fades in about 0.18 s and out about 0.26 s (Roulette:UpdateNodes).
function Node.PaintGlow(node)
    local h = (node.hover or 0) * Anim.HoverStrength()
    local c = node.color or ns.Colors.TELEPORT
    local live = node.usable ~= false
    local edge = live and (0.42 + 0.48 * h) or 0.18
    node.ring:SetVertexColor(c[1] * 0.5 + 0.5, c[2] * 0.5 + 0.5, 1, edge)
    local haloSize = node.size * (1.55 + 0.18 * h)
    node.halo:SetSize(haloSize, haloSize)
    node.halo:SetVertexColor(c[1], c[2], c[3], live and (0.07 + 0.20 * h) or 0)
    -- Icons and labels stay stationary on hover: only the light changes.
end

-- Paint the bead for `resolved` (see Destinations:Resolve).
--   state: { preview, reagentState, missingTeleport, missingPortal }
function Node.Update(node, resolved, state)
    node.resolved = resolved
    node.icon:SetTexture(ns.Destinations:GetIcon(resolved, false))
    node.label:SetText(resolved.name or "")
    node.sub:SetText(resolved.subtitle or "")

    local usable = resolved.teleportKnown or resolved.portalKnown
    if resolved.id == "karazhan" then
        usable = resolved.state == "ready"
    end
    node.icon:SetDesaturated(not usable)
    node.visual:SetAlpha(usable and 1 or 0.55)

    local color = resolved.kind == "bonus" and ns.Colors.BONUS or ns.Colors.TELEPORT
    Skin:SetRimColor(node.glass, color[1], color[2], color[3], 0.45)
    node.color = color
    node.usable = usable or state.preview
    Node.PaintGlow(node)

    local warn = state.reagentState ~= "free" and not state.preview
        and ((resolved.teleportKnown and state.missingTeleport) or (resolved.portalKnown and state.missingPortal))
    node.pip:SetShown(warn and true or false)

    -- Portal cooldown (1 min) on the bead; teleports have none.
    if resolved.portalKnown and resolved.portalID and resolved.id ~= "karazhan" then
        SA.ApplySpellCooldown(node.cooldown, resolved.portalID)
    else
        node.cooldown:Clear()
    end
end

-- The secure actions for the current state; nil entries mean "no action".
--   opts: { preview, confirmTeleport (needs confirmation, not armed) }
function Node.Actions(resolved, opts)
    if not resolved or opts.preview then
        return {}
    end
    local actions = {}
    if resolved.id == "karazhan" then
        if resolved.state == "ready" then
            -- Atiesh in the main hand: use the slot. type=item on the item ID
            -- would EQUIP an unequipped Atiesh instead (SecureTemplates.lua).
            actions[2] = { type = "macro", macrotext = "/use 16" }
        end
        return actions
    end
    if resolved.teleportKnown and resolved.teleportID and not opts.confirmTeleport then
        actions[1] = { type = "spell", spell = resolved.teleportID }
    end
    if resolved.portalKnown and resolved.portalID then
        actions[2] = { type = "spell", spell = resolved.portalID }
    end
    return actions
end
