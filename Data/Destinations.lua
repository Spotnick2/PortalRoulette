-- ============================================================
-- Destinations: explicit spell data, measured on 70205
-- (docs/FOREVER-PROBE.md). No runtime spell scanning.
--
-- teleport / portal: candidate spell IDs. Resolve() prefers one the player
-- KNOWS, then one that EXISTS (shown as not learned yet), else the
-- destination is hidden. Names and icons always come from the IDs, so they
-- are localized by the client.
-- ============================================================

local _, ns = ...

local API = ns.API

local Destinations = {}
ns.Destinations = Destinations

local HORDE = ns.Constants.FACTION_HORDE
local ALLIANCE = ns.Constants.FACTION_ALLIANCE

-- clock: position on the disc, in clock hours (12 = top).
Destinations.LIST = {
    { id = "stormwind",     faction = ALLIANCE, kind = "capital", clock = 12, teleport = { 3561 }, portal = { 10059 }, tLevel = 20, pLevel = 40 },
    { id = "ironforge",     faction = ALLIANCE, kind = "capital", clock = 3,  teleport = { 3562 }, portal = { 11416 }, tLevel = 20, pLevel = 40 },
    { id = "darnassus",     faction = ALLIANCE, kind = "capital", clock = 6,  teleport = { 3565 }, portal = { 11419 }, tLevel = 30, pLevel = 50 },
    { id = "orgrimmar",     faction = HORDE,    kind = "capital", clock = 12, teleport = { 3567 }, portal = { 11417 }, tLevel = 20, pLevel = 40 },
    { id = "undercity",     faction = HORDE,    kind = "capital", clock = 3,  teleport = { 3563 }, portal = { 11418 }, tLevel = 20, pLevel = 40 },
    { id = "thunder_bluff", faction = HORDE,    kind = "capital", clock = 6,  teleport = { 3566 }, portal = { 11420 }, tLevel = 30, pLevel = 50 },
    -- New in Forever. 1297659 is the mage spell (rune, 9.9 s); 1308652 has
    -- no reagent and may be another source. Teleport only.
    { id = "dalaran",  kind = "bonus", clock = 9, teleport = { 1297659, 1308652 }, tLevel = 50 },
    -- Atiesh only: the staff casts Portal: Karazhan (28148). Portal only.
    -- A satellite outside the disc, linked to its rim (as in TBC).
    { id = "karazhan", kind = "bonus", outer = true, clock = 4, item = ns.Constants.ITEM_ATIESH, portalSpell = 28148, subtitle = "Atiesh only" },
}

-- Pick the spell to use from a candidate list.
local function resolveCandidates(candidates)
    if not candidates then
        return nil, false
    end
    for _, id in ipairs(candidates) do
        if API.IsKnown(id) then
            return id, true
        end
    end
    for _, id in ipairs(candidates) do
        if API.SpellExists(id) then
            return id, false
        end
    end
    return nil, false
end
Destinations.ResolveCandidates = resolveCandidates

function Destinations:GetPlayerFaction()
    local override = ns.db and ns.db.debugFaction
    if override == HORDE or override == ALLIANCE then
        return override
    end
    return API.PlayerFaction() or ALLIANCE
end

-- Karazhan: hidden (no Atiesh), owned (carried, must be equipped) or ready
-- (equipped in the main hand with its item spell). type=item on an
-- unequipped Atiesh would EQUIP it (SecureTemplates.lua:418), so only the
-- ready state casts, through the equipped slot.
local MAIN_HAND = 16
function Destinations:GetKarazhanState(entry)
    local item = entry.item
    if API.EquippedItemID(MAIN_HAND) == item then
        if API.ItemSpell(item) then
            return "ready"
        end
        API.RequestItemData(item)
        return "owned" -- cache pending: retried on GET_ITEM_INFO_RECEIVED
    end
    local count = API.ItemCount(item)
    if count and count > 0 then
        return "owned"
    end
    return "hidden"
end

-- The destinations to show, each a resolved copy:
--   { entry, id, kind, clock, teleportID, teleportKnown, portalID,
--     portalKnown, state, name }
-- preview: show everything as if known.
function Destinations:Resolve(preview)
    local faction = self:GetPlayerFaction()
    local result = {}
    for _, entry in ipairs(self.LIST) do
        if entry.faction == nil or entry.faction == faction then
            local r = { entry = entry, id = entry.id, kind = entry.kind, clock = entry.clock, subtitle = entry.subtitle }
            if entry.id == "karazhan" then
                r.state = preview and "ready" or self:GetKarazhanState(entry)
                r.portalID = entry.portalSpell
                r.portalKnown = r.state == "ready"
                if r.state ~= "hidden" or (ns.db and ns.db.showUnavailableKarazhan) then
                    r.visible = true
                end
            else
                r.teleportID, r.teleportKnown = resolveCandidates(entry.teleport)
                r.portalID, r.portalKnown = resolveCandidates(entry.portal)
                if preview then
                    r.teleportKnown = r.teleportID ~= nil
                    r.portalKnown = r.portalID ~= nil
                end
                -- Shown whenever the spell exists; dimmed with "Learn at N"
                -- until learned (Dalaran included, user request 2026-10-05).
                r.visible = r.teleportID ~= nil or r.portalID ~= nil
            end
            r.name = self:GetName(r)
            if r.visible then
                result[#result + 1] = r
            end
        end
    end
    return result
end

-- "Teleport: Stormwind" -> "Stormwind", from whichever spell exists.
local DISPLAY_NAMES = { karazhan = "Karazhan", dalaran = "Dalaran" }
function Destinations:GetName(resolved)
    local spellID = resolved.teleportID or resolved.portalID
    local name = spellID and API.SpellName(spellID)
    if name then
        local stripped = name:match("^[^:]+:%s*(.+)$")
        if stripped then
            return stripped
        end
    end
    return DISPLAY_NAMES[resolved.id] or resolved.id
end

-- The city art shipped in Media\CityIcons, falling back to the spell icon.
local ICON_FILES = {
    stormwind = "Alliance\\Normal\\stormwind", ironforge = "Alliance\\Normal\\ironforge",
    darnassus = "Alliance\\Normal\\darnassus", orgrimmar = "Horde\\Normal\\orgrimmar",
    undercity = "Horde\\Normal\\undercity", thunder_bluff = "Horde\\Normal\\thunder_bluff",
    karazhan = "Alliance\\Normal\\karazhan",
}
function Destinations:GetIcon(resolved, hover)
    local file = ICON_FILES[resolved.id]
    if file then
        if hover then
            file = file:gsub("\\Normal\\", "\\Hover\\")
        end
        return ns.Media.CITY_ICON_ROOT .. file .. ".tga"
    end
    local spellID = resolved.teleportID or resolved.portalID
    return (spellID and API.SpellIcon(spellID)) or 134400
end

-- Every spell this addon casts, for CastTracker: spellID -> { name, mode }.
function Destinations:AllSpells()
    local map = {}
    for _, entry in ipairs(self.LIST) do
        for _, id in ipairs(entry.teleport or {}) do
            map[id] = { id = entry.id, mode = ns.Mode.TELEPORT }
        end
        for _, id in ipairs(entry.portal or {}) do
            map[id] = { id = entry.id, mode = ns.Mode.PORTAL }
        end
        if entry.portalSpell then
            map[entry.portalSpell] = { id = entry.id, mode = ns.Mode.PORTAL }
        end
    end
    return map
end
