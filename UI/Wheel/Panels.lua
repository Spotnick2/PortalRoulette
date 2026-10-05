-- ============================================================
-- Panels: the glass pills around the disc (header, reagent strip, info
-- pill). All non-secure; they live on the protected root, so they are only
-- shown, hidden or moved out of combat.
-- ============================================================

local _, ns = ...

local Skin = ns.Skin
local Layout = ns.Layout
local C = ns.Constants

local Panels = {}
ns.Panels = Panels

------------------------------------------------------------
-- Header: title, gear, close.
------------------------------------------------------------

local function roundButton(parent, size, icon, onClick, tooltip)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(size, size)
    local g = Skin:Disc(b, "disc_small")
    local tex = b:CreateTexture(nil, "ARTWORK")
    tex:SetPoint("TOPLEFT", 5, -5)
    tex:SetPoint("BOTTOMRIGHT", -5, 5)
    tex:SetTexture(icon)
    b.icon, b.glass = tex, g
    b:SetScript("OnClick", onClick)
    b:SetScript("OnEnter", function(self)
        tex:SetVertexColor(1, 1, 1, 1)
        if tooltip then
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:SetText(tooltip, 1, 1, 1)
            GameTooltip:Show()
        end
    end)
    b:SetScript("OnLeave", function()
        tex:SetVertexColor(0.85, 0.88, 0.95, 0.9)
        GameTooltip:Hide()
    end)
    tex:SetVertexColor(0.85, 0.88, 0.95, 0.9)
    return b
end

function Panels.CreateHeader(root)
    local header = CreateFrame("Frame", nil, root)
    header:SetSize(280, Layout.HEADER_H)
    header:SetPoint("TOP", root, "TOP", -24, -4)
    header.glass = Skin:Pill(header)
    local g = header.glass
    -- Retain liquid glass, with a much clearer reading surface and thin lip.
    if g.tint then g.tint:SetColorTexture(0.10, 0.13, 0.22, 0.12) end
    if g.grain then g.grain:SetAlpha(0.025) end
    if g.wash then g.wash:SetAlpha(0.2) end
    if g.shadow then g.shadow:SetAlpha(0.35) end
    if g.rim then g.rim:SetAlpha(0.3) end
    if g.dark then g.dark:SetAlpha(0.4) end
    local top = g.top or header
    local title = Skin:Font(top, 20, "CENTER")
    title:SetFont("Fonts\\FRIZQT__.TTF", 20, "")
    title:SetWidth(232)
    title:SetPoint("CENTER")
    title:SetText("PORTAL ROULETTE")
    title:SetTextColor(0.82, 0.86, 1, 1)
    title:SetShadowOffset(1.5, -1.5)
    title:SetShadowColor(0.02, 0.03, 0.08, 1)
    header.title = title

    header.glints = {}
    header.time = 0
    -- Same masked LibGlass sweep used by GlassUnitFrames on target change.
    -- A separate visual host lets intensity dim the sweep without dimming text.
    local scan = CreateFrame("Frame", nil, header)
    scan:SetAllPoints(header)
    scan:SetFrameLevel(header:GetFrameLevel() + 9)
    scan:EnableMouse(false)
    header.sheenHost = scan
    header.sheen = Skin:Sheen({ size = g.size, top = scan }, scan, 280, Layout.HEADER_H)
    header.sheenWait = 0.8
    for i, side in ipairs({ "LEFT", "RIGHT" }) do
        local glint = top:CreateTexture(nil, "OVERLAY", nil, 6)
        glint:SetSize(24, 24)
        glint:SetPoint(side, header, side, i == 1 and 8 or -8, 0)
        glint:SetTexture(ns.Media.TITLE_GLINT)
        glint:SetBlendMode("ADD")
        glint:SetVertexColor(0.58, 0.68, 1)
        header.glints[i] = glint
    end
    Panels.UpdateHeader(header, 0)

    header.gear = roundButton(root, 30, "Interface\\Buttons\\UI-OptionsButton", function()
        if ns.Roulette then ns.Roulette:OpenOptions() end
    end, "Options")
    header.gear:SetPoint("LEFT", header, "RIGHT", 10, 0)
    header.close = roundButton(root, 30, "Interface\\Buttons\\UI-StopButton", function()
        if ns.Roulette then ns.Roulette:Close() end
    end, "Close")
    header.close:SetPoint("LEFT", header.gear, "RIGHT", 8, 0)

    -- Alt-drag the title to move the wheel (out of combat).
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function()
        if IsAltKeyDown() and not InCombatLockdown() then
            root:StartMoving()
            root.moving = true
        end
    end)
    header:SetScript("OnDragStop", function()
        if root.moving then
            root.moving = false
            root:StopMovingOrSizing()
            if ns.Roulette then ns.Roulette:SavePosition() end
        end
    end)
    return header
