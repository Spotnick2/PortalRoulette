------------------------------------------------------------
-- wow_stubs.lua: Portal Roulette's WoW: Forever mock for Lua 5.1 unit tests.
-- dofile("tests/wow_stubs.lua") FIRST in every test; drive it via the WoW table.
--
-- The mechanics come from WowTestKit (tests/kit.lua loads the commit
-- tests/kit.pin names; its README is the reference): strict globals, secrets,
-- event names checked against the pinned build, widgets that record every
-- method called, protected frames refused in combat, print (with the
-- stray-"|" check done() fails on), timers and the clock (WoW.now,
-- WoW.advance), fire / fireAllRegistered / tick, check / eq / done.
--
-- This file adds Portal Roulette's own client APIs, each verified in the API
-- dump (C:\Projects\WoW\References\Forever\api\forever-api-1.60.1.70959.md)
-- or in Blizzard's FrameXML (C:\Projects\WoW\wow-ui-source). Stub a global
-- only after confirming it there, with the client's signature. A name the
-- client does NOT have goes in the Kit.strict list at the bottom, so the
-- addon has to cope without it. A forgiving stub quietly certifies calls the
-- client will reject.
------------------------------------------------------------

dofile("tests/kit.lua")
local Methods = WoW.Methods
local newWidget = WoW.newWidget
local Secret = WoW.Secret

-- What a protected frame refuses in combat beyond the kit's list: the old
-- stub refused these too (AGENTS.md: no Hide, move, scale or reparent in
-- combat), so the tests asserting WoW.blocked stays empty still cover them.
WoW.PROTECTED.SetParent = true
WoW.PROTECTED.SetScale = true

------------------------------------------------------------
-- Templates
------------------------------------------------------------

-- Templates the addon uses bring these regions (UIPanelButtonTemplate's and
-- UICheckButtonTemplate's Text font string, with its template's font; a
-- named frame's also as <name>Text, as the client's $parent names do).
local TEMPLATE_REGIONS = {
    UICheckButtonTemplate = { "Text" },
    UIPanelButtonTemplate = { "Text" },
}
for template, regions in pairs(TEMPLATE_REGIONS) do
    WoW.templates[template] = function(w)
        for _, region in ipairs(regions) do
            local r = Methods.CreateFontString(w, nil, "ARTWORK", "GameFontNormal")
            w[region] = r
            if w._name then rawset(_G, w._name .. region, r) end
        end
    end
end

------------------------------------------------------------
-- Widget methods the kit's core doesn't have (each a real method of that
-- widget type on this build: Kit.checkMethods checks every call)
------------------------------------------------------------

-- A frame's own scale (LibShowcase records and restores it; the hover
-- growth reads it back). 1 unless set.
function Methods.SetScale(w, s) w._scale = s end
function Methods.GetScale(w) return w._scale or 1 end
function Methods.GetSize(w) return w._width, w._height end
function Methods.GetNumPoints(w) return #w._points end
function Methods.GetTexture(t) return t._file end
-- The secure buttons' click edges (tests check both are registered).
function Methods.RegisterForClicks(b, ...) b._clicks = { ... } end
-- Frame:CreateLine (SimpleFrameAPI): a Line region of the frame.
function Methods.CreateLine(w, name)
    local l = WoW.addRegion(w, newWidget("Line", w, name))
    if name then rawset(_G, name, l) end
    return l
end
-- Events: the core's check of the name against the build, plus two refusals
-- the tests simulate: WoW.badEvents throws, WoW.refusedEvents returns false
-- (ns.API.RegisterEvents must report both).
local kitRegister = Methods.RegisterEvent
function Methods.RegisterEvent(w, e)
    if WoW.badEvents[e] then error("Attempt to register unknown event \"" .. tostring(e) .. "\"", 2) end
    if WoW.refusedEvents[e] then return false end
    return kitRegister(w, e)
end

------------------------------------------------------------
-- State the tests reset
------------------------------------------------------------

table.insert(WoW.onReset, function()
    WoW.now          = 10000     -- the client's clock is never near 0
    WoW.build        = "70205"
    WoW.class        = "MAGE"
    WoW.combatSecret = false     -- cooldowns and stack counts secret (unmeasured; worst case)
    WoW.bags         = {}        -- [bag] = { [slot] = { itemID=, stackCount= } }
    WoW.cooldowns    = {}        -- [itemID] = { start, duration }
    WoW.items        = {}        -- [itemID] = name; missing -> cache miss
    WoW.badEvents    = {}        -- RegisterEvent throws
    WoW.refusedEvents = {}       -- RegisterEvent returns false
    WoW.altDown      = false
    WoW.popups       = {}
    WoW.sent         = {}        -- SendChatMessage: { msg, channel }
end)

