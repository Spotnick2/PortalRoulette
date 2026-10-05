-- ============================================================
-- Roulette: the wheel controller.
--
-- Combat rules (measured on 70205):
--   * The root parents secure buttons, so it is protected: Show/Hide/move/
--     scale only out of combat.
--   * InCombatLockdown() is still false inside PLAYER_REGEN_DISABLED
--     handlers, so the wheel closes synchronously there: no invisible
--     targets are left during combat.
--   * Secure attributes are written by one coalesced sync (SecureAction)
--     that reads the current state when it runs.
-- ============================================================

local _, ns = ...

local API = ns.API
local SA = ns.SecureAction
local Anim = ns.Anim
local Layout = ns.Layout
local Node = ns.Node
local Disc = ns.Disc
local HearthOrb = ns.HearthOrb
local Panels = ns.Panels

local Roulette = {
    slots = {},
    open = false,
    preview = false,
}
ns.Roulette = Roulette

-- The diamond of the approved mockup (docs/mockups): capitals at 12, 3 and
-- 6 inside the disc, Dalaran at 9, Karazhan a satellite outside the disc at
-- about 4 o'clock, linked to the rim.
local CAPITAL_CLOCKS = { 12, 3, 6 }
local BONUS_SLOTS = {
    dalaran = { clock = 9, radius = "NODE_RADIUS" },
    karazhan = { clock = 4, radius = "OUTER_RADIUS", outer = true },
}
local CONFIRM_SECONDS = 8

local function printf(msg)
    if ns.Print then ns.Print(msg) end
end

------------------------------------------------------------
-- Construction (lazy, out of combat)
------------------------------------------------------------

function Roulette:Create()
    if self.root then
        return self.root
    end
    local root = CreateFrame("Frame", "PortalRouletteFrame", UIParent)
    root:SetSize(Layout.ROOT_W, Layout.ROOT_H)
    root:SetFrameStrata("HIGH")
    root:SetClampedToScreen(true)
    root:SetMovable(true)
    root:EnableMouse(false)
    root:Hide()
    self.root = root

    -- Full-screen dimmer behind the wheel (lifted along with the root).
    local dimmer = CreateFrame("Frame", nil, root)
    dimmer:SetFrameStrata("BACKGROUND")
    dimmer:SetAllPoints(WorldFrame)
    dimmer:EnableMouse(false)
    local shade = dimmer:CreateTexture(nil, "BACKGROUND")
    shade:SetAllPoints()
    shade:SetTexture(ns.Media.WHITE)
    shade:SetGradient("HORIZONTAL", CreateColor(0, 0, 0, 0), CreateColor(0, 0, 0, 0.55))
    self.dimmer = dimmer

    -- Everything visual hangs off `stage`, which the open/close animation
    -- scales and fades. Secure buttons are children of the root, not of
    -- the stage, so they never move.
    local stage = CreateFrame("Frame", nil, root)
    stage:SetAllPoints()
    stage:EnableMouse(false)
    self.stage = stage

    self.disc = Disc.Create(stage)
    self.header = Panels.CreateHeader(stage)
    self.strip = Panels.CreateReagentStrip(stage)
    self.info = Panels.CreateInfoPill(stage)
    self.orb = HearthOrb.Create(root)

    local previewChip = CreateFrame("Frame", nil, stage)
    previewChip:SetSize(90, 20)
    previewChip:SetPoint("BOTTOM", self.header, "TOP", 0, 2)
    local chipGlass = ns.Skin:Pill(previewChip)
    local chipText = ns.Skin:Font(chipGlass.top or previewChip, 11, "CENTER")
    chipText:SetPoint("CENTER")
    chipText:SetText("PREVIEW")
    previewChip:Hide()
    self.previewChip = previewChip

    -- Node slots, created once: 3 capitals + 2 bonus.
    for i, clock in ipairs(CAPITAL_CLOCKS) do
        self.slots[i] = Node.Create(root, i, Layout.NODE)
        Node.Place(self.slots[i], root, clock, Layout.NODE_RADIUS)
    end
    self.bonusSlots = {}
    local i = #self.slots
    for _, id in ipairs({ "dalaran", "karazhan" }) do
        local slot = BONUS_SLOTS[id]
        i = i + 1
        local node = Node.Create(root, i, Layout.BONUS)
        node.outer = slot.outer
        node.radius = Layout[slot.radius]
        Node.Place(node, root, slot.clock, node.radius)
        self.slots[i] = node
        self.bonusSlots[id] = node
    end

    self.openAnim = Anim.Appear(stage, 0.35, 0.7)
    self.closeAnim = Anim.Disappear(stage, 0.18, 0.9)
    self.closeAnim:SetScript("OnFinished", function()
        Roulette:FinishClose()
    end)

    self:ApplyPosition()
    self:ApplyScale()
    SA.RegisterSync(function() Roulette:SyncSecure() end)

    -- Escape: a plain proxy frame in UISpecialFrames. CloseSpecialWindows
    -- hides it and its OnHide closes the wheel. Not a keyboard handler: an
    -- insecure OnKeyDown that touches SetPropagateKeyboardInput taints the
    -- Escape binding (measured on 70205: ToggleGameMenu then trips
    -- ADDON_ACTION_FORBIDDEN on SpellStopCasting). No parent, so hiding the
    -- game UI does not hide it.
    local escape = CreateFrame("Frame", "PortalRouletteEscape")
    escape:Hide()
    escape:SetScript("OnHide", function()
        if Roulette.open and not Roulette.closingFromEscape then
            Roulette.closingFromEscape = true
            Roulette:Close()
            Roulette.closingFromEscape = false
        end
    end)
    if UISpecialFrames then
        table.insert(UISpecialFrames, "PortalRouletteEscape")
    end
    self.escape = escape
    return root
