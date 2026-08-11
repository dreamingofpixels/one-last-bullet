# One Last Bullet — Project Map

This is a high-level map of the repo: where things live, how the core systems connect, and the conventions the project uses.

## Repo layout
```
One Last Bullet/
├── planning/
│   ├── One Last Bullet.txt     Source-of-truth design document
│   ├── One Last Bullet.docx    Word export of the design doc
│   ├── GAME_BRIEF.md           Living brief (this project)
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
    │       └── desert_tilemap.png
    ├── data/                   (empty)
    └── entities/
        ├── enemies/
        │   └── grunt/          (empty)
        └── player/
            ├── player.aseprite
            └── player.png
```

## Godot project entry
- **Project config**: `project/project.godot`
- **Main scene**: not set yet (`run/main_scene` unset)
- **Engine**: Godot 4.7, Forward+ (default), stretch `canvas_items` + `expand`
- **Physics**: 3D physics engine set to Jolt (2D gameplay TBD)
- **Editor plugins**: none yet

## Autoloads (from `project/project.godot`)
None yet. Add rows here when autoloads are registered.

| Name | Path | Purpose |
|------|------|---------|
| — | — | TBD |

## Physics layers (from `project/project.godot`)
Not configured yet. Document named layers here when added (e.g. player, enemy, bullet, world).

| Layer | Name |
|-------|------|
| — | TBD |

---

## Key scenes & scripts (high-signal)

No `.tscn` or `.gd` gameplay files yet. Existing scaffolding:

### Areas
- `project/areas/level/desert_tilemap.png` — tile art for levels (saloon/desert look)

### Entities
- `project/entities/player/player.png` (+ `player.aseprite`) — player sprite source
- `project/entities/enemies/grunt/` — reserved for the basic chase enemy (empty)

### Data
- `project/data/` — reserved for game data (upgrades, enemies, etc.); empty

---

## Groups
None yet. Document Godot groups here when introduced.

## Conventions
- Prefer `%UniqueName` for required node references; fail fast on missing required nodes (see `.cursor/rules/godot-node-references.mdc`).
- Do not hunt for an exported `.exe` to test; use in-editor play (see `.cursor/rules/godot-testing.mdc`).
- Keep this file updated when autoloads, scenes, scripts, groups, or physics layers change.

## Scratch / experimental
None yet.
