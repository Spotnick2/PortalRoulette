-- The wheel: secure attributes, preview isolation, grouped confirm, and
-- combat (closing inside PLAYER_REGEN_DISABLED, which is still unlocked).

dofile("tests/wow_stubs.lua")
local H = dofile("tests/harness.lua")

WoW.spells[3561] = { name = "Teleport: Stormwind", known = true }
WoW.spells[3562] = { name = "Teleport: Ironforge", known = true }
WoW.spells[3565] = { name = "Teleport: Darnassus" }
WoW.spells[10059] = { name = "Portal: Stormwind", known = true }
WoW.spells[11416] = { name = "Portal: Ironforge" }
WoW.spells[11419] = { name = "Portal: Darnassus" }
WoW.spells[1297659] = { name = "Teleport: Dalaran" }
WoW.spells[28148] = { name = "Portal: Karazhan" }
WoW.hearthstone = nil
WoW.counts[6948] = 1
WoW.items[6948] = "Hearthstone"

local ns = H.loadAddon()
local R = ns.Roulette
H.slash("PORTALROULETTE", "")
check(R.open, "/pr opens the wheel")
check(R.root:IsShown(), "the root is shown")

local function nodeFor(id)
    for _, node in ipairs(R.slots) do
        local r = R.assigned[node]
        if r and r.id == id then return node end
    end
end

