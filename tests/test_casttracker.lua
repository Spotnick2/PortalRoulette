-- Casts are followed by spell ID and castGUID; broadcasts follow the options.

dofile("tests/wow_stubs.lua")
local H = dofile("tests/harness.lua")

WoW.spells[10059] = { name = "Portal: Stormwind", known = true }
WoW.spells[3561] = { name = "Teleport: Stormwind", known = true }
local ns = H.loadAddon()
local CT = ns.CastTracker

WoW.inGroup = true
WoW.fire("UNIT_SPELLCAST_SENT", "player", "", "guid-1", 10059)
WoW.fire("UNIT_SPELLCAST_START", "player", "guid-1", 10059)
H.eq(#WoW.chat, 1, "one announcement for SENT + START of the same cast")
H.eq(WoW.chat[1][1], "Opening a portal to Stormwind.", "the portal announcement")
H.eq(WoW.chat[1][2], "PARTY", "to the party")
WoW.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid-other", 10059)
H.check(CT.activeCast ~= nil, "another cast's GUID does not end this one")
WoW.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid-1", 10059)
H.eq(CT.activeCast, nil, "the cast ends on its own GUID")

WoW.fire("UNIT_SPELLCAST_SENT", "player", "", "guid-2", 3561)
H.eq(#WoW.chat, 1, "teleports are not announced by default")
WoW.fire("UNIT_SPELLCAST_FAILED", "player", "guid-2", 3561)
H.eq(CT.activeCast, nil, "a failed cast ends")

-- A secret spell ID is ignored, never compared.
WoW.fire("UNIT_SPELLCAST_SENT", "player", "", WoW.Secret("g"), WoW.Secret(10059))
H.eq(CT.activeCast, nil, "secret payloads are ignored")

WoW.fire("UNIT_SPELLCAST_SENT", "player", "", "guid-3", 99999)
H.eq(CT.activeCast, nil, "other spells are not tracked")
H.done("test_casttracker")
