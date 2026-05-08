local _, ns = ...

-- Narcissus-style camera presentation, ported from Narcissus Classic and AltTracker.
--
-- Character framing:  POSITIVE test_cameraOverShoulder shifts character LEFT on screen
--                     (camera goes right of player), which is what we want since the
--                     wheel sits on the right side of the screen.
-- Mounted detection:  separate zoom + shoulder values so a mounted character is fully
--                     visible with the mount, matching Narcissus Classic behaviour.
-- CVar popup:         EXPERIMENTAL_CVAR_CONFIRMATION_NEEDED is suppressed at file load
--                     (same approach as Narcissus).

local CameraMode = {
    active  = false,
    mode    = nil,
    capture = nil,
    elapsed = 0,
}
ns.CameraMode = CameraMode

local function clamp(v, lo, hi, fallback)
    v = tonumber(v)
    if not v then return fallback end
    return math.max(lo, math.min(hi, v))
end

local function inOutSine(t, b, e, d)
    return -(e - b) / 2 * (math.cos(math.pi * t / d) - 1) + b
end

-- ── Race-specific shoulder factors for UNMOUNTED framing ────────────────────
-- Mirrors Narcissus Classic ZoomValuebyRaceID (shoulder columns only).
-- offset = ZOOM_REF × f[1] + f[2]
local SHOULDER_FACTORS = {
    [0]  = { 0.361,  -0.1654 },  -- default / fallback
    [1]  = { 0.3283, -0.02   },  -- Human
    [2]  = { 0.2667, -0.1233 },  -- Orc
    [3]  = { 0.2667, -0.0267 },  -- Dwarf
    [4]  = { 0.30,   -0.0404 },  -- Night Elf
    [5]  = { 0.3537, -0.15   },  -- Undead
    [6]  = { 0.2027, -0.18   },  -- Tauren
    [7]  = { 0.329,   0.0517 },  -- Gnome
    [8]  = { 0.2787,  0.04   },  -- Troll
    [10] = { 0.361,  -0.1654 },  -- Blood Elf
    [11] = { 0.248,  -0.02   },  -- Draenei
}

-- Narcissus mounted shoulder factors: much larger offset to show full mount.
local MOUNTED_SHOULDER_F1 = 1.2495
local MOUNTED_SHOULDER_F2 = -4.0

