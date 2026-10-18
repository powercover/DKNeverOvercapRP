# DK Never Overcap RP on CurseForge and Wago

What goes on each project page. The description is the same Markdown on both:
[description.md](description.md). Nothing in this folder ships with the addon.

| Field | Value |
| --- | --- |
| Name | DK Never Overcap RP |
| CurseForge | CURSEFORGE_SLUG, project ID CURSEFORGE_ID |
| Wago | WAGO_ID |
| Summary (139 characters) | A soft glow builds around your Death Knight as runic power nears the cap, so you spend it before it's wasted. Blood, Frost and Unholy. |
| Short summary, if a field is shorter (90 characters) | A soft glow around your Death Knight as runic power nears the cap. Every spec, its own color. |
| Description | [description.md](description.md), as Markdown |
| Logo | [icon-400.png](icon-400.png) (CurseForge asks for 400 x 400), or [icon-512.png](icon-512.png) |
| License | All Rights Reserved |
| Game | World of Warcraft, Retail only (12.1.0 and 12.1.5, Midnight) |
| Category | Combat (CurseForge: Combat; Wago: Combat) |
| Source code | `https://github.com/powercover/DKNeverOvercapRP` |
| Issues | `https://github.com/powercover/DKNeverOvercapRP/issues` |

## Images

Upload to each project's image gallery, then put its address in description.md in place of the
placeholder.

| Placeholder | Image |
| --- | --- |
| `IMAGE_OVERVIEW` | [overview.png](overview.png) (2560 x 1440): the settings window with each part labelled, and four overlay patterns in game-like scenes |

## Regenerating

From the addon folder:

- `python tools/make_icon.py`: `Icon.tga` for the game, and `icon-400.png`, `icon-512.png` here.
- `python tools/make_overview.py`: `overview.png`, after the UI or the textures change.
- `python tools/make_textures.py`: the overlay and UI textures in `Media/`.
