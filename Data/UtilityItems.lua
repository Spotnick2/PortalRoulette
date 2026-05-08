local _, ns = ...

local UtilityItems = {}
ns.UtilityItems = UtilityItems

local C_Container = C_Container

local utilityDefinitions = {
    [ns.UtilityMode.HEARTHSTONE] = {
        key = ns.UtilityMode.HEARTHSTONE,
        label = "Hearthstone",
        itemID = ns.Constants.ITEM_HEARTHSTONE,
        customIcon = ns.Media.ICON_HEARTHSTONE_CUSTOM,
    },
    [ns.UtilityMode.DARK_PORTAL] = {
        key = ns.UtilityMode.DARK_PORTAL,
        label = "Dark Portal",
        itemName = ns.Constants.DARK_PORTAL_NAME,
    },
    [ns.UtilityMode.NAARU_EMBRACE] = {
        key = ns.UtilityMode.NAARU_EMBRACE,
        label = "Naaru's Embrace",
        itemName = ns.Constants.NAARU_EMBRACE_NAME,
    },
}

local utilityOrder = {
    ns.UtilityMode.HEARTHSTONE,
    ns.UtilityMode.DARK_PORTAL,
    ns.UtilityMode.NAARU_EMBRACE,
    ns.UtilityMode.RANDOM,
}

local function getItemLinkItemID(itemLink)
    if not itemLink then
        return nil
    end
    local itemID = tonumber(itemLink:match("item:(%d+)"))
    return itemID
end

local function getBagSlotCount(bagIndex)
    if C_Container and C_Container.GetContainerNumSlots then
        return C_Container.GetContainerNumSlots(bagIndex) or 0
    end
    return GetContainerNumSlots(bagIndex) or 0
end

local function getBagItemLink(bagIndex, slotIndex)
    if C_Container and C_Container.GetContainerItemLink then
        return C_Container.GetContainerItemLink(bagIndex, slotIndex)
    end
    return GetContainerItemLink(bagIndex, slotIndex)
end

local function getSpellSourceByName(name)
    if not name or name == "" then
        return nil
    end

    local spellName, _, icon, _, _, _, spellID = GetSpellInfo(name)
    if not spellName then
        return nil
    end

    local known = false
    if spellID and IsSpellKnown then
        known = IsSpellKnown(spellID)
    end
    if not known and IsPlayerSpell and spellID then
        known = IsPlayerSpell(spellID)
    end
    if not known and IsUsableSpell then
        known = IsUsableSpell(spellName) and true or false
    end

    return {
        spellName = spellName,
        available = known,
        icon = icon or GetSpellTexture(spellName),
        macro = "/cast " .. spellName,
    }
end

function UtilityItems:GetModeOrder()
    return utilityOrder
end

function UtilityItems:NormalizeMode(mode)
    if mode == ns.UtilityMode.HEARTHSTONE
        or mode == ns.UtilityMode.DARK_PORTAL
        or mode == ns.UtilityMode.NAARU_EMBRACE
        or mode == ns.UtilityMode.RANDOM then
        return mode
    end
    return ns.UtilityMode.HEARTHSTONE
end

function UtilityItems:FindItemInBagsByName(itemName)
    if not itemName or itemName == "" then
        return nil
    end

    for bag = 0, 4 do
        local slots = getBagSlotCount(bag)
        for slot = 1, slots do
            local link = getBagItemLink(bag, slot)
            if link then
                local linkName = GetItemInfo(link)
                if linkName == itemName then
                    local itemID = getItemLinkItemID(link)
                    return itemID
                end
            end
        end
    end
    return nil
end

function UtilityItems:HasItem(itemID)
    if not itemID then
        return false
    end
    if itemID == ns.Constants.ITEM_ATIESH and ns.db then
        if ns.db.debugAtiesh == "on" then
            return true
        elseif ns.db.debugAtiesh == "off" then
            return false
        end
    end
    local count = GetItemCount(itemID, false, false) or 0
    if count > 0 then
        return true
    end
    if IsEquippedItem and IsEquippedItem(itemID) then
        return true
    end
    return false
end

function UtilityItems:ResolveNameBasedItemOrSpell(source, definition)
    source.itemName = definition.itemName
    local foundItemID = self:FindItemInBagsByName(definition.itemName)
    if foundItemID then
        source.itemID = foundItemID
        source.available = true
        source.icon = GetItemIcon(foundItemID)
        source.actionType = "item"
        source.actionValue = "item:" .. foundItemID
        source.macro = "/use item:" .. foundItemID
        return
    end

    local spellSource = getSpellSourceByName(definition.itemName)
    if spellSource then
        source.spellName = spellSource.spellName
        source.available = spellSource.available
        source.icon = spellSource.icon or "Interface\\ICONS\\INV_Misc_QuestionMark"
        source.actionType = "macro"
        source.actionValue = spellSource.macro
        source.macro = spellSource.macro
        return
    end

    source.available = false
    source.icon = "Interface\\ICONS\\INV_Misc_QuestionMark"
    source.actionType = "macro"
    source.actionValue = "/use " .. definition.itemName
    source.macro = "/use " .. definition.itemName
end

function UtilityItems:ResolveSource(mode)
    local definition = utilityDefinitions[mode]
    if not definition then
        return nil
    end

    local source = {
        key = definition.key,
        label = definition.label,
        available = false,
    }

    if definition.itemID then
        source.itemID = definition.itemID
        source.available = self:HasItem(definition.itemID)
        source.icon = definition.customIcon or GetItemIcon(definition.itemID)
        source.actionType = "item"
        source.actionValue = "item:" .. definition.itemID
        source.macro = "/use item:" .. definition.itemID
    else
        self:ResolveNameBasedItemOrSpell(source, definition)
    end

    return source
end

function UtilityItems:GetAvailableConcreteSources()
    local available = {}
    for _, mode in ipairs({ ns.UtilityMode.HEARTHSTONE, ns.UtilityMode.DARK_PORTAL, ns.UtilityMode.NAARU_EMBRACE }) do
        local source = self:ResolveSource(mode)
        if source and source.available then
            available[#available + 1] = source
        end
    end
    return available
end

function UtilityItems:GetSourceForMode(mode)
    mode = self:NormalizeMode(mode)
    if mode == ns.UtilityMode.RANDOM then
        local available = self:GetAvailableConcreteSources()
        if #available == 0 then
            local fallback = self:ResolveSource(ns.UtilityMode.HEARTHSTONE)
            fallback.label = "Random"
            return fallback
        end
        local index = math.random(1, #available)
        local chosen = available[index]
        chosen = {
            key = chosen.key,
            label = "Random: " .. chosen.label,
            available = chosen.available,
            itemID = chosen.itemID,
            itemName = chosen.itemName,
            spellName = chosen.spellName,
            icon = chosen.icon,
            actionType = chosen.actionType,
            actionValue = chosen.actionValue,
            macro = chosen.macro,
        }
        return chosen
    end

    return self:ResolveSource(mode)
end
