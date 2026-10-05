-- ============================================================
-- Hearth: what the center orb uses.
--
-- Order: the Hearthstone (PlayerHasHearthstone() is only a hint: measured
-- nil on 70205 with one in the backpack, so item 6948 is counted
-- directly), then Crumbling Hearthstone (single use), then owned hearth
-- toys. "Random" picks once per wheel open, not on every refresh.
-- ============================================================

local _, ns = ...

local API = ns.API
local C = ns.Constants

local Hearth = {}
ns.Hearth = Hearth

local function itemSource(itemID)
    return {
        kind = "item",
        id = itemID,
        icon = API.ItemIcon(itemID),
        name = API.ItemName(itemID),
        -- Measured on 70205: a secure macro "/use item:ID" casts once per click.
        action = { type = "macro", macrotext = "/use item:" .. itemID },
    }
end

local function toySource(itemID)
    return {
        kind = "toy",
        id = itemID,
        icon = API.ItemIcon(itemID),
        name = API.ItemName(itemID),
        action = { type = "toy", toy = itemID },
    }
end

-- Every hearth source the player has, in preference order.
function Hearth:Available()
    local list = {}
    local hinted = API.HearthstoneItemID()
    local hearthCount = API.ItemCount(C.ITEM_HEARTHSTONE)
    if hinted then
        list[#list + 1] = itemSource(hinted)
    elseif hearthCount and hearthCount > 0 then
        list[#list + 1] = itemSource(C.ITEM_HEARTHSTONE)
    end
    local crumbling = API.ItemCount(C.ITEM_CRUMBLING_HEARTHSTONE)
    if crumbling and crumbling > 0 then
        list[#list + 1] = itemSource(C.ITEM_CRUMBLING_HEARTHSTONE)
    end
    for _, toyID in ipairs(C.HEARTH_TOYS) do
        if API.HasToy(toyID) then
            list[#list + 1] = toySource(toyID)
        end
    end
    return list
end

-- Call once per wheel open: settles which source Random uses.
function Hearth:Roll()
    self.rolled = nil
    local list = self:Available()
    if #list > 1 and ns.db and ns.db.utilityMode == ns.UtilityMode.RANDOM then
        self.rolled = list[math.random(#list)].id
    end
end

-- The source to use now, or nil when the player has none.
function Hearth:Current()
    local list = self:Available()
    if #list == 0 then
        return nil
    end
    if self.rolled then
        for _, source in ipairs(list) do
            if source.id == self.rolled then
                return source
            end
        end
    end
    return list[1]
end

function Hearth:BindLocation()
    return API.BindLocation()
end
