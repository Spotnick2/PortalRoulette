-- The glass reskin must keep drag-to-macro behavior, action-bar visibility,
-- theme settings and the shared entry-point icon. Macro APIs are listed in
-- the 70205 dump; these fakes record their existing call contract.
dofile("tests/wow_stubs.lua")
local H = dofile("tests/harness.lua")
local customIcon = "Interface\\AddOns\\PortalRoulette\\Media\\Launcher\\Portal_256.tga"
local macro = { name = "Portal Roulette", icon = customIcon, body = "/pr" }
local nativeIcon = 5929586 -- the chosen Forever macro icon
WoW.spells[10059] = { name = "Portal: Stormwind", icon = 135748 }
local edits, picked, placed = 0, nil, false
local macroIndex, reorder, refusePickup, createFails = 121, false, false, false
function GetMacroIndexByName() return macro and macroIndex or 0 end
function GetMacroInfo() if macro then return macro.name, macro.icon, macro.body end end
function CreateMacro(name, icon, body)
    if createFails then error("no free macro slots") end
    macro = { name = name, icon = icon, body = body }
    return macroIndex
end
function EditMacro(index, name, icon, body, ...)
    assert(select("#", ...) == 0, "use the current four-argument EditMacro contract")
    edits = edits + 1
    macro.name, macro.icon, macro.body = name or macro.name, icon or macro.icon, body or macro.body
    if reorder then macroIndex = 122 end
    return macroIndex
end
function PickupMacro(index)
    -- Owner reproduced this in Blizzard's macro UI too: an unset icon
    -- prevents pickup. Assigning a native icon makes that macro draggable.
    if not refusePickup and type(macro.icon) == "number" and macro.icon > 0 then picked = index end
end
function GetCursorInfo() if picked then return "macro", picked end end
function GetActionInfo(slot) if placed and slot == 10 then return "macro", 121 end end

local ns = H.loadAddon()
local L = ns.LauncherButton
local button = L.button
H.eq(macro.icon, nativeIcon, "existing custom macro icon is repaired with a native file ID")
H.eq(macro.body, "/pr", "icon migration preserves macro body")
H.eq(button.art:GetTexture(), ns.Media.LAUNCHER_PORTAL, "launcher uses clear portal artwork")
H.check(button:IsShown(), "unplaced launcher is visible")
button:GetScript("OnDragStart")(button)
H.eq(picked, 121, "drag picks up a macro for the action bar")
H.eq(macro.body, "/pr", "dragged macro still opens the wheel")
H.eq(edits, 1, "dragging an already-prepared macro does not edit it again")
local wasOpen = ns.Roulette.open
button:GetScript("OnDragStop")(button)
button:GetScript("OnClick")(button, "LeftButton")
H.eq(ns.Roulette.open, wasOpen, "drag release cannot open the wheel and hide action bars")
placed = true
L:RefreshVisibility()
H.check(not button:IsShown() and not L.prompt:IsShown(), "placing the macro hides launcher and prompt")
placed = false
L:RefreshVisibility()
H.check(button:IsShown(), "removing macro from bars restores launcher")
macro = nil
L:PickupLauncherMacro()
H.eq(macro.icon, nativeIcon, "new macro uses a resolved native icon")
H.eq(picked, 121, "new macro can be dragged")

macro.body, macro.icon = "/say custom", 134414
L:RefreshExistingMacroIcon()
H.eq(macro.icon, 134414, "login refresh leaves customized macros alone")
macro.body = "/pr"
L:RefreshExistingMacroIcon()
L:PickupLauncherMacro()
H.eq(macro.icon, 134414, "login and drag preserve a manually chosen native icon")
macro.icon = 0
WoW.inCombat = true
local before = edits
L:RefreshExistingMacroIcon()
L:PickupLauncherMacro()
H.eq(edits, before, "no macro edit in combat")
WoW.inCombat = false
WoW.fire("PLAYER_REGEN_ENABLED")
H.eq(macro.icon, nativeIcon, "deferred missing-icon repair runs after combat")
macro.icon = nil
L:PickupLauncherMacro()
H.eq(macro.icon, nativeIcon, "nil macro icon is repaired before pickup")
WoW.spells[10059] = nil
H.eq(L:GetDesiredMacroIcon(), 5929586, "the macro icon does not depend on any spell being cached")
WoW.spells[10059] = { name = "Portal: Stormwind", icon = 135748 }

