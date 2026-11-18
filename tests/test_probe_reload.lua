-- The secure and keyup procedures across a /reload. ForeverProbe resumes a
-- procedure at its saved step, but the probe's own state (the panel, the
-- clicks, the combat result) starts again with the new Lua session: each
-- wait must bring the round back rather than wait forever (#25's review).
-- A reload here is what it is in game: a fresh client (the stubs loaded
-- again), the host and the probe loaded over the same saved tables, and the
-- CVars kept.

dofile("tests/wow_stubs.lua")
local H = dofile("tests/harness.lua")

local function clientData()
    WoW.spells[3561] = { name = "Teleport: Stormwind", known = false }
    WoW.spells[10059] = { name = "Portal: Stormwind", known = false }
    WoW.spells[168] = { name = "Frost Armor", known = true, usable = true }
    WoW.spells[8690] = { name = "Hearthstone", known = true }
    WoW.items[17031] = "Rune of Teleportation"
    WoW.items[6948] = "Hearthstone"
    WoW.counts[17031] = 7
    WoW.counts[6948] = 1
    WoW.hearthstone = nil
end
clientData()
local FP = H.loadForeverProbe()
H.loadProbe()

local function reload()
    local fpDB, prDB, cvars = ForeverProbeDB, PortalRouletteProbeDB, WoW.cvars
    dofile("tests/wow_stubs.lua")
    clientData()
    for k, v in pairs(cvars) do WoW.cvars[k] = v end
    rawset(_G, "ForeverProbe", nil)
    rawset(_G, "ForeverProbeDB", fpDB)
    FP = H.loadForeverProbe()
    H.loadProbe(prDB)
    check(FP.db == fpDB, "the reloaded host adopts the saved table")
end
local function rec(name) return ForeverProbeDB.steps.records["PortalRouletteProbe/" .. name] end
local function panelButtons() return H.framesWithTemplate("SecureActionButtonTemplate") end
local function clickAll()
    for _, b in ipairs(panelButtons()) do
        WoW.click(b, "LeftButton", true) WoW.click(b, "LeftButton", false)
        if b:GetAttribute("type2") then WoW.click(b, "RightButton", true) WoW.click(b, "RightButton", false) end
    end
    WoW.advance(1)
    FP.Steps.Poll()
end
local function fight()
    WoW.enterCombat()
    WoW.advance(0.1)
    FP.Steps.Poll()
end

-- secure, reloaded on the clicks step: the panel comes back and the round
-- starts again.
H.fp("steps pr secure")
FP.Steps.Run()
eq(rec("secure").at, 2, "secure: the panel is shown, the clicks wait")
check(#panelButtons() >= 6, "secure: the panel's buttons exist before the reload")
reload()
eq(rec("secure").status, "active", "secure: still running after the reload")
eq(rec("secure").at, 2, "secure: resumed on the clicks step")
FP.Steps.Poll()
check(#panelButtons() >= 6, "secure: the resumed wait brought the panel back")
eq(rec("secure").at, 2, "secure: and waits for the clicks again")
clickAll()
eq(rec("secure").at, 3, "secure: the new clicks complete the step")
fight()
eq(rec("secure").at, 4, "secure: the combat tests ran on the rebuilt panel")
eq(rec("secure").results[3].check, "PASS", "secure: under lockdown")
WoW.leaveCombat()
FP.Steps.Poll()
eq(rec("secure").status, "done", "secure: done")

-- secure, reloaded on the leave-combat step: nothing is left to put back.
H.fp("steps pr secure")
FP.Steps.Run()
clickAll()
fight()
eq(rec("secure").at, 4, "secure again: at the leave-combat step")
reload()
FP.Steps.Poll()
eq(rec("secure").status, "done", "secure again: the reload left no panel to restore, so it is done")
check(tostring(rec("secure").results[4].detail):find("nothing to put back", 1, true),
    "secure again: and says why")

-- keyup, reloaded and then in combat on the combat step: no secure button is
-- made in combat; out of combat the panel comes back, the fight runs the
-- tests, and Restore puts the CVar back as it was before the procedure.
WoW.cvars.ActionButtonUseKeyDown = "1"
H.fp("steps pr keyup")
FP.Steps.Run()
eq(WoW.cvars.ActionButtonUseKeyDown, "0", "keyup: set to 0")
FP.Steps.Run()
clickAll()
eq(rec("keyup").at, 4, "keyup: at the combat step")
reload()
eq(WoW.cvars.ActionButtonUseKeyDown, "0", "keyup: the CVar survives the reload")
WoW.blocked = {}
fight()
eq(#panelButtons(), 0, "keyup: no secure button is made in combat")
eq(#WoW.blocked, 0, "keyup: nothing blocked: " .. table.concat(WoW.blocked, ", "))
eq(rec("keyup").at, 4, "keyup: still waiting")
WoW.leaveCombat()
FP.Steps.Poll()
check(#panelButtons() >= 6, "keyup: out of combat, the panel is back")
fight()
eq(rec("keyup").at, 5, "keyup: the combat tests ran")
WoW.leaveCombat()
FP.Steps.Poll()
eq(rec("keyup").at, 6, "keyup: the panel was put back after combat")
FP.Steps.Run()
eq(WoW.cvars.ActionButtonUseKeyDown, "1", "keyup: Restore puts the original back")
eq(rec("keyup").results[6].check, "PASS", "keyup: its check passes")
eq(rec("keyup").status, "done", "keyup: done")

done("test_probe_reload")