-- WowTestKit #76: WoW.advance(0) fires a 0-second ticker only once (it is
-- re-armed at now + 1e-9, never due at the same now). A 0-second ticker
-- fires every frame on the client, and the probe's scan runs on one, so a
-- 0-second advance moves the clock by that nanosecond meanwhile.
local kitAdvance = WoW.advance
function WoW.advance(dt)
    if dt == 0 then dt = 1e-9 end
    return kitAdvance(dt)
end

-- Measured on 70205: InCombatLockdown() is still false while
-- PLAYER_REGEN_DISABLED handlers run; lockdown starts right after.
function WoW.enterCombat()
    WoW.fire("PLAYER_REGEN_DISABLED")
    WoW.combat = true
end

function WoW.leaveCombat()
    WoW.combat = false
    WoW.fire("PLAYER_REGEN_ENABLED")
end

------------------------------------------------------------
-- Frames the client makes
------------------------------------------------------------

GameTooltip = newWidget("GameTooltip", UIParent, "GameTooltip")
function GameTooltip:IsOwned(f) return self._owner == f end
function GameTooltip:SetOwner(f) self._owner = f end
GameFontNormal, GameFontHighlight = {}, {}
WorldFrame = newWidget("Frame", nil, "WorldFrame")

------------------------------------------------------------
-- Globals present on this client (forever-api-1.60.1.70959.md)
------------------------------------------------------------

function time() return math.floor(WoW.now) end
function IsAltKeyDown() return WoW.altDown end
function GetBuildInfo() return "1.60.1", WoW.build, "Sep 22 2026", 16001 end
function UnitClass() return WoW.class:sub(1, 1) .. WoW.class:sub(2):lower(), WoW.class, 5 end

Enum = { BagIndex = { Backpack = 0, ReagentBag = 5 }, PowerType = { Mana = 0 },
         SpellBookSpellBank = { Player = 0, Pet = 1 } }

-- Hearth, toys, items.
WoW.hearthstone = 6948       -- C_Container.PlayerHasHearthstone() result
WoW.toys = {}                -- [itemID] = true (owned)
WoW.equippedItems = {}       -- [itemID] = true
WoW.counts = {}              -- [itemID] = count for C_Item.GetItemCount

C_Container = {}
function C_Container.GetContainerNumSlots(bag)
    local b = WoW.bags[bag]
    if not b then return 0 end
    local n = 0
    for slot in pairs(b) do if slot > n then n = slot end end
    return n
end
function C_Container.GetContainerItemID(bag, slot)
    local s = WoW.bags[bag] and WoW.bags[bag][slot]
    return s and s.itemID
end
function C_Container.GetContainerItemInfo(bag, slot)
    local s = WoW.bags[bag] and WoW.bags[bag][slot]
    if not s then return nil end
    local count = WoW.combatSecret and Secret("stackCount") or s.stackCount
    return { itemID = s.itemID, stackCount = count, hyperlink = "item:" .. s.itemID }
end
function C_Container.GetItemCooldown(itemID)
    if WoW.combatSecret then return Secret("GetItemCooldown start"), Secret("GetItemCooldown duration"), 1 end
    local c = WoW.cooldowns[itemID]
    if c then return c[1], c[2], 1 end
    return 0, 0, 1
end
function C_Container.PlayerHasHearthstone() return WoW.hearthstone end

C_Item = {}
-- Cache miss returns NO values, not nil.
function C_Item.GetItemInfo(itemID)
    local name = WoW.items[itemID]
    if not name then return end
    return name, "item:" .. itemID, 1, 1, 1, "Consumable", "Potion", 20, "", 134400
end
function C_Item.GetItemIconByID(itemID) return WoW.items[itemID] and 134400 or nil end
function C_Item.GetItemCount(itemID)
    if WoW.combatSecret then return Secret("GetItemCount") end
    return WoW.counts[itemID] or 0
