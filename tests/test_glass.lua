-- The wheel built with the real LibGlass (r11, as pinned) (from $LIBGLASS or ../LibGlass)
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
local g = ns.Roulette.disc.glass
H.eq(g.rim:GetTexture(), ns.Media.DISC_RIM, "only the wheel uses its thin rim asset")
H.eq(g.grain:GetAlpha(), 0.06, "wheel grain is restrained")

-- #6: the wash is a gradient, which ignores SetAlpha on Forever; its
-- strength goes through the gradient's top colour.
local function washTop(surface) return surface.wash._gradient.max.a end
local builtWash = glass.STYLE.wash
local function near(a, b) return math.abs(a - b) < 1e-6 end
H.check(near(washTop(g), builtWash * 0.22), "disc wash at 0.22 of the built strength")
H.check(near(washTop(ns.Roulette.header.glass), builtWash * 0.2), "header wash at 0.2")
ns.LauncherButton:CreatePrompt()
H.check(near(washTop(ns.LauncherButton.prompt.glass), builtWash * 0.3), "prompt wash at 0.3")
g.wash:SetAlpha(0)
H.eq(g.wash:GetAlpha(), 1, "the stub, like the client, ignores SetAlpha on a gradient")
local other = CreateFrame("Frame", nil, UIParent)
other:SetSize(440, 440)
local untouched = glass.Disc(other, "disc")
H.check(untouched.rim:GetTexture() ~= g.rim:GetTexture(), "surface override leaves instance defaults intact")
H.check(untouched.grain:GetAlpha() > g.grain:GetAlpha(), "other surfaces retain their grain")
H.check(ns.LauncherButton.button.glass.mask ~= nil, "launcher has a real glass mask")
H.eq(ns.LauncherButton.button.glass.size, "small", "launcher uses rounded-rectangle glass")
H.check(ns.Roulette.header.glass.grain:GetAlpha() < untouched.grain:GetAlpha(), "header uses a clearer glass surface")
local header = ns.Roulette.header
H.check(header.sheen ~= nil, "header uses the real LibGlass sheen")
WoW.tick(1)
H.check(header.sheen:IsPlaying(), "opening sweeps the title")
ns.db.animationIntensity = 0.4
WoW.tick(0)
H.eq(header.sheenHost:GetAlpha(), 0.2, "title scan respects intensity")
ns.db.idleAnimationsEnabled = false
WoW.tick(0)
H.check(not header.sheen:IsPlaying(), "idle off stops title scan")
ns.db.idleAnimationsEnabled = true
WoW.tick(1)
ns.Roulette:FinishClose()
H.check(not header.sheen:IsPlaying(), "close stops title scan")
H.done("test_glass")
