local _, ns = ...

local Destinations = {}
ns.Destinations = Destinations

local HORDE = ns.Constants.FACTION_HORDE
local ALLIANCE = ns.Constants.FACTION_ALLIANCE

local factions = {
    [HORDE] = {
        {
            id = "orgrimmar",
            label = "Orgrimmar",
            teleportSpell = 3567,
            portalSpell = 11417,
            angleDeg = 90,
        },
        {
            id = "thunder_bluff",
            label = "Thunder Bluff",
            teleportSpell = 3566,
            portalSpell = 11420,
            angleDeg = 30,
        },
        {
            id = "stonard",
            label = "Stonard",
            teleportSpell = 49358,
            portalSpell = 49361,
            angleDeg = 330,
        },
        {
            id = "shattrath",
            label = "Shattrath",
            teleportSpell = 33690,
            portalSpell = 35717,
            angleDeg = 270,
        },
        {
            id = "silvermoon",
            label = "Silvermoon",
            teleportSpell = 32272,
            portalSpell = 32267,
            angleDeg = 210,
        },
        {
            id = "undercity",
            label = "Undercity",
            teleportSpell = 3563,
            portalSpell = 11418,
            angleDeg = 150,
        },
    },
    [ALLIANCE] = {
        {
            id = "stormwind",
            label = "Stormwind",
            teleportSpell = 3561,
            portalSpell = 10059,
            angleDeg = 90,
        },
        {
            id = "darnassus",
            label = "Darnassus",
            teleportSpell = 3565,
            portalSpell = 11419,
            angleDeg = 30,
        },
        {
            id = "theramore",
            label = "Theramore",
            teleportSpell = 49359,
            portalSpell = 49360,
            angleDeg = 330,
        },
        {
            id = "shattrath",
            label = "Shattrath",
            teleportSpell = 33690,
            portalSpell = 35715,
            angleDeg = 270,
        },
        {
            id = "exodar",
            label = "The Exodar",
            teleportSpell = 32271,
            portalSpell = 32266,
            angleDeg = 210,
        },
        {
            id = "ironforge",
            label = "Ironforge",
            teleportSpell = 3562,
            portalSpell = 11416,
            angleDeg = 150,
        },
    },
}

local karazhanNode = {
    id = "karazhan",
    label = "Karazhan",
    subtitle = "Atiesh only",
    angleDeg = 318,
    radius = 226,
    ringAttachRadius = 168,
}

local destinationIcons = {
    orgrimmar = ns.Media.ICON_CITY_ORGRIMMAR,
    undercity = ns.Media.ICON_CITY_UNDERCITY,
    thunder_bluff = ns.Media.ICON_CITY_THUNDER_BLUFF,
    silvermoon = ns.Media.ICON_CITY_SILVERMOON,
    stonard = ns.Media.ICON_CITY_STONARD,
    shattrath = ns.Media.ICON_CITY_SHATTRATH,
    stormwind = ns.Media.ICON_CITY_STORMWIND,
    ironforge = ns.Media.ICON_CITY_IRONFORGE,
    darnassus = ns.Media.ICON_CITY_DARNASSUS,
    exodar = ns.Media.ICON_CITY_THE_EXODAR,
    theramore = ns.Media.ICON_CITY_THERAMORE,
    karazhan = ns.Media.ICON_CITY_KARAZHAN,
}

local function getSpellName(spellID)
    if not spellID then
        return nil
    end
    local spellName = GetSpellInfo(spellID)
    return spellName
end

function Destinations:GetFactionDestinations(faction)
    return factions[faction] or factions[ALLIANCE]
end

function Destinations:GetPlayerDestinations()
    local faction = UnitFactionGroup("player")
    return self:GetFactionDestinations(faction)
end

function Destinations:GetKarazhanNode()
    return karazhanNode
end

function Destinations:GetSpellForMode(destination, mode)
    if mode == ns.Mode.PORTAL then
        return destination.portalSpell, getSpellName(destination.portalSpell)
    end
    return destination.teleportSpell, getSpellName(destination.teleportSpell)
end

function Destinations:GetIconForDestination(destination, mode)
    if not destination then
        return "Interface\\ICONS\\INV_Misc_QuestionMark", false
    end

    local customIcon = destination and destination.id and destinationIcons[destination.id]
    if customIcon then
        return customIcon, true
    end

    local spellID = destination.teleportSpell
    if mode == ns.Mode.PORTAL then
        spellID = destination.portalSpell
    end

    local icon = spellID and GetSpellTexture(spellID)
    return icon or "Interface\\ICONS\\INV_Misc_QuestionMark", false
end

local destinationFileNames = {
    orgrimmar = "orgrimmar",
    undercity = "undercity",
    thunder_bluff = "thunder_bluff",
    silvermoon = "silvermoon",
    stonard = "stonard",
    shattrath = "shattrath",
    stormwind = "stormwind",
    ironforge = "ironforge",
    darnassus = "darnassus",
    exodar = "the_exodar",
    theramore = "theramore",
    karazhan = "karazhan",
}

local function getVisualRootsForFaction(faction)
    if faction == HORDE then
        return {
            iconNormal = ns.Media.CITY_ICON_HORDE_NORMAL_ROOT,
            iconHover = ns.Media.CITY_ICON_HORDE_HOVER_ROOT,
            nameplateNormal = ns.Media.CITY_NAMEPLATE_HORDE_NORMAL_ROOT,
            nameplateHover = ns.Media.CITY_NAMEPLATE_HORDE_HOVER_ROOT,
        }
    end

    return {
        iconNormal = ns.Media.CITY_ICON_ALLIANCE_NORMAL_ROOT,
        iconHover = ns.Media.CITY_ICON_ALLIANCE_HOVER_ROOT,
        nameplateNormal = ns.Media.CITY_NAMEPLATE_ALLIANCE_NORMAL_ROOT,
        nameplateHover = ns.Media.CITY_NAMEPLATE_ALLIANCE_HOVER_ROOT,
    }
end

function Destinations:GetVisualsForDestination(destination, faction)
    if not destination or not destination.id then
        return nil
    end

    local roots = getVisualRootsForFaction(faction or UnitFactionGroup("player"))
    local cityFileName = destinationFileNames[destination.id]
    if not roots or not cityFileName then
        return nil
    end

    return {
        iconNormal = roots.iconNormal .. cityFileName .. ".tga",
        iconHover = roots.iconHover .. cityFileName .. ".tga",
        nameplateNormal = roots.nameplateNormal .. cityFileName .. ".tga",
        nameplateHover = roots.nameplateHover .. cityFileName .. ".tga",
    }
end
