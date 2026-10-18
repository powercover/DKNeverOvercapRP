# BDK Never Overcap RP

A blood aura around your character that fades in as runic power approaches the cap, so you spend it before it's wasted. No bars, numbers or sounds. Author: **powercover**. For WoW **12.1.x** (Midnight).

## Features

- Aura appears at a configurable share of max runic power (default **85%**) and reaches full opacity at the cap
- Optional pulsing flare right before you cap (default **95%**)
- Nine texture presets, optional custom color, size, vertical offset, max opacity, spinning runes, smooth fade
- Choose which specs it runs in: Blood by default, Frost and Unholy optional
- Optional "only in combat" mode
- Live **Preview** button in the settings
- Works in combat in Midnight, where runic power is hidden from addons: opacity is computed by the client through a curve
- Minimap button, addon compartment entry and an entry under *Options → AddOns*

## Performance

The addon does nothing unless it's needed:

- **Not a Death Knight**: after login it never registers an event, never builds the overlay and never runs an update.
- **Spec not tracked or overlay disabled**: it only listens for spec changes.
- **Active**: it reacts to the player's runic power events only. Nothing runs every frame. The only frame-by-frame work is a short fade that stops itself once it reaches its target, plus the spin and pulse animations, which the client runs only while the aura is visible.

## Settings

Left-click the minimap button, click the entry in the addon compartment, or type `/bnorp`.

| Section | Setting | Default |
|---|---|---|
| Behavior | Enable overlay | on |
| | Track these specs | Blood |
| | Only in combat | off |
| | Minimap button | shown |
| Trigger | Appear at runic power | 85% |
| | Pulse near cap / Pulse at | on / 95% |
| Appearance | Texture | Blood Boil + Necropolis |
| | Custom color | off |
| | Max opacity | 100% |
| | Size | 100% |
| | Vertical offset | -20 |
| | Spinning runes | on |
| | Smooth fade | on |

Right-click the minimap button to turn the overlay on or off. The icon turns gray when it's off. Settings are saved account-wide. Settings from 1.x carry over automatically.

## Slash commands

`/bdkrp` works the same as `/bnorp`.

| Command | Description |
|---|---|
| `/bnorp` | Open or close settings |
| `/bnorp on` / `off` / `toggle` | Turn the overlay on or off |
| `/bnorp preview` | Show the aura at full strength |
| `/bnorp start <percent>` | Runic power share where the aura appears |
| `/bnorp pulse <percent \| off>` | Pulse threshold, or turn the pulse off |
| `/bnorp minimap` | Show or hide the minimap button |
| `/bnorp status` | Current state and runic power |
| `/bnorp reset` | Restore default settings |
| `/bnorp help` | List commands |

## Releasing

Releases are built by [BigWigsMods/packager](https://github.com/BigWigsMods/packager) in GitHub Actions (`.github/workflows/release.yml`). Each release lints the code, builds `BDKNeverOvercapRP-<version>.zip` with the version in the TOC, writes a changelog from the commits, and publishes a GitHub release.

There are two ways to start a release:

1. **From GitHub**: *Actions → Release → Run workflow*, then enter a version such as `2.1.0`. The workflow creates the `v2.1.0` tag for you.
2. **From a terminal**: push a tag.

   ```bash
   git tag v2.1.0 && git push origin v2.1.0
   ```

Tags containing `alpha` or `beta` (for example `v2.1.0-beta.1`) are published as pre-releases.

**CurseForge and Wago (optional).** Add `## X-Curse-Project-ID: <id>` and/or `## X-Wago-ID: <id>` to the TOC, then add the `CF_API_KEY` and/or `WAGO_API_TOKEN` repository secrets. Without them, the release goes to GitHub only.

Every push and pull request also runs luacheck (`.github/workflows/ci.yml`).