-- Narcissus uses the ACTUAL zoom as the reference in the shoulder formula:
--   offset = currentZoom * factor1 + factor2
-- For unmounted Human at zoom 2.1: offset = 2.1*0.3283 + (-0.02) = 0.669 → small left bias.
-- We use the same convention.
local UNMOUNTED_ZOOM         = 2.1   -- Narcissus default for human-baseline
local MOUNTED_ZOOM           = 8.0   -- Narcissus default for mounted
-- Fast-forward: the entry yaw integrates to ~180° of rotation regardless of duration
-- (it's a function of YAW_DEGREES and the inOutSine averaging). At 0.5s the rotation
-- happens as a brief burst rather than a slow visible swing — the camera "starts" at
-- the facing position and the slow orbit continues from there indefinitely.
local ENTER_DURATION         = 0.50
local EXIT_DURATION          = 0.35
local ORBIT_SPEED            = 0.005
-- Ping-pong orbit: hold one direction for ORBIT_HALF_PERIOD, then reverse.
-- At 0.005 speed × 180°/s × 30s ≈ 27° of swing per leg, so the character
-- oscillates around the facing pose and is never far from facing the viewer.
local ORBIT_HALF_PERIOD      = 30.0
local YAW_DEGREES            = 360
local YAW_DIRECTION          = -1    -- -1 = turn left (character faces toward camera)
local SAVED_VIEW_SLOT        = 5

-- ── Helpers ──────────────────────────────────────────────────────────────────

function CameraMode:IsSupported()
    return type(SaveView)      == "function"
       and type(SetView)       == "function"
       and type(GetCameraZoom) == "function"
       and type(CameraZoomIn)  == "function"
       and type(CameraZoomOut) == "function"
end

function CameraMode:_IsPlayerMounted()
    if type(IsMounted) == "function" and IsMounted() then return true end
    return false
end

function CameraMode:_GetTargetZoom()
    return self:_IsPlayerMounted() and MOUNTED_ZOOM or UNMOUNTED_ZOOM
end

function CameraMode:_GetShoulderOffset()
    if self:_IsPlayerMounted() then
        return MOUNTED_ZOOM * MOUNTED_SHOULDER_F1 + MOUNTED_SHOULDER_F2
    end
    local raceID = 0
    if type(UnitRace) == "function" then
        local _, _, rid = UnitRace("player")
        raceID = tonumber(rid) or 0
    end
    local f = SHOULDER_FACTORS[raceID] or SHOULDER_FACTORS[0]
    return UNMOUNTED_ZOOM * f[1] + f[2]
end

function CameraMode:_SetZoom(goal)
    local current = tonumber(GetCameraZoom()) or goal
    local delta = (tonumber(goal) or current) - current
    if math.abs(delta) < 0.001 then return end
    if delta > 0 then
        pcall(CameraZoomOut, delta)
    else
        pcall(CameraZoomIn, -delta)
    end
end

function CameraMode:_StopYaw()
    if type(MoveViewRightStop) == "function" then pcall(MoveViewRightStop) end
    if type(MoveViewLeftStop)  == "function" then pcall(MoveViewLeftStop)  end
end

function CameraMode:_ApplyYaw(speed)
    speed = tonumber(speed) or 0
    if math.abs(speed) <= 0.0001 then return end
    if speed > 0 and type(MoveViewRightStart) == "function" then
        pcall(MoveViewRightStart, speed)
    elseif speed < 0 and type(MoveViewLeftStart) == "function" then
        pcall(MoveViewLeftStart, -speed)
    end
end

-- ── Public API ───────────────────────────────────────────────────────────────

function CameraMode:Enter()
    if self.active then return end
    if InCombatLockdown and InCombatLockdown() then return end
    if not (ns.db and ns.db.cinematicCamera) then return end
    if not self:IsSupported() then return end

    self.capture = {
        savedViewSlot = SAVED_VIEW_SLOT,
        zoom          = tonumber(GetCameraZoom()) or 0,
    }
    pcall(SaveView, SAVED_VIEW_SLOT)

    self.active  = true
    self.mode    = "enter"
    self.elapsed = 0

    -- Capture and optionally raise CVars we touch.
    if type(GetCVar) == "function" and type(SetCVar) == "function" then
        self.capture.cameraDistanceMaxZoomFactor =
            tonumber(GetCVar("cameraDistanceMaxZoomFactor")) or 1.0
        if self.capture.cameraDistanceMaxZoomFactor < 2.0 then
            pcall(SetCVar, "cameraDistanceMaxZoomFactor", 2.0)
        end
        self.capture.cameraOverShoulder =
            tonumber(GetCVar("test_cameraOverShoulder")) or 0
        self.capture.cameraDynamicPitch =
            tonumber(GetCVar("test_cameraDynamicPitch")) or 0
        pcall(SetCVar, "test_cameraDynamicPitch", "1")
        pcall(SetCVar, "test_cameraOverShoulder", self:_GetShoulderOffset())
    end

    -- Start from a clean base view, then apply zoom.
    if type(SetView) == "function" then pcall(SetView, 2) end
    self:_SetZoom(self:_GetTargetZoom())

    -- Compute entry yaw swing speed.
    local yawMoveSpeed = tonumber(GetCVar and GetCVar("cameraYawMoveSpeed")) or 180
    if yawMoveSpeed <= 0 then yawMoveSpeed = 180 end
    local degrees  = math.abs(YAW_DEGREES)
    local seconds  = math.max(0.05, ENTER_DURATION)
    local rawSpeed = (degrees / yawMoveSpeed) / seconds
    local dir = YAW_DIRECTION < 0 and -1 or 1
    self.yawDir       = dir
    self.yawFromSpeed = clamp(rawSpeed, 0.10, 4.0, 1.0)
    self.yawToSpeed   = ORBIT_SPEED
    self:_ApplyYaw(dir * self.yawFromSpeed)

    if self.animFrame then self.animFrame:Show() end
end

function CameraMode:Exit()
    if not self.active or self.mode == "exit" then return end
    self:_StopYaw()
    self.mode    = "exit"
    self.elapsed = 0
    if self.capture and self.capture.savedViewSlot and type(SetView) == "function" then
        pcall(SetView, self.capture.savedViewSlot)
    end
    if self.animFrame then self.animFrame:Show() end
end

function CameraMode:ForceRestore(reason)
    self:_StopYaw()
    if self.animFrame then self.animFrame:Hide() end

    if self.capture then
        if self.capture.savedViewSlot and type(SetView) == "function" then
            pcall(SetView, self.capture.savedViewSlot)
        end
        self:_SetZoom(self.capture.zoom or 0)
        if type(SetCVar) == "function" then
            if self.capture.cameraDistanceMaxZoomFactor then
                pcall(SetCVar, "cameraDistanceMaxZoomFactor",
                      self.capture.cameraDistanceMaxZoomFactor)
            end
            if self.capture.cameraOverShoulder then
                pcall(SetCVar, "test_cameraOverShoulder",
                      self.capture.cameraOverShoulder)
            end
            if self.capture.cameraDynamicPitch then
                pcall(SetCVar, "test_cameraDynamicPitch",
                      self.capture.cameraDynamicPitch)
            end
        end
    end

    self.active  = false
    self.mode    = nil
    self.capture = nil
    self.elapsed = 0
end

function CameraMode:UpdateAnimation(elapsed)
    if not self.mode then
        if self.animFrame then self.animFrame:Hide() end
        return
    end
    self.elapsed = (self.elapsed or 0) + (elapsed or 0)

    if self.mode == "enter" then
        local entryDur = math.max(0.01, ENTER_DURATION)
        if self.elapsed < entryDur then
            -- Entry burst: ease from initial fast yaw down to orbit speed.
            -- Rotates ~180° in ~0.5s (the "fast-forward" to facing pose).
            if self.yawDir and self.yawFromSpeed and self.yawToSpeed then
                self:_ApplyYaw(self.yawDir * inOutSine(self.elapsed, self.yawFromSpeed, self.yawToSpeed, entryDur))
            end
        else
            -- Transition to ping-pong orbit. Keep the animFrame running so
            -- we can flip direction every ORBIT_HALF_PERIOD seconds.
            self:_StopYaw()
            self:_ApplyYaw(self.yawDir * ORBIT_SPEED)
            self.mode = "orbit"
            self.orbitElapsed = 0
        end
        return
    end

    if self.mode == "orbit" then
        self.orbitElapsed = (self.orbitElapsed or 0) + (elapsed or 0)
        if self.orbitElapsed >= ORBIT_HALF_PERIOD then
            -- Reverse direction so the character orbits back toward facing.
            self.orbitElapsed = self.orbitElapsed - ORBIT_HALF_PERIOD
            self.yawDir = -self.yawDir
            self:_StopYaw()
            self:_ApplyYaw(self.yawDir * ORBIT_SPEED)
        end
        return
    end

    if self.mode == "exit" then
        if self.elapsed >= math.max(0.01, EXIT_DURATION) then
            self:ForceRestore("exit-complete")
        end
    end
end

-- ── Frame plumbing ───────────────────────────────────────────────────────────

CameraMode.animFrame = CreateFrame("Frame")
CameraMode.animFrame:Hide()
CameraMode.animFrame:SetScript("OnUpdate", function(_, elapsed)
    CameraMode:UpdateAnimation(elapsed)
end)

CameraMode.eventFrame = CreateFrame("Frame")
CameraMode.eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
CameraMode.eventFrame:RegisterEvent("PLAYER_LOGOUT")
CameraMode.eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
CameraMode.eventFrame:SetScript("OnEvent", function(_, event)
    if CameraMode.active then
        CameraMode:ForceRestore(event)
    end
end)

-- Suppress "Are you sure you want to enable experimental feature?" popup.
-- Narcissus does the same unregister to allow silent test_* CVar writes.
if UIParent and type(UIParent.UnregisterEvent) == "function" then
    pcall(UIParent.UnregisterEvent, UIParent, "EXPERIMENTAL_CVAR_CONFIRMATION_NEEDED")
end
