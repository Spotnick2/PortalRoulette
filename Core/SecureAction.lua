-- ============================================================
-- SecureAction: the single writer of secure attributes.
--
-- Adapted from Apotheca's ApplySecureItemAttributes (Apotheca.lua:2215) and
-- its PLAYER_REGEN_ENABLED re-apply, extended to numbered spell/item/toy/
-- macro families. Rules (measured on 70205, docs/FOREVER-PROBE.md):
--   * SecureActionButtonTemplate, RegisterForClicks("AnyUp", "AnyDown"):
--     one cast per click whichever edge the player casts on.
--   * Numbered families only: typeN + spellN / itemN / toyN / macrotextN.
--     Unnumbered `type` is never set, so an unbound button does nothing.
--   * NEVER typerelease (any variant): with ActionButtonUseKeyHeldSpell on
--     it casts twice and consumes two reagents.
--   * SetAttribute silently does nothing in combat: writes happen out of
--     combat only, through a coalesced rebuild (MarkDirty -> sync) that
--     resolves the CURRENT state when it runs, never a replay of old writes.
-- ============================================================

local _, ns = ...

local SA = {
    syncs = {},
    dirty = false,
}
ns.SecureAction = SA

local API = ns.API

-- Every attribute family a rebuild clears, numbered and not.
SA.FAMILIES = { "type", "spell", "item", "toy", "macro", "macrotext", "target-slot", "unit" }
SA.SUFFIXES = { "", "1", "2" }

function SA.Create(parent, name)
    local button = CreateFrame("Button", name, parent, "SecureActionButtonTemplate")
    button:RegisterForClicks(API.ClickEdges())
    return button
end

-- Clear every family. Returns false (and changes nothing) in combat.
function SA.Clear(button)
    if InCombatLockdown() then
        return false
    end
    for _, family in ipairs(SA.FAMILIES) do
        for _, suffix in ipairs(SA.SUFFIXES) do
            if button:GetAttribute(family .. suffix) ~= nil then
                button:SetAttribute(family .. suffix, nil)
            end
        end
    end
    for _, suffix in ipairs(SA.SUFFIXES) do
        if button:GetAttribute("typerelease" .. suffix) ~= nil then
            button:SetAttribute("typerelease" .. suffix, nil)
        end
    end
    return true
end

-- actions = { [1] = { type = "spell", spell = 3561 }, [2] = { type = "item", item = "16" } }
-- Index 1 is the left mouse button, 2 the right. Everything is cleared
-- first, so a family set by an earlier state never lingers.
function SA.Apply(button, actions)
    if not SA.Clear(button) then
        return false
    end
    for index = 1, 2 do
        local action = actions and actions[index]
        if action and action.type then
            local suffix = tostring(index)
            button:SetAttribute("type" .. suffix, action.type)
            local payloadKey = action.type == "macro" and "macrotext" or action.type
            local payload = action[payloadKey]
            if payload ~= nil then
                button:SetAttribute(payloadKey .. suffix, payload)
            end
        end
    end
    return true
end

-- True when the button would do something on a click.
function SA.HasAction(button)
    for _, suffix in ipairs(SA.SUFFIXES) do
        if button:GetAttribute("type" .. suffix) ~= nil then
            return true
        end
    end
    return false
end

------------------------------------------------------------
-- Coalesced sync
------------------------------------------------------------

-- Register a function that rebuilds attributes from the current state.
function SA.RegisterSync(fn)
    SA.syncs[#SA.syncs + 1] = fn
end

function SA.RunSyncs()
    if InCombatLockdown() then
        SA.dirty = true
        return false
    end
    SA.dirty = false
    for _, fn in ipairs(SA.syncs) do
        fn()
    end
    return true
end

-- Ask for a rebuild: now when possible, otherwise once combat ends. Many
-- requests in one frame collapse into one rebuild.
function SA.MarkDirty()
    SA.dirty = true
    if SA.pending then
        return
    end
    SA.pending = true
    C_Timer.After(0, function()
        SA.pending = false
        if SA.dirty then
            SA.RunSyncs()
        end
    end)
end

function SA.Initialize()
    ns.Events:Register("PLAYER_REGEN_ENABLED", function()
        if SA.dirty then
            SA.RunSyncs()
        end
    end)
end

------------------------------------------------------------
-- Cooldowns: values may be secret in combat. They go to the widget
-- untouched; only their presence is checked, through type() on a
-- non-secret value.
------------------------------------------------------------

function SA.ApplyItemCooldown(cooldown, itemID)
    if not cooldown or not itemID then
        return
    end
    local ok, start, duration = pcall(API.ItemCooldown, itemID)
    if not ok then
        return
    end
    if not API.Readable(start) or not API.Readable(duration) then
        pcall(cooldown.SetCooldown, cooldown, start, duration)
        return
    end
    if type(start) ~= "number" or type(duration) ~= "number" then
        cooldown:Clear()
        return
    end
    cooldown:SetCooldown(start, duration)
end

function SA.ApplySpellCooldown(cooldown, spellID)
    if not cooldown or not spellID then
        return
    end
    local duration = API.SpellCooldownDuration(spellID)
    if duration == nil then
        cooldown:Clear()
        return
    end
    pcall(cooldown.SetCooldownFromDurationObject, cooldown, duration)
end
