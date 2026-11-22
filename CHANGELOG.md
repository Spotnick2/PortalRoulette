# Changelog

## v1.2.2

- Fixed: closing the wheel with the cinematic camera on left the game camera on saved view 5,
  where it no longer follows your character, and the game kept that view at every login. The
  wheel now closes onto your own view at your zoom (onto the normal view if yours is view 4, which
  "Frame the character while casting" uses). If you were left on view 5, you're moved back to the
  normal view once, at your first login with this version. (LibShowcase-1.0 updated to r14.)

## v1.2.1

- In a group, the teleport confirmation's **Yes** now casts the teleport itself, instead of asking
  you to click the destination again within 8 seconds.
- The confirmation's background is near opaque, so it reads over busy scenery.

## v1.2.0

- New option (Launcher, on by default): show the launcher button. Turned off, the launcher and its
  "drag onto an action bar" prompt stay hidden; the minimap button, the Addon Compartment, the key
  binding and `/pr` still open the wheel.
- LibShowcase-1.0 updated to r10: a pull countdown or a battleground/arena start timer brings the
  game UI back like a ready check; the camera orbit keeps the same speed whatever your camera turn
  speed; female characters get their own shoulder framing; with a gamepad, the presentation no
  longer changes the camera-centring settings.

## v1.1.0

- New option (Wheel, off by default): close the wheel as soon as a teleport or portal starts
  casting, instead of when it ends.
- Releases are now also on GitHub (with WowUp support) and Wago Addons.
- Fixed: the `/pr` help and debug lines printed a bare `|`, which chat reads as the start of a
  colour or link code.
- LibGlass-1.0 updated to r13.

## v1.0.1

- Fixed: the glass sheen on the wheel, its title bar and the launcher's placement prompt was drawn
  at full strength instead of the intended softer one.
- **Glass suite**, only when the Glass UI addon is installed (without it, nothing changes):
  - the wheel joins Glass UI's suite and follows its Pearl look when Glass UI says so (after a
    `/reload`); its own look comes back when it stops following;
  - with Glass Action Bars as well, the launcher can be a button on its Utility bar (off until you
    tick it there). While it's on the bar, the floating launcher and its placement prompt hide.
- LibGlass-1.0 updated to r11.

## v1.0.0

Portal Roulette moves to **WoW: Forever**. The TBC Anniversary version is no longer supported (last
release: v0.1.1, tag `v0.1.1-tbc`).

- Rebuilt for Forever (Interface 16001) on the modern client API, with secure, combat-safe casting.
  Each click casts once, whichever key-down setting you use.
- New frosted-glass wheel:
  - capitals in a diamond, Dalaran inside the wheel, Karazhan as a linked satellite;
  - new painted city art, and destinations you haven't learned yet shown dimmed;
  - circulating arcane energy, orbiting lights, glowing links with light pulses, a glass shimmer.
- Teleport: Dalaran (new in Forever) and Portal: Karazhan through Atiesh.
- Your hearthstone sits in the centre with its cooldown and bind location. Crumbling Hearthstone is
  used only without a Hearthstone.
- Reagent counts include the reagent bag and hide with the Reagent Economy perk.
- The cinematic presentation is on by default and restored after a crash. The game UI comes back for
  ready checks, invites, dungeon proposals, loot rolls and chat, with the wheel still open.
- New launcher: drag it onto an action bar. It glows until placed, with a glow style option and a
  clearer lock.
- Minimap button (LibDBIcon), Addon Compartment entry, and an options page with sound sets and volume
  channel.
- `/pr preview` shows every destination without casting.
- Removed: the TBC destinations (Shattrath, Silvermoon, Exodar, Stonard, Theramore), the Dark Portal
  and Naaru's Embrace utilities, and the center-orb and launcher-theme options.

## v0.1.1

- Fixed the minimap button icon by removing the extra Blizzard tracking border overlay.
- Switched the minimap button to the stable Portal Roulette 64px icon.
- Removed the unused minimap-specific icon asset and media constant.

## v0.1

- Initial release.