end
-- Reads the client's item DB: answers for any known ID, cache or not.
-- Item class by ID ({ classID, subClassID, subType }); consumables by
-- default. The type name follows the class, as the client's does.
WoW.itemClass = {}
local CLASS_NAME = { [2] = "Weapon", [4] = "Armor" }
function C_Item.GetItemInfoInstant(itemID)
    local c = WoW.itemClass[itemID]
    if c then return itemID, CLASS_NAME[c[1]] or "Miscellaneous", c[3] or "", "", 134400, c[1], c[2] end
    if not WoW.items[itemID] then return nil end
    return itemID, "Consumable", "Food & Drink", "", 134400, 0, 5
end
function C_Item.RequestLoadItemDataByID() end
function C_Item.GetItemSpell(itemID)
    if WoW.items[itemID] then return "Food", 433 end
end
function C_Item.GetItemNameByID(itemID) return WoW.items[itemID] end
function C_Item.IsEquippedItem(itemID) return WoW.equippedItems[itemID] or false end
function C_Item.GetItemCooldown(itemID)
    local c = WoW.cooldowns[itemID]
    if c then return c[1], c[2], true end
    return 0, 0, true
end

-- Spells: WoW.spells[id] = { name=, icon=, known=, usable= }.
WoW.spells = {}
WoW.spellCooldowns = {}      -- [id] = { startTime, duration }
local function spell(id) return type(id) == "number" and WoW.spells[id] or nil end
C_Spell = {}
-- Spells whose name only appears after `n` load requests, like the client,
-- which answers nil until the data arrives (n = math.huge: never loads).
WoW.spellLoadAfter = {}
function C_Spell.RequestLoadSpellData(spellID)
    local e = WoW.spellLoadAfter[spellID]
    if e then
        e.n = e.n - 1
        if e.n <= 0 then WoW.spellNames[spellID], WoW.spellLoadAfter[spellID] = e.name, nil end
    end
end
-- Localized names by spell ID, for spells not in WoW.spells.
WoW.spellNames = {}
function C_Spell.GetSpellName(id)
    local s = spell(id)
    if s then return s.name end
    return WoW.spellNames[id]
end
function C_Spell.DoesSpellExist(id)
    return spell(id) ~= nil or WoW.spellNames[id] ~= nil or WoW.spellLoadAfter[id] ~= nil
end
WoW.spellDescriptions = {}
function C_Spell.GetSpellDescription(spellID)
    if spellID == 433 then return "Restores 61 health over 18 sec." end
    return WoW.spellDescriptions[spellID] or ""
end
function C_Spell.GetSpellInfo(id)
    local s = spell(id)
    if not s then return nil end
    return { name = s.name, iconID = s.icon or 136235, originalIconID = s.icon or 136235,
             castTime = s.castTime or 10000, minRange = 0, maxRange = 0, spellID = id }
end
function C_Spell.GetSpellTexture(id) local s = spell(id) return s and (s.icon or 136235) or nil end
function C_Spell.IsSpellUsable(id) local s = spell(id) return s and s.usable or false, false end
function C_Spell.GetSpellCooldown(id)
    if WoW.combatSecret then return Secret("GetSpellCooldown") end
    local c = WoW.spellCooldowns[id] or { 0, 0 }
    return { startTime = c[1], duration = c[2], isEnabled = true, modRate = 1 }
end
function C_Spell.GetSpellCooldownDuration(id) return { _duration = true, spellID = id } end
function C_Spell.GetSpellPowerCost() return {} end
C_SpellBook = {}
function C_SpellBook.IsSpellKnown(id) local s = spell(id) return s and s.known or false end
function C_SpellBook.GetNumSpellBookSkillLines() return 0 end
function IsSpellKnown(id) return C_SpellBook.IsSpellKnown(id) end
function IsPlayerSpell(id) return C_SpellBook.IsSpellKnown(id) end

-- A profiling clock that advances with every read, so a per-frame time
-- budget really ends a frame's work in tests.
WoW.profileMs = 0
function debugprofilestop() WoW.profileMs = WoW.profileMs + 0.0005 return WoW.profileMs end

WoW.level = 3
function UnitLevel() return WoW.level end

C_TooltipInfo = {}
-- Spell tooltips: WoW.spellTips[id] = { lines... }; missing -> no data yet.
WoW.spellTips = {}
function C_TooltipInfo.GetSpellByID(id)
    local tip = WoW.spellTips[id]
    if not tip then return nil end
    local lines = {}
    for i, t in ipairs(tip) do lines[i] = { leftText = t } end
    return { lines = lines }
end

-- Groups: solo by default.
function IsInGroup(category)
    if category and category ~= WoW.groupCategory then return false end
    return WoW.inGroup or false
