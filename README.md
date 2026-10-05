# Portal Roulette

**Portal Roulette** puts every mage teleport and portal on one frosted-glass wheel, for **World of
Warcraft: Forever**.

Open the wheel, then left-click a destination to teleport or right-click it to open a portal. The
hearthstone sits in the middle.

## Features

- **One wheel per faction.**
  - Alliance: Stormwind, Ironforge, Darnassus.
  - Horde: Orgrimmar, Undercity, Thunder Bluff.
  - Every faction: Dalaran (Forever's new Teleport: Dalaran), and Karazhan as a satellite node for
    Atiesh owners.
- **Left-click teleports, right-click opens a portal**, from secure, combat-safe buttons.
  Destinations you haven't learned yet are shown dimmed with the level they unlock at.
- **The hearthstone in the centre.** It uses your Hearthstone, Crumbling Hearthstone or a hearth toy,
  and shows its cooldown and your bind location.
- **Reagent counts** for Rune of Teleportation and Rune of Portals (reagent bag included). They hide
  themselves once you have the Reagent Economy perk.
- **Arcane glass look.** Slowly circulating energy, glowing links with pulses of light running out
  to each destination, and a gentle shimmer across the glass.
- **Optional cinematic camera.** Your character turns to face the camera while the game UI steps
  aside. Everything is restored on close, in combat, at logout and even after a crash.
- **Group friendly.** It can announce your portals, and asks before you teleport away from your
  group.
- **Launcher button** you can drag onto an action bar, a minimap button, an Addon Compartment entry
  and a key binding.
- **Options** under Options → AddOns → Portal Roulette: animation, sound set and channel, camera,
  reagents and launcher.

## Commands

| Command | What it does |
|---|---|
| `/pr` | Open or close the wheel |
| `/pr options` | Open the options |
| `/pr preview` | Show every destination without casting (handy on a low-level mage) |
| `/pr reset` | Reset the wheel and launcher positions |
| `/pr debug` | Print the wheel's state (for bug reports) |

## Requirements

- WoW: Forever (Interface 16001). The TBC Anniversary version is frozen at tag `v0.1.1-tbc`.
- Mage characters only. Other classes get no UI at all.

Embedded libraries (installed automatically with the release): LibGlass-1.0, LibShowcase-1.0,
LibStub, CallbackHandler-1.0, LibDataBroker-1.1, LibDBIcon-1.0.

## Development

- Tests: `pwsh tests/run.ps1` (Lua 5.1).
- Deploy to the game: `pwsh Tools/deploy.ps1` (`-Probe` also installs the measurement probe). LibGlass
  and LibShowcase come from sibling checkouts (`..\LibGlass`, `..\LibShowcase`).
- Generated art: `python Tools/make_art.py` (effects), `Tools/make_city_art.py` and
  `Tools/make_launcher_art.py`.
- What has been measured in game is in `docs/FOREVER-PROBE.md`. Agent instructions are in
  `AGENTS.md`.
