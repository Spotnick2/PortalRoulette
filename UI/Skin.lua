-- ============================================================
-- Skin: the glass material, through LibGlass-1.0 when the loaded copy has
-- the disc material (MINOR >= 2), else a plain fallback that keeps the
-- addon usable (round tinted shapes with a rim). Every surface of the wheel
-- is made here, so the rest of the UI never talks to LibGlass directly.
--
-- With Glass UI loaded and following (Core/GlassUI.lua), the instance is
-- LibGlass's Pearl preset and our own look (the disc's tuning, its rim art,
-- the panels' grain and wash) is suspended: OwnLook() is false.
-- ============================================================

local _, ns = ...

local Skin = {}
ns.Skin = Skin

local NEEDS_MINOR = 2
local WHITE = ns.Media.WHITE
local CIRCLE = ns.Media.CIRCLE_MASK

-- The LibGlass instance, or nil when the library is missing or too old.
function Skin:Glass()
    if self.glass ~= nil then
        return self.glass or nil
    end
    self.glass = false
    local stub = _G.LibStub
    local lib, minor
    if stub then
        -- Not `stub and stub:GetLibrary(...)`: `and` keeps only one value.
        lib, minor = stub:GetLibrary("LibGlass-1.0", true)
    end
    if lib and minor and minor >= NEEDS_MINOR and lib.ready == minor then
        local GlassUI = ns.GlassUI
        local wanted = GlassUI and GlassUI:Preset()
        local reason
        if wanted == "pearl" then
            if minor < GlassUI.PEARL_MINOR then
                reason = "library-too-old"
            else
                local ok, instance = pcall(lib.New, lib, { preset = "pearl", font = "arial" })
                if ok and instance then
                    self.glass, self.preset = instance, "pearl"
                else
                    reason = "build-failed"
                end
            end
        end
        if not self.glass then
            local ok, instance = pcall(lib.New, lib, { font = "arial" })
            if ok and instance then
                self.glass = instance
            end
        end
        if wanted and GlassUI then
            GlassUI:Built(self.preset, reason, minor)
        end
    elseif ns.GlassUI and ns.GlassUI:Preset() then
        ns.GlassUI:Built(nil, "library-too-old", minor)
    end
    if not self.glass and not self.warned then
        self.warned = true
        if ns.Print then
            ns.Print("|cffff6060LibGlass-1.0 r" .. NEEDS_MINOR .. "+ not found: using the plain look.|r")
        end
    end
    return self.glass or nil
end

-- False while following Glass UI's Pearl: the per-surface tuning and rim
-- art below are Portal Roulette's own look, suspended then (SUITE.md,
-- "Each addon", step 3). Rim colours that show state stay.
function Skin:OwnLook()
    self:Glass()
    return self.preset == nil
end

