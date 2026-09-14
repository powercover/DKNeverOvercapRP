# BDK Never Overcap RP

Blood Death Knight runic power cap overlay.

When runic power gets high, a Blood Boil / Necropolis-style aura appears around your character so you can dump RP before you overcap. Overlay only — no bars, numbers, or sounds. Author: **powercover**. For WoW **12.1.5**.

## Features

- Aura around the character, not a full-screen bar or resource text
- Hidden until RP hits the threshold (default **85%**)
- Fades from low opacity (~0.1) at that threshold to full at **100%** RP
- Texture presets: Blood Boil + Necropolis, Blood Boil, Necropolis, Blood Surge, Sudden Doom, Shadow of Death, Dark Transformation, Sudden Death, Killing Machine
- Minimap button: left-click settings, right-click on/off (gray icon when off)
- Blood spec only
- Combat-safe (does not compare secret RP values in Midnight)

## Settings

Left-click the Death Strike minimap button, or type `/bnorp config`.

- **Overlay texture** — dropdown of Blood DK-style spell overlays
- **Visible from X% RP** — slider `0–100` (default `85`)

Right-click the minimap button to enable or disable the overlay. The icon is gray when it is off. Drag the button to move it. Texture, start percent, and on/off are saved across reloads.

## Slash commands

| Command | Description |
|---|---|
| `/bnorp help` | List commands |
| `/bnorp config` | Open settings |
| `/bnorp on` / `/bnorp off` | Enable or disable |
| `/bnorp overlay <percent>` | Set start percent (default 85) |
| `/bnorp status` | Current RP and settings |
| `/bdkrp` | Same as `/bnorp` |

## Defaults

- Overlay starts at **85%** of max RP
- Texture: **Blood Boil + Necropolis**
- Addon: **on**
