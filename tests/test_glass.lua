-- The wheel built with the real LibGlass r2 (from $LIBGLASS or ../LibGlass)
-- instead of the plain fallback.

dofile("tests/wow_stubs.lua")
local H = dofile("tests/harness.lua")

local root = os.getenv("LIBGLASS") or "../LibGlass"
local libFile = root .. "/LibGlass.lua"
if not io.open(libFile) then
    io.write("test_glass: skipped (no LibGlass checkout at " .. root .. ")\n")
    os.exit(0)
end

WoW.spells[3561] = { name = "Teleport: Stormwind", known = true }
local ns = H.loadAddon({ libs = { libFile } })
local glass = ns.Skin:Glass()
H.check(glass ~= nil, "LibGlass r2+ is picked up")
H.check(glass and glass.Disc ~= nil, "it has Disc")
H.slash("PORTALROULETTE", "")
H.check(ns.Roulette.open, "the wheel opens with the glass material")
H.check(ns.Roulette.disc.glass.top ~= nil, "the disc is glass")
H.done("test_glass")
