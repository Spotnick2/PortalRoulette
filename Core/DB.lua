local _, ns = ...

local DB = {}
ns.DB = DB

local function deepCopy(value)
    if type(value) ~= "table" then
        return value
    end

    local copy = {}
    for key, nestedValue in pairs(value) do
        copy[key] = deepCopy(nestedValue)
    end
    return copy
end

local function mergeDefaults(defaults, current)
    local result = deepCopy(defaults)
    if type(current) ~= "table" then
        return result
    end

    for key, value in pairs(current) do
        if type(value) == "table" and type(result[key]) == "table" then
            result[key] = mergeDefaults(result[key], value)
        else
            result[key] = value
        end
    end
    return result
end

function DB:Initialize()
    if type(PortalRouletteDB) ~= "table" then
        PortalRouletteDB = {}
    end

    -- Reset saved frame positions when the DB version increments so users
    -- automatically get the corrected default layout.
    local savedVersion = tonumber(PortalRouletteDB.version) or 0
    if savedVersion < ns.Constants.VERSION then
        PortalRouletteDB.roulette = nil
        PortalRouletteDB.launcher = nil
        PortalRouletteDB.minimap  = nil
    end

    local defaults = ns.Constants.DEFAULTS
    PortalRouletteDB = mergeDefaults(defaults, PortalRouletteDB)
    PortalRouletteDB.version = ns.Constants.VERSION

    self.data = PortalRouletteDB
    ns.db = self.data
    return self.data
end

function DB:GetData()
    return self.data
end

function DB:Get(key)
    if not self.data then
        return nil
    end
    return self.data[key]
end

function DB:Set(key, value)
    if not self.data then
        return
    end
    self.data[key] = value
end

function DB:ResetPositions()
    if not self.data then
        return
    end

    self.data.launcher = deepCopy(ns.Constants.DEFAULTS.launcher)
    self.data.roulette = deepCopy(ns.Constants.DEFAULTS.roulette)
    self.data.minimap = deepCopy(ns.Constants.DEFAULTS.minimap)
end