local function circleMask(frame, region)
    local mask = frame:CreateMaskTexture()
    mask:SetTexture(CIRCLE, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(region or frame)
    return mask
end
Skin.CircleMask = circleMask

-- A texture clipped to a circle covering `frame`.
function Skin:RoundTexture(frame, layer, sublevel)
    local texture = frame:CreateTexture(nil, layer or "ARTWORK", nil, sublevel or 0)
    texture:SetAllPoints()
    texture:AddMaskTexture(circleMask(frame, texture))
    return texture
end

-- A round glass surface on a square host. Returns g with:
--   g.top   the frame to parent content above the glass to
--   g.mask  a circle mask for clipping content inside the disc
--   g.rim   the rim texture (or nil)
-- size: "disc" (frames 128 px and up) or "disc_small".
function Skin:Disc(host, size)
    local glass = self:Glass()
    if glass then
        local ok, g = pcall(glass.Disc, host, size)
        if ok and g then
            g.mask = g.mask or circleMask(host)
            if size == "disc" and self:OwnLook() then
                -- Tune this wheel surface only. LibGlass r2 puts body layers
                -- below our BORDER energy and rims on g.top, above it.
                -- Each layer guarded: a later LibGlass layout must not
                -- break wheel creation.
                if g.tint then g.tint:SetColorTexture(0.10, 0.15, 0.23, 0.14) end
                if g.grain then g.grain:SetAlpha(0.06) end
                self:SetWash(g, 0.22)
                if g.shadow then g.shadow:SetAlpha(0.45) end
                if g.rim then
                    g.rim:SetTexture(ns.Media.DISC_RIM)
                    g.rim:SetVertexColor(0.78, 0.88, 1, 1)
                    g.rim:SetAlpha(0.82)
                end
                if g.dark then
                    g.dark:SetTexture(ns.Media.DISC_RIM_DARK)
                    g.dark:SetVertexColor(0, 0, 0, 1)
                end
            end
            return g
        end
    end

    -- Fallback: a light edge circle under a cool translucent fill inset by
    -- the rim width, plus a faint top-down wash.
    local g = {}
    local rimWidth = size == "disc" and 2 or 1.5
    local rim = self:RoundTexture(host, "BACKGROUND", -7)
    rim:SetTexture(WHITE)
    rim:SetVertexColor(0.85, 0.9, 1, 0.45)
    local fillHost = CreateFrame("Frame", nil, host)
    fillHost:SetPoint("TOPLEFT", rimWidth, -rimWidth)
    fillHost:SetPoint("BOTTOMRIGHT", -rimWidth, rimWidth)
    fillHost:SetFrameLevel(host:GetFrameLevel())
    local fill = self:RoundTexture(fillHost, "BACKGROUND", -6)
    fill:SetTexture(WHITE)
    fill:SetVertexColor(0.10, 0.12, 0.18, 0.62)
    local wash = self:RoundTexture(fillHost, "BACKGROUND", -4)
    wash:SetTexture(WHITE)
    wash:SetGradient("VERTICAL", CreateColor(1, 1, 1, 0), CreateColor(1, 1, 1, 0.12))
    local top = CreateFrame("Frame", nil, host)
    top:SetAllPoints()
    top:SetFrameLevel(host:GetFrameLevel() + 10)
    g.top, g.mask, g.rim, g.fill = top, circleMask(host), rim, fill
    return g
end

-- A surface's wash (its top-down white sheen) at `factor` times the
-- instance's built strength. Not SetAlpha: on Forever a gradient texture
-- ignores it (porting guide §3, #6), so the strength goes through the
-- gradient, as LibGlass r7+'s SetWash paints it.
function Skin:SetWash(g, factor)
    local glass = self:Glass()
    if not (glass and g and g.wash) then
        return
    end
    local built = glass.STYLE and glass.STYLE.wash or 0
    local top = math.max(0, math.min(1, built * factor))
    if glass.SetWash then
        pcall(glass.SetWash, g, top)
    else
        g.wash:SetGradient("VERTICAL", CreateColor(1, 1, 1, 0), CreateColor(1, 1, 1, top))
        g.wash:SetShown(top > 0)
    end
end

-- A rounded-rect glass pill (header, plates, reagent strip).
function Skin:Pill(host)
    local glass = self:Glass()
    if glass then
        local ok, g = pcall(glass.Apply, host, "small")
        if ok and g then
            return g
        end
    end
    local g = {}
    local bg = host:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(WHITE)
    bg:SetVertexColor(0.08, 0.10, 0.16, 0.72)
    local edge = host:CreateTexture(nil, "BORDER")
    edge:SetPoint("TOPLEFT")
    edge:SetPoint("TOPRIGHT")
    edge:SetHeight(1)
    edge:SetTexture(WHITE)
    edge:SetVertexColor(1, 1, 1, 0.28)
    local top = CreateFrame("Frame", nil, host)
    top:SetAllPoints()
    top:SetFrameLevel(host:GetFrameLevel() + 10)
    g.top, g.bg = top, bg
    return g
end

-- A FontString in the glass font, or the game font.
function Skin:Font(parent, size, justify)
    local glass = self:Glass()
    if glass and glass.Font then
        local ok, fs = pcall(glass.Font, parent, size, justify)
        if ok and fs then
            return fs
        end
    end
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    local font = fs:GetFont()
    if font then
        fs:SetFont(font, size or 12, "")
    end
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 0.8)
    if justify then
        fs:SetJustifyH(justify)
    end
    return fs
end

-- A one-shot sheen sweep across a glass surface (no-op without LibGlass).
function Skin:Sheen(g, host, w, h)
    local glass = self:Glass()
    if glass and glass.Sheen and g then
        local ok, anim = pcall(glass.Sheen, g, host, w, h)
        if ok then
            return anim
        end
    end
    return nil
end

-- Tint a surface's rim (glass or fallback) toward an accent colour.
function Skin:SetRimColor(g, r, gg, b, a)
    local rim = g and g.rim
    if rim and rim.SetVertexColor then
        rim:SetVertexColor(r, gg, b, a or 1)
    end
end
