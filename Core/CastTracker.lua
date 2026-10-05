-- ============================================================
-- CastTracker: follows the player's travel casts by spell ID (the
-- UNIT_SPELLCAST_* payload carries castGUID and spellID on Forever), drives
-- the wheel's casting state and the optional group broadcast.
-- ============================================================

local _, ns = ...

local API = ns.API

local CastTracker = {
    activeCast = nil,
    spells = {},
}
ns.CastTracker = CastTracker

local function getBroadcastChannel()
    if not IsInGroup() then
        return nil
    end
    if LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        return "INSTANCE_CHAT"
    end
    if IsInRaid() then
        return "RAID"
    end
    return "PARTY"
end

function CastTracker:RefreshSpellMap()
    self.spells = ns.Destinations:AllSpells()
    self.spells[ns.Constants.SPELL_HEARTHSTONE] = { id = "hearth", mode = "utility" }
end

-- A plain spell ID from an event payload, or nil (secret or missing).
local function spellIDFrom(value)
    return API.Number(value)
end

function CastTracker:GetInfo(spellID)
    spellID = spellIDFrom(spellID)
    local info = spellID and self.spells[spellID]
    if not info then
        return nil
    end
    local name = API.SpellName(spellID) or ""
    return {
        spellID = spellID,
        id = info.id,
        mode = info.mode,
        destination = info.mode == "utility" and (API.BindLocation() or "") or (name:match("^[^:]+:%s*(.+)$") or name),
    }
end

function CastTracker:MaybeBroadcast(info, timing)
    local db = ns.db
    if not info or not db then
        return
    end
    if info.mode == "utility" then
        return
    end
    if timing == "start" and not db.broadcastOnStart then
        return
    end
    if timing == "success" and not db.broadcastOnSuccess then
        return
    end
    if info.mode == ns.Mode.PORTAL and not db.broadcastPortals then
        return
    end
    if info.mode == ns.Mode.TELEPORT and not db.broadcastTeleports then
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

function CastTracker:StartCast(castGUID, spellID)
    local info = self:GetInfo(spellID)
    if not info then
        return
    end
    if self.activeCast and self.activeCast.castGUID == castGUID then
        return -- SENT then START for the same cast
    end
    self.activeCast = { castGUID = castGUID, info = info }
    if ns.Roulette and ns.Roulette.OnCastStart then
        ns.Roulette:OnCastStart(info)
    end
    self:MaybeBroadcast(info, "start")
end

function CastTracker:FinishCast(castGUID, succeeded)
    local active = self.activeCast
    if not active then
        return
    end
    if castGUID and active.castGUID and castGUID ~= active.castGUID then
        return
    end
    self.activeCast = nil
    if succeeded then
        self:MaybeBroadcast(active.info, "success")
    end
    if ns.Roulette and ns.Roulette.OnCastEnd then
        ns.Roulette:OnCastEnd(active.info, succeeded)
    end
end

-- castGUID may be secret: compare it only when readable.
local function guid(value)
    if API.Readable(value) then
        return value
    end
    return nil
end

function CastTracker:Initialize()
    self:RefreshSpellMap()
    local Events = ns.Events
    Events:Register("SPELLS_CHANGED", function()
        CastTracker:RefreshSpellMap()
    end)
    Events:Register("UNIT_SPELLCAST_SENT", function(_, unit, _, castGUID, spellID)
        if unit == "player" then
            CastTracker:StartCast(guid(castGUID), spellID)
        end
    end)
    Events:Register("UNIT_SPELLCAST_START", function(_, unit, castGUID, spellID)
        if unit == "player" then
            CastTracker:StartCast(guid(castGUID), spellID)
        end
    end)
    Events:Register("UNIT_SPELLCAST_SUCCEEDED", function(_, unit, castGUID)
        if unit == "player" then
            CastTracker:FinishCast(guid(castGUID), true)
        end
    end)
    for _, eventName in ipairs({ "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED" }) do
        Events:Register(eventName, function(_, unit, castGUID)
            if unit == "player" then
                CastTracker:FinishCast(guid(castGUID), false)
            end
        end)
    end
end
