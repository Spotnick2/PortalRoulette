-- ============================================================
-- GlassUI: Portal Roulette as a member of the Glass UI suite
-- (GlassUI/docs/SUITE.md, "The contract"; roster entry GlassUI#107).
--
-- Everything here exists only when Glass UI is loaded and speaks
-- Suite.API 1. Without it, Present() is false, nothing is asked or
-- reported, and the addon keeps its own look exactly as before.
--
--   * One decision per session, at PLAYER_LOGIN, before any glass is
--     built (Skin builds lazily). Every class asks, so a non-mage reads
--     "following" on Glass UI's page, not "not yet integrated".
--   * Following means LibGlass's Pearl preset (r11+) with our own disc
--     tuning and rim art suspended (Skin:OwnLook()).
--   * Not live: the wheel is built once, so a change waits for /reload.
--     We take Pearl's material only (no Suite.Body tint), so no `look`
--     is reported and Glass UI never asks for a reload over a look key.
-- ============================================================

local _, ns = ...

local GlassUI = {}
ns.GlassUI = GlassUI

local ADDON = "PortalRoulette"
GlassUI.PEARL_MINOR = 11 -- LibGlass revision that knows preset = "pearl"

-- Glass UI's Suite table when it is loaded and speaks API 1 exactly,
-- else nil (the released Glass UI had no Suite at all).
function GlassUI:Suite()
    local G = rawget(_G, "GlassUI")
    if type(G) ~= "table" then return nil end
    local suite = rawget(G, "Suite")
    if type(suite) ~= "table" or rawget(suite, "API") ~= 1 then return nil end
    if type(rawget(suite, "Theme")) ~= "function" or type(rawget(suite, "Report")) ~= "function" then
        return nil
    end
    return suite
end

function GlassUI:Present()
    return self:Suite() ~= nil
end

-- The preset Glass UI asked for ("pearl"), or nil for our own look.
function GlassUI:Preset()
    return self.preset
end

-- Ask once. Safe to call again: the first answer stands for the session.
function GlassUI:Decide()
    if self.decided then return self.preset end
    self.decided = true
    local suite = self:Suite()
    if not suite then return nil end
    local ok, theme, reason = pcall(suite.Theme, ADDON)
    if ok and type(theme) == "table" and theme.preset == "pearl" then
        self.preset = "pearl"
    else
        self.reason = ok and reason or "theme-error"
    end
    -- Report what we will build. Skin:Glass() reports again if the lazy
    -- build turns out differently (old library, New erroring).
    self:Report(self.preset, nil, nil)
    return self.preset
end

-- What we built (or will build): preset or nil, why not, LibGlass MINOR.
function GlassUI:Report(built, reason, minor)
    local suite = self:Suite()
    if not suite then return end
    local state = {
        api = 1,
        built = built,
        reason = reason,
        minor = minor,
        live = false,
        -- We paint no opaque backing under the glass: the wheel floats
        -- over the world.
        own = { backing = true },
    }
    if ns.isMage and ns.Options and ns.Options.Open then
        state.options = function() ns.Options:Open() end
    end
    self.reported = { built = built, reason = reason, minor = minor }
    pcall(suite.Report, ADDON, state)
end

-- Called by Skin after its one build attempt. The first report (from
-- Decide) has no MINOR yet, so a successful build still reports once more:
-- the suite records the winning LibGlass revision at the build attempt.
function GlassUI:Built(built, reason, minor)
    if not self.preset then return end
    local last = self.reported
    if last and last.built == built and last.reason == reason and last.minor == minor then return end
    self:Report(built, reason, minor)
end

-- One line for the options page and /pr debug.
function GlassUI:StatusText()
    if not self:Present() then return nil end
    if self.preset then
        local last = self.reported
        if last and last.built ~= "pearl" and last.reason then
            return "Look: own look (" .. last.reason .. ")"
        end
        return "Look: following Glass UI (Pearl), set in Glass UI"
    end
    return "Look: own look (not following Glass UI)"
end

-- Glass UI's settings page, when its Suite offers Open (additive in API 1).
function GlassUI:CanOpen()
    local suite = self:Suite()
    return suite ~= nil and type(rawget(suite, "Open")) == "function"
end

function GlassUI:Open()
    local suite = self:Suite()
    if suite and type(rawget(suite, "Open")) == "function" then
        pcall(suite.Open)
    end
end
