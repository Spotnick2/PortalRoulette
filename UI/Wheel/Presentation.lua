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
            -- The library brought the game UI back by itself (a dialog such
            -- as a guild invite appeared): the wheel stays open.
            onGameUIShown = function()
                Presentation.uiHidden = false
                Presentation.active = Presentation.camera
            end,
        })
        if ok and sc then
            self.lib = sc
        end
    end
    return self.lib or nil
end

-- Out of combat only (the caller checks).
function Presentation:Enter(root)
    local sc = self:Lib()
    local db = ns.db
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
    if db.hideGameUI ~= false then
        local ok = sc:HideGameUI(root)
        self.uiHidden = ok and true or false
    end
    self.active = self.uiHidden or self.camera
    return self.active
end

-- Bring the game UI back while the wheel stays open (and the camera keeps
-- going): typing in chat needs the chat frames.
function Presentation:ShowGameUI()
    local sc = self:Lib()
    if not sc or not self.uiHidden then
        return
    end
    self.uiHidden = false
    sc:RestoreGameUI()
    self.active = self.camera
end

function Presentation:IsGameUIHidden()
    return self.uiHidden == true
end

-- Any other frame that must stay visible over the hidden UI (dropped again
-- on restore).
function Presentation:LiftFrame(frame)
    local sc = self:Lib()
    if sc and self.active and frame then
        sc:Lift(frame, "FULLSCREEN_DIALOG")
    end
end


-- A normal close: the camera eases back (the library restores the UI and
-- finishes later); without a camera, the UI comes back now.
function Presentation:Exit(reason)
    local sc = self:Lib()
    if not sc or not self.active then
        return
    end
    self.active = false
    if self.camera and sc:IsActive() then
        sc:Exit(reason or "close")
    else
        sc:RestoreGameUI()
    end
    self.camera, self.uiHidden = false, false
end

-- Immediate restore (combat entry, logout): no animation. Protected frames
-- the library cannot reparent under lockdown go back at combat end.
function Presentation:ForceExit(reason)
    local sc = self:Lib()
    if not sc or not self.active then
        return
    end
    self.active = false
    self.camera, self.uiHidden = false, false
    sc:ForceRestore(reason or "forced")
end
