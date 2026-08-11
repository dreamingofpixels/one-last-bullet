# One Last Bullet — Project Map

This is a high-level map of the repo: where things live, how the core systems connect, and the conventions the project uses.

## Repo layout
```
One Last Bullet/
├── planning/
│   ├── One Last Bullet.txt     Source-of-truth design document
│   ├── One Last Bullet.docx    Word export of the design doc
│   ├── GAME_BRIEF.md           Living brief
│   ├── DECISIONS.md            Living decision log
│   └── PROJECT_MAP.md          Living project map (this file)
├── marketing/                  Promotional art / store assets (empty for now)
├── .cursor/
│   └── rules/                  Cursor AI guidance rules
└── project/                    Godot project root
    ├── project.godot
    ├── icon.svg
    ├── areas/
    │   └── level/
    │       ├── desert.tscn     Main playable arena
    │       ├── level.gd        Level director (spawn, aim start, win/lose)
    │       └── desert_tilemap.png
    ├── data/                   (empty; upgrades later)
    ├── effects/
    │   ├── pixel_fall.gdshader       Per-pixel gravity crumble
    │   └── destruction_effect.gd     Spawns detached sprite FX on destroy/die
    ├── entities/
    │   ├── last_bullet/
    │   │   ├── last_bullet.tscn / .gd / .png
    │   │   └── aim_arrow.gd
    │   ├── player/
    │   │   ├── player.tscn / .gd / .png
    │   │   └── player.aseprite
    │   └── enemies/
    │       ├── grunt/
    │       │   ├── grunt_knife.tscn / .gd / .png
    │       └── brute/
    │           └── brute.png   (deferred)
    └── objects/
        ├── _base/
        │   ├── level_object_variant.gd   Per-variant texture + collision Resource
        │   ├── level_object.gd           Solid prop base (world layer, random variant)
        │   └── breakable.gd              Breakable props (destroy on bullet bounce)
        ├── cactai/
        │   ├── cactus.tscn               Breakable; picks cactus_1..4 at runtime
        │   ├── cactus_1..4.png
        │   └── variants/                 LevelObjectVariant .tres per art
        └── rocks/
            ├── rock.tscn                 Solid; picks from rock variants at runtime
            ├── rock_1.png
            └── variants/
```

## Godot project entry
- **Project config**: `project/project.godot`
- **Main scene**: `res://areas/level/desert.tscn` (`uid://drul7vfq10oin`)
- **Engine**: Godot 4.7, Forward+, stretch `canvas_items` + `expand`, **integer scale mode**, nearest project default texture filter, **snap 2D transforms to pixel off** (conflicts with smooth pixel shader), **physics interpolation off**, 640x360 base resolution
- **Physics**: 3D uses Jolt; 2D gameplay uses built-in Godot 2D physics
- **Editor plugins**: none

## Autoloads (from `project/project.godot`)
None yet.

| Name | Path | Purpose |
|------|------|---------|
| — | — | — |

## Physics layers (from `project/project.godot`)

| Layer | Name |
|-------|------|
| 1 | world |
| 2 | player |
| 3 | enemy |
| 4 | bullet |

---

## Key scenes & scripts (high-signal)

### Areas
- `project/areas/level/desert.tscn` — playable prototype arena (tile ground, walls, player, bullet, HUD, fixed `Camera2D`)
- `project/areas/level/level.gd` — director: spawn 3 grunts, opening aim, win/lose/restart

### Entities
- `project/entities/player/player.tscn` + `player.gd` — WASD move, redirect range, death (+ pixel-fall FX); smooth pixel material
- `project/entities/last_bullet/last_bullet.tscn` + `last_bullet.gd` — HELD/AIMING/FLYING bullet + slow-mo aim; smooth pixel material; 180 px/s; body contact destroys breakables
- `project/entities/last_bullet/aim_arrow.gd` — drawn aim arrow during aim windows
- `project/entities/enemies/grunt/grunt_knife.tscn` + `grunt_knife.gd` — chase + contact kill (+ pixel-fall FX on die); smooth pixel material

### Objects
- `project/objects/_base/level_object.gd` — solid prop base (`StaticBody2D` on world layer; random variant; bounce material)
- `project/objects/_base/breakable.gd` — breakable props (`breakables` group + `destroy()` + pixel-fall FX)
- `project/objects/_base/level_object_variant.gd` — Resource: texture + hand-tuned collision size/offset
- `project/objects/cactai/cactus.tscn` — breakable cactus (4 art variants)
- `project/objects/rocks/rock.tscn` — solid rock (1 art variant for now)

### Effects
- `project/effects/SmoothPixel.gdshader` — [CptPotato Smooth Pixel Filtering](https://github.com/CptPotato/GodotThings/tree/master/SmoothPixelFiltering) (requires Linear filter on sprites)
- `project/effects/smooth_pixel_material.tres` — shared `ShaderMaterial` for player, enemies, bullet
- `project/effects/pixel_fall.gdshader` — canvas-item shader: staggered per-pixel fall + ground fade
- `project/effects/destruction_effect.gd` — `DestructionEffect.play_from_sprite()`; detached copy, tween `progress`, free when done

### Data
- `project/data/` — reserved for game data (upgrades, enemies, etc.); empty

---

## Groups

| Group | Used by |
|-------|---------|
| `player` | Player root |
| `enemies` | GruntKnife root |
| `bullet` | LastBullet root |
| `breakables` | Breakable props (cactus, etc.) |

## Input actions
- `move_up/down/left/right` — W/A/S/D
- `redirect` — Space
- `aim_confirm` — Space + left click (confirm aim early during slow-mo)
- `restart` — R

## Conventions
- Prefer `%UniqueName` for required node references; fail fast on missing required nodes (see `.cursor/rules/godot-node-references.mdc`).
- Do not hunt for an exported `.exe` to test; use in-editor play (see `.cursor/rules/godot-testing.mdc`).
- Level objects: origin is **bottom-center** of the art; collision size/offset lives in a per-variant `LevelObjectVariant` Resource; shapes are built in code so instances do not share a mutated sub-resource.
- Keep this file updated when autoloads, scenes, scripts, groups, or physics layers change.

## Scratch / experimental
None yet.
