-- The wheel with the real LibShowcase r1 (from $LIBSHOWCASE or ../LibShowcase):
-- open hides the game UI and lifts the root; combat entry restores at once.

dofile("tests/wow_stubs.lua")
local H = dofile("tests/harness.lua")

local root = os.getenv("LIBSHOWCASE") or "../LibShowcase"
local libFile = root .. "/LibShowcase.lua"
if not io.open(libFile) then
    io.write("test_showcase: skipped (no LibShowcase checkout at " .. root .. ")\n")
    os.exit(0)
end

WoW.spells[3561] = { name = "Teleport: Stormwind", known = true }
local ns = H.loadAddon({ libs = { libFile } })
local R = ns.Roulette
H.check(ns.Presentation:Lib() ~= nil, "LibShowcase r1+ is picked up")

H.slash("PORTALROULETTE", "")
H.check(R.open, "the wheel opens")
H.eq(WoW.uiVisible, false, "the game UI is hidden")
H.eq(R.root:GetParent(), nil, "the root is lifted out of UIParent")

WoW.blocked = {}
WoW.enterCombat()
H.check(not R.open, "combat closes the wheel")
H.eq(WoW.uiVisible, true, "the game UI is back at combat entry")
H.eq(#WoW.blocked, 0, "nothing protected was blocked: " .. table.concat(WoW.blocked, ", "))
WoW.leaveCombat()
WoW.runTimers(1)
H.eq(R.root:GetParent(), UIParent, "the root is back under UIParent")

-- A dialog shown while the UI is hidden (a guild invite) brings the game UI
-- back, so Escape never declines it unseen; Blizzard's dialog frame itself
-- is never reparented (that would risk tainting its Accept button).
H.slash("PORTALROULETTE", "")
local invite = CreateFrame("Frame", "StaticPopup1", UIParent)
WoW.shownDialogs = { invite }
StaticPopup_Show("GUILD_INVITE", "Someone", "Guild")
H.eq(WoW.uiVisible, true, "an invite brings the game UI back")
H.eq(invite:GetParent(), UIParent, "the dialog frame is left alone")
H.check(R.open, "the wheel stays open")
WoW.shownDialogs = {}
R:Close()
R:FinishClose()
for _ = 1, 30 do WoW.tick(0.05) end
WoW.runTimers(1)

-- Typing in chat brings the game UI back; the wheel stays open.
H.slash("PORTALROULETTE", "")
H.eq(WoW.uiVisible, false, "UI hidden while the wheel is open")
ChatFrameUtil.ActivateChat({})
H.eq(WoW.uiVisible, true, "opening the chat box shows the game UI")
H.check(R.open, "the wheel stays open")
R:Close()
R:FinishClose()
for _ = 1, 30 do WoW.tick(0.05) end
WoW.runTimers(1)

-- r3: with a Blizzard dialog already up, HideGameUI refuses ("dialog"):
-- the wheel opens over the visible UI and the root stays under UIParent.
local pending = CreateFrame("Frame", "StaticPopup2", UIParent)
WoW.shownDialogs = { pending }
H.slash("PORTALROULETTE", "")
H.check(R.open, "the wheel opens with a dialog up")
H.eq(WoW.uiVisible, true, "the game UI stays visible while a dialog is up")
H.eq(R.root:GetParent(), UIParent, "the root is not lifted")
H.eq(ns.Presentation:IsGameUIHidden(), false, "the wrapper knows the UI is not hidden")
WoW.shownDialogs = {}
R:Close()
R:FinishClose()
for _ = 1, 30 do WoW.tick(0.05) end
WoW.runTimers(1)

-- Normal close.
H.slash("PORTALROULETTE", "")
H.eq(WoW.uiVisible, false, "hidden again")
R:Close()
R:FinishClose()
WoW.runTimers(1)
H.eq(WoW.uiVisible, true, "close restores the game UI")
H.eq(R.root:GetParent(), UIParent, "and drops the root")
H.done("test_showcase")
