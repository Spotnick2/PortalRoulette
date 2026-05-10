local _, ns = ...

-- Narcissus-style camera presentation, ported from Narcissus Classic and AltTracker.
--
-- Character framing:  POSITIVE test_cameraOverShoulder shifts character LEFT on screen
--                     (camera goes right of player), which is what we want since the
--                     wheel sits on the right side of the screen.
-- Mounted detection:  separate zoom + shoulder values so a mounted character is fully
--                     visible with the mount, matching Narcissus Classic behaviour.
-- CVar popup:         untouched; mutating UIParent event ownership can taint
--                     protected Blizzard callbacks such as the game menu.

local CameraMode = {
    active  = false,
    mode    = nil,
    capture = nil,
    elapsed = 0,
}
ns.CameraMode = CameraMode

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
-- For unmounted Human at zoom 2.5: offset = 2.5*0.3283 + (-0.02) = 0.801 → small left bias.
-- We use the same convention.
local UNMOUNTED_ZOOM         = 2.5   -- Narcissus close-up goal with dynamic pitch
local MOUNTED_ZOOM           = 8.0   -- Narcissus default for mounted
-- Narcissus eases into its portrait angle instead of snapping through a full spin.
local ENTER_DURATION         = 1.50
local CAST_RESET_DURATION    = 0.90
local EXIT_DURATION          = 0.92
local EXIT_RESTORE_AT        = 0.10
local ORBIT_SPEED            = 0.005
local ENTER_YAW_FROM_SPEED   = 1.0
local CAST_RESET_YAW_SPEED   = 0.78
local CAST_RESET_YAW_DURATION = 0.42
local YAW_DIRECTION          = 1     -- Narcissus uses MoveViewRightStart on entry
local SAVED_VIEW_SLOT        = 5
local PRESENTATION_VIEW_SLOT = 4

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

function CameraMode:_StopYawDirection(direction)
    if direction and direction > 0 and type(MoveViewRightStop) == "function" then
        pcall(MoveViewRightStop)
    elseif direction and direction < 0 and type(MoveViewLeftStop) == "function" then
        pcall(MoveViewLeftStop)
    else
        self:_StopYaw()
    end
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
        self.capture.cameraViewBlendStyle =
            tonumber(GetCVar("cameraViewBlendStyle")) or 1
        pcall(SetCVar, "cameraViewBlendStyle", "2")
        pcall(SetCVar, "test_cameraDynamicPitch", "1")
        pcall(SetCVar, "test_cameraOverShoulder", self:_GetShoulderOffset())
    end
    if type(ConsoleExec) == "function" then
        pcall(ConsoleExec, "pitchlimit 1")
    end

    -- Start from a clean base view, then apply zoom.
    if type(SetView) == "function" then pcall(SetView, 2) end
    self:_SetZoom(self:_GetTargetZoom())

    local dir = YAW_DIRECTION < 0 and -1 or 1
    self.yawDir       = dir
    self.yawFromSpeed = ENTER_YAW_FROM_SPEED
    self.yawToSpeed   = ORBIT_SPEED
    self:_StopYaw()
    self:_ApplyYaw(dir * self.yawFromSpeed)

    if self.animFrame then self.animFrame:Show() end
end

function CameraMode:Exit()
    if not self.active or self.mode == "exit" then return end
    self:_StopYaw()
    self.mode    = "exit"
    self.elapsed = 0
    self.exitRestored = nil
    if self.animFrame then self.animFrame:Show() end
end

function CameraMode:ResetOrbitForCast()
    if not self.active or self.mode == "exit" then return end
    if not self:IsSupported() then return end

    self:_StopYaw()
    local restoredPresentationView = false
    if self.presentationViewSaved and type(SetView) == "function" then
        local ok = pcall(SetView, PRESENTATION_VIEW_SLOT)
        restoredPresentationView = ok and true or false
    end
    if not restoredPresentationView and type(SetView) == "function" then
        pcall(SetView, 2)
    end
    self:_SetZoom(self:_GetTargetZoom())

    if type(SetCVar) == "function" then
        pcall(SetCVar, "cameraViewBlendStyle", "2")
        pcall(SetCVar, "test_cameraDynamicPitch", "1")
        pcall(SetCVar, "test_cameraOverShoulder", self:_GetShoulderOffset())
    end

    local dir = YAW_DIRECTION < 0 and -1 or 1
    self.yawDir = dir
    self.elapsed = 0
    self.resumeOrbitAfterCastReset = nil

    if restoredPresentationView then
        self.castResetDuration = nil
        self.mode = "castHold"
        if self.animFrame then self.animFrame:Hide() end
    else
        self.castResetDuration = CAST_RESET_YAW_DURATION
        self.mode = "castReset"
        self:_ApplyYaw(dir * CAST_RESET_YAW_SPEED)
        if self.animFrame then self.animFrame:Show() end
    end