end

------------------------------------------------------------
-- State
------------------------------------------------------------

function Roulette:IsGrouped()
    return IsInGroup() and true or false
end

-- Assign resolved destinations to slots.
function Roulette:Resolve()
    local list = ns.Destinations:Resolve(self.preview)
    local capitals, bonus = {}, {}
    for _, r in ipairs(list) do
        if r.kind == "capital" then
            capitals[#capitals + 1] = r
        else
            bonus[r.id] = r
        end
    end
    -- Capitals keep their data clock order (12, 4, 8).
    table.sort(capitals, function(a, b)
        local order = { [12] = 1, [3] = 2, [6] = 3 }
        return (order[a.clock] or 9) < (order[b.clock] or 9)
    end)
    self.assigned = {}
    for i = 1, #CAPITAL_CLOCKS do
        self.assigned[self.slots[i]] = capitals[i]
    end
    for id, node in pairs(self.bonusSlots) do
        self.assigned[node] = bonus[id]
    end

    local spellIDs = {}
    for _, r in ipairs(list) do
        spellIDs[#spellIDs + 1] = r.teleportID
        spellIDs[#spellIDs + 1] = r.portalID
    end
    self.reagentState = ns.Reagents:State(spellIDs)
    self.hearthSource = ns.Hearth:Current()
end

function Roulette:NeedsConfirm()
    if not (ns.db and ns.db.confirmGroupedTeleport) then
        return false
    end
    if not self:IsGrouped() then
        return false
    end
    return not (self.armed and self.armed.expires > GetTime())
end

-- The coalesced secure rebuild (registered with SecureAction).
function Roulette:SyncSecure()
    if not self.root then
        return
    end
    local preview = self.preview
    local confirm = self:NeedsConfirm()
    for _, node in ipairs(self.slots) do
        local resolved = self.assigned and self.assigned[node]
        SA.Apply(node.button, Node.Actions(resolved, { preview = preview, confirmTeleport = confirm }))
        node.button:SetShown(resolved ~= nil)
    end
    SA.Apply(self.orb.button, HearthOrb.Actions(self.hearthSource, preview))
end

-- Repaint everything non-secure. Safe in combat.
function Roulette:Paint()
    if not self.root then
        return
    end
    local state = {
        preview = self.preview,
        reagentState = self.reagentState,
        missingTeleport = ns.Reagents:IsMissing("teleport"),
        missingPortal = ns.Reagents:IsMissing("portal"),
    }
    for _, node in ipairs(self.slots) do
        local resolved = self.assigned and self.assigned[node]
        if resolved then
            Node.Update(node, resolved, state)
            local x, y = Layout.ClockOffset(node.clock, node.radius or Layout.NODE_RADIUS)
            -- Inside nodes link to the orb; a satellite links to the rim.
            local inner = node.outer and (Layout.DISC / 2 - 2) or (Layout.ORB / 2 + 2)
            -- Energy flows to every destination; ones not learned yet get a
            -- dimmer flow. Only an unavailable Karazhan (no Atiesh) is quiet.
            local level = (resolved.teleportKnown or resolved.portalKnown or self.preview) and 1 or 0.45
            if resolved.id == "karazhan" and resolved.state ~= "ready" and not self.preview then
                level = 0
            end
            Disc.Link(self.disc, node.index, x, y, inner, node.size,
                resolved.kind == "bonus" and ns.Colors.BONUS or ns.Colors.TELEPORT, level)
        else
            Disc.HideLink(self.disc, node.index)
        end
    end
    HearthOrb.Update(self.orb, self.hearthSource)
    Panels.UpdateReagentStrip(self.strip, self.reagentState)
    self.previewChip:SetShown(self.preview)
end

-- Full refresh: resolve, then secure sync (deferred if needed) and paint.
function Roulette:Refresh()
    if not self.root then
        return
    end
    self:Resolve()
    SA.MarkDirty()
    self:Paint()
end

------------------------------------------------------------
-- Open / close
------------------------------------------------------------

function Roulette:Open()
    if InCombatLockdown() then
        printf("Can't open in combat.")
        if ns.Sound then ns.Sound:Play("Error") end
        return
    end
    self:Create()
    if self.open then
        return
    end
    self.open = true
    ns.Hearth:Roll()
    self:Resolve()
    SA.RunSyncs() -- out of combat: attributes are current before the first click
    self:Paint()

    self.closeAnim:Stop()
    self.root:Show()
    self.escape:Show()
    ns.Presentation:Enter(self.root)
    if self.LiftShownDialogs then self.LiftShownDialogs() end
    Disc.Start(self.disc)
    if Anim.Enabled() then
        self.stage:SetAlpha(1)
        self.openAnim:Play()
        for _, visual in ipairs(self:Visuals()) do
            visual.disappear:Stop()
            visual.appear:Play()
        end
        self.disc.shimmerT, self.disc.shimmerWait = -1, 0.4 -- one streak right after opening
    end
    if ns.Sound then ns.Sound:Play("Open") end
end

function Roulette:Close()
    if not self.open then
        return
    end
    if InCombatLockdown() then
        return -- closed at combat entry; nothing to do under lockdown
    end
    self.open = false
    self.escape:Hide()
    self:Disarm()
    self:HideInfo()
    if ns.Sound then ns.Sound:Play("Close") end
    if Anim.Enabled() then
        self.openAnim:Stop()
        self.closeAnim:Play()
        for _, visual in ipairs(self:Visuals()) do
            visual.appear:Stop()
            visual.disappear:Play()
        end
    else
        self:FinishClose()
    end
end

-- Per frame while open (driven by Disc's updater): smooth each node's
-- hover glow.
function Roulette:UpdateNodes(elapsed)
    for _, node in ipairs(self.slots) do
        if node.hover ~= node.hoverTarget then
            node.hover = Disc.Approach(node.hover, node.hoverTarget, elapsed, 0.18, 0.26)
            ns.Node.PaintGlow(node)
        end
    end
end

-- Node and orb visuals animate with their own groups: they hang off the
-- secure buttons, not off the stage.
function Roulette:Visuals()
    local list = { self.orb }
    for _, node in ipairs(self.slots) do
        list[#list + 1] = node
    end
    return list
end

function Roulette:ResetVisuals()
    for _, visual in ipairs(self:Visuals()) do
        visual.appear:Stop()
        visual.disappear:Stop()
        visual.visual:SetAlpha(1)
    end
end

function Roulette:FinishClose()
    Disc.Stop(self.disc)
    self:ResetVisuals()
    if InCombatLockdown() then
        self.pendingHide = true
        return
    end
    self.root:Hide()
    self.stage:SetAlpha(1)
    ns.Presentation:Exit("close")
end

-- The header's eye button: bring the game UI back (to chat) or hide it
-- again, without closing the wheel.
function Roulette:ToggleGameUI()
    if not self.open or InCombatLockdown() then
        return
    end
    if ns.Presentation:IsGameUIHidden() then
        ns.Presentation:ShowGameUI()
    else
        ns.Presentation:HideGameUIAgain(self.root)
        if self.LiftShownDialogs then self.LiftShownDialogs() end
    end
end

function Roulette:Toggle()
    if self.open then
        self:Close()
    else
        self:Open()
    end
end

-- Combat entry: runs inside PLAYER_REGEN_DISABLED, which is still
-- unlocked (measured), so the wheel can close synchronously.
function Roulette:OnCombatStart()
    self:Disarm()
    if not self.open then
        return
    end
    self.open = false
    self.escape:Hide()
    self.openAnim:Stop()
    self.closeAnim:Stop()
    self:ResetVisuals()
    Disc.Stop(self.disc)
    self:HideInfo()
    ns.Presentation:ForceExit("combat")
    if InCombatLockdown() then
        -- Lockdown already on (another handler ran long): fade the visuals
        -- and hide at combat end. The buttons stay where they are.
        self.stage:SetAlpha(0)
        self.pendingHide = true
        return
    end
    self.root:Hide()
end

function Roulette:OnCombatEnd()
    if self.pendingHide and not self.open then
        self.pendingHide = false
        self.root:Hide()
        self.stage:SetAlpha(1)
    end
end

-- Esc / Alt+Z through LibShowcase, or another forced restore.
function Roulette:OnForcedExit(reason)
    if self.open and not InCombatLockdown() then
        self.open = false
        self.escape:Hide()
        self:HideInfo()
        Disc.Stop(self.disc)
        self.root:Hide()
    end
end

------------------------------------------------------------
-- Preview (no casting possible)
------------------------------------------------------------

function Roulette:SetPreview(on)
    if InCombatLockdown() then
        printf("Can't change preview in combat.")
        return
    end
    self.preview = on and true or false
    self:Create()
    self:Resolve()
    SA.RunSyncs() -- clears every attribute family while in preview
    self:Paint()
    printf(self.preview and "Preview on: every destination is shown, nothing can be cast."
        or "Preview off.")
end

------------------------------------------------------------
-- Grouped-teleport confirmation
------------------------------------------------------------

StaticPopupDialogs = StaticPopupDialogs or {}
StaticPopupDialogs.PORTALROULETTE_CONFIRM_TELEPORT = {
    text = "You are in a group. Teleport to %s yourself?",
    button1 = YES or "Yes",
    button2 = NO or "No",
    OnAccept = function()
        Roulette:Arm()
    end,
    timeout = 0,
    whileDead = false,
    hideOnEscape = true,
    preferredIndex = 3,
}

function Roulette:Arm()
    if InCombatLockdown() then
        return
    end
    self.armed = { expires = GetTime() + CONFIRM_SECONDS }
    SA.RunSyncs()
    printf("Teleport armed: click the destination again within " .. CONFIRM_SECONDS .. " seconds.")
    local token = self.armed
    C_Timer.After(CONFIRM_SECONDS, function()
        if Roulette.armed == token then
            Roulette:Disarm()
        end
    end)
end

function Roulette:Disarm()
    if self.armed then
        self.armed = nil
        SA.MarkDirty()
    end
end

------------------------------------------------------------
-- Node interaction (all insecure: visuals, sounds, messages)
------------------------------------------------------------

local function teleportLine(resolved)
    local c = Panels.Hex(ns.Colors.TELEPORT)
    if not resolved.teleportID then
        return nil
    end
    local name = API.SpellName(resolved.teleportID) or resolved.name
    if resolved.teleportKnown then
        return c .. name .. "|r  ·  Left-click"
    end
    return "|cff999999" .. name .. "  ·  Learn at " .. (resolved.entry.tLevel or "?") .. "|r"
end

local function portalLine(resolved, reagentState)
    local c = Panels.Hex(ns.Colors.PORTAL)
    if resolved.id == "karazhan" then
        if resolved.state == "ready" then
            return c .. "Portal: Karazhan|r  ·  Right-click"
        end
        return "|cff999999Equip Atiesh to open Portal: Karazhan|r"
    end
    if not resolved.portalID then
        return nil
    end
    local name = API.SpellName(resolved.portalID) or resolved.name
    if not resolved.portalKnown then
        return "|cff999999" .. name .. "  ·  Learn at " .. (resolved.entry.pLevel or "?") .. "|r"
    end
    local line = c .. name .. "|r  ·  Right-click"
    if reagentState ~= "free" then
        local raw = API.ItemCountRaw(ns.Constants.ITEM_RUNE_PORTALS)
        if API.Readable(raw) and type(raw) == "number" then
            line = line .. "  —  Rune of Portals ×" .. raw
        end
    end
    return line
end

function Roulette:OnNodeEnter(node)
    local resolved = self.assigned and self.assigned[node]
    if not resolved then
        return
    end
    Disc.SetIntent(self.disc, ns.Mode.TELEPORT)
    Disc.SetLinkLit(self.disc, node.index, true)
    local lines = {}
    lines[#lines + 1] = teleportLine(resolved)
    lines[#lines + 1] = portalLine(resolved, self.reagentState)
    if #lines == 0 then
        lines[1] = resolved.name
    end
    Panels.ShowInfo(self.info, node, self.disc, lines)
    if ns.Sound then
        ns.Sound:Play(resolved.id == "karazhan" and "KarazhanHover" or "NodeHover")
    end
end

function Roulette:OnNodeLeave(node)
    Disc.SetLinkLit(self.disc, node.index, false)
    self:HideInfo()
end

function Roulette:HideInfo()
    if self.info then
        self.info:Hide()
    end
end

function Roulette:OnNodeClick(node, mouseButton)
    local resolved = self.assigned and self.assigned[node]
    if not resolved then
        return
    end
    if mouseButton == "RightButton" then
        Disc.SetIntent(self.disc, ns.Mode.PORTAL)
    end
    if self.preview then
        local spellID = mouseButton == "RightButton" and resolved.portalID or resolved.teleportID
        printf("Preview: " .. ((spellID and API.SpellName(spellID)) or resolved.name) .. " is not cast in preview.")
        return
    end
    if mouseButton == "LeftButton" and resolved.teleportKnown and self:NeedsConfirm() and not InCombatLockdown() then
        local popup = StaticPopup_Show("PORTALROULETTE_CONFIRM_TELEPORT", resolved.name)
        ns.Presentation:LiftPopup(popup)
        return
    end
    if ns.Sound then ns.Sound:Play("NodeClick") end
end

function Roulette:OnOrbEnter(orb)
    local source = orb.source
    local lines = {}
    if source then
        lines[1] = Panels.Hex(ns.Colors.TELEPORT) .. (source.name or "Hearthstone") .. "|r  ·  Left-click"
        local where = ns.Hearth:BindLocation()
        if where then lines[2] = "|cffbbbbbb" .. where .. "|r" end
    else
        lines[1] = "|cff999999No Hearthstone|r"
    end
    self.info:SetHeight(lines[2] and 52 or 32)
    self.info.line1:SetText(lines[1])
    self.info.line2:SetText(lines[2] or "")
    self.info:ClearAllPoints()
    self.info:SetPoint("LEFT", self.disc, "RIGHT", 12, 0)
    self.info:Show()
end

function Roulette:OnOrbLeave()
    self:HideInfo()
end

function Roulette:OnOrbClick(orb)
    if self.preview then
        printf("Preview: the hearth is not used in preview.")
        return
    end
    if ns.Sound then ns.Sound:Play("HearthstoneClick") end
end

------------------------------------------------------------
-- Casting
------------------------------------------------------------

function Roulette:OnCastStart(info)
    if not self.open then
        return
    end
    Disc.SetIntent(self.disc, info.mode == ns.Mode.PORTAL and ns.Mode.PORTAL or ns.Mode.TELEPORT)
end

function Roulette:OnCastEnd(info, succeeded)
    if succeeded and self.open and info.mode ~= "utility" then
        self:Close()
    end
end

------------------------------------------------------------
-- Position, scale, options
------------------------------------------------------------

function Roulette:ApplyPosition()
    if not self.root or InCombatLockdown() then
        return
    end
    local pos = ns.db.roulette
    self.root:ClearAllPoints()
    self.root:SetPoint(pos.point or "CENTER", UIParent, pos.point or "CENTER", pos.x or 0, pos.y or 0)
end

function Roulette:ApplyScale()
    if not self.root or InCombatLockdown() then
        return
    end
    self.root:SetScale(tonumber(ns.db.uiScale) or 1)
end

function Roulette:SavePosition()
    local point, _, _, x, y = self.root:GetPoint(1)
    ns.db.roulette.point = point
    ns.db.roulette.x = math.floor((x or 0) + 0.5)
    ns.db.roulette.y = math.floor((y or 0) + 0.5)
end

function Roulette:OpenOptions()
    if InCombatLockdown() then
        return
    end
    self:Close()
    if ns.Options then
        -- After the close: the game UI is back once the fade has run.
        C_Timer.After(0.2, function() ns.Options:Open() end)
    end
end

------------------------------------------------------------
-- Events
------------------------------------------------------------

function Roulette:Initialize()
    local Events = ns.Events
    local function refresh()
        if Roulette.root then Roulette:Refresh() end
    end
    local function paint()
        if Roulette.root then Roulette:Paint() end
    end
    Events:Register("PLAYER_REGEN_DISABLED", function() Roulette:OnCombatStart() end)
    Events:Register("PLAYER_REGEN_ENABLED", function() Roulette:OnCombatEnd() end)
    for _, event in ipairs({ "SPELLS_CHANGED", "PLAYER_EQUIPMENT_CHANGED", "GET_ITEM_INFO_RECEIVED",
        "SPELL_DATA_LOAD_RESULT", "BAG_UPDATE_DELAYED", "GROUP_ROSTER_UPDATE", "HEARTHSTONE_BOUND",
        "TRAIT_CONFIG_UPDATED", "PLAYER_LEVEL_UP" }) do
        Events:Register(event, refresh)
    end
    for _, event in ipairs({ "SPELL_UPDATE_COOLDOWN", "BAG_UPDATE_COOLDOWN" }) do
        Events:Register(event, paint)
    end
    Events:Register("PLAYER_LOGOUT", function()
        ns.Presentation:ForceExit("logout")
    end)

    -- Pressing Enter (or /) to type opens the chat edit box, which lives in
    -- the hidden game UI: bring the UI back so the player can see and type.
    -- The wheel stays open.
    local function onChatActivated()
        if Roulette.open then
            ns.Presentation:ShowGameUI()
        end
    end
    if ChatFrameUtil and ChatFrameUtil.ActivateChat then
        hooksecurefunc(ChatFrameUtil, "ActivateChat", onChatActivated)
    elseif ChatEdit_ActivateChat then
        hooksecurefunc("ChatEdit_ActivateChat", onChatActivated)
    end

    -- A dialog that appears while the game UI is hidden (a guild or party
    -- invite, a ready check...) would be invisible, and Escape would decline
    -- it unseen (StaticPopup_EscapePressed runs first). Lift it above the
    -- hidden UI so the player sees it and chooses.
    local function liftShownDialogs()
        if Roulette.open and ns.Presentation.active and StaticPopup_ForEachShownDialog then
            StaticPopup_ForEachShownDialog(function(dialog)
                ns.Presentation:LiftPopup(dialog)
            end)
        end
    end
    Roulette.LiftShownDialogs = liftShownDialogs
    if StaticPopup_Show then
        hooksecurefunc("StaticPopup_Show", liftShownDialogs)
    end
    if StaticPopupSpecial_Show then
        hooksecurefunc("StaticPopupSpecial_Show", function(frame)
            if Roulette.open and ns.Presentation.active then
                ns.Presentation:LiftFrame(frame)
            end
        end)
    end
end
