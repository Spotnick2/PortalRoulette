-- The wheel with the real LibShowcase (from $LIBSHOWCASE or ../LibShowcase;
-- .pkgmeta pins r3 and tests/run.ps1 checks the checkout matches that tag):
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
H.check(ns.Presentation:Lib() ~= nil, "LibShowcase r3+ is picked up")

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

-- Measured on 70205: a ready check hides "special windows" from client code
-- before the library reveals the UI. With the UI hidden the Escape proxy is
-- not armed, so that hide cannot close the wheel; once the UI is back the
-- proxy is armed again so Escape still closes it.
H.slash("PORTALROULETTE", "")
H.eq(WoW.uiVisible, false, "UI hidden while the wheel is open")
H.check(not R.escape:IsShown(), "the Escape proxy is not armed while the UI is hidden")
for _, name in ipairs(UISpecialFrames) do _G[name]:Hide() end -- the client's hide
WoW.fire("READY_CHECK", "Friend", 35)
H.check(R.open, "a ready check does not close the wheel")
H.eq(WoW.uiVisible, true, "the ready check brings the game UI back")
WoW.runTimers(0)
H.check(R.escape:IsShown(), "the Escape proxy is armed again once the UI is visible")
WoW.time = WoW.time + 1
R.escape:Hide() -- Escape
WoW.runTimers(0) -- the close is decided a frame later
H.check(not R.open, "Escape still closes the wheel afterwards")
R:FinishClose()
WoW.fire("READY_CHECK_FINISHED")
for _ = 1, 30 do WoW.tick(0.05) end
WoW.runTimers(1)

-- Escape while the UI is hidden is a forced exit from the library: our state
-- must follow it, or the next open believes the UI is still hidden.
local function shutAll()
    if R.open then R:Close() R:FinishClose() end
    for _ = 1, 30 do WoW.tick(0.05) end
    WoW.runTimers(1)
end
H.slash("PORTALROULETTE", "")
H.eq(WoW.uiVisible, false, "hidden before the forced exit")
WoW.inGroup = true
R:Arm()
SetUIVisibility(true) -- the engine's Escape path while the UI is hidden
H.check(not R.open, "a forced exit closes the wheel")
H.eq(ns.Presentation:IsGameUIHidden(), false, "the wrapper forgets the hidden UI")
H.eq(R.armed, nil, "a forced exit disarms the grouped-teleport confirmation")
WoW.inGroup = false
shutAll()
ns.db.hideGameUI = false
H.slash("PORTALROULETTE", "")
H.check(R.escape:IsShown(), "after a forced exit, the next open (UI shown) arms the Escape proxy")

-- A ready check while the UI is already visible: the client still hides
-- special windows in that frame, and the wheel must stay open.
WoW.time = WoW.time + 1
for _, name in ipairs(UISpecialFrames) do _G[name]:Hide() end
WoW.fire("READY_CHECK", "Friend", 35)
WoW.runTimers(0)
H.check(R.open, "a ready check with the UI visible does not close the wheel")
H.check(R.escape:IsShown(), "the Escape proxy is re-armed")
WoW.fire("READY_CHECK_FINISHED")
shutAll()
ns.db.hideGameUI = true

-- HideGameUI refuses with a dialog up ("dialog"), and the UI is hidden again
-- once the dialog clears (polled about once a second while open).
local popup = CreateFrame("Frame", "StaticPopup3", UIParent)
WoW.shownDialogs = { popup }
H.slash("PORTALROULETTE", "")
H.eq(WoW.uiVisible, true, "UI kept up while a dialog is shown")
H.check(ns.Presentation.pendingHide, "the hide is pending")
WoW.shownDialogs = {}
for _ = 1, 30 do WoW.tick(0.05) end
H.eq(WoW.uiVisible, false, "the UI is hidden once the dialog is gone")
H.check(R.open, "and the wheel is still open")
shutAll()

-- Normal close.
H.slash("PORTALROULETTE", "")
H.eq(WoW.uiVisible, false, "hidden again")
R:Close()
R:FinishClose()
WoW.runTimers(1)
H.eq(WoW.uiVisible, true, "close restores the game UI")
H.eq(R.root:GetParent(), UIParent, "and drops the root")
H.done("test_showcase")