local secure = H.framesWithTemplate("SecureActionButtonTemplate")
eq(#secure, 6, "5 node slots + the hearth orb")
local FAMILIES = { "type", "spell", "item", "toy", "macro", "macrotext" }
local function executable(button)
    for _, f in ipairs(FAMILIES) do
        for _, s in ipairs({ "", "1", "2" }) do
            if f == "type" and button:GetAttribute(f .. s) ~= nil then return true end
        end
    end
    return false
end
for _, b in ipairs(secure) do
    check(b._clicks and b._clicks[1] == "AnyUp" and b._clicks[2] == "AnyDown", "both click edges")
    for k in pairs(b._attrs or {}) do
        check(not k:find("^typerelease"), "never typerelease")
        check(k ~= "type", "never unnumbered type")
    end
end

local sw = nodeFor("stormwind")
eq(sw.button:GetAttribute("type1"), "spell", "left = teleport")
eq(sw.button:GetAttribute("spell1"), 3561, "Teleport: Stormwind by ID")
eq(sw.button:GetAttribute("type2"), "spell", "right = portal")
eq(sw.button:GetAttribute("spell2"), 10059, "Portal: Stormwind by ID")
local ifg = nodeFor("ironforge")
eq(ifg.button:GetAttribute("type2"), nil, "an unlearned portal has no action")
local darn = nodeFor("darnassus")
check(not executable(darn.button), "an unlearned destination does nothing")
eq(R.orb.button:GetAttribute("type1"), "macro", "the hearth orb")
eq(R.orb.button:GetAttribute("macrotext1"), "/use item:6948", "uses the Hearthstone")
check(nodeFor("dalaran") and not executable(nodeFor("dalaran").button), "Dalaran shown but not castable until learned")

-- Visuals never take the mouse.
for _, node in ipairs(R.slots) do
    check(not node.visual:IsMouseEnabled(), "node visuals are mouse-disabled")
end

-- Preview: normal -> preview -> normal leaves no executable attribute in preview.
R:SetPreview(true)
for _, b in ipairs(secure) do
    check(not executable(b), "preview: no executable attribute on " .. tostring(b:GetName()))
end
check(nodeFor("dalaran") ~= nil, "preview shows Dalaran")
R:SetPreview(false)
eq(nodeFor("stormwind").button:GetAttribute("spell1"), 3561, "attributes come back after preview")

-- Grouped confirm: the teleport is withheld until armed, then expires.
WoW.inGroup = true
R:Refresh()
WoW.advance(0)
sw = nodeFor("stormwind")
eq(sw.button:GetAttribute("type1"), nil, "grouped: teleport withheld")
eq(sw.button:GetAttribute("spell2"), 10059, "grouped: portal still direct")
sw.button:GetScript("PostClick")(sw.button, "LeftButton", false)
check(R.confirm and R.confirm:IsShown(), "our own confirm pill shows")
eq(#WoW.popups, 0, "no Blizzard StaticPopup is used (it would taint the shared dialogs)")
R.confirm.yes:GetScript("OnClick")()
check(not R.confirm:IsShown(), "Yes closes the pill")
eq(sw.button:GetAttribute("spell1"), 3561, "armed: teleport set")
WoW.advance(9)
eq(sw.button:GetAttribute("type1"), nil, "expired: teleport withheld again")
WoW.inGroup = false
R:Refresh()
WoW.advance(0)

-- Combat while open: the wheel closes inside PLAYER_REGEN_DISABLED, which
-- runs before lockdown, so nothing protected is blocked.
WoW.blocked = {}
WoW.enterCombat()
check(not R.open, "combat closes the wheel")
check(not R.root:IsShown(), "the root is hidden before lockdown")
eq(#WoW.blocked, 0, "no protected call was blocked: " .. table.concat(WoW.blocked, ", "))
-- Opening in combat is refused.
H.slash("PORTALROULETTE", "")
check(not R.open, "cannot open in combat")
-- A rebuild requested in combat waits for combat end.
WoW.spells[3565].known = true
R:Refresh()
WoW.advance(0)
eq(nodeFor("darnassus").button:GetAttribute("spell1"), nil, "no attribute write in combat")
WoW.leaveCombat()
eq(nodeFor("darnassus").button:GetAttribute("spell1"), 3565, "applied at combat end, from the current state")
eq(#WoW.blocked, 0, "still nothing blocked: " .. table.concat(WoW.blocked, ", "))

-- Escape: hiding the UISpecialFrames proxy closes the wheel; no keyboard
-- handler is involved.
H.slash("PORTALROULETTE", "")
check(R.open, "open before Escape")
WoW.now = WoW.now + 1
R.escape:Hide()
WoW.advance(0) -- the close is decided a frame later
check(not R.open, "Escape (CloseSpecialWindows) closes the wheel")
local found = false
for _, name in ipairs(UISpecialFrames) do if name == "PortalRouletteEscape" then found = true end end
check(found, "the proxy is registered in UISpecialFrames")
R:FinishClose()

-- Close and reopen in the same frame (a macro toggling twice): the deferred
-- Escape decision from the first opening must not close the second.
if not R.open then H.slash("PORTALROULETTE", "") end
R:Close()
R:FinishClose()
H.slash("PORTALROULETTE", "")
WoW.advance(0)
check(R.open, "a reopen in the same frame stays open")
R:Close()
R:FinishClose()

-- Close path.
H.slash("PORTALROULETTE", "")
check(R.open, "reopens after combat")
R:Close()
R:FinishClose()
check(not R.root:IsShown(), "closed")

-- Casting from the wheel (#17). By default it stays open while the cast runs
-- and closes when a teleport or portal succeeds.
local function openWheel()
    if R.open then R:Close() end
    R:FinishClose()
    H.slash("PORTALROULETTE", "")
    check(R.open, "open before the cast")
end
local guid = 0
local function cast(spellID, outcome)
    guid = guid + 1
    local g = "cast-" .. guid
    WoW.fire("UNIT_SPELLCAST_SENT", "player", "", g, spellID)
    if outcome then WoW.fire(outcome, "player", g, spellID) end
end
eq(ns.db.closeOnCastStart, false, "closing at cast start is off by default")
openWheel()
cast(10059)
check(R.open, "off: the wheel stays open while the portal casts")
WoW.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-" .. guid, 10059)
check(not R.open, "off: it closes when the portal succeeds")
openWheel()
cast(3561, "UNIT_SPELLCAST_FAILED")
check(R.open, "off: a failed teleport leaves it open")

ns.db.closeOnCastStart = true
openWheel()
cast(3561)
check(not R.open, "on: a teleport closes it as the cast starts")
WoW.fire("UNIT_SPELLCAST_INTERRUPTED", "player", "cast-" .. guid, 3561)
check(not R.open, "on: an interrupted cast leaves it closed")
openWheel()
cast(10059)
check(not R.open, "on: a portal closes it as the cast starts")
openWheel()
cast(ns.Constants.SPELL_HEARTHSTONE)
check(R.open, "on: the hearth never closes it")
cast(99999)
check(R.open, "on: an unrelated spell does not close it")
ns.db.closeOnCastStart = false
R:Close()
R:FinishClose()

done("test_wheel")