end

-- Shares the wheel's visible-only updater (also works with UIParent hidden).
-- Only the ornament light breathes; the wordmark and glass remain stationary.
function Panels.UpdateHeader(header, elapsed)
    local intensity = ns.Anim.Intensity()
    local idle = ns.Anim.Enabled("idle") and intensity > 0
    if idle then header.time = header.time + elapsed end
    if header.sheen then
        header.sheenHost:SetAlpha(0.5 * intensity)
        if idle then
            header.sheenWait = header.sheenWait - elapsed
            if header.sheenWait <= 0 then
                header.sheen:Stop()
                header.sheen:Play()
                header.sheenWait = 8
            end
        else
            Panels.StopHeader(header)
        end
    end
    for i, glint in ipairs(header.glints) do
        local wave = idle and (0.5 + 0.5 * math.sin(header.time * math.pi / 3.5 + i * math.pi)) or 0
        glint:SetAlpha(0.35 + 0.3 * wave * intensity)
    end
end

function Panels.StopHeader(header)
    if header.sheen then header.sheen:Stop() end
    header.sheenWait = 0.8
end

------------------------------------------------------------
-- Reagent strip: rune counts + click hint. Counts may be secret in
-- combat; they go to SetText untouched (FontStrings accept secrets).
------------------------------------------------------------

local function reagentCell(parent, icon)
    local tex = parent:CreateTexture(nil, "ARTWORK")
    tex:SetSize(24, 24)
    tex:SetTexture(icon)
    local text = Skin:Font(parent, 14, "LEFT")
    text:SetPoint("LEFT", tex, "RIGHT", 4, 0)
    return tex, text
end

function Panels.CreateReagentStrip(root)
    local strip = CreateFrame("Frame", nil, root)
    strip:SetSize(Layout.DISC - 20, Layout.STRIP_H)
    strip:SetPoint("BOTTOM", root, "BOTTOM", 0, 4)
    strip.glass = Skin:Pill(strip)
    local top = strip.glass.top or strip

    strip.tIcon, strip.tCount = reagentCell(top, ns.API.ItemIcon(C.ITEM_RUNE_TELEPORTATION) or ns.Media.REAGENT_ICON_TELEPORT)
    strip.pIcon, strip.pCount = reagentCell(top, ns.API.ItemIcon(C.ITEM_RUNE_PORTALS) or ns.Media.REAGENT_ICON_PORTAL)
    strip.tIcon:SetPoint("LEFT", top, "LEFT", 14, 0)
    strip.pIcon:SetPoint("LEFT", strip.tCount, "RIGHT", 14, 0)

    local divider = top:CreateTexture(nil, "ARTWORK")
    divider:SetSize(1, Layout.STRIP_H - 18)
    divider:SetTexture(ns.Media.WHITE)
    divider:SetVertexColor(1, 1, 1, 0.25)
    divider:SetPoint("LEFT", strip.pCount, "RIGHT", 14, 0)
    strip.divider = divider

    local hint = Skin:Font(top, 12, "CENTER")
    hint:SetTextColor(1, 1, 1, 0.7)
    hint:SetText("Left-click: Teleport  ·  Right-click: Portal")
    strip.hint = hint
    return strip
end

-- A count that may be secret: a secret goes to SetText untouched (never
-- compared or truth-tested); a readable nil shows "?".
function Panels.SetCount(fontString, raw)
    if not ns.API.Readable(raw) then
        fontString:SetText(raw)
    elseif type(raw) == "number" then
        fontString:SetText(raw)
    else
        fontString:SetText("?")
    end
end

