-- ============================================================
-- Portal Roulette - Forever probe, a ForeverProbe module (/fp pr)
--
-- A development-only measurement tool for the Forever port (see
-- docs/FOREVER-PROBE.md). It is its own addon, never packaged; it runs on
-- ForeverProbe, the shared probe host (..\ForeverProbe, its docs/GUIDE.md),
-- and `pwsh Tools/deploy.ps1 -Probe` installs both.
--
-- Its lines go to the ForeverProbe console (/fp) and to
-- PortalRouletteProbeDB.log, never to chat. Every result keeps the format
-- docs/FOREVER-PROBE.md's results were read from: "key = RETURNED ..." /
-- "THREW ..." / "ABSENT ...", and each run's lines are also kept on their own
-- as PortalRouletteProbeDB.<run> (core, tips, traits, ...). The client writes
-- them at /reload or logout. Secret values are never compared or formatted:
-- they are saved as "<secret>".
--
-- Commands (/fp pr <command>):
--   core              spells, items, hearth, talents, misc
--   tips [id]         spell tooltips of every teleport/portal (async)
--   traits            the talent tree (C_Traits); flags reagent/portal talents
--   scan [max]        find every "Teleport:"/"Portal:" spell ID and Reagent Economy (slow)
--   find <text>       the same scan, also matching names containing <text>
--   secure            secure test buttons (click them; arms combat tests)
--   gfx               graphics test panel (screenshot it)
--   spell <id>        dump one spell
--   item <id>         dump one item
--   cvarmark          record camera CVars, write marker values (restart test)
--   cvarrestore       put back the CVars cvarmark changed
--   popup             test GameEvent.UnregisterInternalEvent for the CVar popup
--   clear             wipe saved results and the log
--
-- Procedures, for what needs the owner's hands (/fp steps pr <name>):
--   secure      the secure buttons, clicked, then the combat tests
--   keyup       the same with ActionButtonUseKeyDown 0 (cast on release)
--   gfx         the graphics panel, looked at and screenshotted
--   popup       the experimental-CVar popup, then a /reload and a minute of play
--   persist     camera CVars across a full exit and relaunch
--   reagentbag  whether the rune count includes the reagent bag
--   talent      the reagent-free talent/perk, and which Reagent Economy ID is known
-- ============================================================

local ADDON, NS = ...
local MAX_LOG = 3000

local Probe = ForeverProbe:Module("PortalRouletteProbe", { api = 1, cmd = "pr" })

local function say(msg) Probe:Say(msg) end

-- Spell and item IDs under test. Vanilla IDs; the probe confirms them.
local TELEPORTS = {
    { "Stormwind", 3561 }, { "Ironforge", 3562 }, { "Darnassus", 3565 },
    { "Orgrimmar", 3567 }, { "Undercity", 3563 }, { "Thunder Bluff", 3566 },
}
local PORTALS = {
    { "Stormwind", 10059 }, { "Ironforge", 11416 }, { "Darnassus", 11419 },
    { "Orgrimmar", 11417 }, { "Undercity", 11418 }, { "Thunder Bluff", 11420 },
}
local ITEMS = {
    { "Rune of Teleportation", 17031 }, { "Rune of Portals", 17032 },
    { "Atiesh", 22589 }, { "Hearthstone", 6948 }, { "Crumbling Hearthstone", 282006 },
}
local FROST_ARMOR = 168
local HEARTH_SPELL = 8690
local RUNE_OF_TELEPORTATION = 17031
-- The "Reagent Economy" perk, one spell per class (docs/FOREVER-PROBE.md, run 2).
local REAGENT_ECONOMY = { 1225503, 1262636, 1262638, 1262643, 1262647, 1262650, 1262654, 1262662 }

------------------------------------------------------------
-- Saved results
------------------------------------------------------------

-- The saved table, made at this addon's ADDON_LOADED (never at file scope:
-- the client loads SavedVariables after the files).
local function DB()
    if type(PortalRouletteProbeDB) ~= "table" then PortalRouletteProbeDB = {} end
    return PortalRouletteProbeDB
end

local runLog -- the current run's list of "key = value" lines

local function isSecret(v)
    return issecretvalue ~= nil and issecretvalue(v) or false
end

