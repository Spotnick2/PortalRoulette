-- Core port: DB migration, destinations, hearth, reagents.

dofile("tests/wow_stubs.lua")
local H = dofile("tests/harness.lua")

-- A TBC-era save (schema 3).
local saved = {
    version = 3, utilityMode = "dark_portal", cinematicCamera = true,
    showMinimapButton = false, minimap = { angle = 137 }, debugAtiesh = "on",
    uiScale = 1.2,
}
WoW.spells[3561] = { name = "Teleport: Stormwind", known = true }
WoW.spells[3562] = { name = "Teleport: Ironforge", known = true }
WoW.spells[3565] = { name = "Teleport: Darnassus" }
WoW.spells[10059] = { name = "Portal: Stormwind" }
WoW.spells[11416] = { name = "Portal: Ironforge" }
WoW.spells[11419] = { name = "Portal: Darnassus" }
WoW.spells[3567] = { name = "Teleport: Orgrimmar" }
WoW.spells[1297659] = { name = "Teleport: Dalaran" }
WoW.spells[28148] = { name = "Portal: Karazhan" }

local ns = H.loadAddon({ savedDB = saved })
local db = PortalRouletteDB

-- Migration v3 -> v4.
H.eq(db.version, 6, "schema is 6")
H.eq(db.minimap.minimapPos, 137, "the minimap angle survives")
H.eq(db.minimap.hide, true, "a hidden minimap button stays hidden")
H.eq(db.utilityMode, nil, "the removed utility mode is dropped")
H.eq(db.launcherTheme, nil, "the removed launcher theme is dropped")
H.eq(db.cinematicCamera, true, "the camera is on by default")
H.eq(db.debugAtiesh, nil, "removed keys are dropped")
H.eq(db.uiScale, 1.2, "player settings survive")
H.eq(db.loadCount, 1, "the load sentinel counts")

-- Destinations (Alliance, preview off).
local list = ns.Destinations:Resolve(false)
local byId = {}
for _, r in ipairs(list) do byId[r.id] = r end
H.check(byId.stormwind and byId.ironforge and byId.darnassus, "the three Alliance capitals")
H.check(not byId.orgrimmar, "no Horde city on an Alliance character")
H.eq(byId.stormwind.clock, 12, "Stormwind at 12")
H.eq(byId.ironforge.clock, 3, "Ironforge at 3")
H.eq(byId.darnassus.clock, 6, "Darnassus at 6")
H.eq(byId.stormwind.teleportKnown, true, "a known teleport")
H.eq(byId.darnassus.teleportKnown, false, "an existing but unlearned teleport")
H.eq(byId.stormwind.name, "Stormwind", "names come from the spell")
H.check(byId.dalaran and not byId.dalaran.teleportKnown, "Dalaran shows, not learned yet")
H.check(byId.karazhan and byId.karazhan.state == "hidden", "Karazhan shows as unavailable (option on)")

-- A known candidate wins over one that merely exists.
WoW.spells[1308652] = { name = "Teleport: Dalaran", known = true }
local id, known = ns.Destinations.ResolveCandidates({ 1297659, 1308652 })
H.eq(id, 1308652, "the known candidate is picked")
H.eq(known, true, "and is known")
WoW.spells[1308652] = nil
byId = {}
for _, r in ipairs(ns.Destinations:Resolve(true)) do byId[r.id] = r end
H.check(byId.dalaran and byId.dalaran.teleportKnown, "preview shows Dalaran")
H.eq(byId.karazhan.state, "ready", "preview shows Karazhan ready")

-- Karazhan states.
WoW.items[22589] = "Atiesh, Greatstaff of the Guardian"
WoW.counts[22589] = 1
H.eq(ns.Destinations:GetKarazhanState({ item = 22589 }), "owned", "carried Atiesh is owned")
WoW.equipped = { [16] = 22589 }
H.eq(ns.Destinations:GetKarazhanState({ item = 22589 }), "ready", "equipped Atiesh with its spell is ready")
WoW.equipped = nil
WoW.counts[22589] = 0
H.eq(ns.Destinations:GetKarazhanState({ item = 22589 }), "hidden", "no Atiesh is hidden")

-- Hearth: PlayerHasHearthstone is nil on 70205; item 6948 is counted.
WoW.hearthstone = nil
WoW.counts[6948] = 1
WoW.items[6948] = "Hearthstone"
local source = ns.Hearth:Current()
H.eq(source and source.id, 6948, "the hearthstone is found by count")
H.eq(source.action.type, "macro", "used through the measured macro path")
H.eq(source.action.macrotext, "/use item:6948", "the macro uses the item")
WoW.counts[6948] = 0
H.eq(ns.Hearth:Current(), nil, "no hearth at all")
WoW.counts[282006] = 1
WoW.items[282006] = "Crumbling Hearthstone"
H.eq(ns.Hearth:Current().id, 282006, "Crumbling Hearthstone is the fallback")
WoW.counts[6948] = 1
H.eq(ns.Hearth:Current().id, 6948, "with both, the Hearthstone is used, never the single-use one")

-- Reagents: required / free / unknown.
WoW.items[17031] = "Rune of Teleportation"
WoW.items[17032] = "Rune of Portals"
H.eq(ns.Reagents:State({ 3561 }), "unknown", "no tooltip yet: unknown")
WoW.spellTips[3561] = { "Teleport: Stormwind", "120 Mana", "Reagents: |n|cffff2020Rune of Teleportation|r" }
H.eq(ns.Reagents:State({ 3561 }), "required", "a reagent line: required")
WoW.spellTips[3561] = { "Teleport: Stormwind", "120 Mana", "Teleports the caster to Stormwind." }
H.eq(ns.Reagents:State({ 3561 }), "unknown", "no reagent line is not proof of free")
WoW.spells[1262650] = { name = "Reagent Economy", known = true }
H.eq(ns.Reagents:State({ 3561 }), "free", "the Reagent Economy perk: free")
WoW.spells[1262650] = nil
db.reagentDisplay = "hide"
H.eq(ns.Reagents:State({}), "free", "option hide")
db.reagentDisplay = "show"
H.eq(ns.Reagents:State({}), "required", "option show")
db.reagentDisplay = "auto"
WoW.counts[17032] = 0
H.eq(ns.Reagents:IsMissing("portal"), true, "no portal runes")
WoW.combatSecret = true
H.eq(ns.Reagents:IsMissing("portal"), false, "a secret count never warns")
WoW.combatSecret = false

-- Events the client refuses are reported, not fatal.
WoW.refusedEvents.SOME_EVENT = true
H.eq(ns.Events:Register("SOME_EVENT", function() end), false, "a refused event is reported")
H.check(table.concat(ns.API.eventFailures, ","):find("SOME_EVENT"), "and listed for /pr debug")

H.done("test_core")
