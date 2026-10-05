# Forever probe results

What `Tools/PortalRouletteProbe` (`/prprobe`) measured on the WoW: Forever client. The rule is
**measured beats reasoned**: code relies on a row here only once it says MEASURED.

## How to run it

1. Deploy it with `pwsh Tools/deploy.ps1 -ProbeOnly`. It is a separate dev addon, and a new addon
   folder needs a **client restart**.
2. Log in on the mage, then run `/console scriptErrors 1`.
3. Run each command below, then `/reload` (or log out) so the client writes
   `WTF\Account\<ACCOUNT>\SavedVariables\PortalRouletteProbe.lua`.
4. Send that file, plus screenshots where asked.

| Step | Command | What to do |
|---|---|---|
| 1 | `/prprobe` | Core run: spell and item IDs, hearth, toys, talents, spellbook, CVars. Instant. |
| 2 | `/prprobe tips` | Spell tooltips for every teleport and portal (about 5 s, async). |
| 3 | `/prprobe scan` | Finds every "Teleport:"/"Portal:" spell ID, including the Dalaran ID. It takes a few minutes; progress is printed, and running it again cancels. |
| 4 | `/prprobe secure` | A panel of secure test buttons appears on the left. Left-click each once; right-click the "R" one. Then, **with the panel shown**, pull a training dummy or a mob: the combat tests run on combat entry. |
| 5 | Repeat step 4 after `/console ActionButtonUseKeyDown 0` | Checks the cast-on-release path. Afterwards, `/console ActionButtonUseKeyDown 1` restores the default. |
| 6 | `/prprobe gfx` | A graphics panel appears. **Take a screenshot.** Run `/prprobe gfx` again to hide it. |
| 7 | `/prprobe popup` | Note whether a "experimental CVar" confirmation popup appears. Then `/reload`, play a minute, and note any taint errors. |
| 8 | `/prprobe cvarmark`, then **exit the game fully**, start it again, log in, then `/prprobe cvarrestore` | Checks whether camera CVars persist across a restart. |
| 9 | Put one Rune of Teleportation in the **reagent bag**, then `/prprobe item 17031` | Checks whether the count includes the reagent bag. |
| 10 | Open the talent UI, find the talent that removes reagent costs, and tell us its name | We then look its spell ID up in the core run's `talent.*` lines. |

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
| Secure `type1=item` hearth casts once per click | OPEN | Probe v2 adds "hearth item:ID" and "hearth macro" buttons. |
| Secure `type1=toy` | OPEN | Needs an owned toy. |

### Secure casting (ActionButtonUseKeyDown = 1)
| Item | Status | Result |
|---|---|---|
| `spell1=<numeric ID>` casts | MEASURED 70205 | Yes: 2 edges, 1 cast per click. Rank 1 is cast when given the rank-1 ID: Frost Armor 168. |
| `spell1=<name>` casts | MEASURED 70205 | Yes, 1 cast. |
| `type2/spell2` on right-click | MEASURED 70205 | Yes, 1 cast. Left-click on a type2-only button casts nothing (no fallthrough). |
| `useOnKeyDown` true/false attribute | MEASURED 70205 | Both give 1 cast per click with the CVar at 1. |
| ActionButtonUseKeyDown = 0 | OPEN | |
| `itemN="16"` main-hand slot | INCONCLUSIVE | 0 casts and no error, because the weapon has no Use effect. |
| In combat: EnableMouse/SetAlpha/SetParent/SetUIVisibility | OPEN | The combat run did not save. Probe v2 saves incrementally and runs whenever the panel is shown. |

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
