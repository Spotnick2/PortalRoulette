-- ============================================================
-- Presentation: hiding the game UI and the optional cinematic camera,
-- through LibShowcase-1.0 (extracted from AltStable, where it is measured).
-- Without the library the wheel still works: no UI hide, no camera.
--
-- LibShowcase holds one owner at a time and claims it on the first call
-- (HideGameUI / Lift / Enter); it gives it back once nothing is left to
-- restore. The wheel root parents secure buttons, so it is protected: the
-- library lifts it out of UIParent out of combat and, if combat interrupts,
-- keeps the record and puts it back at PLAYER_REGEN_ENABLED.
--
-- State: uiHidden (the library hid the game UI for us), camera (the camera
-- presentation runs), pendingHide (the player wants the UI hidden but it is
-- up for a dialog or prompt: hide it again once that clears).
-- ============================================================

local _, ns = ...

local Presentation = {}
ns.Presentation = Presentation

local NEEDS_MINOR = 3 -- r3, the first release: onGameUIShown, dialog-aware HideGameUI

function Presentation:Lib()
    if self.lib ~= nil then
        return self.lib or nil
    end
    self.lib = false
    local stub = _G.LibStub
    local lib, minor
    if stub then
        -- Not `stub and stub:GetLibrary(...)`: `and` keeps only one value.
        lib, minor = stub:GetLibrary("LibShowcase-1.0", true)
    end
    if lib and minor and minor >= NEEDS_MINOR and lib.ready == minor then
        local ok, sc = pcall(lib.New, lib, {
            owner = "PortalRoulette",
            -- A function: PortalRouletteDB is replaced at login.
            db = function() return ns.db and ns.db.showcase end,
            hideUI = false, -- the UI hide is driven separately below
            anchorStrata = "HIGH",
            onForcedExit = function(reason)
                if ns.Roulette then ns.Roulette:OnForcedExit(reason) end
            end,
            debug = function(msg)
                if ns.Roulette then ns.Roulette:Trace("LibShowcase: " .. tostring(msg)) end
            end,
            -- The library brought the game UI back by itself (a dialog or a
            -- prompt such as a ready check): the wheel stays open, and the
            -- UI is hidden again once the prompt clears. State first, so a
            -- failing diagnostic can never leave it stale.
            onGameUIShown = function(reason)
                Presentation.uiHidden = false
                Presentation.pendingHide = true
                if ns.Roulette then
                    ns.Roulette:OnGameUIShown()
                    ns.Roulette:Trace("game UI shown: " .. tostring(reason))
                end
            end,
        })
        if ok and sc then
            self.lib = sc
        end
    end
    if not self.lib and lib and not self.warned then
        -- A copy is loaded but too old or did not finish loading: say so
        -- instead of silently running without the camera and the UI hide.
        self.warned = true
        if ns.Print then
            ns.Print("|cffff6060LibShowcase-1.0 r" .. NEEDS_MINOR .. "+ not available (found MINOR "
                .. tostring(minor) .. "): no cinematic camera or UI hide.|r")
        end
    end
    return self.lib or nil
end

function Presentation:IsActive()
    return self.uiHidden == true or self.camera == true
end

function Presentation:IsGameUIHidden()
    return self.uiHidden == true
end

-- Hide the game UI through the library. False when it refuses (a dialog or
-- prompt is up, or another addon holds the lease).
local function hide(self, sc, root)
    local ok = sc:HideGameUI(root)
    self.uiHidden = ok and true or false
    return self.uiHidden
end

-- Out of combat only (the caller checks).
function Presentation:Enter(root)
    local sc = self:Lib()
    local db = ns.db
    self.pendingHide = false
    if not sc or not db then
        return false
    end
    -- Camera first: entering while the previous exit is still easing back
    -- restarts the presentation, which restores the UI. Hiding the UI after
    -- that keeps it hidden.
    if db.cinematicCamera then
        sc.opts.orbit = db.cameraOrbit ~= false
        sc.opts.castAware = db.cameraCastAware ~= false
        self.camera = sc:Enter(root) and true or false
    end
    if db.hideGameUI ~= false and not hide(self, sc, root) then
        -- Refused, usually because a dialog or prompt is up: try again once
        -- it clears (RetryHide, polled while the wheel is open).
        self.pendingHide = true
    end
    return self:IsActive()
end

-- Polled about once a second while the wheel is open: hide the UI again
-- once the dialog or prompt that kept it up has cleared.
function Presentation:RetryHide(root)
    if not self.pendingHide or self.uiHidden or InCombatLockdown() then
        return false
    end
    local sc = self:Lib()
    if not sc or not ns.db or ns.db.hideGameUI == false then
        self.pendingHide = false
        return false
    end
    if hide(self, sc, root) then
        self.pendingHide = false
        return true
    end
    return false
end

-- Bring the game UI back on the player's behalf (typing in chat) while the
-- wheel stays open and the camera keeps going. Not re-hidden afterwards.
function Presentation:ShowGameUI()
    local sc = self:Lib()
    self.pendingHide = false
    if not sc or not self.uiHidden then
        return
    end
    self.uiHidden = false
    sc:RestoreGameUI()
    if ns.Roulette then ns.Roulette:OnGameUIShown() end
end

-- The library already restored everything itself (a forced exit: Escape or
-- Alt+Z while hidden, combat, logout): forget our state to match.
function Presentation:MarkClosed()
    self.uiHidden, self.camera, self.pendingHide = false, false, false
end

-- A normal close: the camera eases back (the library restores the UI and
-- finishes later); without a camera, the UI comes back now.
function Presentation:Exit(reason)
    local sc = self:Lib()
    local wasActive, camera = self:IsActive(), self.camera
    self:MarkClosed()
    if not sc or not wasActive then
        return
    end
    if camera and sc:IsActive() then
        sc:Exit(reason or "close")
    else
        sc:RestoreGameUI()
    end
end

-- Immediate restore (combat entry, logout): no animation. Protected frames
-- the library cannot reparent under lockdown go back at combat end.
function Presentation:ForceExit(reason)
    local sc = self:Lib()
    local wasActive = self:IsActive()
    self:MarkClosed()
    if sc and wasActive then
        sc:ForceRestore(reason or "forced")
    end
end
