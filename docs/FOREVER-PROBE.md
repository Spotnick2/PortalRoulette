# Forever probe results

What `Tools/PortalRouletteProbe` (`/fp pr`, a ForeverProbe module; `/prprobe` before #13) measured
on the WoW: Forever client. The rule is **measured beats reasoned**: code relies on a row here only
once it says MEASURED.

## How to run it

The probe is a module of ForeverProbe, the shared probe host (`..\ForeverProbe`, its
`docs/GUIDE.md`). Its lines go to the `/fp` console and to its saved log, never to chat.

1. Deploy it with `pwsh Tools/deploy.ps1 -ProbeOnly` (or `-Probe`, with the addon). Either one
   deploys ForeverProbe first, then the probe. `/reload` loads them, a brand-new folder included.
2. Log in on the mage, then run `/console scriptErrors 1`.
3. Run the commands and procedures below. A procedure (`/fp steps pr <name>`) is a small panel of
   buttons, one step at a time: it saves every outcome, and the owner types what they see in its
   Note box. `/fp` shows the console.
4. `/reload` (or log out), so the client writes the results. A session then reads them from
   `WTF\Account\<ACCOUNT>\SavedVariables\`, so nothing needs sending:
   - `PortalRouletteProbe.lua`: `log` (every line, the `STEP` lines included) and each run's own
     lines, in the format the results below were read from (`core`, `tips`, `traits`, `secure`,
     `combat`, `gfx`, `popup`, `persist`, `reagentbag`, `reagenteconomy`, `scan`, `logins`, ...);
   - `ForeverProbe.lua`: `steps.records` (each procedure's results and notes), the screenshots,
     and the blocked actions in the host's `log`.

| Step | Command | What it does |
|---|---|---|
| 1 | `/fp pr core` | Core run: spell and item IDs, hearth, toys, talents, spellbook, CVars. Instant. |
| 2 | `/fp pr tips` | Spell tooltips for every teleport and portal (about 5 s, async). |
| 3 | `/fp pr scan` | Finds every "Teleport:"/"Portal:" spell ID, including the Dalaran ID. It takes a few minutes; progress is logged, and running it again cancels. `/fp pr find <text>` also matches names containing the text. |
| 4 | `/fp steps pr secure` | Shows the secure test buttons, waits until each was left-clicked once and the "R" one right-clicked too, then waits for a fight (a training dummy or a mob) with the panel shown: the combat tests run once lockdown starts. Then it waits for the end of combat. |
| 5 | `/fp steps pr keyup` | Step 4 with `ActionButtonUseKeyDown` set to 0 (the cast-on-release path), then puts the CVar back. |
| 6 | `/fp steps pr gfx` | Shows the graphics panel, asks whether it looks right and takes a screenshot, then hides it. |
| 7 | `/fp steps pr popup` | Runs the popup test, asks whether an "experimental CVar" confirmation popup appeared, then a `/reload` and a minute of play: checks no action was blocked, and asks about taint errors. |
| 8 | `/fp steps pr persist` | Writes the camera CVar markers, asks for a **full exit** and relaunch, reads them back at login (PASS = they persisted), then restores them. |
| 9 | `/fp steps pr reagentbag` | Asks for one Rune of Teleportation in the **reagent bag**, then reads the count and every bag. PASS = `GetItemCount` includes the reagent bag. |
| 10 | `/fp steps pr talent` | Asks for the talent or perk that removes reagent costs (its name in the Note box) and whether it is learned, then records the talent tree and which Reagent Economy spell ID is known. |

The one-off commands are also there: `/fp pr secure` and `/fp pr gfx` (show or hide the panels),
`/fp pr spell <id>`, `/fp pr item <id>`, `/fp pr traits`, `/fp pr popup`, `/fp pr cvarmark` /
`cvarrestore`, and `/fp pr clear` (empties the saved results and the log). `/fp pr` lists them.
The results below name the old commands (`/prprobe ...`) they were measured with.

## Results

Run 1: build 70205, 2026-10-04. Level-10 High Order Skyborne mage (Alliance), bound at Valanaar.

### Spells
| Item | Status | Result |
|---|---|---|
| Vanilla teleport IDs 3561/3562/3565/3567/3563/3566 exist | MEASURED 70205 | All exist; names are correct; cast time 9.9 s; 120 mana. |
| Vanilla portal IDs 10059/11416/11419/11417/11418/11420 exist | MEASURED 70205 | All exist; 850 mana; 10 yd range; 1 min cooldown. |
| Teleport: Dalaran spell ID(s) | MEASURED 70205 | **1297659, 1297660, 1308652**. It is still OPEN which one a mage learns (needs level 50). The data table lists all three, known one first. |
| Other new travel spells | MEASURED 70205 | **Portal: Karazhan 28148** (the TBC Atiesh spell) and **Portal: Valanaar 1269466** (Skyborne home zone?) exist. Also Portal: Elsewhere 1232033 and Teleport: Elsewhen 465789 (unrelated?). The `tips` run of probe v2 dumps their tooltips. |
| `C_Spell.GetSpellDescription` | MEASURED 70205 | Returns nothing for the Horde-side spells on an Alliance character. Use names and tooltips, not descriptions. |
| Spell cooldown out of combat | MEASURED 70205 | A plain struct `{startTime, duration, isEnabled, isActive, modRate}`. |

### Items and reagents
| Item | Status | Result |
|---|---|---|
| Rune of Teleportation 17031 / Rune of Portals 17032 exist | MEASURED 70205 | Both exist, class 15/1 "Reagent". 17032 was uncached at first (GetItemInfo returned nothing; GetItemInfoInstant and GetItemIconByID work). |
| Counts include the reagent bag (bag 5) | OPEN | No reagent bag equipped yet (bag5.slots = 0). |
| Reagent line format in spell tooltips | MEASURED 70205 | Line text is `"Reagents: \|n\|cffff2020Rune of Teleportation\|r"`, red when missing. The data loaded on the first try. |
| Reagent-free talent: name and spell ID | PARTIAL | It is the **Perk "Reagent Economy"** (1 rank, Resourcefulness tab): "Your class abilities no longer require reagents purchasable from vendors". It is not a class talent. Its spell ID comes from `/prprobe scan` (probe v2); detect it with `IsPlayerSpell(id)`. |
| Atiesh 22589 exists | MEASURED 70205 | It exists (2H staff); GetItemSpell was uncached. Portal: Karazhan 28148 exists as a spell. |
| Crumbling Hearthstone 282006 | MEASURED 70205 | It exists (consumable); not carried. |

### Hearth
| Item | Status | Result |
|---|---|---|
| `C_Container.PlayerHasHearthstone()` | MEASURED 70205 | **Returns nil even with Hearthstone 6948 in the backpack.** Fall back to `C_Item.GetItemCount(6948)`. |
| Hearthstone item spell | MEASURED 70205 | `GetItemSpell(6948)` = "Hearthstone", 8690. |
| Toys | MEASURED 70205 | `C_ToyBox.GetNumToys()` = 20, none owned. |
| Secure `type1=item` hearth casts once per click | MEASURED 70959 | Yes: 2 edges, 1 cast, clicked on its own (run 3, second pass). The first pass's 2 casts shared a quick click on the next button. |
| Secure `type1=toy` | OPEN | Run 3: 0 casts, no error, with toy 289439 on both passes, possibly on cooldown. |

### Secure casting (ActionButtonUseKeyDown = 1)
| Item | Status | Result |
|---|---|---|
| `spell1=<numeric ID>` casts | MEASURED 70205 | Yes: 2 edges, 1 cast per click. Rank 1 is cast when given the rank-1 ID: Frost Armor 168. |
| `spell1=<name>` casts | MEASURED 70205 | Yes, 1 cast. |
| `type2/spell2` on right-click | MEASURED 70205 | Yes, 1 cast. Left-click on a type2-only button casts nothing (no fallthrough). |
| `useOnKeyDown` true/false attribute | MEASURED 70205 | Both give 1 cast per click with the CVar at 1. |
| ActionButtonUseKeyDown = 0 | OPEN | |
| `itemN="16"` main-hand slot | INCONCLUSIVE | 0 casts and no error, because the weapon has no Use effect. |
| In combat: EnableMouse/SetAlpha/SetParent/SetUIVisibility | MEASURED 70959 | Under lockdown, on a secure button and its panel: **blocked** (ADDON_ACTION_BLOCKED, no effect): EnableMouse, SetAttribute, the panel's SetParent, SetUIVisibility(false) and (true). **Allowed**: SetAlpha on the button and the panel, UIParent:SetAlpha. Run 3 has the lines. |

### Graphics
| Item | Status | Result |
|---|---|---|
| Unsliced circle masks at 40, 64 and 320 px (TempPortraitAlphaMask) | MEASURED 70205 | No errors. The screenshot shows round clipping. The icon's own black corners make the 320 px edge hard to judge. |
| Rotation stays clipped under a static mask | MEASURED 70205 | A round gradient disc, clipped. |
| `SetRadialProgressBarPercent` on a masked texture | MEASURED 70205 | Draws a partial disc. |
| `C_Spell.GetSpellCooldownDuration` + `SetCooldownFromDurationObject` | MEASURED 70205 | Returns a LuaDurationObject and accepts it; no swipe, since the hearth was not on cooldown. |
| `CreateLine` | MEASURED 70205 | Works. |

### Misc
| Item | Status | Result |
|---|---|---|
| `WOW_PROJECT_ID` | MEASURED 70205 | 18. |
| Specialization | MEASURED 70205 | `GetSpecializationInfo(1)` = 1482 "Mage" with pointsSpent 0; specs 2 and 3 are empty. There are **no talent tabs**, so the launcher theme cannot come from points per tab: use C_Traits, or drop it. |
| Spellbook lines | MEASURED 70205 | General / Frost / Fire / Arcane. |
| Camera CVar defaults | MEASURED 70205 | test_cameraOverShoulder 0, CameraKeepCharacterCentered **1**, CameraReduceUnexpectedMovement 0, cameraDistanceMaxZoomFactor 1, cameraViewBlendStyle 1, ActionButtonUseKeyDown 1, ActionButtonUseKeyHeldSpell 0. |
| CVar persistence | PARTIAL | Across a `/reload`, CameraKeepCharacterCentered kept the marker (0) and test_cameraOverShoulder did not (it reverted to 0). A full restart is still OPEN. |
| `GameEvent.UnregisterInternalEvent` | MEASURED 70205 | Callable; no ADDON_ACTION_BLOCKED. Popup visibility and taint are still OPEN. |
| `PlayerCanTeleport()` | MEASURED 70205 | true. |
| `GetBindLocation()` | MEASURED 70205 | "Valanaar". |

## Deferred acceptance (needs a higher-level mage)
- Real teleports at levels 20/30, and portals at 40/50 consuming exactly one rune.
- Teleport: Dalaran at 50.
- The reagent-free talent on/off tooltip comparison, which gates the tooltip signal in Auto mode.
- Karazhan through an equipped Atiesh.

## Launcher pickup investigation (2026-10-05)

- Owner observation: normal left-drag reaches the launcher handler, but after
  `pcall(PickupMacro, index)` returns successfully, `GetCursorInfo()` does not
  report a macro. Repeated three times. Shift-drag moves the launcher correctly.
- The saved launcher macro exists with body `/pr` and the custom launcher TGA
  path. This does not establish that the client resolves that icon for pickup.
- Owner isolated the cause in Blizzard's `/macro` window: **no icon was set**,
  and dragging failed there too. Assigning an icon made the same macro draggable.
  This confirms icon resolution, rather than the launcher's mouse handler, is the
  cause of this report. The launcher now supplies a native numeric icon for macros
  and preserves icons selected manually. Its own custom textures remain separate.
- Unit-test pickup fakes verify addon control flow only, not client acceptance.

## Run 2 (build 70205, 2026-10-04)
- **Reagent Economy** perk spell IDs: 1225503, 1262636, 1262638, 1262643, 1262647, 1262650, 1262654 and 1262662 (one per class?). None is known at level 10. Detection is "free" when `IsPlayerSpell` is true for any of them. Which ID belongs to mages is still OPEN until the perk can be taken.
- Teleport: Dalaran tooltips:
  - **1297659** is the mage spell: 120 mana, 9.9 s cast, Rune of Teleportation.
  - **1308652** has no reagent ("Teleports you to Dalaran"), so it is probably an item or other source.
  - 1297660 is an instant, 100 yd effect spell.
  - The table uses 1297659 first, then 1308652.
- Portal: Karazhan 28148: 10 yd range, 9.9 s cast, 1 min cooldown, no reagent line.
- Portal: Valanaar 1269466: 0.25 s cast, 1 min cooldown. This is not a mage spell (a zone/NPC portal); the addon ignores it.
- Portal: Elsewhere 1232033 and Teleport: Elsewhen 465789 are unrelated (an NPC ability and a Tanaris event).
- `SPELL_DATA_LOAD_RESULT` fires for each requested spell (success = true).
- Secure **`type1=macro`, `macrotext1="/use item:6948"`**: 1 cast per left click; right click does nothing. The `type1=item` hearth button was not recorded (OPEN).
- The experimental-CVar popup did **not** appear after `GameEvent.UnregisterInternalEvent` + writing `test_cameraOverShoulder` (no ADDON_ACTION_BLOCKED). Taint after `/reload`: none reported.
- **`InCombatLockdown()` is false inside `PLAYER_REGEN_DISABLED` handlers**: lockdown starts right after. The combat run therefore measured nothing under lockdown. Probe v3 waits for lockdown; the run is still OPEN. This matters for the addon: anything done in a REGEN_DISABLED handler still runs unlocked, which gives a last out-of-combat moment for restoring the UI.

## Run 3 (build 70959, 2026-11-18)

The first runs on ForeverProbe: `/fp steps pr secure` twice, read from the SavedVariables
(`ForeverProbe.lua` `steps.records`, `PortalRouletteProbe.lua` `secure` and `combat`). Both finished
with the combat check PASS. On the first pass the clicks step was completed by hand (the "R" button
was not right-clicked). On the second it completed itself ("10 clicks recorded"). The combat lines
were the same both times.

**Combat, under lockdown** (`InCombatLockdown() = true`; the panel `IsProtected() = true, false`, i.e.
protected through its secure buttons):

| Call | Result |
|---|---|
| `button:EnableMouse(false)`, then `(true)` | Blocked both times; `IsMouseEnabled()` stays true. |
| `button:SetAlpha(0.5)`, `panel:SetAlpha(0.5)` | Allowed (`GetAlpha()` = 0.502). |
| `button:SetAttribute("probeAttr", 1)` | Blocked; the attribute stays nil. |
| `panel:SetParent(nil)` | Blocked; the parent stays UIParent. |
| `SetUIVisibility(false)`, `SetUIVisibility(true)` | Blocked both times; UIParent stays shown. |
| `UIParent:SetAlpha(1)` | Allowed. |
| `C_Item.GetItemCooldown(6948)` | Plain values: `0, 0, true`, and on the global cooldown `122929.45, 1.5, true`. |
| `C_Spell.GetSpellCooldown(168)` | `startTime`, `duration` and `modRate` secret; `isEnabled` and `isActive` plain. |
| `C_Item.GetItemCount(17031)` | **Plain** (4), not secret, in combat. One reading: keep `ns.API.Readable` on counts. |

Each blocked call raises ADDON_ACTION_BLOCKED, which an error catcher (Bugsy) reports against the probe
as `UNKNOWN()`: expected, since that is what the run measures.

So the guardrails hold: the wheel must hide, reparent and give back the UI before lockdown (inside
`PLAYER_REGEN_DISABLED`, run 2), and only alpha can change in combat.

**Clicks** (ActionButtonUseKeyDown 1). Each line counts the edges and casts from 0.65 s before the
release to 0.6 s after, so quick clicks on neighbouring buttons share them:
- `spell1` numeric, `spell1` by name, `useOnKeyDown` true and false: 2 edges, 1 cast each, as on 70205.
- `type2` button: left-click 0 casts (no fallthrough), right-click 2 edges, 1 cast, as on 70205.
- `hearth item:ID` (`type1=item`): 2 edges, 1 cast on the second pass. The first pass counted 2 casts
  because the "hearth macro" button was clicked right after (its lines show 4 and 3 edges) and its
  cast fell in the same window.
- `hearth macro`: 1 cast per click.
- `toy 289439` (`type1=toy`): 0 casts, no error, on both passes. INCONCLUSIVE: the toy may have been
  on cooldown.
- `item1="16"`: 0 casts, as on 70205 (no Use effect).
