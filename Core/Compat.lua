-- ============================================================
-- Compat: the one place the addon touches WoW: Forever's client API.
--
-- Adapted from Apotheca's ApothecaCompat.lua (measured on 70009) plus what
-- Tools/PortalRouletteProbe measured on 70205 (docs/FOREVER-PROBE.md).
--
-- Secret values: cooldowns and counts may be secret in combat. A secret may
-- be held and passed back to the client (a Cooldown widget, a FontString),
-- but comparing, truth-testing or doing arithmetic on one throws. Every
-- such use goes through API.Readable first.
-- ============================================================

local _, ns = ...

local API = {}
ns.API = API

API.MEASURED_ON_BUILD = 70205

-- True when `v` can be compared and used in arithmetic.
function API.Readable(v)
    if issecretvalue and issecretvalue(v) then return false end
    if canaccessvalue and not canaccessvalue(v) then return false end
    return true
end

-- A plain number, or nil when the value is missing or secret.
function API.Number(v)
    if v == nil or not API.Readable(v) then return nil end
    if type(v) ~= "number" then return nil end
    return v
end

function API.ClientBuild()
    local _, build = GetBuildInfo()
    return tonumber(build)
end

-- Both mouse edges: the secure click handler acts on the edge matching the
-- button's useOnKeyDown / ActionButtonUseKeyDown, so a single edge leaves
-- the button dead for half the players. Measured: one cast per click.
function API.ClickEdges()
    return "AnyUp", "AnyDown"
end

------------------------------------------------------------
-- Events: RegisterEvent on an unknown event throws, and may return false.
------------------------------------------------------------

API.eventFailures = {}

function API.RegisterEvent(frame, event)
    local ok, result = pcall(frame.RegisterEvent, frame, event)
    if ok and result ~= false then return true end
    API.eventFailures[#API.eventFailures + 1] = event .. (ok and " (refused)" or (": " .. tostring(result)))
    return false
end

function API.RegisterEvents(frame, ...)
    local all = true
    for i = 1, select("#", ...) do
        if not API.RegisterEvent(frame, (select(i, ...))) then all = false end
    end
    return all
end

------------------------------------------------------------
-- Spells
------------------------------------------------------------

function API.SpellExists(spellID)
    local ok, exists = pcall(C_Spell.DoesSpellExist, spellID)
    return ok and exists == true
end

function API.SpellInfo(spellID)
    local ok, info = pcall(C_Spell.GetSpellInfo, spellID)
    if ok and type(info) == "table" then return info end
    return nil
end

function API.SpellName(spellID)
    local ok, name = pcall(C_Spell.GetSpellName, spellID)
    if ok and type(name) == "string" and API.Readable(name) then return name end
    return nil
end

function API.SpellIcon(spellID)
    local ok, icon = pcall(C_Spell.GetSpellTexture, spellID)
    if ok and icon and API.Readable(icon) then return icon end
    return nil
end

-- C_SpellBook.IsSpellKnown measured on 70205; IsPlayerSpell also covers
-- spells granted by perks and talents.
function API.IsKnown(spellID)
    if not spellID then return false end
    local ok, known = pcall(C_SpellBook.IsSpellKnown, spellID)
    if ok and known == true then return true end
    if IsPlayerSpell then
        local okP, has = pcall(IsPlayerSpell, spellID)
        if okP and has == true then return true end
    end
    return false
end

-- A LuaDurationObject for a Cooldown widget, or nil. Safe with secrets.
function API.SpellCooldownDuration(spellID)
    local ok, duration = pcall(C_Spell.GetSpellCooldownDuration, spellID)
    if ok then return duration end
    return nil
end

function API.RequestSpellData(spellID)
    pcall(C_Spell.RequestLoadSpellData, spellID)
end

------------------------------------------------------------
-- Items
------------------------------------------------------------

-- C_Item.GetItemInfo returns NO values on a cache miss.
function API.ItemInfo(itemID)
    return C_Item.GetItemInfo(itemID)
end

function API.ItemName(itemID)
    local ok, name = pcall(C_Item.GetItemNameByID, itemID)
    if ok and type(name) == "string" and API.Readable(name) then return name end
    return nil
end

-- Answers without the item cache (C_Item.GetItemIcon wants an ItemLocation).
function API.ItemIcon(itemID)
    local ok, icon = pcall(C_Item.GetItemIconByID, itemID)
    if ok and icon and API.Readable(icon) then return icon end
    return nil
end

-- Raw count: may be secret in combat. Pass it to a FontString as is.
function API.ItemCountRaw(itemID)
    local ok, count = pcall(C_Item.GetItemCount, itemID)
    if ok then return count end
    return nil
end

-- A plain count, or nil when unreadable.
function API.ItemCount(itemID)
    return API.Number(API.ItemCountRaw(itemID))
end

-- (start, duration, enable) as C_Container.GetItemCooldown returns them;
-- possibly secret. Never compare them here.
function API.ItemCooldown(itemID)
    return C_Container.GetItemCooldown(itemID)
end

function API.ItemSpell(itemID)
    local ok, name, spellID = pcall(C_Item.GetItemSpell, itemID)
    if ok and name and API.Readable(name) then return name, spellID end
    return nil
end

function API.IsEquipped(itemID)
    local ok, equipped = pcall(C_Item.IsEquippedItem, itemID)
    return ok and equipped == true
end

function API.EquippedItemID(slot)
    local ok, id = pcall(GetInventoryItemID, "player", slot)
    if ok and API.Number(id) then return id end
    return nil
end

function API.RequestItemData(itemID)
    pcall(C_Item.RequestLoadItemDataByID, itemID)
end

-- Carried bags, including the reagent bag (Enum.BagIndex.ReagentBag = 5).
function API.CarriedBags()
    local bags = { 0, 1, 2, 3, 4 }
    local reagentBag = Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag
    if reagentBag then bags[#bags + 1] = reagentBag end
    return bags
end

------------------------------------------------------------
-- Hearth and toys
------------------------------------------------------------

-- Measured on 70205: PlayerHasHearthstone() returns nil even with a
-- Hearthstone in the backpack, so it is only a hint.
function API.HearthstoneItemID()
    local ok, id = pcall(C_Container.PlayerHasHearthstone)
    if ok and API.Number(id) then return id end
    return nil
end

function API.HasToy(itemID)
    if not PlayerHasToy then return false end
    local ok, has = pcall(PlayerHasToy, itemID)
    return ok and has == true
end

function API.BindLocation()
    local ok, where = pcall(GetBindLocation)
    if ok and type(where) == "string" and API.Readable(where) then return where end
    return nil
end

------------------------------------------------------------
-- Tooltips
------------------------------------------------------------

-- The left-text lines of a spell's tooltip, or nil when not loaded yet.
function API.SpellTooltipLines(spellID)
    local ok, data = pcall(C_TooltipInfo.GetSpellByID, spellID)
    if not ok or type(data) ~= "table" or not API.Readable(data) or type(data.lines) ~= "table" then
        return nil
    end
    local lines = {}
    for i, line in ipairs(data.lines) do
        local text = line.leftText
        lines[i] = (type(text) == "string" and API.Readable(text)) and text or ""
    end
    return lines
end

------------------------------------------------------------
-- Player
------------------------------------------------------------

function API.PlayerFaction()
    local faction = UnitFactionGroup("player")
    if faction == "Horde" or faction == "Alliance" then return faction end
    return nil
end

function API.PlayerLevel()
    return API.Number(UnitLevel("player")) or 1
end
