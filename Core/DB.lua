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
DB.DeepCopy = deepCopy

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

-- Bring a TBC-era save (schema 3 or older) to the Forever schema. Runs
-- before defaults are merged, so nothing the player set is lost.
local function migrate(saved)
    local version = tonumber(saved.version) or 0
    if version >= 5 then
        return
    end
    if version == 4 then
        -- The camera became default ON in schema 5.
        saved.cinematicCamera = true
        return
    end

    -- Minimap: the hand-rolled button stored {angle}; LibDBIcon wants
    -- {minimapPos, hide}.
    local minimap = type(saved.minimap) == "table" and saved.minimap or {}
    local angle = tonumber(minimap.minimapPos) or tonumber(minimap.angle)
    saved.minimap = {
        minimapPos = angle or 220,
        hide = saved.showMinimapButton == false,
    }

    -- The TBC utility modes no longer exist.
    if saved.utilityMode ~= "hearthstone" and saved.utilityMode ~= "random" then
        saved.utilityMode = "hearthstone"
    end

    -- The camera is on by default on Forever.
    saved.cinematicCamera = true

    -- Keys of removed features.
    for _, key in ipairs({ "debugAtiesh", "lastMode", "showOptionsButton", "showCloseButton",
        "showReagentPanel", "enableWheelAnimation", "openCloseAnimationsEnabled", "clickPulseEnabled",
        "nodeStaggerEnabled", "portalVortexIdleEnabled", "portalVortexMotesEnabled",
        "portalVortexEnabled", "portalVortexIntensity" }) do
        saved[key] = nil
    end
end
DB.Migrate = migrate

-- Called at PLAYER_LOGIN: SavedVariables load after the addon's files, so
-- PortalRouletteDB is not readable at file scope.
function DB:Initialize()
    local saved = PortalRouletteDB
    if type(saved) ~= "table" then
        saved = {}
    end

    migrate(saved)
    saved = mergeDefaults(ns.Constants.DEFAULTS, saved)
    saved.version = ns.Constants.VERSION
    -- A sentinel that proves saved data survives a full client restart.
    saved.loadCount = (tonumber(saved.loadCount) or 0) + 1

    PortalRouletteDB = saved
    self.data = saved
    ns.db = saved
    return saved
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
    local hide = self.data.minimap and self.data.minimap.hide
    self.data.minimap = deepCopy(ns.Constants.DEFAULTS.minimap)
    self.data.minimap.hide = hide or false
end