end

function CameraMode:ResumeOrbitAfterCast()
    if not self.active or self.mode == "exit" then return end
    if self.mode == "castReset" then
        self.resumeOrbitAfterCastReset = true
        return
    end
    if self.mode ~= "castHold" then return end

    self:_StopYaw()
    self.yawDir = YAW_DIRECTION < 0 and -1 or 1
    self:_ApplyYaw(self.yawDir * ORBIT_SPEED)
    self.mode = "orbit"
    self.elapsed = 0
    self.castResetDuration = nil
    self.resumeOrbitAfterCastReset = nil
    if self.animFrame then self.animFrame:Hide() end
end

function CameraMode:ForceRestore(reason)
    self:_StopYaw()
    if self.animFrame then self.animFrame:Hide() end
    if type(ConsoleExec) == "function" then
        pcall(ConsoleExec, "pitchlimit 88")
    end

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
            if self.capture.cameraViewBlendStyle then
                pcall(SetCVar, "cameraViewBlendStyle",
                      self.capture.cameraViewBlendStyle)
            end
        end
    end

    self.active  = false
    self.mode    = nil
    self.capture = nil
    self.elapsed = 0
    self.entryDuration = nil
    self.castResetDuration = nil
    self.resumeOrbitAfterCastReset = nil
    self.presentationViewSaved = nil
    self.exitYawDir = nil
    self.exitRestored = nil
end

function CameraMode:UpdateAnimation(elapsed)
    if not self.mode then
        if self.animFrame then self.animFrame:Hide() end
        return
    end
    self.elapsed = (self.elapsed or 0) + (elapsed or 0)

    if self.mode == "enter" then
        local entryDur = math.max(0.01, self.entryDuration or ENTER_DURATION)
        if self.elapsed < entryDur then
            -- Narcissus-style entry: ease from the initial portrait turn down to orbit speed.
            if self.yawDir and self.yawFromSpeed and self.yawToSpeed then
                self:_ApplyYaw(self.yawDir * inOutSine(self.elapsed, self.yawFromSpeed, self.yawToSpeed, entryDur))
            end
        else
            -- Transition to a very slow one-way drift. Casting exits this mode
            -- gracefully so the spell animation can play without camera motion.
            self:_StopYaw()
            if type(SaveView) == "function" then
                self.presentationViewSaved = pcall(SaveView, PRESENTATION_VIEW_SLOT) and true or false
            end
            self:_ApplyYaw(self.yawDir * ORBIT_SPEED)
            self.mode = "orbit"
            self.entryDuration = nil
        end
        return
    end

    if self.mode == "castReset" then
        local resetDur = math.max(0.01, self.castResetDuration or CAST_RESET_DURATION)
        if self.elapsed >= resetDur then
            self:_StopYaw()
            self.mode = "castHold"
            self.castResetDuration = nil
            if self.resumeOrbitAfterCastReset then
                self:ResumeOrbitAfterCast()
            elseif self.animFrame then
                self.animFrame:Hide()
            end
        end
        return
    end

    if self.mode == "castHold" then
        if self.animFrame then self.animFrame:Hide() end
        return
    end

    if self.mode == "orbit" then
        return
    end

    if self.mode == "exit" then
        local exitDur = math.max(0.01, EXIT_DURATION)
        if not self.exitRestored and self.elapsed >= EXIT_RESTORE_AT then
            self.exitRestored = true
            self:ForceRestore("exit-restore")
            return
        end
        if self.elapsed >= exitDur then
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
CameraMode.eventFrame:RegisterEvent("UNIT_SPELLCAST_START")
CameraMode.eventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
CameraMode.eventFrame:RegisterEvent("UNIT_SPELLCAST_STOP")
CameraMode.eventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
CameraMode.eventFrame:RegisterEvent("UNIT_SPELLCAST_FAILED")
CameraMode.eventFrame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
CameraMode.eventFrame:SetScript("OnEvent", function(_, event, unit)
    if CameraMode.active then
        if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" then
            if unit == "player" then
                CameraMode:ResetOrbitForCast()
            end
            return
        end
        if event == "UNIT_SPELLCAST_STOP"
            or event == "UNIT_SPELLCAST_CHANNEL_STOP"
            or event == "UNIT_SPELLCAST_FAILED"
            or event == "UNIT_SPELLCAST_INTERRUPTED"
        then
            if unit == "player" then
                CameraMode:ResumeOrbitAfterCast()
            end
            return
        end
        CameraMode:ForceRestore(event)
    end
end)

