-- The Glass UI suite (GlassUI/docs/SUITE.md, roster entry GlassUI#107) and
-- the Utility bar button on Glass Action Bars (GlassActionBars#52, its
-- docs/PUBLIC-API.md version 2). Both exist only with Glass UI loaded:
-- without it nothing is asked, reported or registered.
--
-- Each scenario reloads the stubs and the addon. GlassUI and
-- GlassActionBars are other addons' globals, faked here by their public
-- contracts only.

-- One harness for every scenario, so its pass/fail counts add up.
local H = dofile("tests/harness.lua")

local libRoot = os.getenv("LIBGLASS") or "../LibGlass"
local libFile = libRoot .. "/LibGlass.lua"
local haveLib = io.open(libFile) ~= nil

-- Glass UI's Suite. answer: "pearl", a reason string, or "throw".
local function fakeGlassUI(answer, extra)
    local rec = { theme = {}, reports = {} }
    local suite = {
        API = 1,
        Theme = function(addon)
            rec.theme[#rec.theme + 1] = addon
            if answer == "throw" then error("theme broke") end
            if answer == "pearl" then return { name = "pearl", preset = "pearl" } end
            return nil, answer
        end,
        Report = function(addon, state)
            rec.reports[#rec.reports + 1] = { addon = addon, state = state }
        end,
        Open = function() rec.opened = true return true end,
    }
    for k, v in pairs(extra or {}) do suite[k] = v end
    rawset(_G, "GlassUI", { Suite = suite })
    return rec
end

-- Glass Action Bars. result: "ok", "refuse" or "throw".
local function fakeGAB(version, result)
    local rec = {}
    rawset(_G, "GlassActionBars", {
        PUBLIC_API_VERSION = version,
        RegisterButton = function(def)
            rec.def = def
            if result == "throw" then error("register broke") end
            if result == "refuse" then return false, "bad id" end
            return true
        end,
    })
    return rec
end

-- A LibGlass copy older than Pearl (r5: the disc material, no presets).
local function oldLibGlass()
    local lib = LibStub:NewLibrary("LibGlass-1.0", 5)
    lib.ready = 5
    lib.New = function(_, opts)
        lib.asked = opts
        return {}
    end
end

local function fresh(setup)
    dofile("tests/wow_stubs.lua")
    rawset(_G, "LibStub", nil)
    rawset(_G, "GlassUI", nil)
    rawset(_G, "GlassActionBars", nil)
    WoW.spells[3561] = { name = "Teleport: Stormwind", known = true }
    return setup and setup() or {}
end

local function lastReport(rec)
    local r = rec.reports[#rec.reports]
    return r and r.state
end

------------------------------------------------------------
-- 1. No Glass UI: nothing changes, even with Glass Action Bars loaded.
------------------------------------------------------------
do
    local gab = fresh(function() return fakeGAB(2, "ok") end)
    local ns = H.loadAddon({ libs = haveLib and { libFile } or nil })
    H.check(not ns.GlassUI:Present(), "no Glass UI: not present")
    H.eq(ns.GlassUI:Preset(), nil, "no Glass UI: own look")
    H.eq(gab.def, nil, "no Glass UI: the Utility bar button is not registered, GAB or not")
    H.check(ns.LauncherButton.button:IsShown(), "no Glass UI: the floating launcher shows")
    H.check(ns.Skin:OwnLook(), "no Glass UI: own look")
    H.eq(ns.UtilityButton:StatusText(), nil, "no Glass UI: no Utility bar status")
    H.eq(ns.GlassUI:StatusText(), nil, "no Glass UI: no look status")
    if haveLib then
        H.eq(ns.Skin:Glass().preset, "classic", "no Glass UI: the original material")
        H.slash("PORTALROULETTE", "")
        H.eq(ns.Roulette.disc.glass.rim:GetTexture(), ns.Media.DISC_RIM, "no Glass UI: our rim art")
    end
end

------------------------------------------------------------
-- 2. A Glass UI that doesn't speak API 1 counts as absent.
------------------------------------------------------------
for _, bad in ipairs({ "string", "noSuite", "api2", "noReport" }) do
    local rec
    fresh(function()
        if bad == "string" then
            rawset(_G, "GlassUI", "nope")
        elseif bad == "noSuite" then
            rawset(_G, "GlassUI", {})
        else
            rec = fakeGlassUI("pearl")
            local suite = rawget(_G, "GlassUI").Suite
            if bad == "api2" then suite.API = 2 else suite.Report = nil end
        end
    end)
    local ns = H.loadAddon()
    H.check(not ns.GlassUI:Present(), bad .. ": counts as absent")
    H.eq(ns.GlassUI:Preset(), nil, bad .. ": own look")
    if rec then H.eq(#rec.theme, 0, bad .. ": Theme is never asked") end
end

------------------------------------------------------------
-- 3. Theme throwing, or answering junk: own look, reported as such.
------------------------------------------------------------
for _, answer in ipairs({ "throw", "not-following" }) do
    local rec = fresh(function() return fakeGlassUI(answer) end)
    local ns = H.loadAddon()
    H.eq(ns.GlassUI:Preset(), nil, answer .. ": own look")
    H.eq(#rec.theme, 1, answer .. ": asked once")
    local st = lastReport(rec)
    H.check(st and st.api == 1 and st.built == nil, answer .. ": reports its own look")
    H.check(ns.Skin:OwnLook(), answer .. ": own tuning applies")
end

------------------------------------------------------------
-- 4. Following, with LibGlass r11+: Pearl, our tuning suspended.
------------------------------------------------------------
if haveLib then
    local rec = fresh(function() return fakeGlassUI("pearl") end)
    local ns = H.loadAddon({ libs = { libFile } })
    H.eq(rec.theme[1], "PortalRoulette", "asks Theme for PortalRoulette")
    H.eq(#rec.theme, 1, "asks once per session")
    H.eq(rec.reports[1].addon, "PortalRoulette", "reports as PortalRoulette")
    local st = lastReport(rec)
    H.eq(st.built, "pearl", "reports Pearl")
    H.eq(st.live, false, "not a live follower")
    H.eq(st.look, nil, "no look keys (Pearl's material only)")
    H.check(st.own and st.own.backing == true, "its own backing")
    H.eq(type(st.options), "function", "a mage reports its options page")
    H.eq(ns.Skin:Glass().preset, "pearl", "the instance is Pearl")
    H.check(not ns.Skin:OwnLook(), "own look suspended")
    H.slash("PORTALROULETTE", "")
    H.check(ns.Roulette.open, "the wheel opens under Pearl")
    H.check(ns.Roulette.disc.glass.rim:GetTexture() ~= ns.Media.DISC_RIM, "Pearl's disc rim, not our art")
    H.check(ns.Roulette.header.glass.grain == nil
        or ns.Roulette.header.glass.grain:GetAlpha() ~= 0.025, "header tuning suspended")
    H.eq(#rec.reports, 2, "the build reports once more, with its MINOR")
    H.eq(lastReport(rec).built, "pearl", "still Pearl")
    H.eq(lastReport(rec).minor, LibStub("LibGlass-1.0").ready, "the winning LibGlass MINOR")
    ns.GlassUI:Built("pearl", nil, lastReport(rec).minor)
    H.eq(#rec.reports, 2, "the same build again doesn't report again")
    H.check(ns.GlassUI:StatusText():find("following Glass UI", 1, true), "status: following")
    ns.GlassUI:Decide()
    H.eq(#rec.theme, 1, "deciding again keeps the session's answer")
end

------------------------------------------------------------
-- 5. Following, but the winning LibGlass predates Pearl.
------------------------------------------------------------
do
    local rec = fresh(function() return fakeGlassUI("pearl") end)
    local ns = H.loadAddon({ libs = { oldLibGlass } })
    H.eq(rec.reports[1].state.built, "pearl", "first reports what it will build")
    local st = lastReport(rec)
    H.eq(st.built, nil, "then reports the own look it built")
    H.eq(st.reason, "library-too-old", "because the library is too old")
    H.eq(st.minor, 5, "with the MINOR it found")
    H.check(LibStub("LibGlass-1.0").asked.preset == nil, "never asks r5 for a preset")
    H.check(ns.GlassUI:StatusText():find("library-too-old", 1, true), "status: the failure")
end

------------------------------------------------------------
-- 6. A non-mage asks and reports, and builds nothing.
------------------------------------------------------------
do
    local rec, gab
    fresh(function()
        WoW.class = "WARRIOR"
        rec = fakeGlassUI("pearl")
        gab = fakeGAB(2, "ok")
    end)
    local ns = H.loadAddon()
    H.eq(#rec.theme, 1, "non-mage: asks Theme")
    local st = lastReport(rec)
    H.eq(st.built, "pearl", "non-mage: reports Pearl, not a false failure")
    H.eq(st.options, nil, "non-mage: no options page to offer")
    H.eq(gab.def, nil, "non-mage: no Utility bar button")
    H.eq(ns.LauncherButton.button, nil, "non-mage: no launcher")
end

------------------------------------------------------------
-- 7. The Utility bar button (Glass UI and GAB version 2).
------------------------------------------------------------
do
    local placed = false
    local gab, glassui
    fresh(function()
        glassui = fakeGlassUI("not-following")
        gab = fakeGAB(2, "ok")
        function GetActionInfo(slot) if placed and slot == 10 then return "macro", 121 end end
        function GetMacroInfo() return "Portal Roulette", 5929586, "/pr" end
    end)
    local ns = H.loadAddon()
    local L, def = ns.LauncherButton, gab.def
    H.check(def ~= nil, "registers with Glass UI and GAB present")
    H.eq(def.id, "portalroulette", "its id")
    H.eq(def.binding, "PORTALROULETTE_TOGGLE", "its binding")
    H.eq(def.icon, ns.Media.LAUNCHER_PORTAL, "its icon")
    H.eq(type(def.tooltip), "function", "a tooltip filler")
    H.check(ns.UtilityButton.registered, "recorded as registered")
    H.check(L.button:IsShown(), "not hosted until told: the launcher shows")

    def.OnClick()
    H.check(ns.Roulette.open, "the button opens the wheel")
    ns.Roulette:FinishClose()

    H.check(def.IsEnabled(), "enabled out of combat")
    WoW.enterCombat()
    H.check(not def.IsEnabled(), "refused in combat")
    WoW.leaveCombat()
    WoW.runTimers(1)

    def.OnHosted(true)
    H.check(not L.button:IsShown(), "hosted: the launcher hides")
    H.check(not (L.prompt and L.prompt:IsShown()), "hosted: no drag-the-macro prompt")
    WoW.fire("ACTIONBAR_SLOT_CHANGED", 10)
    WoW.fire("UPDATE_MACROS")
    WoW.runTimers(1)
    H.check(not L.button:IsShown(), "hosted: a visibility event keeps it hidden")
    H.check(ns.UtilityButton:StatusText():find("on Glass Action Bars", 1, true), "status: hosted")

    placed = true
    def.OnHosted(false)
    WoW.runTimers(1)
    H.check(not L.button:IsShown(), "unhosted with the macro on a bar: still hidden")
    placed = false
    WoW.fire("ACTIONBAR_SLOT_CHANGED", 10)
    WoW.runTimers(1)
    H.check(L.button:IsShown(), "unhosted, macro removed: the launcher is back")
    H.check(ns.UtilityButton:StatusText():find("tick Portal Roulette", 1, true), "status: how to turn it on")

    -- The options page shows the Glass UI section and its two lines.
    local panel = rawget(_G, "PortalRouletteOptions")
    panel:GetScript("OnShow")(panel)
    local found, opener
    local regions = {}
    for _, f in ipairs(WoW.frames) do regions[#regions + 1] = f end
    for _, f in ipairs(panel._children) do regions[#regions + 1] = f end
    for _, f in ipairs(regions) do
        local t = f.GetText and f:GetText()
        if type(t) == "string" and t:find("not following Glass UI", 1, true)
            and t:find("tick Portal Roulette", 1, true) then found = true end
        if t == "Open Glass UI" then opener = f end
    end
    H.check(found, "options: the Glass UI status lines")
    H.check(opener ~= nil, "options: an Open Glass UI button")
    opener:GetScript("OnClick")(opener)
    H.check(glassui.opened, "options: the button opens Glass UI's page")
end

------------------------------------------------------------
-- 8. GAB refusing, throwing, or speaking another version.
------------------------------------------------------------
for _, case in ipairs({ { 2, "refuse" }, { 2, "throw" }, { 1, "ok" }, { 3, "ok" } }) do
    local gab
    fresh(function()
        fakeGlassUI("pearl")
        gab = fakeGAB(case[1], case[2])
    end)
    local ns = H.loadAddon()
    local label = "GAB v" .. case[1] .. " " .. case[2]
    H.check(not ns.UtilityButton.registered, label .. ": not registered")
    H.check(ns.LauncherButton.button:IsShown(), label .. ": the launcher stays")
    if case[1] ~= 2 then
        H.eq(gab.def, nil, label .. ": never called")
    else
        H.check(ns.UtilityButton:StatusText():find("refused", 1, true), label .. ": status says refused")
    end
end

H.done("test_suite")
