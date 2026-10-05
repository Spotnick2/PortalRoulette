-- ============================================================
-- Reagents: Rune of Teleportation and Rune of Portals.
--
-- State is "required", "free" or "unknown":
--   * free:     the "Reagent Economy" perk is known (IsPlayerSpell on any of
--               its per-class spell IDs, docs/FOREVER-PROBE.md run 2), or
--               the option forces counts off.
--   * required: a resolved spell's tooltip has a "Reagents:" line.
--   * unknown:  nothing loaded yet. Counts stay visible; only a positive
--               "free" hides them.
-- Counts include the reagent bag (C_Item.GetItemCount counts carried bags;
-- the reagent-bag case is still OPEN in the probe doc).
-- ============================================================

local _, ns = ...

local API = ns.API
local C = ns.Constants

local Reagents = {}
ns.Reagents = Reagents

Reagents.ITEMS = {
    teleport = C.ITEM_RUNE_TELEPORTATION,
    portal = C.ITEM_RUNE_PORTALS,
}

function Reagents:HasPerk()
    for _, spellID in ipairs(C.REAGENT_ECONOMY_SPELLS) do
        if API.IsKnown(spellID) then
            return true
        end
    end
    return false
end

-- Does this spell's tooltip list a reagent? true / false / nil (not loaded).
function Reagents:TooltipNeedsReagent(spellID)
    local lines = API.SpellTooltipLines(spellID)
    if not lines or #lines < 2 then
        API.RequestSpellData(spellID)
        return nil
    end
    -- The reagent line reads "Reagents: |n|cffff2020Rune of Teleportation|r"
    -- (measured 70205). Match the client's localized rune names, not the
    -- English label.
    local names = {}
    for _, itemID in pairs(self.ITEMS) do
        local name = API.ItemName(itemID)
        if not name then
            API.RequestItemData(itemID)
            return nil
        end
        names[#names + 1] = name
    end
    for _, line in ipairs(lines) do
        for _, name in ipairs(names) do
            if line:find(name, 1, true) then
                return true
            end
        end
    end
    return false
end

-- The current state, given the resolved spell IDs on the wheel.
function Reagents:State(spellIDs)
    local mode = ns.db and ns.db.reagentDisplay or "auto"
    if mode == "hide" then
        return "free"
    elseif mode == "show" then
        return "required"
    end
    if self:HasPerk() then
        return "free"
    end
    for _, spellID in ipairs(spellIDs or {}) do
        if self:TooltipNeedsReagent(spellID) then
            return "required"
        end
    end
    return "unknown"
end

-- Raw counts (possibly secret in combat: for display only).
function Reagents:Counts()
    return API.ItemCountRaw(self.ITEMS.teleport), API.ItemCountRaw(self.ITEMS.portal)
end

-- True when the player has none of the rune `kind` needs. Unknown (secret)
-- counts never warn.
function Reagents:IsMissing(kind)
    local count = API.ItemCount(self.ITEMS[kind])
    return count ~= nil and count <= 0
end
