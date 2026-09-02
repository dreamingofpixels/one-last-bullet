# Ritual Menu — UI Mockup Gallery

Interactive layout exploration for the summoning-circle ritual menu. **Does not modify** any Godot scenes.

## Open

Double-click or drag into a browser:

```
planning/ritual_menu_mockups/index.html
```

No install or server required.

## What to try

1. **Layout strip (01–20)** — click a thumbnail label to swap composition. All layouts share the same widgets; only placement changes.
2. **Style** — toggle **Wireframe** (sketch-like) vs **Pixel HUD** (darker in-game feel).
3. **Presets** — jump to common states without manual clicking:
   - **Empty** — blank orb, Earth + Fire in inventory
   - **1 glyph** — one socketed; Transmorph off; stats show bonus
   - **2× Air** — matches your sketch; **4 possible upgrades** list appears
   - **3 / new** — Air+Air+Water (Haunt path in data); Transmorph on; hover shows `???`
   - **3 / Ghost** — Air+Air+Earth; hover shows Ghost stats if discovered
   - **Poor** — 5 mana; Buy Blank Orb disabled
4. **Discovered checkboxes** — toggle Ghost / Conduit / Rot / Inferno to see named vs `???` in the outcome list and Transmorph tooltip.
5. **Interact** — click inventory glyphs to socket; click socketed glyphs to return; **Transmorph** when 3 slots full; **Recycle** / **Buy Blank Orb** / **Close**.

Viewport is **640×360** (game resolution), scaled up in the page for readability.

## Rules modeled

| Slots filled | Behavior |
|--------------|----------|
| 0–1 | Stat bonuses only; no outcome list; Transmorph disabled |
| 2 | Four possible third-element orbs listed (`???` if undiscovered) |
| 3 | Transmorph enabled (blank orb only); hover reveals stats only if discovered; bonuses persist after transform |

**20 orb recipes** = every 3-element combination of Fire / Water / Air / Earth (order ignored). Game data defines Ghost, Conduit, Rot, and Inferno; the rest use placeholder names in the mock.

## Layout guide

| # | Name | What it tests |
|---|------|----------------|
| 01 | Sketch-faithful | Your wireframe: stats left, ritual center, shop right, inventory bottom |
| 02 | Sketch + chrome | Same + header bar (mana, close, tooltip under Transmorph) |
| 03 | Game viewport HUD | Dim arena backdrop; floating ritual panel |
| 04 | Radial altar | Large orb center; triangle slots |
| 05 | Two-page codex | Wide stats “page”; ritual + shop on right; inventory in shop |
| 06 | Top toolbar | All economy in top bar; full-width inventory dock |
| 07 | Bottom-heavy | Large bottom strip for inventory + shop |
| 08 | Inspector drawer | Tall stats column; big orb preview |
| 09 | Outcome orbs | Four possibles as orb icons instead of text list |
| 10 | Tooltip-first | Minimal center; stats hidden until Transmorph hover (discovered) |
| 11 | Corner chrome | Stats top-left, shop top-right, ritual center |
| 12 | Split vault | Wide ritual left; shop column right with inventory |
| 13 | Dense dashboard | Everything visible at once |
| 14 | Inventory-as-tray | Glyphs tray overlaps slot area (short drag distance) |
| 15 | Vertical stack | Single column — likely too tall for 640×360 |
| 16 | Tabbed | Stats / Ritual / Shop tabs |
| 17 | Wide header + 3 cols | Header + three columns + inventory bar |
| 18 | Recycle-as-danger | Separate recycle pit below ritual |
| 19 | Preview constellation | Four faint nodes around empty third slot |
| 20 | Minimal pixel | Compact stats row; largest glyph slots |

## After review

Pick a layout number (or mix: e.g. “01 stats + 12 shop column + 19 constellation”). That choice drives the real `ritual_menu.tscn` pass — not this mock.
