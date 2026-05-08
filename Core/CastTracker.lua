local _, ns = ...

local CastTracker = {
    activeCast = nil,
    spellDestinations = {},
}
ns.CastTracker = CastTracker

local function normalizeSpellName(name)
    if not name or name == "" then
        return nil
    end
    return string.lower(name)
end

local function getBroadcastChannel()
    if IsInGroup and not IsInGroup() then
        return nil
    end
    if IsInGroup and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        return "INSTANCE_CHAT"
    end
    if IsInRaid and IsInRaid() then
        return "RAID"
    end
    if IsInGroup and IsInGroup() then
        return "PARTY"
    end
    return nil
end

local function addSpell(spellID, destination, mode)
    if not spellID or not destination then
        return
    end
    local spellName = GetSpellInfo(spellID)
    local key = normalizeSpellName(spellName)
    if not key then
        return
    end
    CastTracker.spellDestinations[key] = {
        destination = destination.label,
        mode = mode,
        spellName = spellName,
    }
end

function CastTracker:RefreshSpellMap()
    self.spellDestinations = {}
    for _, faction in ipairs({ ns.Constants.FACTION_HORDE, ns.Constants.FACTION_ALLIANCE }) do
        for _, destination in ipairs(ns.Destinations:GetFactionDestinations(faction)) do
            addSpell(destination.teleportSpell, destination, ns.Mode.TELEPORT)
            addSpell(destination.portalSpell, destination, ns.Mode.PORTAL)
        end
    end
    self.spellDestinations[normalizeSpellName(GetItemInfo(ns.Constants.ITEM_ATIESH) or "Atiesh, Greatstaff of the Guardian") or ""] = {
        destination = "Karazhan",
        mode = ns.Mode.PORTAL,
        spellName = "Atiesh",
    }
end

function CastTracker:GetInfoForSpell(spellName)
    local key = normalizeSpellName(spellName)
    return key and self.spellDestinations[key] or nil
end

function CastTracker:MaybeBroadcast(info, timing)
    if not info or not ns.db then
        return
    end
    if timing == "start" and not ns.db.broadcastOnStart then
        return
    end
    if timing == "success" and not ns.db.broadcastOnSuccess then
        return
    end
    if info.mode == ns.Mode.PORTAL and not ns.db.broadcastPortals then
        return
    end
    if info.mode == ns.Mode.TELEPORT and not ns.db.broadcastTeleports then
        return
    end
    local channel = getBroadcastChannel()
    if not channel then
        return
    end
    local message
    if info.mode == ns.Mode.PORTAL then
        message = "Opening a portal to " .. info.destination .. "."
    else
        message = "Teleporting to " .. info.destination .. "."
    end
    SendChatMessage(message, channel)
end

function CastTracker:StartCast(spellName)
    local info = self:GetInfoForSpell(spellName)
    if not info then
        return
    end
    local name, _, _, startMS, endMS = UnitCastingInfo("player")
    if not name and UnitChannelInfo then
        name, _, _, startMS, endMS = UnitChannelInfo("player")
    end
    self.activeCast = {
        spellName = spellName,
        info = info,
    }
    if ns.RouletteFrame and ns.RouletteFrame.ShowCastBar then
        ns.RouletteFrame:ShowCastBar(info, startMS, endMS)
    end
    self:MaybeBroadcast(info, "start")
end

function CastTracker:FinishCast(spellName, succeeded)
    local info = (self.activeCast and self.activeCast.info) or self:GetInfoForSpell(spellName)
    if succeeded then
        self:MaybeBroadcast(info, "success")
    end
    self.activeCast = nil
    if ns.RouletteFrame and ns.RouletteFrame.HideCastBar then
        ns.RouletteFrame:HideCastBar()
    end
end

function CastTracker:Initialize()
    self:RefreshSpellMap()
    ns.Events:Register("SPELLS_CHANGED", function()
        CastTracker:RefreshSpellMap()
    end)
    ns.Events:Register("UNIT_SPELLCAST_START", function(_, unit, _, spellID)
        if unit ~= "player" then return end
        local spellName = spellID and GetSpellInfo(spellID) or UnitCastingInfo("player")
        CastTracker:StartCast(spellName)
    end)
    ns.Events:Register("UNIT_SPELLCAST_CHANNEL_START", function(_, unit, _, spellID)
        if unit ~= "player" then return end
        local spellName = spellID and GetSpellInfo(spellID) or (UnitChannelInfo and UnitChannelInfo("player"))
        CastTracker:StartCast(spellName)
    end)
    ns.Events:Register("UNIT_SPELLCAST_SUCCEEDED", function(_, unit, _, spellID)
        if unit ~= "player" then return end
        CastTracker:FinishCast(spellID and GetSpellInfo(spellID), true)
    end)
    for _, eventName in ipairs({ "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_CHANNEL_STOP" }) do
        ns.Events:Register(eventName, function(_, unit)
            if unit == "player" then
                CastTracker:FinishCast(nil, false)
            end
        end)
    end
end
