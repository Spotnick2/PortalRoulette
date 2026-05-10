# Portal Roulette agent instructions

## Deployment
- After local changes, deploy addon files to:
  - `C:\Program Files (x86)\World of Warcraft\_anniversary_\Interface\AddOns\PortalRoulette`
- Use the approved PowerShell executable for Windows commands when the default shell runner is unreliable:
  - `C:\Users\nicol\AppData\Local\Microsoft\WindowsApps\pwsh.exe -Command '...'`
- Prefer single-quoted `-Command` payloads when the command uses PowerShell variables like `$source`, `$dest`, `$i`, `$_`, or `$LASTEXITCODE`; double-quoted payloads can be expanded by the wrapper before PowerShell receives them.
- Deploy with a tracked-file copy from `git ls-files`; do not copy untracked review/temp folders such as `.tmp_video_review`.

## Addon context (TBC Classic Anniversary)

### Core product goals
- Mage-only addon.
- One launcher button:
  - **Left-click** opens Teleport roulette.
  - **Right-click** opens Portal roulette.
- Main UI is a **floating no-box arcane wheel** (not a large rectangular window).

### Visual and UX direction
- Arcane blue/purple runic circle with subtle glow — **no rectangular box frame**.
- **Title bar** at top: "Portal Roulette" with decorative runic flanks.
- **Mode tabs row** below title: `[Teleports]` `[Portals]` tabs + `[⚙]` gear icon on the right.
  - Left-click launcher -> open panel with Teleports tab active.
  - Right-click launcher -> open panel with Portals tab active.
  - User can also click tabs directly to switch modes.
- **Destination ring**: 6 nodes connected by lines to a central arcane star core, at clock positions 12/10/2/8/4/6.
  - Horde clockwise from top: Orgrimmar, Thunder Bluff, Stonard, Shattrath, Silvermoon, Undercity.
  - Alliance clockwise from top: Stormwind, Darnassus, Theramore, Shattrath, The Exodar, Ironforge.
- **Karazhan bonus node**: outside the main ring at ~4-o'clock, connected by a line; labeled "Karazhan / Atiesh only"; smaller + distinct purple art.
- **Reagent panel**: floats LEFT of the wheel; two rows: Rune of Teleportation + Rune of Portals.
- **Hint bar**: below the wheel — "Left Click: Teleport · Right Click: Portal / Reagents are shared."
- **Single utility button**: large, full-width below hint bar; shows current utility icon + name only.
- **Utility chip selector** (Hearthstone / Dark Portal / Naaru's Embrace / Random) is in **Options only** — NOT shown on the main overlay.
- Minimap button (hideable from options).

### Required gameplay behavior
- Faction-aware destination sets:
  - Horde: Orgrimmar, Undercity, Thunder Bluff, Silvermoon, Stonard, Shattrath.
  - Alliance: Stormwind, Ironforge, Darnassus, The Exodar, Theramore, Shattrath.
- Karazhan is a **special Atiesh-only bonus node** (smaller, visually distinct, conditional).
- Reagents are shared globally (Rune of Teleportation + Rune of Portals only).
- Utility behavior is configured in options; only one active main utility button:
  - Hearthstone, Dark Portal, Naaru's Embrace, or Random.

### Configuration requirements
- Utility selection (single active mode).
- Toggle showing unavailable Karazhan.
- Toggle cinematic camera mode (default OFF).
- Toggle launcher lock.
- Toggle minimap button visibility.
- UI scale setting.
- Reset position action.

### Technical guardrails
- TOC interface number: `20505` (TBC Anniversary, confirmed from AltTracker.toc).
- Target World of Warcraft Classic TBC-era compatibility (avoid Retail-only assumptions).
- Prioritize secure casting-safe patterns and combat-lockdown safety.
- Non-mage characters should not get UI clutter.
- Camera mode is optional polish only (default OFF); character must **face the camera** (not show back to player) — achieved via yaw swing. Must restore camera state cleanly on exit/error/combat.
- Keep animations tasteful and lightweight (fade, slight scale, subtle rotation/pulse/hover).
- Avoid mandatory external libraries; minimap button uses angle-based persistence without LibDBIcon.

### Media notes
- Use media pack TGA assets in `Media\`.
- Prefer mockup/media iconography first (custom TGA style), not built-in WoW spell/item icons.
- Use built-in icons only as fallback when no mockup-equivalent asset exists.
