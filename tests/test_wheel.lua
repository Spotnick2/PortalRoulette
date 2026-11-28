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

-- Grouped confirm: the node's teleport is withheld; the pill's Yes is a
-- secure button that casts it.
WoW.inGroup = true
R:Refresh()
WoW.advance(0)
sw = nodeFor("stormwind")
eq(sw.button:GetAttribute("type1"), nil, "grouped: teleport withheld")
eq(sw.button:GetAttribute("spell2"), 10059, "grouped: portal still direct")
sw.button:GetScript("PostClick")(sw.button, "LeftButton", false)
check(R.confirm and R.confirm:IsShown(), "our own confirm pill shows")
eq(#WoW.popups, 0, "no Blizzard StaticPopup is used (it would taint the shared dialogs)")
-- (the fallback look here: these tests load no LibGlass)
local body = R.confirm.glass.bg
check(body and body._vertex and body._vertex[4] == 0.9, "the pill's body is near opaque")
local yes = R.confirm.yes
eq(yes._template, "SecureActionButtonTemplate", "Yes is a secure button")
eq(yes:GetParent(), R.root, "on the stationary root, not the animated stage")
check(yes:IsShown(), "Yes shows with the pill")
check(yes._clicks and yes._clicks[1] == "AnyUp" and yes._clicks[2] == "AnyDown", "Yes: both click edges")
eq(yes:GetAttribute("type1"), "spell", "Yes casts a spell")
eq(yes:GetAttribute("spell1"), 3561, "Yes casts Teleport: Stormwind")
eq(yes:GetAttribute("type2"), nil, "Yes: no right-click action")
for k in pairs(yes._attrs or {}) do
    check(not k:find("^typerelease"), "Yes: never typerelease")
    check(k ~= "type", "Yes: never unnumbered type")
end
check(yes:GetFrameLevel() > R.confirm:GetFrameLevel(), "Yes sits above the pill")
check(not R.confirm.yesLook:IsMouseEnabled(), "the Yes look takes no mouse")
eq(sw.button:GetAttribute("type1"), nil, "the node still withholds the teleport")
WoW.click(yes, "LeftButton", true)
check(R.confirm:IsShown(), "the down edge leaves the pill up")
WoW.click(yes, "LeftButton", false)
check(not R.confirm:IsShown() and not yes:IsShown(), "the click closes the pill")
WoW.advance(0)
eq(yes:GetAttribute("type1"), nil, "Yes is emptied once closed")
-- No: closes without casting.
sw.button:GetScript("PostClick")(sw.button, "LeftButton", false)
eq(yes:GetAttribute("spell1"), 3561, "asked again")
WoW.click(R.confirm.no, "LeftButton", false)
check(not R.confirm:IsShown() and not yes:IsShown(), "No closes the pill")
WoW.advance(0)
eq(yes:GetAttribute("type1"), nil, "No empties Yes")
-- Preview cancels a pending question; leaving it does not bring it back (Codex, #38).
sw.button:GetScript("PostClick")(sw.button, "LeftButton", false)
check(yes:IsShown(), "asked before preview")
R:SetPreview(true)
eq(yes:GetAttribute("type1"), nil, "preview: Yes casts nothing")
check(not R.confirm:IsShown() and not yes:IsShown(), "preview closes the question")
R:ShowConfirm(R.assigned[sw])
check(not yes:IsShown(), "no question is asked in preview")
R:SetPreview(false)
check(not yes:IsShown(), "after preview: Yes stays hidden")
eq(yes:GetAttribute("type1"), nil, "after preview: Yes stays empty")
eq(R.confirmTarget, nil, "after preview: no destination kept")
-- A bead clicked during the close fade asks nothing, and the next opening
-- starts with no question (Codex, #38).
R:Close()
check(not R.open and R.closeAnim:IsPlaying(), "closing, the fade running")
sw.button:GetScript("PostClick")(sw.button, "LeftButton", false)
check(not yes:IsShown(), "no question while closing")
eq(R.confirmTarget, nil, "no destination taken while closing")
R:FinishClose()
H.slash("PORTALROULETTE", "")
WoW.advance(0)
check(R.open, "reopened")
check(not R.confirm:IsShown() and not yes:IsShown(), "the reopened wheel shows no question")
eq(yes:GetAttribute("type1"), nil, "and Yes casts nothing")
eq(sw.button:GetAttribute("type1"), nil, "the bead still asks first")
WoW.inGroup = false
R:Refresh()
WoW.advance(0)

-- Swap clicks (#49): the portal on the left, the teleport on the right, and
-- everything that names a click follows.
eq(ns.db.swapClicks, false, "swapping the clicks is off by default")
eq(R.strip.hint:GetText(), "Left-click: Teleport  ·  Right-click: Portal", "default hint")
ns.db.swapClicks = true
R:Refresh()
WoW.advance(0)
sw = nodeFor("stormwind")
eq(sw.button:GetAttribute("spell1"), 10059, "swapped: left = Portal: Stormwind")
eq(sw.button:GetAttribute("spell2"), 3561, "swapped: right = Teleport: Stormwind")
eq(nodeFor("ironforge").button:GetAttribute("type1"), nil, "swapped: an unlearned portal has no left action")
eq(nodeFor("ironforge").button:GetAttribute("spell2"), 3562, "swapped: Ironforge's teleport on the right")
eq(R.strip.hint:GetText(), "Left-click: Portal  ·  Right-click: Teleport", "swapped hint")
R:OnNodeEnter(sw)
check(R.info.line1:GetText():find("Right%-click"), "swapped: the teleport line says right-click")
check(R.info.line2:GetText():find("Left%-click"), "swapped: the portal line says left-click")
R:OnNodeLeave(sw)
eq(ns.Node.ModeOf("LeftButton"), ns.Mode.PORTAL, "swapped: the left button is the portal")
eq(ns.Node.ModeOf("RightButton"), ns.Mode.TELEPORT, "swapped: the right button is the teleport")
eq(ns.Node.ModeOf("MiddleButton"), nil, "another button casts nothing")
-- Preview: a swapped left click on Dalaran (no portal) names Dalaran, not
-- its teleport (Codex, #50).
R:SetPreview(true)
local dalNode = nodeFor("dalaran")
local dalName = R.assigned[dalNode].name
local before = H.messagesMatching("Teleport: Dalaran is not cast")
dalNode.button:GetScript("PostClick")(dalNode.button, "LeftButton", false)
eq(H.messagesMatching("Teleport: Dalaran is not cast"), before, "swapped preview: the left click doesn't name the teleport")
check(H.messagesMatching("Preview: " .. dalName:gsub("%p", "%%%0") .. " is not cast") > 0, "swapped preview: it names the destination")
dalNode.button:GetScript("PostClick")(dalNode.button, "RightButton", false)
check(H.messagesMatching("Teleport: Dalaran is not cast") > before, "swapped preview: the right click names the teleport")
R:SetPreview(false)
WoW.advance(0)
-- Karazhan and Dalaran, from Node.Actions directly.
local kara = { id = "karazhan", state = "ready" }
local a = ns.Node.Actions(kara, { swapped = true })
eq(a[1] and a[1].macrotext, "/use 16", "swapped: Atiesh's portal on the left")
eq(a[2], nil, "swapped: nothing on the right for Karazhan")
a = ns.Node.Actions(kara, { swapped = false })
eq(a[2] and a[2].macrotext, "/use 16", "default: Atiesh's portal on the right")
local dal = { id = "dalaran", teleportKnown = true, teleportID = 1297659 }
a = ns.Node.Actions(dal, { swapped = true })
eq(a[2] and a[2].spell, 1297659, "swapped: Dalaran teleports on the right")
eq(a[1], nil, "swapped: Dalaran has no left action")
-- Grouped: the right click (the teleport) asks; the left (the portal) casts.
WoW.inGroup = true
R:Refresh()
WoW.advance(0)
eq(sw.button:GetAttribute("type2"), nil, "swapped, grouped: the teleport is withheld on the right")
eq(sw.button:GetAttribute("spell1"), 10059, "swapped, grouped: the portal still direct on the left")
sw.button:GetScript("PostClick")(sw.button, "LeftButton", false)
check(not R.confirm:IsShown(), "swapped, grouped: the left click asks nothing")
sw.button:GetScript("PostClick")(sw.button, "RightButton", false)
check(R.confirm:IsShown(), "swapped, grouped: the right click asks first")
eq(R.confirm.yes:GetAttribute("spell1"), 3561, "and Yes casts the teleport")
WoW.click(R.confirm.no, "LeftButton", false)
WoW.inGroup = false
ns.db.swapClicks = false
R:Refresh()
WoW.advance(0)
eq(nodeFor("stormwind").button:GetAttribute("spell1"), 3561, "unswapped: left = teleport again")
eq(R.strip.hint:GetText(), "Left-click: Teleport  ·  Right-click: Portal", "unswapped hint")

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
-- The client's order: SENT (the request), then START (the cast bar) unless
-- the request fails first, then SUCCEEDED, FAILED or INTERRUPTED.
local guid = 0
local function send(spellID)
    guid = guid + 1
    WoW.fire("UNIT_SPELLCAST_SENT", "player", "", "cast-" .. guid, spellID)
end
local function start(spellID)
    WoW.fire("UNIT_SPELLCAST_START", "player", "cast-" .. guid, spellID)
end
local function finish(event, spellID)
    WoW.fire(event, "player", "cast-" .. guid, spellID)
end
eq(ns.db.closeOnCastStart, false, "closing at cast start is off by default")
openWheel()
send(10059)
start(10059)
check(R.open, "off: the wheel stays open while the portal casts")
finish("UNIT_SPELLCAST_SUCCEEDED", 10059)
check(not R.open, "off: it closes when the portal succeeds")
openWheel()
send(3561)
start(3561)
finish("UNIT_SPELLCAST_FAILED", 3561)
check(R.open, "off: a failed teleport leaves it open")

ns.db.closeOnCastStart = true
openWheel()
send(3561)
check(R.open, "on: the request alone does not close it")
start(3561)
check(not R.open, "on: a teleport closes it when its cast bar starts")
finish("UNIT_SPELLCAST_INTERRUPTED", 3561)
check(not R.open, "on: an interrupted cast leaves it closed")
openWheel()
send(10059)
finish("UNIT_SPELLCAST_FAILED", 10059)
check(R.open, "on: a request that fails before casting leaves it open")
send(10059)
start(10059)
check(not R.open, "on: a portal closes it when its cast bar starts")
openWheel()
send(ns.Constants.SPELL_HEARTHSTONE)
start(ns.Constants.SPELL_HEARTHSTONE)
check(R.open, "on: the hearth never closes it")
finish("UNIT_SPELLCAST_SUCCEEDED", ns.Constants.SPELL_HEARTHSTONE)
send(99999)
start(99999)
check(R.open, "on: an unrelated spell does not close it")
ns.db.closeOnCastStart = false
R:Close()
R:FinishClose()

done("test_wheel")
