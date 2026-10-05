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
H.check(R.open, "/pr opens the wheel")
H.check(R.root:IsShown(), "the root is shown")

local function nodeFor(id)
    for _, node in ipairs(R.slots) do
        local r = R.assigned[node]
        if r and r.id == id then return node end
    end
end

local secure = H.framesWithTemplate("SecureActionButtonTemplate")
H.eq(#secure, 6, "5 node slots + the hearth orb")
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
    H.check(b._clicks and b._clicks[1] == "AnyUp" and b._clicks[2] == "AnyDown", "both click edges")
    for k in pairs(b._attrs) do
        H.check(not k:find("^typerelease"), "never typerelease")
        H.check(k ~= "type", "never unnumbered type")
    end
end

local sw = nodeFor("stormwind")
H.eq(sw.button:GetAttribute("type1"), "spell", "left = teleport")
H.eq(sw.button:GetAttribute("spell1"), 3561, "Teleport: Stormwind by ID")
H.eq(sw.button:GetAttribute("type2"), "spell", "right = portal")
H.eq(sw.button:GetAttribute("spell2"), 10059, "Portal: Stormwind by ID")
local ifg = nodeFor("ironforge")
H.eq(ifg.button:GetAttribute("type2"), nil, "an unlearned portal has no action")
local darn = nodeFor("darnassus")
H.check(not executable(darn.button), "an unlearned destination does nothing")
H.eq(R.orb.button:GetAttribute("type1"), "macro", "the hearth orb")
H.eq(R.orb.button:GetAttribute("macrotext1"), "/use item:6948", "uses the Hearthstone")
H.check(nodeFor("dalaran") and not executable(nodeFor("dalaran").button), "Dalaran shown but not castable until learned")

-- Visuals never take the mouse.
for _, node in ipairs(R.slots) do
    H.check(not node.visual:IsMouseEnabled(), "node visuals are mouse-disabled")
end

-- Preview: normal -> preview -> normal leaves no executable attribute in preview.
R:SetPreview(true)
for _, b in ipairs(secure) do
    H.check(not executable(b), "preview: no executable attribute on " .. tostring(b:GetName()))
end
H.check(nodeFor("dalaran") ~= nil, "preview shows Dalaran")
R:SetPreview(false)
H.eq(nodeFor("stormwind").button:GetAttribute("spell1"), 3561, "attributes come back after preview")

-- Grouped confirm: the teleport is withheld until armed, then expires.
WoW.inGroup = true
R:Refresh()
WoW.runTimers(0)
sw = nodeFor("stormwind")
H.eq(sw.button:GetAttribute("type1"), nil, "grouped: teleport withheld")
H.eq(sw.button:GetAttribute("spell2"), 10059, "grouped: portal still direct")
sw.button:GetScript("PostClick")(sw.button, "LeftButton", false)
H.eq(WoW.popups[#WoW.popups].which, "PORTALROULETTE_CONFIRM_TELEPORT", "the confirm popup shows")
R:Arm()
H.eq(sw.button:GetAttribute("spell1"), 3561, "armed: teleport set")
WoW.runTimers(9)
H.eq(sw.button:GetAttribute("type1"), nil, "expired: teleport withheld again")
WoW.inGroup = false
R:Refresh()
WoW.runTimers(0)

-- Combat while open: the wheel closes inside PLAYER_REGEN_DISABLED, which
-- runs before lockdown, so nothing protected is blocked.
WoW.blocked = {}
WoW.enterCombat()
H.check(not R.open, "combat closes the wheel")
H.check(not R.root:IsShown(), "the root is hidden before lockdown")
H.eq(#WoW.blocked, 0, "no protected call was blocked: " .. table.concat(WoW.blocked, ", "))
-- Opening in combat is refused.
H.slash("PORTALROULETTE", "")
H.check(not R.open, "cannot open in combat")
-- A rebuild requested in combat waits for combat end.
WoW.spells[3565].known = true
R:Refresh()
WoW.runTimers(0)
H.eq(nodeFor("darnassus").button:GetAttribute("spell1"), nil, "no attribute write in combat")
WoW.leaveCombat()
H.eq(nodeFor("darnassus").button:GetAttribute("spell1"), 3565, "applied at combat end, from the current state")
H.eq(#WoW.blocked, 0, "still nothing blocked: " .. table.concat(WoW.blocked, ", "))

-- Escape: hiding the UISpecialFrames proxy closes the wheel; no keyboard
-- handler is involved.
H.slash("PORTALROULETTE", "")
H.check(R.open, "open before Escape")
R.escape:Hide()
H.check(not R.open, "Escape (CloseSpecialWindows) closes the wheel")
local found = false
for _, name in ipairs(UISpecialFrames) do if name == "PortalRouletteEscape" then found = true end end
H.check(found, "the proxy is registered in UISpecialFrames")
R:FinishClose()

-- Close path.
H.slash("PORTALROULETTE", "")
H.check(R.open, "reopens after combat")
R:Close()
R:FinishClose()
H.check(not R.root:IsShown(), "closed")

H.done("test_wheel")
