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

-- Unlearned destinations keep a dim link with no comets.
local darn
for _, node in ipairs(R.slots) do
    if R.assigned[node] and R.assigned[node].id == "darnassus" then darn = node end
end
H.check(disc.links[darn.index].active and disc.links[darn.index].level < 1, "an unlearned destination gets a dimmer flow")

-- Closing stops the updater.
R:Close()
R:FinishClose()
H.check(not ns.Disc.ticker:GetScript("OnUpdate"), "closing stops the updater")
H.done("test_effects")