-- Describe a value without comparing it: comparing a secret throws. Scalars
-- are the host's Probe.Show (secrets as <secret>, strings quoted); tables
-- keep this probe's own format (sorted "k=v", 2 levels, 24 keys), the one the
-- results in docs/FOREVER-PROBE.md were read from (guide section 10: a local
-- adapter where the output format matters).
local function fmt(v, depth)
    if isSecret(v) then return "<secret>" end
    if canaccessvalue ~= nil and not canaccessvalue(v) then return "<inaccessible>" end
    if type(v) == "table" then
        depth = depth or 0
        if depth > 2 then return "{...}" end
        local parts = {}
        for k, x in pairs(v) do
            parts[#parts + 1] = tostring(k) .. "=" .. fmt(x, depth + 1)
            if #parts >= 24 then parts[#parts + 1] = "..." break end
        end
        table.sort(parts)
        return "{" .. table.concat(parts, ", ") .. "}"
    end
    return Probe.Show(v)
end

local function describe(...)
    local n = select("#", ...)
    if n == 0 then return "(no returns)" end
    local parts = {}
    for i = 1, n do parts[i] = fmt((select(i, ...))) end
    return table.concat(parts, ", ")
end

-- One result line: to the console and the module's log (Probe:Say), and to
-- the current run's own list.
local function out(key, text)
    if runLog then runLog[#runLog + 1] = key .. " = " .. text end
    say(key .. " = " .. text)
end

local function report(key, ok, ...)
    if ok then out(key, "RETURNED " .. describe(...))
    else out(key, "THREW " .. tostring((...))) end
end

-- Call a dotted global path; ABSENT when any part of it is missing.
local function resolve(path)
    local v = _G
    for part in path:gmatch("[^%.]+") do
        if type(v) ~= "table" then return nil end
        v = v[part]
    end
    return v
end

-- This probe's try keeps its own format: ABSENT (the host's Try says MISSING)
-- and THREW (ERROR), with the full return tuple (describe keeps every value,
-- nils included), so the results stay comparable with the earlier runs.
local function try(key, path, ...)
    local fn = resolve(path)
    if type(fn) ~= "function" then out(key, "ABSENT " .. path) return end
    report(key, pcall(fn, ...))
end

local function startLog(name)
    runLog = {}
    local _, build = GetBuildInfo()
    out("run", name .. " on build " .. tostring(build) .. " at " .. date("%Y-%m-%d %H:%M:%S"))
end

local function saveLog(name)
    DB()[name] = runLog
    runLog = nil
    say("saved as PortalRouletteProbeDB." .. name .. " (written at logout or /reload)")
end

------------------------------------------------------------
-- Blocked actions (protected calls from insecure code)
--
-- The host's baseline is the one ADDON_ACTION_BLOCKED / FORBIDDEN watcher,
-- and it logs them. The combat and popup tests also record which were
-- blocked after each call ("  blocked = ..."), and the host has no callback
-- for that yet, so this listens on the baseline's frame. Workaround: replace
-- it with the host's callback once ForeverProbe offers one (ForeverProbe#19).
------------------------------------------------------------

local blocked = {}
do
    local taint = ForeverProbe.Baseline and ForeverProbe.Baseline.taintFrame
    if taint and taint.HookScript then
        taint:HookScript("OnEvent", function(_, event, addon, func)
            blocked[#blocked + 1] = event .. "(" .. tostring(addon) .. ", " .. tostring(func) .. ")"
        end)
    else
        say("the host's taint watcher isn't there: blocked actions are not recorded per test (ForeverProbe#19)")
    end
end

local function blockedSince(mark)
    local t = {}
    for i = mark + 1, #blocked do t[#t + 1] = blocked[i] end
    return #t > 0 and table.concat(t, "; ") or "none"
end

------------------------------------------------------------
-- Core run
------------------------------------------------------------

local function probeSpell(prefix, id)
    try(prefix .. ".DoesSpellExist", "C_Spell.DoesSpellExist", id)
    try(prefix .. ".GetSpellInfo", "C_Spell.GetSpellInfo", id)
    try(prefix .. ".IsSpellKnown(SpellBook)", "C_SpellBook.IsSpellKnown", id)
    try(prefix .. ".IsSpellKnown(global)", "IsSpellKnown", id)
    try(prefix .. ".IsPlayerSpell", "IsPlayerSpell", id)
    try(prefix .. ".IsSpellUsable", "C_Spell.IsSpellUsable", id)
    try(prefix .. ".GetSpellCooldown", "C_Spell.GetSpellCooldown", id)
    try(prefix .. ".GetSpellPowerCost", "C_Spell.GetSpellPowerCost", id)
    try(prefix .. ".GetSpellDescription", "C_Spell.GetSpellDescription", id)
end

local function probeItem(prefix, id)
    try(prefix .. ".GetItemInfoInstant", "C_Item.GetItemInfoInstant", id)
    try(prefix .. ".GetItemInfo", "C_Item.GetItemInfo", id)
    try(prefix .. ".GetItemNameByID", "C_Item.GetItemNameByID", id)
    try(prefix .. ".GetItemIconByID", "C_Item.GetItemIconByID", id)
    try(prefix .. ".GetItemCount", "C_Item.GetItemCount", id)
    try(prefix .. ".GetItemCount(bank)", "C_Item.GetItemCount", id, true)
    try(prefix .. ".GetItemSpell", "C_Item.GetItemSpell", id)
    try(prefix .. ".IsEquippedItem", "C_Item.IsEquippedItem", id)
    try(prefix .. ".GetItemCooldown(C_Item)", "C_Item.GetItemCooldown", id)
    try(prefix .. ".GetItemCooldown(C_Container)", "C_Container.GetItemCooldown", id)
    try(prefix .. ".PlayerHasToy", "PlayerHasToy", id)
    try(prefix .. ".C_ToyBox.GetToyInfo", "C_ToyBox.GetToyInfo", id)
end

-- The carried bags, the reagent bag included when the client has one.
local function carriedBags()
    local bags = { 0, 1, 2, 3, 4 }
    local reagentBag = Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag
    if reagentBag then bags[#bags + 1] = reagentBag end
    return bags, reagentBag
end

-- Every carried bag including the reagent bag, and where each tested item is.
local function probeBags()
    local bags, reagentBag = carriedBags()
    out("Enum.BagIndex.ReagentBag", fmt(reagentBag))
    local wanted = {}
    for _, it in ipairs(ITEMS) do wanted[it[2]] = it[1] end
    for _, bag in ipairs(bags) do
        local ok, n = pcall(C_Container.GetContainerNumSlots, bag)
        out("bag" .. bag .. ".slots", ok and fmt(n) or ("THREW " .. tostring(n)))
        if ok and type(n) == "number" and not isSecret(n) then
            for slot = 1, n do
                local okI, id = pcall(C_Container.GetContainerItemID, bag, slot)
                if okI and id and not isSecret(id) and wanted[id] then
                    local okC, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
                    out("bag" .. bag .. ".slot" .. slot, wanted[id] .. " " .. id .. " info=" .. (okC and fmt(info) or "THREW"))
                end
            end
        end
    end
end

-- Every talent the client reports for each specialization index, so the
-- legacy talent that removes reagent costs can be identified (with its spellID).
local function probeTalents()
    try("C_SpecializationInfo.GetSpecialization", "C_SpecializationInfo.GetSpecialization")
    for spec = 1, 3 do
        try("spec" .. spec .. ".GetSpecializationInfo", "C_SpecializationInfo.GetSpecializationInfo", spec)
    end
    local getTalent = resolve("C_SpecializationInfo.GetTalentInfo")
    if type(getTalent) ~= "function" then out("talents", "ABSENT C_SpecializationInfo.GetTalentInfo") return end
    local found = 0
    for spec = 1, 3 do
        for index = 1, 40 do
            local ok, r = pcall(getTalent, { specializationIndex = spec, talentIndex = index })
            if not ok then
                out("talent." .. spec .. "." .. index, "THREW " .. tostring(r))
                break
            end
            if type(r) == "table" and not isSecret(r) and r.name then
                found = found + 1
                out("talent." .. spec .. "." .. index, fmt(r.name) .. " spellID=" .. fmt(r.spellID)
                    .. " rank=" .. fmt(r.rank) .. "/" .. fmt(r.maxRank) .. " tier=" .. fmt(r.tier)
                    .. " col=" .. fmt(r.column) .. " selected=" .. fmt(r.selected) .. " known=" .. fmt(r.known))
            end
        end
    end
    out("talents.found", tostring(found))
    -- The tier/column form, in case the index form returns nothing.
    if found == 0 then
        for tier = 1, 7 do
            for col = 1, 4 do
                local ok, r = pcall(getTalent, { tier = tier, column = col })
                if ok and type(r) == "table" and not isSecret(r) and r.name then
                    out("talent.t" .. tier .. "c" .. col, fmt(r.name) .. " spellID=" .. fmt(r.spellID) .. " rank=" .. fmt(r.rank))
                end
            end
        end
    end
    try("C_ClassTalents.GetActiveConfigID", "C_ClassTalents.GetActiveConfigID")
end

-- Known spells named Teleport:/Portal: in the spellbook, plus totals.
local function probeSpellbook()
    local numLines = resolve("C_SpellBook.GetNumSpellBookSkillLines")
    if type(numLines) ~= "function" then out("spellbook", "ABSENT") return end
    local okN, n = pcall(numLines)
    if not okN or type(n) ~= "number" then out("spellbook.lines", "THREW " .. tostring(n)) return end
    local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
    for line = 1, n do
        local okL, info = pcall(C_SpellBook.GetSpellBookSkillLineInfo, line)
        if okL and type(info) == "table" then
            out("spellbook.line" .. line, fmt(info.name) .. " offset=" .. fmt(info.itemIndexOffset) .. " n=" .. fmt(info.numSpellBookItems))
            local first = (info.itemIndexOffset or 0) + 1
            local last = (info.itemIndexOffset or 0) + (info.numSpellBookItems or 0)
            for slot = first, last do
                local okI, item = pcall(C_SpellBook.GetSpellBookItemInfo, slot, bank)
                if okI and type(item) == "table" and type(item.name) == "string" and not isSecret(item.name)
                    and (item.name:find("Teleport") or item.name:find("Portal")) then
                    out("spellbook.travel", fmt(item.name) .. " spellID=" .. fmt(item.spellID) .. " type=" .. fmt(item.itemType))
                end
            end
        end
    end
end

local function probeCVars(prefix)
    for _, name in ipairs({ "test_cameraOverShoulder", "CameraKeepCharacterCentered",
        "CameraReduceUnexpectedMovement", "cameraDistanceMaxZoomFactor", "test_cameraDynamicPitch",
        "cameraViewBlendStyle", "ActionButtonUseKeyDown", "ActionButtonUseKeyHeldSpell" }) do
        try(prefix .. "." .. name, "C_CVar.GetCVar", name)
    end
end

local function runCore()
    startLog("core")
    out("UnitClass", describe(UnitClass("player")))
    out("UnitRace", describe(UnitRace("player")))
    out("UnitFactionGroup", describe(UnitFactionGroup("player")))
    out("UnitLevel", describe(UnitLevel("player")))
    out("WOW_PROJECT_ID", fmt(WOW_PROJECT_ID))
    for _, t in ipairs(TELEPORTS) do probeSpell("teleport." .. t[1], t[2]) end
    for _, p in ipairs(PORTALS) do probeSpell("portal." .. p[1], p[2]) end
    -- Found by the scan on 70205.
    for _, id in ipairs({ 1297659, 1297660, 1308652, 28148, 1269466 }) do probeSpell("found." .. id, id) end
    probeSpell("frostArmor", FROST_ARMOR)
    probeSpell("hearthSpell", HEARTH_SPELL)
    for _, it in ipairs(ITEMS) do probeItem("item." .. it[1], it[2]) end
    probeBags()
    try("PlayerHasHearthstone", "C_Container.PlayerHasHearthstone")
    try("GetBindLocation", "GetBindLocation")
    try("PlayerCanTeleport", "PlayerCanTeleport")
    try("C_ToyBox.GetNumToys", "C_ToyBox.GetNumToys")
    try("C_ToyBox.GetNumLearnedDisplayedToys", "C_ToyBox.GetNumLearnedDisplayedToys")
    -- Owned toys: the first 200 indices of the (filtered) toy box.
    local fromIndex = resolve("C_ToyBox.GetToyFromIndex")
    if type(fromIndex) == "function" then
        local owned = 0
        for i = 1, 200 do
            local ok, id = pcall(fromIndex, i)
            if not ok or not id or isSecret(id) or id == -1 then break end
            local okH, has = pcall(PlayerHasToy, id)
            if okH and has then
                owned = owned + 1
                local okI, a, b, c = pcall(C_ToyBox.GetToyInfo, id)
                out("toy." .. id, okI and describe(a, b, c) or "THREW")
            end
        end
        out("toys.owned", tostring(owned))
    end
    try("GetInventoryItemID(16)", "GetInventoryItemID", "player", 16)
    probeTalents()
    probeSpellbook()
    probeCVars("cvar")
    out("SetUIVisibility", type(SetUIVisibility) == "function" and "present" or "ABSENT")
    out("GameEvent.UnregisterInternalEvent", type(resolve("GameEvent.UnregisterInternalEvent")) == "function" and "present" or "ABSENT")
    try("C_Spell.GetSpellCooldownDuration(hearth)", "C_Spell.GetSpellCooldownDuration", HEARTH_SPELL)
    saveLog("core")
end

------------------------------------------------------------
-- traits: the talent tree, which Forever serves through C_Traits
-- (C_SpecializationInfo.GetTalentInfo wants a tier and returns nothing).
-- Every node's spell, rank and description; nodes whose text mentions
-- reagents or runes are flagged, to find the reagent-free talent.
------------------------------------------------------------

local function runTraits()
    startLog("traits")
    local okC, configID = pcall(C_ClassTalents.GetActiveConfigID)
    out("configID", okC and fmt(configID) or ("THREW " .. tostring(configID)))
    if not (okC and configID) then saveLog("traits") return end
    local okI, config = pcall(C_Traits.GetConfigInfo, configID)
    out("configInfo", okI and fmt(config) or ("THREW " .. tostring(config)))
    if not (okI and type(config) == "table" and type(config.treeIDs) == "table") then saveLog("traits") return end
    local flagged = 0
    for _, treeID in ipairs(config.treeIDs) do
        local okN, nodes = pcall(C_Traits.GetTreeNodes, treeID)
        out("tree" .. treeID .. ".nodes", okN and tostring(type(nodes) == "table" and #nodes or nodes) or "THREW")
        for _, nodeID in ipairs(okN and type(nodes) == "table" and nodes or {}) do
            local okNI, node = pcall(C_Traits.GetNodeInfo, configID, nodeID)
            if okNI and type(node) == "table" and type(node.entryIDs) == "table" then
                for _, entryID in ipairs(node.entryIDs) do
                    local okE, entry = pcall(C_Traits.GetEntryInfo, configID, entryID)
                    local def = okE and type(entry) == "table" and entry.definitionID
                        and select(2, pcall(C_Traits.GetDefinitionInfo, entry.definitionID))
                    local spellID = type(def) == "table" and def.spellID
                    local name = spellID and C_Spell.GetSpellName(spellID) or (type(def) == "table" and def.overrideName)
                    local desc = spellID and C_Spell.GetSpellDescription(spellID) or ""
                    if type(desc) ~= "string" or isSecret(desc) then desc = "" end
                    local hit = desc:lower():find("reagent") or desc:lower():find("rune of")
                        or desc:lower():find("teleport") or desc:lower():find("portal")
                    if hit then flagged = flagged + 1 end
                    out((hit and "FLAG " or "") .. "node" .. nodeID .. ".entry" .. entryID,
                        fmt(name) .. " spellID=" .. fmt(spellID) .. " rank=" .. fmt(node.currentRank)
                        .. "/" .. fmt(entry and entry.maxRanks) .. " visible=" .. fmt(node.isVisible)
                        .. " pos=" .. fmt(node.posX) .. "," .. fmt(node.posY)
                        .. (hit and (" desc=" .. fmt(desc)) or ""))
                end
            end
        end
    end
    out("flagged", tostring(flagged))
    saveLog("traits")
end

-- Which Reagent Economy spell is known on this character (IsPlayerSpell is
-- what Data/Reagents.lua reads). Returns the known IDs.
local function runReagentEconomy()
    startLog("reagenteconomy")
    local known = {}
    for _, id in ipairs(REAGENT_ECONOMY) do
        local okP, isPlayer = pcall(IsPlayerSpell, id)
        local okK, isKnown = pcall(C_SpellBook.IsSpellKnown, id)
        out("reagentEconomy." .. id, "IsPlayerSpell=" .. (okP and fmt(isPlayer) or "THREW")
            .. " IsSpellKnown=" .. (okK and fmt(isKnown) or "THREW"))
        if okP and isPlayer == true then known[#known + 1] = id end
    end
    out("reagentEconomy.known", #known > 0 and table.concat(known, ", ") or "none")
    saveLog("reagenteconomy")
    return #known > 0 and table.concat(known, ", ") or "none"
end

------------------------------------------------------------
-- tips: spell tooltips (async: data loads on request)
------------------------------------------------------------

local tipFrame = CreateFrame("Frame")
local function tooltipLines(id)
    local ok, data = pcall(C_TooltipInfo.GetSpellByID, id)
    if not ok then return nil, "THREW " .. tostring(data) end
    if type(data) ~= "table" or isSecret(data) or type(data.lines) ~= "table" then return nil, "no data" end
    local lines = {}
    for i, line in ipairs(data.lines) do
        lines[i] = fmt(line.leftText) .. (line.rightText and (" | " .. fmt(line.rightText)) or "")
    end
    return lines
end

local function runTips(extra)
    startLog("tips")
    local pending = {}
    local all = {}
    for _, t in ipairs(TELEPORTS) do all[#all + 1] = { "teleport." .. t[1], t[2] } end
    for _, p in ipairs(PORTALS) do all[#all + 1] = { "portal." .. p[1], p[2] } end
    for _, id in ipairs({ 1297659, 1297660, 1308652, 28148, 1269466, 1232033, 465789 }) do
        all[#all + 1] = { "found." .. id, id }
    end
    if extra then all[#all + 1] = { "spell." .. extra, extra } end
    for _, e in ipairs(all) do
        pcall(C_Spell.RequestLoadSpellData, e[2])
        pending[#pending + 1] = { key = e[1], id = e[2], tries = 0 }
    end
    for _, it in ipairs(ITEMS) do pcall(C_Item.RequestLoadItemDataByID, it[2]) end
    local loaded = {}
    Probe:RegisterEvents(tipFrame, { "SPELL_DATA_LOAD_RESULT" })
    tipFrame:SetScript("OnEvent", function(_, _, spellID, success)
        loaded[#loaded + 1] = fmt(spellID) .. ":" .. fmt(success)
    end)
    local function step()
        local remaining = {}
        for _, e in ipairs(pending) do
            local lines, why = tooltipLines(e.id)
            e.tries = e.tries + 1
            if lines and #lines > 1 then
                out(e.key .. ".tooltip(" .. e.tries .. ")", table.concat(lines, " // "))
            elseif e.tries < 10 then
                remaining[#remaining + 1] = e
            else
                out(e.key .. ".tooltip", "gave up: " .. tostring(why or (lines and #lines .. " lines")))
            end
        end
        pending = remaining
        if #pending > 0 then
            C_Timer.After(0.5, step)
        else
            out("SPELL_DATA_LOAD_RESULT", #loaded > 0 and table.concat(loaded, ", ") or "none seen")
            for _, it in ipairs(ITEMS) do try("item." .. it[1] .. ".GetItemNameByID", "C_Item.GetItemNameByID", it[2]) end
            tipFrame:UnregisterAllEvents()
            saveLog("tips")
        end
    end
    C_Timer.After(0.2, step)
end

------------------------------------------------------------
-- scan: every Teleport:/Portal: spell name (diagnostic only)
------------------------------------------------------------

local scanning
local function runScan(maxID, findText)
    if scanning then scanning.cancel = true say("scan cancelled") return end
    maxID = tonumber(maxID) or 1500000
    findText = findText and findText ~= "" and findText:lower() or nil
    local hits, nextID = {}, 1
    scanning = { cancel = false }
    local me = scanning
    say("scanning spell IDs 1.." .. maxID .. " (/fp pr scan again cancels)")
    local ticker
    ticker = C_Timer.NewTicker(0, function()
        if me.cancel then ticker:Cancel() scanning = nil return end
        local deadline = debugprofilestop() + 4
        while nextID <= maxID and debugprofilestop() < deadline do
            local name = C_Spell.GetSpellName(nextID)
            if type(name) == "string" and not isSecret(name)
                and (name:find("^Teleport:") or name:find("^Portal:") or name == "Reagent Economy"
                     or (findText and name:lower():find(findText, 1, true))) then
                hits[#hits + 1] = nextID .. " " .. name
            end
            nextID = nextID + 1
        end
        if nextID % 100000 < 2000 then say("scan at " .. nextID .. ", " .. #hits .. " hits") end
        if nextID > maxID then
            ticker:Cancel()
            scanning = nil
            local known = {}
            for _, h in ipairs(hits) do
                local id = tonumber(h:match("^(%d+)"))
                if id then known[#known + 1] = id .. " IsPlayerSpell=" .. fmt(IsPlayerSpell(id))
                    .. " IsSpellKnown=" .. fmt(C_SpellBook.IsSpellKnown(id)) end
            end
            DB().scan = { build = select(2, GetBuildInfo()), maxID = maxID, find = findText, hits = hits, known = known }
            say("scan done: " .. #hits .. " hits, saved as PortalRouletteProbeDB.scan")
            for _, h in ipairs(hits) do
                if h:find("Dalaran") or h:find("Karazhan") or h:find("Reagent Economy")
                    or (findText and h:lower():find(findText, 1, true)) then
                    say(h)
                    local id = tonumber(h:match("^(%d+)"))
                    if id and h:find("Reagent Economy") then
                        say("  IsPlayerSpell=" .. fmt(IsPlayerSpell(id))
                            .. " IsSpellKnown=" .. fmt(C_SpellBook.IsSpellKnown(id)))
                    end
                end
            end
        end
    end)
end

-- The probe's panels go above other addons' windows (DIALOG; ForeverProbe's
-- own panel is higher still) and drag out of combat: by `handle` when given,
-- else by the panel itself. The secure panel drags by its title strip, so
-- no mouse-enabled frame overlaps its secure buttons. Measured in game
-- 2026-11-18: at the default strata the secure panel was hidden behind other
-- addons and couldn't be moved.
local function liftAndDrag(panel, handle)
    panel:SetFrameStrata("DIALOG")
    panel:SetClampedToScreen(true)
    panel:SetMovable(true)
    handle = handle or panel
    handle:EnableMouse(true)
    handle:RegisterForDrag("LeftButton")
    handle:SetScript("OnDragStart", function()
        if not InCombatLockdown() then panel:StartMoving() end
    end)
    handle:SetScript("OnDragStop", function() panel:StopMovingOrSizing() end)
end

------------------------------------------------------------
-- secure: secure test buttons and combat tests
------------------------------------------------------------

local securePanel
local secureLabels = {}      -- every button's label, in panel order
local clicked = {}           -- ["<label>/<button>"] = true once a click was recorded
local combatResult           -- nil until the combat tests ran: "ok", the error, or "no lockdown"
local restoredAfterCombat    -- true once PLAYER_REGEN_ENABLED put the panel back
local casts, edges = {}, {}
local castFrame = CreateFrame("Frame")
castFrame:SetScript("OnEvent", function(_, event, unit, a, b, c)
    if unit ~= "player" then return end
    if event == "UNIT_SPELLCAST_SENT" then
        casts[#casts + 1] = { t = GetTime(), spellID = c, kind = "SENT" }
    elseif event == "UI_ERROR_MESSAGE" then
        casts[#casts + 1] = { t = GetTime(), kind = "ERROR", msg = b }
    end
end)

local function newSecureButton(parent, label, index, attrs, useOnKeyDown)
    local b = CreateFrame("Button", "PRProbeSecure" .. index, parent, "SecureActionButtonTemplate")
    b:SetSize(150, 26)
    b:SetPoint("TOPLEFT", 12, -36 - (index - 1) * 30)
    b:RegisterForClicks("AnyUp", "AnyDown")
    for k, v in pairs(attrs) do b:SetAttribute(k, v) end
    if useOnKeyDown ~= nil then b:SetAttribute("useOnKeyDown", useOnKeyDown) end
    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.15, 0.1, 0.3, 0.9)
    local text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("CENTER")
    text:SetText(label)
    b:SetScript("PreClick", function(_, button, down)
        edges[#edges + 1] = { t = GetTime(), label = label, button = button, down = down }
    end)
    -- Count what one physical click produced, a moment after it.
    b:SetScript("PostClick", function(_, button, down)
        if down then return end
        local since = GetTime() - 0.05
        C_Timer.After(0.6, function()
            local sent, errs, nEdges = 0, {}, 0
            for _, c in ipairs(casts) do
                if c.t >= since - 0.6 then
                    if c.kind == "SENT" then sent = sent + 1 else errs[#errs + 1] = fmt(c.msg) end
                end
            end
            for _, e in ipairs(edges) do
                if e.t >= since - 0.6 and e.label == label then nEdges = nEdges + 1 end
            end
            local key = "secure." .. label .. "." .. button
            local line = "edges=" .. nEdges .. " casts=" .. sent .. " errors=" .. (#errs > 0 and table.concat(errs, ";") or "none")
                .. " ActionButtonUseKeyDown=" .. fmt(C_CVar.GetCVar("ActionButtonUseKeyDown"))
            DB().secure = DB().secure or {}
            table.insert(DB().secure, key .. " = " .. line)
            say(key .. " = " .. line)
            clicked[label .. "/" .. button] = true
        end)
    end)
    secureLabels[#secureLabels + 1] = label
    return b
end

local function firstOwnedToy()
    local fromIndex = resolve("C_ToyBox.GetToyFromIndex")
    if type(fromIndex) ~= "function" then return nil end
    for i = 1, 200 do
        local ok, id = pcall(fromIndex, i)
        if not ok or not id or isSecret(id) or id == -1 then return nil end
        local okH, has = pcall(PlayerHasToy, id)
        if okH and has then return id end
    end
end

local function runCombatTests()
    if not securePanel then return end
    startLog("combat")
    DB().combat = runLog -- saved from the start, so a later error keeps what ran
    say("combat tests running")
    local b = _G.PRProbeSecure1
    local mark = #blocked
    out("InCombatLockdown", fmt(InCombatLockdown()))
    out("panel.IsProtected", describe(securePanel:IsProtected()))
    report("button.EnableMouse(false)", pcall(b.EnableMouse, b, false))
    out("button.IsMouseEnabled", describe(b:IsMouseEnabled()))
    out("  blocked", blockedSince(mark)) mark = #blocked
    report("button.EnableMouse(true)", pcall(b.EnableMouse, b, true))
    out("  blocked", blockedSince(mark)) mark = #blocked
    report("button.SetAlpha(0.5)", pcall(b.SetAlpha, b, 0.5))
    out("button.GetAlpha", describe(b:GetAlpha()))
    out("  blocked", blockedSince(mark)) mark = #blocked
    report("panel.SetAlpha(0.5)", pcall(securePanel.SetAlpha, securePanel, 0.5))
    out("panel.GetAlpha", describe(securePanel:GetAlpha()))
    out("  blocked", blockedSince(mark)) mark = #blocked
    report("button.SetAttribute", pcall(b.SetAttribute, b, "probeAttr", 1))
    out("button.GetAttribute", describe(b:GetAttribute("probeAttr")))
    out("  blocked", blockedSince(mark)) mark = #blocked
    report("panel.SetParent(nil)", pcall(securePanel.SetParent, securePanel, nil))
    out("panel.GetParent", describe(securePanel:GetParent() and securePanel:GetParent():GetName()))
    out("  blocked", blockedSince(mark)) mark = #blocked
    report("SetUIVisibility(false)", pcall(SetUIVisibility, false))
    out("  blocked", blockedSince(mark)) mark = #blocked
    report("SetUIVisibility(true)", pcall(SetUIVisibility, true))
    out("UIParent.IsShown", describe(UIParent:IsShown()))
    out("  blocked", blockedSince(mark)) mark = #blocked
    report("UIParent.SetAlpha(1)", pcall(UIParent.SetAlpha, UIParent, 1))
    out("  blocked", blockedSince(mark))
    try("C_Item.GetItemCooldown(hearth)", "C_Item.GetItemCooldown", 6948)
    try("C_Spell.GetSpellCooldown(frostArmor)", "C_Spell.GetSpellCooldown", FROST_ARMOR)
    try("C_Item.GetItemCount(rune)", "C_Item.GetItemCount", 17031)
    runLog = nil
    say("combat tests saved as PortalRouletteProbeDB.combat")
end

local function buildSecure()
    securePanel = CreateFrame("Frame", "PRProbeSecurePanel", UIParent)
    securePanel:SetSize(176, 300)
    securePanel:SetPoint("LEFT", 40, 0)
    local handle = CreateFrame("Frame", nil, securePanel)
    handle:SetPoint("TOPLEFT")
    handle:SetPoint("TOPRIGHT")
    handle:SetHeight(32) -- the buttons start 36 below the top
    liftAndDrag(securePanel, handle)
    securePanel.dragHandle = handle
    local bg = securePanel:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.6)
    local title = securePanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", 0, -10)
    title:SetText("PR probe: click each (drag here)")

    local frostName = C_Spell.GetSpellName(FROST_ARMOR)
    local okH, hearth = pcall(C_Container.PlayerHasHearthstone)
    -- Measured on 70205: PlayerHasHearthstone() is nil with a Hearthstone in the backpack.
    if not (okH and hearth) and (C_Item.GetItemCount(6948) or 0) > 0 then okH, hearth = true, 6948 end
    local toy = firstOwnedToy()
    local i = 0
    local function add(label, attrs, keyDown)
        i = i + 1
        newSecureButton(securePanel, label, i, attrs, keyDown)
    end
    add("spell1 numeric", { type1 = "spell", spell1 = FROST_ARMOR })
    add("spell1 name", { type1 = "spell", spell1 = frostName })
    add("spell2 numeric R", { type2 = "spell", spell2 = FROST_ARMOR })
    add("keyDown=true", { type1 = "spell", spell1 = FROST_ARMOR }, true)
    add("keyDown=false", { type1 = "spell", spell1 = FROST_ARMOR }, false)
    if okH and hearth and not isSecret(hearth) then
        add("hearth item:ID", { type1 = "item", item1 = "item:" .. hearth })
        add("hearth macro", { type1 = "macro", macrotext1 = "/use item:" .. hearth })
    end
    if toy then add("toy " .. toy, { type1 = "toy", toy1 = toy }) end
    add("item1 slot 16", { type1 = "item", item1 = "16" })
    securePanel:SetHeight(48 + i * 30)

    Probe:RegisterEvents(castFrame, { "UNIT_SPELLCAST_SENT", "UI_ERROR_MESSAGE" })
    say("click each button once with left (and the R one with right). Then enter combat"
        .. " (hit a training dummy) with the panel shown: combat tests run automatically."
        .. " /fp steps pr secure walks you through it.")
end

-- /fp pr secure: build the panel, or toggle it.
local function runSecure()
    if InCombatLockdown() then say("leave combat first") return end
    if securePanel then
        securePanel:SetShown(not securePanel:IsShown())
        return
    end
    buildSecure()
end

-- The procedures' "show the panel": shown (built the first time), and a new
-- round of clicks and combat tests to wait for. A throw keeps the step.
local roundArmed -- true once showSecure ran in this Lua session
local function showSecure()
    if InCombatLockdown() then error("leave combat first, then Retry", 0) end
    if securePanel then securePanel:Show() else buildSecure() end
    clicked, combatResult, restoredAfterCombat = {}, nil, nil
    roundArmed = true
    return #secureLabels .. " buttons"
end

-- ForeverProbe resumes a procedure at its saved step after a /reload, but
-- this file's state starts again: no panel, no clicks, no combat result. A
-- wait that finds the round not armed in this session shows the panel again
-- and starts the round over, instead of waiting forever. In combat it can't
-- build secure buttons, so it says to leave combat first.
local function rearm()
    if roundArmed then return true end
    if InCombatLockdown() then return false, "reloaded since Show panel: leave combat, the panel comes back" end
    showSecure()
    say("reloaded since Show panel: the panel is back, the round starts again")
    return true
end

-- The clicks still to make: every button left, and the R one right too.
local function missingClicks()
    local missing = {}
    for _, label in ipairs(secureLabels) do
        if not clicked[label .. "/LeftButton"] then missing[#missing + 1] = label .. " (left)" end
    end
    if not clicked["spell2 numeric R/RightButton"] then missing[#missing + 1] = "spell2 numeric R (right)" end
    return missing
end

local combatFrame = CreateFrame("Frame")
Probe:RegisterEvents(combatFrame, { "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" })
combatFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_DISABLED" and securePanel and securePanel:IsShown() then
        -- Measured on 70205: InCombatLockdown() is still false inside
        -- PLAYER_REGEN_DISABLED, so wait until lockdown is really on.
        local tries = 0
        local function attempt()
            tries = tries + 1
            if not InCombatLockdown() then
                if tries < 20 then C_Timer.After(0.1, attempt) else combatResult = "no lockdown after 2 s" end
                return
            end
            local ok, err = pcall(runCombatTests)
            if not ok then
                if runLog then runLog[#runLog + 1] = "ERROR = " .. tostring(err) end
                runLog = nil
                say("combat tests stopped: " .. tostring(err))
            end
            combatResult = ok and "ok" or tostring(err)
        end
        attempt()
    elseif event == "PLAYER_REGEN_ENABLED" and securePanel then
        securePanel:SetAlpha(1)
        if securePanel:GetParent() ~= UIParent then securePanel:SetParent(UIParent) end
        local b = _G.PRProbeSecure1
        if b then b:SetAlpha(1) b:EnableMouse(true) end
        restoredAfterCombat = true
        say("combat over; panel restored")
    end
end)

------------------------------------------------------------
-- gfx: graphics test panel
------------------------------------------------------------

local CIRCLE_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local gfxPanel
local function buildGfx()
    startLog("gfx")
    gfxPanel = CreateFrame("Frame", "PRProbeGfx", UIParent)
    gfxPanel:SetSize(620, 380)
    gfxPanel:SetPoint("CENTER")
    liftAndDrag(gfxPanel)
    local bg = gfxPanel:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.05, 0.05, 0.1, 0.85)
    local icon = C_Spell.GetSpellTexture(HEARTH_SPELL) or 134414

    -- Unsliced circle masks at 40, 64 and 320.
    local x = 10
    for _, size in ipairs({ 40, 64, 320 }) do
        local t = gfxPanel:CreateTexture(nil, "ARTWORK")
        t:SetSize(size, size)
        t:SetPoint("TOPLEFT", x, -10)
        t:SetTexture(icon)
        local m = gfxPanel:CreateMaskTexture()
        m:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        m:SetAllPoints(t)
        report("mask" .. size, pcall(t.AddMaskTexture, t, m))
        x = x + size + 10
    end

    -- A rotating texture under a static mask: does the clip stay put?
    local spinHost = CreateFrame("Frame", nil, gfxPanel)
    spinHost:SetSize(120, 120)
    spinHost:SetPoint("BOTTOMLEFT", 10, 10)
    local spin = spinHost:CreateTexture(nil, "ARTWORK")
    spin:SetAllPoints()
    spin:SetTexture("Interface\\Buttons\\WHITE8X8")
    spin:SetGradient("HORIZONTAL", CreateColor(0.2, 0.4, 1, 1), CreateColor(0.8, 0.3, 1, 1))
    local spinMask = spinHost:CreateMaskTexture()
    spinMask:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    spinMask:SetAllPoints(spinHost)
    spin:AddMaskTexture(spinMask)
    local ag = spin:CreateAnimationGroup()
    local rot = ag:CreateAnimation("Rotation")
    rot:SetDegrees(360)
    rot:SetDuration(4)
    ag:SetLooping("REPEAT")
    report("rotationUnderMask.Play", pcall(ag.Play, ag))

    -- Radial progress on a masked texture.
    local radial = gfxPanel:CreateTexture(nil, "ARTWORK")
    radial:SetSize(96, 96)
    radial:SetPoint("BOTTOMLEFT", 150, 20)
    radial:SetTexture("Interface\\Buttons\\WHITE8X8")
    radial:SetVertexColor(0.4, 0.6, 1, 0.9)
    local radialMask = gfxPanel:CreateMaskTexture()
    radialMask:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    radialMask:SetAllPoints(radial)
    radial:AddMaskTexture(radialMask)
    report("SetRadialProgressBarPercent(0.7)", pcall(radial.SetRadialProgressBarPercent, radial, 0.7))

    -- A Cooldown widget driven by a duration object.
    local cdHost = CreateFrame("Frame", nil, gfxPanel)
    cdHost:SetSize(64, 64)
    cdHost:SetPoint("BOTTOMLEFT", 270, 30)
    local cdIcon = cdHost:CreateTexture(nil, "ARTWORK")
    cdIcon:SetAllPoints()
    cdIcon:SetTexture(icon)
    local cd = CreateFrame("Cooldown", nil, cdHost, "CooldownFrameTemplate")
    cd:SetAllPoints()
    local okD, duration = pcall(C_Spell.GetSpellCooldownDuration, HEARTH_SPELL)
    report("GetSpellCooldownDuration(hearth)", okD, duration)
    if okD and duration then
        report("Cooldown:SetCooldownFromDurationObject", pcall(cd.SetCooldownFromDurationObject, cd, duration))
    end

    -- CreateLine.
    local okL, line = pcall(gfxPanel.CreateLine, gfxPanel, nil, "ARTWORK")
    report("CreateLine", okL, line and "line")
    if okL and line then
        line:SetThickness(3)
        line:SetColorTexture(0.6, 0.4, 1, 1)
        line:SetStartPoint("BOTTOMLEFT", 360, 30)
        line:SetEndPoint("BOTTOMLEFT", 600, 120)
    end
    saveLog("gfx")
    say("screenshot this panel: 3 round icons, a spinning round gradient,"
        .. " a 70% radial fill, a hearth cooldown swipe, a purple line. /fp pr gfx hides it.")
end

-- /fp pr gfx: build the panel, or toggle it.
local function runGfx()
    if gfxPanel then gfxPanel:SetShown(not gfxPanel:IsShown()) return end
    buildGfx()
end

local function setGfxShown(show)
    if not gfxPanel then
        if not show then return "not built" end
        buildGfx()
    end
    gfxPanel:SetShown(show)
    return show and "shown" or "hidden"
end

------------------------------------------------------------
-- CVar persistence and the experimental-CVar popup
------------------------------------------------------------

local MARKS = {
    test_cameraOverShoulder = "0.37",
    CameraKeepCharacterCentered = "0",
    CameraReduceUnexpectedMovement = "0",
}

local function runCVarMark()
    local db = DB()
    db.cvarOriginal = db.cvarOriginal or {}
    for name, value in pairs(MARKS) do
        local ok, cur = pcall(C_CVar.GetCVar, name)
        if db.cvarOriginal[name] == nil then db.cvarOriginal[name] = ok and cur or false end
        pcall(C_CVar.SetCVar, name, value)
    end
    db.cvarMarkedAt = date("%Y-%m-%d %H:%M:%S")
    say("marker CVars written. EXIT THE GAME FULLY, start it again and log in:"
        .. " the login check records whether they persisted. /fp pr cvarrestore afterwards"
        .. " (/fp steps pr persist walks you through it).")
end

local function runCVarRestore()
    local db = DB()
    for name, value in pairs(db.cvarOriginal or {}) do
        if value ~= false then pcall(C_CVar.SetCVar, name, value) end
    end
    db.cvarOriginal, db.cvarMarkedAt = nil, nil
    say("camera CVars restored")
end

-- The marker CVars as they read now, against their markers: "name=value"
-- parts, and whether every one holds its marker.
local function markerState()
    local parts, all = {}, true
    for _, name in ipairs({ "test_cameraOverShoulder", "CameraKeepCharacterCentered", "CameraReduceUnexpectedMovement" }) do
        local ok, v = pcall(C_CVar.GetCVar, name)
        local readable = ok and not isSecret(v)
        if not (readable and v == MARKS[name]) then all = false end
        parts[#parts + 1] = name .. "=" .. (ok and fmt(v) or "THREW") .. " (marker " .. MARKS[name] .. ")"
    end
    return all, table.concat(parts, ", ")
end

local popupDone, popupBlocked
local function runPopup()
    startLog("popup")
    popupDone, popupBlocked = false, nil
    local mark = #blocked
    report("GameEvent.UnregisterInternalEvent", pcall(GameEvent.UnregisterInternalEvent, "EXPERIMENTAL_CVAR_CONFIRMATION_NEEDED"))
    out("  blocked", blockedSince(mark))
    local ok, cur = pcall(C_CVar.GetCVar, "test_cameraOverShoulder")
    report("SetCVar(test_cameraOverShoulder)", pcall(C_CVar.SetCVar, "test_cameraOverShoulder", "0.2"))
    C_Timer.After(1, function()
        pcall(C_CVar.SetCVar, "test_cameraOverShoulder", ok and cur or "0")
        report("re-register handler", pcall(GameEvent.RegisterInternalEvent, "EXPERIMENTAL_CVAR_CONFIRMATION_NEEDED",
            function(...) GameEvent.HandleExperimentalCVarConfirmationNeeded(...) end))
        popupBlocked = blockedSince(mark)
        out("  blocked", popupBlocked)
        out("note", "did a confirmation popup appear? write it down; then /reload and play a minute: any taint errors?")
        saveLog("popup")
        popupDone = true
    end)
end

------------------------------------------------------------
-- Reagent bag: does the rune count include it?
------------------------------------------------------------

-- Runes of Teleportation by bag (readable stacks only), and the client's count.
local function runeCounts()
    local bags, reagentBag = carriedBags()
    local total, inReagentBag = 0, 0
    for _, bag in ipairs(bags) do
        local ok, n = pcall(C_Container.GetContainerNumSlots, bag)
        if ok and type(n) == "number" and not isSecret(n) then
            for slot = 1, n do
                local okI, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
                if okI and type(info) == "table" and not isSecret(info.itemID) and info.itemID == RUNE_OF_TELEPORTATION
                    and type(info.stackCount) == "number" and not isSecret(info.stackCount) then
                    total = total + info.stackCount
                    if bag == reagentBag then inReagentBag = inReagentBag + info.stackCount end
                end
            end
        end
    end
    local ok, count = pcall(C_Item.GetItemCount, RUNE_OF_TELEPORTATION)
    return total, inReagentBag, ok and count or nil
end

------------------------------------------------------------
-- Commands: /fp pr <command>
------------------------------------------------------------

local function withArg(fn)
    return function(args) return fn((args or ""):match("^%s*(.-)%s*$")) end
end

Probe:Command("core", function() runCore() end, "spell and item IDs, hearth, toys, talents, spellbook, CVars")
Probe:Command("tips", withArg(function(arg) runTips(tonumber(arg)) end),
    "[spell id]: spell tooltips of every teleport and portal (async, about 5 s)")
Probe:Command("traits", function() runTraits() end, "the talent tree (C_Traits); flags reagent/portal talents")
Probe:Command("scan", withArg(function(arg) runScan(arg) end),
    "[max id]: every Teleport:/Portal: spell ID and Reagent Economy (minutes; again cancels)")
Probe:Command("find", withArg(function(arg)
    if arg == "" then say("/fp pr find <text>") return end
    runScan(1500000, arg)
end), "<text>: the scan, also matching names containing the text")
Probe:Command("secure", function() runSecure() end,
    "secure test buttons; combat tests run on combat entry (/fp steps pr secure)")
Probe:Command("gfx", function() runGfx() end, "graphics test panel, shown or hidden (/fp steps pr gfx)")
Probe:Command("spell", withArg(function(arg)
    local id = tonumber(arg)
    if not id then say("/fp pr spell <id>") return end
    startLog("spell" .. arg) probeSpell("spell." .. arg, id)
    local lines = tooltipLines(id)
    out("tooltip", lines and table.concat(lines, " // ") or "none yet (run again)")
    saveLog("spell" .. arg)
end), "<id>: dump one spell")
Probe:Command("item", withArg(function(arg)
    local id = tonumber(arg)
    if not id then say("/fp pr item <id>") return end
    startLog("item" .. arg) probeItem("item." .. arg, id) saveLog("item" .. arg)
end), "<id>: dump one item")
Probe:Command("cvarmark", function() runCVarMark() end,
    "record camera CVars, write marker values (/fp steps pr persist)")
Probe:Command("cvarrestore", function() runCVarRestore() end, "put back the CVars cvarmark changed")
Probe:Command("popup", function() runPopup() end,
    "GameEvent.UnregisterInternalEvent and the CVar popup (/fp steps pr popup)")
-- Empties the saved results in place: the host holds PortalRouletteProbeDB.log
-- by reference, so neither that table nor the saved table itself is replaced.
Probe:Command("clear", function()
    local db = DB()
    for k in pairs(db) do if k ~= "log" then db[k] = nil end end
    Probe:ClearLog()
    say("cleared")
end, "wipe the saved results and the log")

------------------------------------------------------------
-- Procedures: /fp steps pr <name>
------------------------------------------------------------

-- The clicks and the combat tests, shared by secure and keyup.
local function clickAndCombatSteps(list)
    list[#list + 1] = { text = "Out of combat: press Show panel. A panel of secure test buttons opens on the left;"
        .. " drag it by its title to move it.",
        button = "Show panel", run = showSecure }
    list[#list + 1] = { text = "Left-click each button on the panel once, and right-click the \"spell2 numeric R\""
        .. " one too. This step goes on by itself once every click is recorded.",
        wait = function()
            local armed, why = rearm()
            if not armed then return false, why end
            local missing = missingClicks()
            if #missing == 0 then return true, #secureLabels + 1 .. " clicks recorded" end
            return false, "missing: " .. table.concat(missing, ", ")
        end }
    list[#list + 1] = { text = "Keep the panel shown and pull a training dummy or a mob: the combat tests run"
        .. " once combat lockdown starts.",
        wait = function()
            local armed, why = rearm()
            if not armed then return false, why end
            return combatResult ~= nil, combatResult or "waiting for combat"
        end,
        check = function()
            local lines = table.concat(DB().combat or {}, "\n")
            return combatResult == "ok" and lines:find("InCombatLockdown = true", 1, true) ~= nil,
                "combat tests: " .. tostring(combatResult)
        end }
    list[#list + 1] = { text = "Leave combat (finish the fight or run away). The panel is put back after it.",
        wait = function()
            if InCombatLockdown() then return false, "still in combat" end
            -- After a /reload there is no panel left to put back.
            if not roundArmed then return true, "reloaded since the combat tests: nothing to put back" end
            return restoredAfterCombat == true, "waiting for PLAYER_REGEN_ENABLED"
        end }
    return list
end

Probe:Steps("secure", clickAndCombatSteps({
    rev = 2, -- 2: the waits rebuild the panel after a /reload
    title = "Secure casting and the combat tests",
}))

local function setKeyDown()
    if InCombatLockdown() then error("leave combat first, then Retry", 0) end
    local db = DB()
    if db.keyDownOriginal == nil then
        local ok, cur = pcall(C_CVar.GetCVar, "ActionButtonUseKeyDown")
        db.keyDownOriginal = ok and cur or false
    end
    pcall(C_CVar.SetCVar, "ActionButtonUseKeyDown", "0")
    return C_CVar.GetCVar("ActionButtonUseKeyDown")
end

local keyDownRestoredTo -- what restoreKeyDown put back, for its check
local function restoreKeyDown()
    if InCombatLockdown() then error("leave combat first, then Retry", 0) end
    local db = DB()
    local original = db.keyDownOriginal
    if original ~= nil and original ~= false then pcall(C_CVar.SetCVar, "ActionButtonUseKeyDown", original) end
    db.keyDownOriginal, keyDownRestoredTo = nil, original
    return C_CVar.GetCVar("ActionButtonUseKeyDown"), original
end

do
    local keyup = { rev = 2, -- 2: the waits rebuild the panel after a /reload
                    title = "Secure casting on key release (ActionButtonUseKeyDown 0)" }
    keyup[1] = { text = "Out of combat: press Set to 0. It switches ActionButtonUseKeyDown to 0 (cast on release)."
        .. " If its check fails, type /console ActionButtonUseKeyDown 0 before the clicks.",
        button = "Set to 0", run = setKeyDown,
        check = function() local v = C_CVar.GetCVar("ActionButtonUseKeyDown") return v == "0", v end }
    clickAndCombatSteps(keyup)
    keyup[#keyup + 1] = { text = "Press Restore to put ActionButtonUseKeyDown back as it was.",
        button = "Restore", run = restoreKeyDown,
        check = function()
            local v = C_CVar.GetCVar("ActionButtonUseKeyDown")
            return type(keyDownRestoredTo) == "string" and v == keyDownRestoredTo, v, keyDownRestoredTo
        end }
    Probe:Steps("keyup", keyup)
end

Probe:Steps("gfx", {
    title = "Masks, rotation, radial fill, cooldown and lines",
    { text = "Press Show panel: a graphics test panel opens in the middle of the screen.",
      button = "Show panel", run = function() return setGfxShown(true) end },
    { text = "Does the panel show 3 round icons, a spinning round gradient, a 70% radial fill, a hearth cooldown"
        .. " swipe and a purple line? Type anything that looks wrong in the Note box.",
      ask = true, screenshot = "gfx panel" },
    { text = "Press Hide panel.", button = "Hide panel", run = function() return setGfxShown(false) end },
})

Probe:Steps("popup", {
    title = "The experimental-CVar popup and taint",
    { text = "Out of combat: press Run. It unregisters the experimental-CVar popup's handler and writes"
        .. " test_cameraOverShoulder; a second later it puts both back.",
      run = function()
          if InCombatLockdown() then error("leave combat first, then Retry", 0) end
          runPopup()
          return "started"
      end },
    { text = "Wait a second while the CVar and the handler are put back.",
      wait = function() return popupDone == true, "waiting" end, timeout = 15,
      check = function() return popupBlocked == "none", "blocked: " .. tostring(popupBlocked) end },
    { text = "Did an experimental CVar confirmation popup appear?", ask = true },
    { text = "Type /reload (or press Reload now).", reload = true },
    { text = "Play a minute: move around, open the wheel (/pr), cast something. Then press Next.",
      check = function() return #blocked == 0, "blocked since the /reload: " .. blockedSince(0) end },
    { text = "Did any Lua error or \"interface action blocked\" message appear since the /reload?", ask = true },
})

local cvarsRestoredTo -- the originals the persist procedure's Restore put back, for its check
Probe:Steps("persist", {
    title = "Camera CVars across a full restart",
    { text = "Press Mark: it records the camera CVars and writes marker values.",
      button = "Mark", run = function() runCVarMark() return select(2, markerState()) end,
      check = function() return markerState() end },
    { text = "Exit the game fully (not /reload), start it again and log in on this character."
        .. " The procedure carries on at login.", reload = "exit" },
    { text = "Reading the camera CVars back.", auto = true,
      run = function()
          startLog("persist")
          local all, state = markerState()
          out("markedAt", fmt(DB().cvarMarkedAt))
          out("cvars", state)
          out("persisted", tostring(all))
          saveLog("persist")
          return state
      end,
      check = function() return markerState() end },
    { text = "Press Restore to put the camera CVars back.", button = "Restore",
      run = function()
          cvarsRestoredTo = {}
          for name, value in pairs(DB().cvarOriginal or {}) do cvarsRestoredTo[name] = value end
          runCVarRestore()
          return select(2, markerState())
      end,
      check = function()
          local parts, all = {}, true
          for name, value in pairs(cvarsRestoredTo or {}) do
              local v = C_CVar.GetCVar(name)
              if value ~= false and v ~= value then all = false end
              parts[#parts + 1] = name .. "=" .. fmt(v) .. " (was " .. fmt(value) .. ")"
          end
          table.sort(parts)
          return all and #parts > 0, table.concat(parts, ", ")
      end },
})

Probe:Steps("reagentbag", {
    title = "Rune count with the reagent bag",
    { text = "Put one Rune of Teleportation in your reagent bag (any others stay in your bags), then press Next." },
    { text = "Press Run: it reads the rune count and every bag.",
      run = function()
          startLog("reagentbag")
          probeItem("item.17031", RUNE_OF_TELEPORTATION)
          probeBags()
          local total, inReagentBag, count = runeCounts()
          out("runes", "bags=" .. total .. " reagentBag=" .. inReagentBag .. " GetItemCount=" .. fmt(count))
          saveLog("reagentbag")
          return total, inReagentBag, count
      end,
      check = function()
          local total, inReagentBag, count = runeCounts()
          local readable = type(count) == "number" and not isSecret(count)
          return inReagentBag > 0 and readable and count == total,
              "bags=" .. total .. " reagentBag=" .. inReagentBag .. " GetItemCount=" .. fmt(count)
      end },
})

Probe:Steps("talent", {
    title = "The reagent-free talent or perk",
    { text = "Open the talent window and its Perks tab. Find what removes the reagent cost of teleports and"
        .. " portals, type its name in the Note box, then press Next." },
    { text = "Is it taken (learned) on this character?", ask = true },
    { text = "Press Run: it records the talent tree and which Reagent Economy spell is known.",
      run = function() runTraits() return runReagentEconomy() end },
})

------------------------------------------------------------
-- Load and login: bind the log, record CVars every login (persistence check)
------------------------------------------------------------

local boot = CreateFrame("Frame")
Probe:RegisterEvents(boot, { "ADDON_LOADED", "PLAYER_LOGIN" })
boot:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" then
        if name ~= ADDON then return end
        Probe:Ready()
        local db = DB()
        if type(db.log) ~= "table" then db.log = {} end
        Probe:UseLog(db.log, MAX_LOG)
        say("loaded. /fp pr for the commands, /fp steps for the procedures")
        return
    end
    local db = DB()
    db.loginCount = (db.loginCount or 0) + 1
    db.logins = db.logins or {}
    local entry = { at = date("%Y-%m-%d %H:%M:%S"), build = select(2, GetBuildInfo()), markedAt = db.cvarMarkedAt }
    for cvar in pairs(MARKS) do
        local ok, v = pcall(C_CVar.GetCVar, cvar)
        entry[cvar] = ok and fmt(v) or "THREW"
    end
    table.insert(db.logins, entry)
    while #db.logins > 10 do table.remove(db.logins, 1) end
    say("login " .. db.loginCount .. ": " .. fmt(entry))
end)

NS._test = { Probe = Probe, missingClicks = missingClicks, runeCounts = runeCounts } -- the test seam, never on _G
