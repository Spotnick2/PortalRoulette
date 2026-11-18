-- The dev-only probe, a ForeverProbe module (/fp pr): every command runs
-- against the stubbed client without touching an unstubbed global, secrets
-- are never formatted, and its lines go to the /fp console and its saved log,
-- never to chat. The host is loaded first, from its checkout (harness.lua's
-- loadForeverProbe: $FOREVERPROBE, else ..\ForeverProbe).

dofile("tests/wow_stubs.lua")
local H = dofile("tests/harness.lua")

WoW.spells[3561] = { name = "Teleport: Stormwind", known = false }
WoW.spells[10059] = { name = "Portal: Stormwind", known = false }
WoW.spells[168] = { name = "Frost Armor", known = true, usable = true }
WoW.spells[8690] = { name = "Hearthstone", known = true }
WoW.items[17031] = "Rune of Teleportation"
WoW.items[6948] = "Hearthstone"
WoW.counts[17031] = 7
WoW.toys[54452] = true

WoW.hearthstone = nil  -- measured on 70205: nil even with a Hearthstone carried
WoW.counts[6948] = 1
local FP = H.loadForeverProbe()
local S = FP.Steps
local ns = H.loadProbe()
local db = PortalRouletteProbeDB
check(type(db) == "table", "the probe creates its SavedVariable")
eq(db.loginCount, 1, "each login is counted")
check(db.logins and db.logins[1] and db.logins[1].test_cameraOverShoulder, "login records the camera CVars")

-- A ForeverProbe module: /fp pr, its log bound at ADDON_LOADED by reference.
local mod = FP.modules.PortalRouletteProbe
check(mod and FP.byCmd.pr == mod, "the probe registers as /fp pr")
check(type(db.log) == "table" and mod.log == db.log, "its saved log is bound to the host by reference")
eq(ns._test and ns._test.Probe, mod, "the test seam is the module")
local function logHas(text)
    for _, line in ipairs(db.log) do if line:find(text, 1, true) then return true end end
    return false
end
local function consoleHas(text)
    for _, l in ipairs(FP.lines) do if l.m == mod.name and l.text:find(text, 1, true) then return true end end
    return false
end

-- Core run.
H.fp("pr core")
local core = table.concat(db.core or {}, "\n")
check(core:find("teleport.Stormwind.GetSpellInfo = RETURNED"), "teleport spell info is recorded")
check(core:find("item.Rune of Teleportation.GetItemCount = RETURNED 7"), "reagent count is recorded")
check(core:find("PlayerHasHearthstone = RETURNED nil"), "the hearthstone result is recorded")
check(core:find("toys.owned = 1"), "owned toys are counted")
check(logHas("item.Rune of Teleportation.GetItemCount = RETURNED 7"), "the same line reaches the module's log")
check(consoleHas("toys.owned = 1"), "and the /fp console")

-- Secrets are saved as <secret>, never compared.
WoW.combatSecret = true
H.fp("pr item 17031")
local item = table.concat(db.item17031 or {}, "\n")
check(item:find("GetItemCount = RETURNED <secret>"), "a secret count is saved as <secret>")
WoW.combatSecret = false

-- Tooltips run asynchronously and finish.
WoW.advance(0)
H.fp("pr tips")
for _ = 1, 15 do WoW.advance(0.5) end
check(db.tips ~= nil, "the tooltip run finishes and saves")

