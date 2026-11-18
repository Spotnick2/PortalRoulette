# Portal Roulette agent instructions

Portal Roulette is a mage-only teleport/portal wheel for **WoW: Forever**: Vanilla content on the
Retail (Mainline) API, client 1.60.1, `## Interface: 16001`. The TBC Anniversary version is frozen
at tag `v0.1.1-tbc` and no longer supported.

Read before changing code:
- `C:\Projects\WoW\References\Docs\PORTING-TBC-TO-FOREVER.md`: what changed from TBC, measured.
- `C:\Projects\WoW\References\Forever\api\forever-api-1.60.1.70959.md`: the client's API (grep it; it is huge).
- `C:\Projects\WoW\References\Docs\EMBEDDED-LIBRARIES.md`: rules for the embedded libraries.
- `C:\Projects\WoW\LibGlass\docs\GLASS-MATERIAL.md`: the glass material.
- `C:\Projects\WoW\wow-ui-source`: FrameXML (build 70959).
- `docs/FOREVER-PROBE.md`: what has been measured in game for this addon.

The rule is **measured beats reasoned**. Anything spell-, item- or combat-dependent is confirmed with
the dev probe (`Tools/PortalRouletteProbe`, `/fp pr`) before code relies on it.
- The probe is a ForeverProbe module (`C:\Projects\WoW\ForeverProbe`, its `docs/GUIDE.md`; read
  `C:\Projects\WoW\References\Docs\PROBES.md` first). Its lines go to the `/fp` console and
  `PortalRouletteProbeDB.log`, never chat. What needs the owner in game is a procedure
  (`Probe:Steps`, `/fp steps pr <name>`), and its results are read from the SavedVariables after
  their `/reload`. Never edit ForeverProbe from here: a need is an issue on Spotnick2/ForeverProbe,
  worked around in the module with the issue number meanwhile (today ForeverProbe#19).

## Build, test, deploy
- Tests: `pwsh tests/run.ps1` (Lua 5.1 at `C:\Program Files (x86)\Lua\5.1\`): `luac -p` over every
  Lua file and the LibGlass/LibShowcase checkouts against their `.pkgmeta` tags, then
  `tests/test_*.lua`. Reading an unstubbed global is an error. Stub a global only after confirming
  it in the API dump.
  - The test scaffolding is WowTestKit (`C:\Projects\WoW\WowTestKit`; its README is the reference)
    at the commit and client build `tests\kit.pin` names. `tests\run.ps1` puts that commit in
    `%LOCALAPPDATA%\WowTestKit\<sha>` and hands off to the kit's runner; CI fetches it with
    `tests\fetch_kit.sh`. `tests\kit.lua`, `kit.ps1` and `fetch_kit.sh` are the kit's bootstrap
    copies: never edit them here. A kit need is an issue on the kit, worked around in
    `tests\wow_stubs.lua` with a `-- WowTestKit #N:` comment meanwhile. `tests\run.ps1 -KitDev`
    runs against the `..\WowTestKit` working copy instead of the pin.
  - The probe's tests (`tests/test_probe.lua`) load ForeverProbe from its checkout
    (`$env:FOREVERPROBE`, else `..\ForeverProbe`); locally a missing checkout is an error. It is
    private, so CI sets `FOREVERPROBE_OPTIONAL=1` and that file skips. Run the tests locally before
    every PR that touches the probe.
- Deploy: `pwsh Tools/deploy.ps1` (`-Probe` adds the dev probe, `-ProbeOnly` deploys just the probe).
  - It deploys to `C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns`.
  - It copies git-tracked files only, never untracked scratch folders.
  - It deploys embedded libraries from sibling checkouts (`..\LibGlass`, `..\LibShowcase`).
  - `-Probe` and `-ProbeOnly` deploy ForeverProbe first (`$env:FOREVERPROBE`, else `..\ForeverProbe`).
- In game, `/reload` loads everything a deploy brings, a new addon folder, textures and TOC changes
  included (porting guide §5). A full client exit is only for a persistence test (ForeverProbe
  guide, section 7). Enable `/console scriptErrors 1`.
- When the default shell runner is unreliable, use the approved PowerShell executable:
  `C:\Users\nicol\AppData\Local\Microsoft\WindowsApps\pwsh.exe -Command '...'`. Prefer single-quoted
  payloads when the command uses PowerShell variables.

## Releasing
- The guide is `C:\Projects\WoW\References\Docs\RELEASING.md`. A `vX.Y.Z` tag (or `-alphaN`/`-betaN`) publishes
  three times:
  - **CurseForge** (project 1540067, https://www.curseforge.com/wow/addons/portal-roulette) builds
    its own file from the tag through its webhook. No CurseForge key lives in the repo.
  - **GitHub:** `.github/workflows/package-check.yml`'s `release` job publishes the zip `check`
    built and checked, with `release.json` (WowUp) and the tag's `CHANGELOG.md` section as notes.
  - **Wago Addons** (project `nKWwbZKE`, https://addons.wago.io/addons/nKWwbZKE): the `wago` job
    uploads the same zip (`WAGO_API_TOKEN` secret).
- `check` runs on every PR and push: syntax, unit tests, a `-d` package, the zip allowlist, and
  `tests/release_files.sh` (a copy of the guide's template: never edit it here).
- To publish a tag again where a target failed: Actions > Package check > Run workflow from `main`,
  with the tag and `github`/`wago`/`both`.

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
- **Glass suite integration, only when Glass UI is loaded** (`Core/GlassUI.lua`, `UI/UtilityButton.lua`).
  Without Glass UI nothing is asked, reported or registered, and the addon looks and behaves as on its own.
  - Glass UI's suite (`GlassUI/docs/SUITE.md`, dynamic roster member GlassUI#107): one `Theme` answer
    at `PLAYER_LOGIN`, every class, before any glass is built. Following means LibGlass's Pearl preset
    (r11+), with our own disc tuning, rim art and panel tuning suspended (`Skin:OwnLook()`). Not live:
    a change applies after `/reload`.
  - Glass Action Bars' Utility bar (GAB#52, its `docs/PUBLIC-API.md` version 2): with Glass UI and GAB,
    a mage registers the launcher as a provider button (off until ticked in GAB's options). While it is
    shown there (`OnHosted(true)`), the floating launcher and its macro prompt stay hidden.

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