-- state: "required" / "unknown" show counts; "free" shows the hint only.
function Panels.UpdateReagentStrip(strip, reagentState)
    local showCounts = reagentState ~= "free"
    local tRaw, pRaw = ns.Reagents:Counts()
    for _, region in ipairs({ strip.tIcon, strip.tCount, strip.pIcon, strip.pCount, strip.divider }) do
        region:SetShown(showCounts)
    end
    strip.hint:ClearAllPoints()
    if showCounts then
        Panels.SetCount(strip.tCount, tRaw)
        Panels.SetCount(strip.pCount, pRaw)
        local warn = ns.Colors.WARN
        local tMissing, pMissing = ns.Reagents:IsMissing("teleport"), ns.Reagents:IsMissing("portal")
        strip.tCount:SetTextColor(tMissing and warn[1] or 1, tMissing and warn[2] or 1, tMissing and warn[3] or 1)
        strip.pCount:SetTextColor(pMissing and warn[1] or 1, pMissing and warn[2] or 1, pMissing and warn[3] or 1)
        strip.hint:SetPoint("LEFT", strip.divider, "RIGHT", 14, 0)
        strip.hint:SetPoint("RIGHT", strip, "RIGHT", -14, 0)
    else
        strip.hint:SetPoint("CENTER", strip, "CENTER")
    end
end

------------------------------------------------------------
-- Confirm pill: the grouped-teleport question, on our own glass (never a
-- Blizzard StaticPopup, which addon code would taint).
------------------------------------------------------------

function Panels.CreateConfirm(stage, onYes)
    local pill = CreateFrame("Frame", nil, stage)
    pill:SetSize(300, 64)
    pill:SetPoint("CENTER", stage, "CENTER", 0, Layout.DISC_Y)
    pill:SetFrameLevel(stage:GetFrameLevel() + 60)
    pill:EnableMouse(true)
    pill.glass = Skin:Pill(pill)
    local top = pill.glass.top or pill
    pill.text = Skin:Font(top, 13, "CENTER")
    pill.text:SetPoint("TOP", 0, -10)
    pill.text:SetWidth(280)
    local function choice(label, x, fn)
        local b = CreateFrame("Button", nil, top)
        b:SetSize(80, 22)
        b:SetPoint("BOTTOM", pill, "BOTTOM", x, 8)
        b.glass = Skin:Pill(b)
        local fs = Skin:Font(b.glass.top or b, 12, "CENTER")
        fs:SetPoint("CENTER")
        fs:SetText(label)
        b:SetScript("OnClick", fn)
        b:SetScript("OnEnter", function() fs:SetTextColor(0.7, 0.85, 1) end)
        b:SetScript("OnLeave", function() fs:SetTextColor(1, 1, 1) end)
        return b
    end
    pill.yes = choice(YES or "Yes", -46, function() pill:Hide() onYes() end)
    pill.no = choice(NO or "No", 46, function() pill:Hide() end)
    pill:Hide()
    return pill
end

------------------------------------------------------------
-- Info pill: the hovered node's actions, outside the disc on its side.
------------------------------------------------------------

function Panels.CreateInfoPill(root)
    local pill = CreateFrame("Frame", nil, root)
    pill:SetSize(250, 52)
    pill:SetFrameLevel(root:GetFrameLevel() + 40)
    pill.glass = Skin:Pill(pill)
    local top = pill.glass.top or pill
    pill.line1 = Skin:Font(top, 13, "LEFT")
    pill.line1:SetPoint("TOPLEFT", 12, -9)
    pill.line1:SetPoint("RIGHT", -12, 0)
    pill.line2 = Skin:Font(top, 13, "LEFT")
    pill.line2:SetPoint("TOPLEFT", pill.line1, "BOTTOMLEFT", 0, -4)
    pill.line2:SetPoint("RIGHT", -12, 0)
    pill:Hide()
    return pill
end

local function hex(color)
    return string.format("|cff%02x%02x%02x", color[1] * 255, color[2] * 255, color[3] * 255)
end

-- Show the pill for `node` (side-aware) with its two action lines.
function Panels.ShowInfo(pill, node, discCenter, lines)
    pill.line1:SetText(lines[1] or "")
    pill.line2:SetText(lines[2] or "")
    local h = (lines[2] and lines[2] ~= "") and 52 or 32
    pill:SetHeight(h)
    pill:ClearAllPoints()
    local side = Layout.Side(node.clock or 0)
    if side == "LEFT" then
        pill:SetPoint("RIGHT", node.button, "LEFT", -30, 0)
    elseif side == "RIGHT" then
        pill:SetPoint("LEFT", node.button, "RIGHT", 30, 0)
    else
        pill:SetPoint("LEFT", node.button, "RIGHT", 24, 0)
    end
    pill:Show()
end

Panels.Hex = hex