L:ApplyTheme("fire")
H.eq(L.themeKey, "fire", "theme choice is retained")
H.eq(button.art:GetTexture(), ns.Media.LAUNCHER_PORTAL, "theme colors light rather than swapping detailed art")
button:GetScript("OnEnter")(button)
H.check(button.highlight:GetAlpha() > 0, "hover adds glass light")
button:GetScript("OnLeave")(button)
H.eq(button.highlight:GetAlpha(), 0, "leaving clears glass light")
H.eq(button.art:GetTexture(), ns.Media.LAUNCHER_PORTAL, "hover preserves icon identity")

macro.icon, reorder = customIcon, true
L:PickupLauncherMacro()
H.eq(picked, 122, "pickup uses the index returned after a macro edit")
picked, refusePickup = nil, true
L:PickupLauncherMacro()
H.check(H.messagesMatching("did not put.*cursor") > 0, "silent pickup refusal gives actionable feedback")
refusePickup, createFails, macro = false, true, nil
L:PickupLauncherMacro()
H.check(H.messagesMatching("Macro slots may be full") > 0, "macro capacity failure is handled")
createFails = false

H.check(not button.attention:IsMouseEnabled(), "blue decoration cannot intercept dragging")
H.check(button.attention:IsShown() and button.attentionPulse:IsPlaying(), "placement hint pulses the blue border")
ns.db.actionBarPromptDismissed = true
L:RefreshPromptVisibility()
H.check(not button.attention:IsShown() and not button.attentionPulse:IsPlaying(), "dismissing hint stops attention")
button:GetScript("OnEnter")(button)
H.check(button.attentionPulse:IsPlaying(), "hover tooltip brings back attention")
ns.db.animationsEnabled = false
L:ApplySettings()
H.check(button.attention:IsShown() and not button.attentionPulse:IsPlaying(), "master off leaves static attention")
button:Hide()
H.check(not button.attentionPulse:IsPlaying(), "hiding launcher stops its animation")

-- Minimal dependency fakes let us inspect the broker's actual payload.
local broker = LibStub:NewLibrary("LibDataBroker-1.1", 1)
function broker:NewDataObject(_, obj) return obj end
local dbicon = LibStub:NewLibrary("LibDBIcon-1.0", 1)
function dbicon:Register() end
function dbicon:Show() end
function dbicon:Hide() end
ns.Minimap:Initialize()
H.eq(ns.Minimap.object.icon, ns.Media.LAUNCHER_PORTAL, "minimap shares the portal artwork")

-- The client may hand the saved icon back in another spelling (case,
-- slashes) or as the question mark: still repaired.
macro = { name = "Portal Roulette", icon = "interface/addons/portalroulette/media/launcher/portal_256", body = "/pr" }
L:RefreshExistingMacroIcon()
H.eq(macro.icon, nativeIcon, "a differently spelled addon icon path is repaired")
macro.icon = 134400
L:RefreshExistingMacroIcon()
H.eq(macro.icon, nativeIcon, "a question-mark icon on our /pr macro is repaired")
macro.icon, macro.body = 134400, "/say mine"
L:RefreshExistingMacroIcon()
H.eq(macro.icon, 134400, "someone else's macro body is never touched")

-- Macros not loaded at login: the repair runs again on UPDATE_MACROS.
macro = { name = "Portal Roulette", icon = customIcon, body = "/pr" }
local loaded = false
local realIndex = GetMacroIndexByName
GetMacroIndexByName = function() return loaded and realIndex() or 0 end
L:RefreshExistingMacroIcon()
H.eq(macro.icon, customIcon, "nothing to repair before macros load")
loaded = true
WoW.fire("UPDATE_MACROS")
H.eq(macro.icon, nativeIcon, "repaired once UPDATE_MACROS arrives")
GetMacroIndexByName = realIndex

-- The previous default (Portal: Stormwind's texture) upgrades to the new icon.
macro = { name = "Portal Roulette", icon = 135748, body = "/pr" }
L:RefreshExistingMacroIcon()
H.eq(macro.icon, nativeIcon, "the old default icon is upgraded")

-- A refused EditMacro never aborts the launcher.
local realEdit = EditMacro
EditMacro = function() error("refused") end
macro = { name = "Portal Roulette", icon = customIcon, body = "/pr" }
H.check(pcall(L.RefreshExistingMacroIcon, L), "a refused EditMacro is contained")
EditMacro = realEdit
H.done("test_launcher")
