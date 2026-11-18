-- The dev-only probe: every command runs against the stubbed client
-- without touching an unstubbed global, and secrets are never formatted.

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
H.loadProbe()
local db = PortalRouletteProbeDB
check(type(db) == "table", "the probe creates its SavedVariable")
eq(db.loginCount, 1, "each login is counted")
check(db.logins and db.logins[1] and db.logins[1].test_cameraOverShoulder, "login records the camera CVars")

-- Core run.
H.slash("PRPROBE", "")
local core = table.concat(db.core or {}, "\n")
check(core:find("teleport.Stormwind.GetSpellInfo = RETURNED"), "teleport spell info is recorded")
check(core:find("item.Rune of Teleportation.GetItemCount = RETURNED 7"), "reagent count is recorded")
check(core:find("PlayerHasHearthstone = RETURNED nil"), "the hearthstone result is recorded")
check(core:find("toys.owned = 1"), "owned toys are counted")

-- Secrets are saved as <secret>, never compared.
WoW.combatSecret = true
H.slash("PRPROBE", "item 17031")
local item = table.concat(db.item17031 or {}, "\n")
check(item:find("GetItemCount = RETURNED <secret>"), "a secret count is saved as <secret>")
WoW.combatSecret = false

-- Tooltips run asynchronously and finish.
WoW.advance(0)
H.slash("PRPROBE", "tips")
for _ = 1, 15 do WoW.advance(0.5) end
check(db.tips ~= nil, "the tooltip run finishes and saves")

-- Secure panel: numbered attributes, both click edges, never typerelease.
H.slash("PRPROBE", "secure")
local buttons = H.framesWithTemplate("SecureActionButtonTemplate")
check(#buttons >= 6, "the secure panel has its test buttons")
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
H.slash("PRPROBE", "traits")
local traits = table.concat(db.traits or {}, "\n")
check(traits:find("FLAG node5.entry50 = \"Arcane Mastery\""), "the reagent talent is flagged")

-- Graphics panel builds.
H.slash("PRPROBE", "gfx")
check(db.gfx ~= nil, "the graphics run saves")

-- Scan finds names by prefix and can be cancelled.
WoW.spells[99001] = { name = "Teleport: Dalaran" }
H.slash("PRPROBE", "scan 100000")
for _ = 1, 400 do WoW.advance(0) if db.scan then break end end
check(db.scan and table.concat(db.scan.hits, "\n"):find("99001 Teleport: Dalaran"), "the scan finds Teleport: Dalaran")

-- CVar marker round trip.
WoW.cvars.test_cameraOverShoulder = "0"
H.slash("PRPROBE", "cvarmark")
eq(WoW.cvars.test_cameraOverShoulder, "0.37", "cvarmark writes the marker")
H.slash("PRPROBE", "cvarrestore")
eq(WoW.cvars.test_cameraOverShoulder, "0", "cvarrestore puts the original back")

done("test_probe")
