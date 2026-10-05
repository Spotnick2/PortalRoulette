-- Media paths resolve to real files (a single backslash in a Lua string is
-- silently dropped: "Glass\RuneBand" became "GlassRuneBand" and every
-- generated texture failed to load), and the per-frame effects really run.

dofile("tests/wow_stubs.lua")
local H = dofile("tests/harness.lua")

WoW.spells[3561] = { name = "Teleport: Stormwind", known = true }
WoW.spells[10059] = { name = "Portal: Stormwind", known = true }
WoW.spells[3562] = { name = "Teleport: Ironforge" }
WoW.spells[3565] = { name = "Teleport: Darnassus" }
local ns = H.loadAddon()

-- Every addon media path exists in the repo.
local prefix = "Interface\\AddOns\\PortalRoulette\\"
local checked = 0
for key, path in pairs(ns.Media) do
    if type(path) == "string" and path:sub(1, #prefix) == prefix then
        local rel = path:sub(#prefix + 1):gsub("\\", "/")
        if rel:sub(-1) ~= "/" then
            local f = io.open(rel, "rb")
            H.check(f ~= nil, "media file exists: " .. key .. " -> " .. rel)
            if f then f:close() end
            checked = checked + 1
        end
    end
end
H.check(checked >= 20, "media paths were checked (" .. checked .. ")")

-- Both factions and the shared destinations have art, including Dalaran.
-- Hover keeps the same image: the existing node lighting handles emphasis.
for _, entry in ipairs(ns.Destinations.LIST) do
    local path = ns.Destinations:GetIcon(entry, false)
    H.check(type(path) == "string" and path:find("CityIcons\\Scenes\\", 1, true),
        "city scene is mapped: " .. entry.id)
    local rel = path:sub(#prefix + 1):gsub("\\", "/")
    local file = io.open(rel, "rb")
    H.check(file ~= nil, "city texture exists: " .. entry.id)
    if file then file:close() end
    H.eq(ns.Destinations:GetIcon(entry, true), path, "hover preserves city art: " .. entry.id)
end

-- Open the wheel and run frames: the updater turns the wisps and sends
-- comets along the active links.
H.slash("PORTALROULETTE", "")
local R = ns.Roulette
local disc = R.disc
H.check(ns.Disc.ticker and ns.Disc.ticker:GetScript("OnUpdate"), "the effects updater runs while open")
H.eq(ns.Disc.ticker:GetParent(), WorldFrame, "the updater is parented to WorldFrame")

local rotations = {}
local layer = disc.layers[1].tex
local orig = layer.SetRotation
layer.SetRotation = function(self, r) rotations[#rotations + 1] = r end
local seenComet = false
for _ = 1, 400 do
    WoW.tick(0.05)
    for _, link in pairs(disc.links) do
        if link.comet:IsShown() then seenComet = true end
    end
end
layer.SetRotation = orig
H.check(#rotations > 10 and rotations[#rotations] ~= rotations[1], "the wisp layer turns")
H.check(seenComet, "comets travel along the links")
H.check(disc.time > 15, "time advances")

-- Rune band has a bounded four-second sway, with two seconds per leg.
local runeAngle, runeRotation = 0, disc.runes.SetRotation
disc.runes.SetRotation = function(_, angle) runeAngle = angle end
local savedTime = disc.time
disc.time = 0
ns.Disc.Update(disc, 0)
H.eq(runeAngle, 0, "runes start at rest")
ns.Disc.Update(disc, 2)
H.check(math.abs(runeAngle - math.rad(4)) < 0.00001, "runes reach far end after two seconds")
ns.Disc.Update(disc, 2)
H.check(math.abs(runeAngle) < 0.00001, "runes return after four seconds")
ns.db.idleAnimationsEnabled = false
ns.Disc.Update(disc, 1)
H.check(math.abs(runeAngle) < 0.00001, "idle switch freezes rune sway")
ns.db.idleAnimationsEnabled, ns.db.animationIntensity = true, 0.5
ns.Disc.Update(disc, 2)
H.check(math.abs(runeAngle - math.rad(2)) < 0.00001, "intensity scales rune sway")
disc.runes.SetRotation, disc.time, ns.db.animationIntensity = runeRotation, savedTime, 1

-- Hover brightens one link and its node smoothly; leaving fades back.
local sw
for _, node in ipairs(R.slots) do
    if R.assigned[node] and R.assigned[node].id == "stormwind" then sw = node end
end
sw.button:GetScript("OnEnter")(sw.button)
WoW.tick(0.05)
local mid = sw.hover
H.check(mid > 0 and mid < 1, "hover fades in (not instant)")
for _ = 1, 10 do WoW.tick(0.05) end
H.eq(sw.hover, 1, "hover reaches full")
H.eq(disc.links[sw.index].glow, 1, "its link is lit")
local other
for key, link in pairs(disc.links) do if key ~= sw.index then other = link end end
H.eq(other.glow, 0, "other links stay at idle")
sw.button:GetScript("OnLeave")(sw.button)
for _ = 1, 10 do WoW.tick(0.05) end
H.eq(sw.hover, 0, "hover fades out")

-- Unlearned destinations keep a dimmer flow.
local darn
for _, node in ipairs(R.slots) do
    if R.assigned[node] and R.assigned[node].id == "darnassus" then darn = node end
end
H.check(disc.links[darn.index].active and disc.links[darn.index].level < 1, "an unlearned destination gets a dimmer flow")

-- Hover brings a waiting pulse forward, but never restarts one in flight.
local link = disc.links[sw.index]
link.progress, link.wait = -1, 2.8
sw.button:GetScript("OnEnter")(sw.button)
WoW.tick(0.10)
H.check(link.comet:IsShown(), "hover launches a waiting pulse within 100 ms")
local progress = link.progress
ns.Disc.SetLinkLit(disc, sw.index, false)
ns.Disc.SetLinkLit(disc, sw.index, true)
H.eq(link.progress, progress, "re-enter does not restart a visible pulse")
WoW.tick(0.1)
H.check(math.abs(link.progress - progress - 0.1) < 0.00001, "hover does not change travel speed")

-- Sample the actual texture anchor on short and long spokes at every angle.
-- Its bright head is .32*quad ahead of the center, tail begins .25*quad
-- behind it. Even the full longitudinal quad must stay between both rims.
for _, radius in ipairs({ 150, 295 }) do
    for _, clock in ipairs({ 12, 3, 6, 9, 4 }) do
        local x, y = ns.Layout.ClockOffset(clock, radius)
        ns.Disc.Link(disc, 99, x, y, 66, 72, ns.Colors.TELEPORT, 1)
        local sample = disc.links[99]
        local ux, uy = x / radius, y / radius
        local last, step, firstHead
        local bounded, linear = true, true
        for frame = 0, 99 do
            sample.progress = frame / 100
            ns.Disc.UpdateComet(sample, 0, true)
            local pt = sample.comet._points[1]
            local along = (pt[4] - sample.sx) * ux + (pt[5] - sample.sy) * uy
            local size = sample.comet:GetWidth()
            bounded = bounded and along - size / 2 >= -0.00001
                and along + size / 2 <= sample.length + 0.00001
            local head = along + 0.32 * size
            firstHead = firstHead or head
            if last then
                local delta = head - last
                linear = linear and delta > 0 and (not step or math.abs(delta - step) < 0.00001)
                step = delta
            end
            last = head
        end
        H.check(bounded, "pulse stays between rims: radius " .. radius .. ", clock " .. clock)
        H.check(linear and last - firstHead > sample.length * 0.5, "head visibly travels at constant speed")
    end
end
ns.Disc.HideLink(disc, 99)

-- Disabled Karazhan never gets comets, including when hovered.
ns.Disc.Link(disc, 98, 255, -147, ns.Layout.DISC / 2, 64, ns.Colors.BONUS, 0)
ns.Disc.SetLinkLit(disc, 98, true)
ns.Disc.UpdateComet(disc.links[98], 3, true)
H.check(not disc.links[98].comet:IsShown(), "unavailable satellite stays quiet")
ns.Disc.HideLink(disc, 98)

-- Capture actual alpha calls (the generic stub only records RGB).
local nodeAlpha, linkAlpha, mistAlpha
sw.ring.SetVertexColor = function(_, r, g, b, a) nodeAlpha = a end
link.line.SetVertexColor = function(_, r, g, b, a) linkAlpha = a end
disc.layers[1].tex.SetVertexColor = function(_, r, g, b, a) mistAlpha = a end
-- Repaints happen only on change: invalidate so the captures see one.
sw.paintedStrength, link.paintedIntensity = nil, nil
WoW.tick(0.3)
local fullNode, fullLink, fullMist = nodeAlpha, linkAlpha, mistAlpha
ns.db.animationIntensity = 0.25
WoW.tick(0)
H.check(nodeAlpha < fullNode and linkAlpha < fullLink and mistAlpha < fullMist,
    "intensity lowers both hover lights and the vortex")
H.eq(sw.visual:GetScale(), 1, "hover keeps icons and labels stationary")

ns.db.hoverAnimationsEnabled = false
link.progress, link.wait = -1, 2.8
sw.button:GetScript("OnLeave")(sw.button)
local idleNode, idleLink = nodeAlpha, linkAlpha
sw.button:GetScript("OnEnter")(sw.button)
H.check(nodeAlpha > idleNode and linkAlpha > idleLink, "hover off retains immediate static feedback on node and link")
H.eq(link.wait, 2.8, "hover off does not bring idle pulses forward")
H.eq(sw.hover, link.glow, "node and link use the same static hover state")

ns.db.hoverAnimationsEnabled, ns.db.animationIntensity = true, 1
ns.db.idleAnimationsEnabled = false
local paused = disc.time
WoW.tick(0.5)
H.eq(disc.time, paused, "idle off freezes energy phase")
H.check(not link.comet:IsShown() and not disc.shimmer:IsShown(), "idle off hides pulses and sheen")
sw.button:GetScript("OnLeave")(sw.button)
WoW.tick(0.3)
sw.button:GetScript("OnEnter")(sw.button)
WoW.tick(0.05)
H.check(sw.hover > 0 and sw.hover < 1, "hover still eases with idle off")
H.eq(sw.hover, link.glow, "node and link ease together")
ns.db.idleAnimationsEnabled = true
ns.db.animationIntensity = 0
WoW.tick(0.5)
H.eq(disc.time, paused, "zero intensity stops energy motion")
H.check(not link.comet:IsShown(), "zero intensity stops pulses")
ns.db.animationIntensity = 1
ns.db.animationsEnabled = false
WoW.tick(0.5)
H.eq(disc.time, paused, "master switch stops energy motion")
ns.db.animationsEnabled = true

-- Hearth hover grows the face only; no source-image swap or label movement.
local orb = R.orb
local bindPoint = orb.bind._points[1]
local buttonPoint = orb.button._points[1]
orb.button:GetScript("OnEnter")(orb.button)
WoW.tick(0.05)
H.check(orb.hover > 0 and orb.hover < 1, "hearth hover fades in")
H.eq(orb.art:GetTexture(), ns.Media.HEARTH_ORB_NORMAL, "hearth hover keeps the normal artwork")
H.eq(orb.bind._points[1], bindPoint, "hearth hover preserves label position")
H.eq(orb.button._points[1], buttonPoint, "hearth hover preserves secure hit target")
H.check(orb.face:GetScale() > 1 and orb.face:GetScale() < 1.085, "hearth artwork eases into its larger size")
H.eq(orb.visual:GetScale(), 1, "hearth label's parent remains at normal scale")
WoW.tick(0.2)
H.eq(orb.hover, 1, "hearth hover reaches full light")
H.eq(orb.face:GetScale(), 1.085, "hearth artwork grows by 8.5 percent")
orb.button:GetScript("OnMouseDown")(orb.button)
orb.button:GetScript("OnMouseUp")(orb.button)
H.eq(orb.art:GetTexture(), ns.Media.HEARTH_ORB_NORMAL, "press keeps the same hearth artwork")
orb.button:GetScript("OnLeave")(orb.button)
WoW.tick(0.3)
H.eq(orb.hover, 0, "hearth hover fades out")
H.eq(orb.face:GetScale(), 1, "hearth face returns to resting size")
ns.db.hoverAnimationsEnabled = false
orb.button:GetScript("OnEnter")(orb.button)
H.eq(orb.hover, 1, "hearth keeps immediate feedback with hover motion off")
H.eq(orb.face:GetScale(), 1, "hover motion off disables enlargement")
ns.db.hoverAnimationsEnabled = true

sw.sparkle.wait = 0.1
WoW.tick(0.11)
H.check(sw.sparkle.group:IsPlaying(), "usable bead gets an occasional sparkle")
H.eq(sw.sparkle.wait, sw.sparkle.period, "sparkle waits several seconds before repeating")
sw.usable = false
WoW.tick(0)
H.check(not sw.sparkle.group:IsPlaying(), "unavailable bead has no sparkle")
sw.usable = true

-- Header glints share idle/intensity controls and the single wheel updater.
local headerTime = R.header.time
ns.db.idleAnimationsEnabled = false
WoW.tick(0.5)
H.eq(R.header.time, headerTime, "idle off freezes title glints")
H.eq(R.header.glints[1]:GetAlpha(), 0.35, "idle off leaves restrained static title light")
H.check(not sw.sparkle.group:IsPlaying() and not orb.sparkle.group:IsPlaying(), "idle off stops all orb sparkles")
ns.db.idleAnimationsEnabled = true

-- Closing stops the updater.
R:Close()
R:FinishClose()
H.check(not ns.Disc.ticker:GetScript("OnUpdate"), "closing stops the updater")
H.check(not disc.shimmer:IsShown() and not link.comet:IsShown(), "closing clears transient textures")
H.eq(sw.hover, 0, "closing clears node hover")
H.eq(link.glow, 0, "closing clears link hover")
H.eq(orb.hover, 0, "closing clears hearth hover")
H.eq(orb.hoverLight:GetAlpha(), 0, "closing clears hearth highlight")
H.eq(orb.face:GetScale(), 1, "closing resets face enlargement")
H.check(not sw.sparkle.group:IsPlaying() and not orb.sparkle.group:IsPlaying(), "closing clears sparkles")
local ticker = ns.Disc.ticker
for _ = 1, 3 do
    R:Open()
    H.eq(ns.Disc.ticker, ticker, "reopening reuses one updater")
    R:Close()
    R:FinishClose()
end
H.done("test_effects")