end
function IsInRaid() return WoW.inRaid or false end
function GetInventoryItemID(_, slot) return WoW.equipped and WoW.equipped[slot] end

C_SpecializationInfo = {}
function C_SpecializationInfo.GetSpecialization() return 1 end
function C_SpecializationInfo.GetSpecializationInfo() return 62, "Arcane", "", 135932, "DAMAGER", 4, 0 end
function C_SpecializationInfo.GetNumSpecializationsForClassID() return 1 end

-- A colour object (the dump's colorRGBA; LibGlass's gradients take these).
function CreateColor(r, g, b, a) return { r = r, g = g, b = b, a = a } end

Settings = {}
function Settings.RegisterCanvasLayoutCategory(panel, name)
    return { GetID = function() return 1 end, name = name }
end
function Settings.RegisterAddOnCategory() end
function Settings.OpenToCategory() end

function StaticPopup_Show(which, a, b, data)
    WoW.popups[#WoW.popups + 1] = { which = which, a = a, b = b, data = data }
    return { data = data }
end

SlashCmdList = {}
function debugstack() return "stub:1: in function" end
C_Texture = { GetAtlasExists = function(name) return WoW.atlases == nil or WoW.atlases[name] == true end }
ChatFrameUtil = { ActivateChat = function() end }
WoW.shownDialogs = {}
function StaticPopupSpecial_Show(frame) if frame then frame:Show() end end
function StaticPopup_ForEachShownDialog(fn)
    for _, d in ipairs(WoW.shownDialogs) do fn(d) end
end

WOW_PROJECT_ID = 18
function date(fmt) return os.date(fmt) end
function canaccessvalue(v) return not issecretvalue(v) end
function UnitRace() return "Human", "Human", 1 end
function UnitFactionGroup() return WoW.faction or "Alliance", WoW.faction or "Alliance" end

function GetBindLocation() return WoW.bindLocation or "Stormwind" end
function PlayerCanTeleport() return true end
function PlayerHasToy(itemID) return WoW.toys[itemID] or false end
C_ToyBox = {}
function C_ToyBox.GetNumToys() local n = 0 for _ in pairs(WoW.toys) do n = n + 1 end return n end
function C_ToyBox.GetNumLearnedDisplayedToys() return C_ToyBox.GetNumToys() end
function C_ToyBox.GetToyFromIndex(i)
    local ids = {}
    for id in pairs(WoW.toys) do ids[#ids + 1] = id end
    table.sort(ids)
    return ids[i] or -1
end
function C_ToyBox.GetToyInfo(itemID) return itemID, WoW.items[itemID] or ("Toy " .. itemID), 134414 end
function C_ToyBox.IsToyUsable() return true end

-- Talents: Forever serves its legacy talent tree through C_Traits.
-- WoW.traits = { [nodeID] = { spellID=, rank=, maxRanks= } }
WoW.traits = {}
C_ClassTalents = {}
function C_ClassTalents.GetActiveConfigID() return 8684966 end
C_Traits = {}
function C_Traits.GetConfigInfo(configID) return { ID = configID, name = "Mage", treeIDs = { 1 } } end
function C_Traits.GetTreeNodes()
    local ids = {}
    for id in pairs(WoW.traits) do ids[#ids + 1] = id end
    table.sort(ids)
    return ids
end
function C_Traits.GetNodeInfo(_, nodeID)
    local t = WoW.traits[nodeID]
    if not t then return nil end
    return { ID = nodeID, entryIDs = { nodeID * 10 }, currentRank = t.rank or 0, activeRank = t.rank or 0,
             isVisible = true, posX = 0, posY = 0 }
end
function C_Traits.GetEntryInfo(_, entryID)
    local t = WoW.traits[math.floor(entryID / 10)]
    return t and { definitionID = entryID, maxRanks = t.maxRanks or 1 } or nil
end
function C_Traits.GetDefinitionInfo(definitionID)
    local t = WoW.traits[math.floor(definitionID / 10)]
    return t and { spellID = t.spellID } or nil
end

-- Misc globals the addon reads. Not in the dump's lists: UISpecialFrames
-- is FrameXML's (Blizzard_UIParentPanelManager/Shared/UIParentPanelManager.lua:21), YES / NO are GlobalStrings, and
-- LE_PARTY_CATEGORY_INSTANCE is the client's (FrameXML reads it:
-- Blizzard_Channels/Mainline/VoiceUtils.lua:122).
UISpecialFrames = {}
format = string.format
YES, NO = "Yes", "No"
LE_PARTY_CATEGORY_INSTANCE = 2
-- The chat frame shows a line as print does: the kit's print records it in
-- WoW.chat and checks it for a stray "|" (the addon prints through
-- DEFAULT_CHAT_FRAME:AddMessage).
DEFAULT_CHAT_FRAME = { AddMessage = function(_, msg) print(msg) end }
function SendChatMessage(msg, channel) WoW.sent[#WoW.sent + 1] = { msg, channel } end
function IsShiftKeyDown() return false end
WoW.sounds = {}
function PlaySoundFile(path) WoW.sounds[#WoW.sounds + 1] = path return true end
function PlaySound(kit) WoW.sounds[#WoW.sounds + 1] = kit return true end
-- The kits the "game" sound theme plays (FrameXML's SOUNDKIT,
-- Blizzard_SharedXML/Mainline/SoundKitConstants.lua, wow-ui-source 70959).
SOUNDKIT = { IG_SPELLBOOK_OPEN = 829, IG_SPELLBOOK_CLOSE = 830, IG_MAINMENU_OPTION = 852,
             IG_MAINMENU_OPTION_CHECKBOX_OFF = 857 }
-- Macros and action bars (launcher).
function GetActionInfo() return nil end
function GetMacroInfo() return nil end
function GetMacroIndexByName() return 0 end
function GetBindingKey() return nil end
function GetBindingText(k) return k end
function IsLoggedIn() return true end
-- Camera (LibShowcase).
WoW.camera = { zoom = 10, views = {}, view = 1, yaw = 0 }
function GetCameraZoom() return WoW.camera.zoom end
function CameraZoomIn(d) WoW.camera.zoom = WoW.camera.zoom - (d or 0) end
function CameraZoomOut(d) WoW.camera.zoom = WoW.camera.zoom + (d or 0) end
function SaveView(slot) WoW.camera.views[slot] = WoW.camera.zoom end
function SetView(slot) WoW.camera.view = slot end
function MoveViewLeftStart(s) WoW.camera.yaw = -(s or 1) end
function MoveViewLeftStop() WoW.camera.yaw = 0 end
function MoveViewRightStart(s) WoW.camera.yaw = s or 1 end
function MoveViewRightStop() WoW.camera.yaw = 0 end
function ConsoleExec() end
function IsMounted() return false end

-- CVars and the game UI.
WoW.cvars = { ActionButtonUseKeyDown = "1" }
function GetCVar(name) return WoW.cvars[name] end
function SetCVar(name, value) WoW.cvars[name] = tostring(value) return true end
C_CVar = {}
function C_CVar.GetCVar(name) return WoW.cvars[name] end
function C_CVar.SetCVar(name, value) WoW.cvars[name] = tostring(value) return true end
WoW.uiVisible = true
function SetUIVisibility(v) WoW.uiVisible = v and true or false end
GameEvent = {}
function GameEvent.UnregisterInternalEvent() end
function GameEvent.RegisterInternalEvent() end
function GameEvent.HandleExperimentalCVarConfirmationNeeded() end

------------------------------------------------------------
-- Strict globals
------------------------------------------------------------

-- The onReset state above, set once before the first test line.
WoW.reset()

-- Names the client does not have, or that start nil. Reading one returns
-- nil instead of failing the test, so guarded feature checks still run.
-- Any other read of an undefined global fails the test.
Kit.strict({
    -- Removed on Forever (forever-api-1.60.1.70009.md).
    AnimateTexCoords = true, InterfaceOptions_AddCategory = true,
    InterfaceOptionsFrame_OpenToCategory = true, GetItemInfo = true,
    GetItemIcon = true, UnitBuff = true, UnitDebuff = true, UnitAura = true,
    GetTalentTabInfo = true, GetNumTalentTabs = true, UseItemByName = true,
    MouseIsOver = true, GetContainerNumSlots = true, GetContainerItemLink = true,
    GetContainerItemInfo = true, GetItemCooldown = true, MAX_PLAYER_LEVEL = true,
    -- SavedVariables, nil until the client would have loaded them.
    PortalRouletteDB = true, PortalRouletteProbeDB = true,
    -- Present on Mainline; the addon guards for it. Absent in the stub world.
    AddonCompartmentFrame = true,
    -- Libraries: nil until their file loads.
    LibStub = true,
    -- Frames the probe names itself; nil until created.
    PRProbeSecure1 = true, PRProbeSecurePanel = true, PRProbeGfx = true,
})