-- Secure panel: numbered attributes, both click edges, never typerelease.
H.fp("pr secure")
local buttons = H.framesWithTemplate("SecureActionButtonTemplate")
check(#buttons >= 6, "the secure panel has its test buttons")
-- Above other addons' windows, and dragged by its title strip, never over a
-- button (measured in game: at the default strata it was hidden, unmovable).
local panel = buttons[1]:GetParent()
eq(panel:GetFrameStrata(), "DIALOG", "the secure panel sits above other addons' windows")
check(panel:IsMovable(), "the secure panel can be moved")
local handle = panel.dragHandle
check(handle and handle:IsMouseEnabled() and handle:GetScript("OnDragStart"), "its title strip drags it")
check(not panel:IsMouseEnabled(), "the panel itself takes no mouse behind its buttons")
for _, b in ipairs(buttons) do check(b:GetParent() ~= handle, "no secure button sits on the drag strip") end
-- A drag combat interrupts: the client refuses to stop a drag on this
-- protected panel under lockdown, so the drag ends at combat entry (still
-- unlocked), and the release in combat calls nothing protected. The panel is
-- hidden here so that the combat tests (they run while it is shown) stay out.
panel:Hide()
local function drag(script) handle:GetScript(script)(handle, "LeftButton") end
WoW.blocked = {}
drag("OnDragStart")
check(panel._moving, "drag: it starts out of combat")
WoW.enterCombat()
check(not panel._moving, "drag: combat entry ends it, before lockdown")
drag("OnDragStop")
drag("OnDragStart")
check(not panel._moving, "drag: none starts in combat")
drag("OnDragStop")
WoW.leaveCombat()
eq(#WoW.blocked, 0, "drag: nothing blocked: " .. table.concat(WoW.blocked, ", "))
drag("OnDragStart")
drag("OnDragStop")
check(not panel._moving, "drag: out of combat, the release ends it")
panel:Show()
for _, b in ipairs(buttons) do
    check(b._clicks and b._clicks[1] == "AnyUp" and b._clicks[2] == "AnyDown", "both click edges are registered")
    for k in pairs(b._attrs or {}) do
        check(not k:find("^typerelease"), "typerelease is never set")
        check(k ~= "type", "unnumbered type is never set")
    end
end
eq(buttons[1]:GetAttribute("spell1"), 168, "the numeric spell ID test")
eq(buttons[2]:GetAttribute("spell1"), "Frost Armor", "the spell name test")

-- Combat tests run on combat entry and save.
WoW.enterCombat()
check(db.combat == nil, "combat tests wait for lockdown")
WoW.advance(0.1)
check(db.combat ~= nil, "combat tests run once lockdown is on")
check(table.concat(db.combat, "\n"):find("InCombatLockdown = true"), "they run under lockdown")
WoW.leaveCombat()
eq(buttons[1]:GetAlpha(), 1, "the test button is restored after combat")

-- Hearth falls back to item 6948 when PlayerHasHearthstone is nil (70205).
local labels = {}
for _, b in ipairs(buttons) do labels[#labels + 1] = b:GetAttribute("item1") or b:GetAttribute("macrotext1") or "" end
check(table.concat(labels, ","):find("item:6948"), "the hearth button uses the fallback item")

-- Talent tree via C_Traits flags the reagent-free talent.
WoW.traits[5] = { spellID = 77001, rank = 1 }
WoW.spells[77001] = { name = "Arcane Mastery" }
WoW.spellDescriptions[77001] = "Your Teleport and Portal spells no longer require reagents."
H.fp("pr traits")
local traits = table.concat(db.traits or {}, "\n")
check(traits:find("FLAG node5.entry50 = \"Arcane Mastery\""), "the reagent talent is flagged")

-- Graphics panel builds.
H.fp("pr gfx")
check(db.gfx ~= nil, "the graphics run saves")

-- Scan finds names by prefix and can be cancelled.
WoW.spells[99001] = { name = "Teleport: Dalaran" }
H.fp("pr scan 100000")
for _ = 1, 400 do WoW.advance(0) if db.scan then break end end
check(db.scan and table.concat(db.scan.hits, "\n"):find("99001 Teleport: Dalaran"), "the scan finds Teleport: Dalaran")

-- CVar marker round trip.
WoW.cvars.test_cameraOverShoulder = "0"
H.fp("pr cvarmark")
eq(WoW.cvars.test_cameraOverShoulder, "0.37", "cvarmark writes the marker")
H.fp("pr cvarrestore")
eq(WoW.cvars.test_cameraOverShoulder, "0", "cvarrestore puts the original back")

-- Blocked actions: the host's baseline is the only watcher (the probe
-- registers none), and the popup test still records the ones its calls
-- caused (ForeverProbe#19 workaround).
local watchers = {}
for _, f in ipairs(WoW.frames) do
    if f._events.ADDON_ACTION_BLOCKED or f._events.ADDON_ACTION_FORBIDDEN then watchers[#watchers + 1] = f end
end
check(#watchers == 1 and watchers[1] == FP.Baseline.taintFrame, "the only blocked-action watcher is the host's")
H.fp("pr popup")
WoW.fire("ADDON_ACTION_BLOCKED", "PortalRouletteProbe", "SetCVar")
WoW.advance(1)
local popup = table.concat(db.popup or {}, "\n")
check(popup:find("  blocked = ADDON_ACTION_BLOCKED(PortalRouletteProbe, SetCVar)", 1, true),
    "a blocked action during the popup test is recorded in its run")
check(popup:find("GameEvent.UnregisterInternalEvent = RETURNED", 1, true), "the popup test runs")

-- Procedures: the secure one walked as the owner would. Show the panel, the
-- clicks complete their step by themselves, the fight runs the combat tests.
db.combat = nil
H.fp("steps pr secure")
local rec = ForeverProbeDB.steps.records["PortalRouletteProbe/secure"]
check(rec and rec.status == "active", "/fp steps pr secure starts the procedure")
S.Run()
eq(rec.at, 2, "1: Show panel")
for _, b in ipairs(buttons) do WoW.click(b, "LeftButton", true) WoW.click(b, "LeftButton", false) end
WoW.advance(1)
S.Poll()
eq(rec.at, 2, "2: waits while the right-click is missing")
local R
for _, b in ipairs(buttons) do if b:GetAttribute("type2") then R = b end end
WoW.click(R, "RightButton", true) WoW.click(R, "RightButton", false)
WoW.advance(1)
S.Poll()
eq(rec.at, 3, "2: every click recorded")
check(db.secure and #db.secure >= #buttons + 1, "each click's result is saved")
WoW.enterCombat()
WoW.advance(0.1)
S.Poll()
eq(rec.at, 4, "3: the combat tests ran")
eq(rec.results[3].check, "PASS", "3: under lockdown")
WoW.leaveCombat()
S.Poll()
eq(rec.status, "done", "4: out of combat, the panel back: done")
check(logHas("STEP secure FINISHED"), "the procedure's lines reach the module's log")

-- The others are defined, one per in-game row of docs/FOREVER-PROBE.md.
for _, name in ipairs({ "secure", "keyup", "gfx", "popup", "persist", "reagentbag", "talent" }) do
    check(FP.procedures["PortalRouletteProbe/" .. name], "procedure " .. name .. " is defined")
end

-- persist: marked, the exit and relaunch (a new run number), read back.
WoW.cvars.test_cameraOverShoulder = "0"
WoW.cvars.CameraKeepCharacterCentered = "1"
H.fp("steps pr persist")
rec = ForeverProbeDB.steps.records["PortalRouletteProbe/persist"]
S.Run()
eq(rec.results[1].check, "PASS", "persist 1: the markers are written")
FP.run = FP.run + 1
S.Resume()
eq(rec.results[2].status, "done", "persist 2: back after the exit")
eq(rec.results[3].check, "PASS", "persist 3: read back on arrival (the stub keeps them)")
check(db.persist and table.concat(db.persist, "\n"):find("persisted = true", 1, true), "persist 3: saved as its run")
S.Run()
eq(rec.results[4].check, "PASS", "persist 4: the originals are back")
eq(WoW.cvars.test_cameraOverShoulder, "0", "persist 4: test_cameraOverShoulder restored")
eq(WoW.cvars.CameraKeepCharacterCentered, "1", "persist 4: CameraKeepCharacterCentered restored")

-- reagentbag: one rune in the reagent bag (5), six in the backpack.
WoW.bags[0] = { [1] = { itemID = 17031, stackCount = 6 } }
WoW.bags[5] = { [1] = { itemID = 17031, stackCount = 1 } }
WoW.counts[17031] = 7
H.fp("steps pr reagentbag")
rec = ForeverProbeDB.steps.records["PortalRouletteProbe/reagentbag"]
S.Next()
S.Run()
eq(rec.results[2].check, "PASS", "reagentbag: the count includes the reagent bag")
check(table.concat(db.reagentbag or {}, "\n"):find("bag5.slot1 = Rune of Teleportation 17031", 1, true),
    "reagentbag: the rune is found in bag 5")

-- talent: the Reagent Economy IDs are read.
WoW.spells[1262636] = { name = "Reagent Economy", known = true }
H.fp("steps pr talent")
rec = ForeverProbeDB.steps.records["PortalRouletteProbe/talent"]
S.Next()
S.Answer(true)
S.Run()
eq(rec.status, "done", "talent: done")
check(table.concat(db.reagenteconomy or {}, "\n"):find("reagentEconomy.known = 1262636", 1, true),
    "talent: the known Reagent Economy ID is recorded")

-- Clearing: the saved results go, the log is emptied IN PLACE (the host
-- still holds it), and a new line lands in both the log and the console.
local boundLog = db.log
H.fp("pr clear")
check(PortalRouletteProbeDB == db and db.log == boundLog and mod.log == boundLog, "clear keeps the saved tables")
check(db.core == nil and db.secure == nil, "clear wipes the saved results")
check(not consoleHas("toys.owned"), "clear empties the module's console lines")
H.fp("pr spell 168")
check(logHas("spell.168.DoesSpellExist = RETURNED true"), "after clear, a line lands in the saved log")
check(consoleHas("spell.168.DoesSpellExist = RETURNED true"), "and in ForeverProbe.lines")

-- The dependency is the probe's alone: the host is never packaged (guide,
-- section 1), so neither the addon's TOC nor .pkgmeta names it.
local function read(path) local f = assert(io.open(path, "rb")) local s = f:read("*a") f:close() return s end
check(read("Tools/PortalRouletteProbe/PortalRouletteProbe.toc"):find("## Dependencies: ForeverProbe", 1, true),
    "the probe's TOC depends on ForeverProbe")
check(not read("PortalRoulette.toc"):find("ForeverProbe", 1, true), "the addon's TOC never names ForeverProbe")
check(not read(".pkgmeta"):find("ForeverProbe", 1, true), ".pkgmeta never names ForeverProbe")

-- Nothing diagnostic reaches chat: the probe has no chat stimuli.
eq(#WoW.chat, 0, "the probe printed nothing to chat")

done("test_probe")
