# Portal Roulette agent instructions

Portal Roulette is a mage-only teleport/portal wheel for **WoW: Forever**: Vanilla content on the
Retail (Mainline) API, client 1.60.1, `## Interface: 16001`. The TBC Anniversary version is frozen
at tag `v0.1.1-tbc` and no longer supported.

Read before changing code:
- `C:\Projects\References\PORTING-TBC-TO-FOREVER.md`: what changed from TBC, measured.
- `C:\Projects\References\forever-api-1.60.1.70205.md`: the client's API (grep it; it is huge).
- `C:\Projects\References\EMBEDDED-LIBRARIES.md`: rules for the embedded libraries.
- `C:\Projects\LibGlass\docs\GLASS-MATERIAL.md`: the glass material.
- `C:\Projects\wow-ui-source`: FrameXML (build 70170).
- `docs/FOREVER-PROBE.md`: what has been measured in game for this addon.

The rule is **measured beats reasoned**. Anything spell-, item- or combat-dependent is confirmed with
the dev probe (`Tools/PortalRouletteProbe`, `/prprobe`) before code relies on it.

## Build, test, deploy
- Tests: `pwsh tests/run.ps1` (Lua 5.1 at `C:\Program Files (x86)\Lua\5.1\`): `luac -p` over every
  Lua file, then `tests/test_*.lua` against `tests/wow_stubs.lua`. Reading an unstubbed global is
  an error. Stub a global only after confirming it in the API dump.
- Deploy: `pwsh Tools/deploy.ps1` (`-Probe` adds the dev probe, `-ProbeOnly` deploys just the probe).
  - It deploys to `C:\Program Files (x86)\World of Warcraft\_classic_beta_\Interface\AddOns`.
  - It copies git-tracked files only, never untracked scratch folders.
  - It deploys embedded libraries from sibling checkouts (`..\LibGlass`, `..\LibShowcase`).
- A brand-new addon folder needs a client restart; otherwise `/reload`. Enable `/console scriptErrors 1`.
- When the default shell runner is unreliable, use the approved PowerShell executable:
  `C:\Users\nicol\AppData\Local\Microsoft\WindowsApps\pwsh.exe -Command '...'`. Prefer single-quoted
  payloads when the command uses PowerShell variables.

## Product
- Mage-only. Non-mages get no UI at all.
- The launcher button opens the wheel. On any destination node, **left-click casts the teleport** and
  **right-click casts the portal**. There are no mode tabs.
- The main UI is one **frosted-glass disc** (LibGlass) floating over the world, with no rectangular
  window. Visual targets: `docs/mockups/forever-layout.png` (layout, the approved one) and
  `docs/mockups/forever-glass-wheel.png` (glass material).
  - **Capitals** sit on a diamond inside the disc at 12/3/6 o'clock: Alliance Stormwind/Ironforge/
    Darnassus, Horde Orgrimmar/Undercity/Thunder Bluff. Labels sit under the beads.
  - **Dalaran** (Teleport: Dalaran, new in Forever, teleport only) sits inside the disc at 9 o'clock,
    shown once learned.
  - **Karazhan** (Atiesh only) is a satellite outside the disc at about 4 o'clock, linked to the rim,
    as in TBC. A hidden bonus leaves its place empty.
  - **Center:** a smart hearth orb (Hearthstone, then Crumbling Hearthstone, then owned hearth toys)
    with a cooldown arc and the bind location.
  - **Reagent strip** under the disc: Rune of Teleportation and Rune of Portals counts (reagent bag
    included) and the click hint. It hides its counts when the legacy reagent-free talent applies
    (states: required / free / unknown; unknown keeps the counts).
  - **Header pill:** title, gear (options), close.
- Optional cinematic camera (default OFF) through LibShowcase-1.0: the character faces the camera and
  the game UI is hidden, all restored on exit, combat, logout and after a crash.
- Minimap button (LibDBIcon) and Addon Compartment entry, both hideable.
- `/pr preview` renders the whole wheel on a low-level character with no castable actions.

## Technical guardrails
- Secure casting (see the plan and `Core/SecureAction.lua`):
  - `SecureActionButtonTemplate` with `RegisterForClicks("AnyUp", "AnyDown")`.
  - Numbered attribute families only (`typeN` + `spellN`/`itemN`/`toyN`). Never unnumbered `type`, and
    **never `typerelease`**, which consumes two reagents.
  - Secure buttons are stationary and are the only mouse-enabled frames in their footprint. Visuals
    and animations live on mouse-disabled children.
  - Attribute writes happen out of combat, via a coalesced rebuild at `PLAYER_REGEN_ENABLED`.
  - No `SecureHandler*`, state drivers or `WrapScript`: they are broken on this client.
- Combat:
  - The parent of secure buttons is protected: no Hide, move, scale or reparent in combat.
  - Secret values (cooldowns, counts in combat): never compare, truth-test or do arithmetic on an
    API return without `ns.API.Readable`. Pass them to widgets untouched.
- SavedVariables load after the addon's files: read them at `PLAYER_LOGIN`, never at file scope.
- Register events through `ns.API.RegisterEvents` (pcall; a false return is a failure).
- Options use the Settings canvas API, with the page hidden right after creation. There is no
  UIDropDownMenu: use radio groups.
- Animations are AnimationGroups on visual frames. Keep them tasteful and light (fade, slight scale,
  slow rotation, sheen).
- Embedded libraries live in `Libs\` (gitignored, pinned in `.pkgmeta`): LibGlass-1.0,
  LibShowcase-1.0, LibStub, CallbackHandler, LibDataBroker, LibDBIcon.

## Media
- Addon TGAs live in `Media\`. Generated art comes from scripts in `Tools\`: never hand-edit a
  generated TGA.
- Prefer the addon's own iconography. Built-in icons are a fallback.
