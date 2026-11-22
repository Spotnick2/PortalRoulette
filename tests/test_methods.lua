-- Every widget method the addon calls exists on that widget type in the
-- pinned build (Kit.checkMethods). The exercise loads the addon (with the
-- LibGlass and LibShowcase checkouts when they are there), fires every
-- registered event, opens the wheel, the options page and the launcher's
-- prompt, hovers and clicks every frame with a handler, runs every slash
-- command, and goes in and out of combat.

dofile("tests/wow_stubs.lua")
local H = dofile("tests/harness.lua")

local libs = {}
for _, lib in ipairs({ { os.getenv("LIBGLASS") or "../LibGlass", "LibGlass.lua" },
                       { os.getenv("LIBSHOWCASE") or "../LibShowcase", "LibShowcase.lua" } }) do
    local file = lib[1] .. "/" .. lib[2]
    local f = io.open(file)
    if f then f:close() libs[#libs + 1] = file end
end

WoW.spells[3561] = { name = "Teleport: Stormwind", known = true }
WoW.spells[3562] = { name = "Teleport: Ironforge", known = true }
WoW.spells[3565] = { name = "Teleport: Darnassus" }
WoW.spells[10059] = { name = "Portal: Stormwind", known = true }
WoW.spells[11416] = { name = "Portal: Ironforge" }
WoW.spells[1297659] = { name = "Teleport: Dalaran", known = true }
WoW.spells[28148] = { name = "Portal: Karazhan" }
WoW.hearthstone = nil
WoW.counts[6948] = 1
WoW.items[6948] = "Hearthstone"
WoW.counts[17031], WoW.counts[17032] = 5, 0
WoW.items[17031], WoW.items[17032] = "Rune of Teleportation", "Rune of Portals"
-- The launcher's macro (test_launcher's fakes, the dump's macro API).
local macro, picked
function GetMacroIndexByName() return macro and 121 or 0 end
function GetMacroInfo() if macro then return macro.name, macro.icon, macro.body end end
function CreateMacro(name, icon, body) macro = { name = name, icon = icon, body = body } return 121 end
function EditMacro(_, name, icon, body)
    macro.name, macro.icon, macro.body = name or macro.name, icon or macro.icon, body or macro.body
    return 121
end
function PickupMacro(index) picked = index end
function GetCursorInfo() if picked then return "macro", picked end end

local ns = H.loadAddon({ libs = libs })
WoW.fireAllRegistered()
for _ = 1, 5 do WoW.step(0.05) end

-- Hover and click every frame that answers to it, as the player would.
local function poke()
    local list = {}
    for _, f in ipairs(WoW.frames) do list[#list + 1] = f end
    for _, f in ipairs(list) do
        local s = f._scripts
        if s.OnEnter then s.OnEnter(f) end
        WoW.step(0.05)
        if s.OnMouseDown then s.OnMouseDown(f, "LeftButton") end
        if s.OnMouseUp then s.OnMouseUp(f, "LeftButton") end
        if s.OnDragStart then s.OnDragStart(f, "LeftButton") end
        if s.OnDragStop then s.OnDragStop(f) end
        if s.OnLeave then s.OnLeave(f) end
        WoW.step(0.05)
    end
end
local function click(f, button)
    if f then WoW.click(f, button or "LeftButton", false) end
end

-- The wheel: open, let the effects run, hover and click everything on it.
H.slash("PORTALROULETTE", "")
for _ = 1, 40 do WoW.step(0.05) end
local R = ns.Roulette
poke()
for _, node in ipairs(R.slots) do
    click(node.button, "LeftButton")
    click(node.button, "RightButton")
end
click(R.orb.button)
-- Grouped: the confirm pill, both answers.
WoW.inGroup = true
R:Refresh()
WoW.advance(0)
for _, node in ipairs(R.slots) do click(node.button, "LeftButton") end
if R.confirm then
    for _, f in ipairs(R.confirm._children) do click(f) end
    click(R.confirm.yes)
end
WoW.inGroup = false
R:Refresh()
WoW.advance(1)

-- The launcher and its drag-the-macro prompt.
ns.LauncherButton:CreatePrompt()
ns.LauncherButton.prompt:Show()
ns.LauncherButton:RefreshAttention()
poke()

-- The options page.
H.slash("PORTALROULETTE", "options")
local panel = rawget(_G, "PortalRouletteOptions")
if panel then
    if panel._scripts.OnShow then panel._scripts.OnShow(panel) end
    local list = {}
    for _, f in ipairs(WoW.frames) do list[#list + 1] = f end
    for _, f in ipairs(list) do
        if f._scripts.OnClick then click(f) end
        if f._scripts.OnValueChanged then f._scripts.OnValueChanged(f, 1, true) end
    end
    if panel._scripts.OnHide then panel._scripts.OnHide(panel) end
end

-- Every slash command.
for _, cmd in ipairs({ "", "", "preview", "preview", "options", "config", "debug", "debug trace on",
                       "debug trace off", "debug faction horde", "debug faction alliance",
                       "debug faction auto", "debug faction bogus", "reset", "bogus" }) do
    H.slash("PORTALROULETTE", cmd)
    WoW.step(0.05)
end

-- Combat with the wheel open, then out of it.
if not R.open then H.slash("PORTALROULETTE", "") end
for _ = 1, 10 do WoW.step(0.05) end
WoW.enterCombat()
WoW.advance(1)
H.slash("PORTALROULETTE", "")
WoW.leaveCombat()
WoW.advance(1)
H.slash("PORTALROULETTE", "")
for _ = 1, 10 do WoW.step(0.05) end
R.escape:Hide()
WoW.advance(1)
if R.open then R:Close() end
R:FinishClose()
for _ = 1, 20 do WoW.step(0.05) end

-- The floor is what the exercise records today, rounded down (144 with both
-- libraries, 128 on the addon's fallbacks without them): it keeps the
-- exercise from quietly shrinking.
local recorded = Kit.checkMethods()
local floor = #libs == 2 and 140 or 120
check(recorded >= floor, "the exercise reached the windows (" .. recorded .. " recorded)")


done("test_methods")
