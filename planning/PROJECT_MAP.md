# A Final Spell — Project Map

This is a high-level map of the repo: where things live, how the core systems connect, and the conventions the project uses.

## Repo layout
```
A Final Spell/
├── planning/
│   ├── A Final Spell.txt       Source-of-truth design document
│   ├── A Final Spell.docx      Word export of the design doc
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
    │       ├── level.gd        Level director (nav bake, win/lose, starts EnemySpawner)
    │       └── desert_tilemap.png
    ├── components/             Reusable component scripts + scenes
    │   ├── component_handler.gd / .tscn   Registers children into owner.COMPONENTS
    │   ├── health_component.gd / .tscn    HP; flash + optional i-frames; DestroyComponent on death
    │   ├── health_bar_component.gd / .tscn  Damage-reveal 18×2 px percentage bar above entities
    │   ├── damage_component.gd / .tscn    Damage + instigator + optional contact tick interval
    │   ├── hitbox_component.gd / .tscn    Area2D; polls overlaps; frame dedup + contact ticks
    │   ├── destroy_component.gd / .tscn   Disables collisions, destroy SFX, pixel-fall FX, emits destroyed(node)
    │   ├── movement_component.gd / .tscn  move(dir) / move_velocity() / stop() with optional sprite flip
    │   ├── knockback_component.gd / .tscn Decaying shove (CharacterBody2D / RigidBody2D / Node2D)
    │   ├── navigation_component.gd / .tscn  NavigationAgent2D chase + avoidance for enemies
    │   ├── attack_component.gd / .tscn   Player arc swing; knocks enemies (orb deflect gated by flag)
    │   ├── orb_tether_component.gd / .tscn  Proximity focus + tether capture/release for the orb
    │   ├── dash_component.gd / .tscn     Fixed-distance dash with i-frames, ghost alpha, afterimages, dash SFX, + 4s cooldown ring
    │   └── directional_sprite_component.gd / .tscn  8-way logical facing (4-way visual) via AnimatedSprite2D
    ├── audio/
    │   ├── audio_manager.gd / .tscn   Autoload: Music/SFX pools + bus helpers
    │   ├── sound_event.gd             SoundEvent Resource (streams, pitch, cooldown)
    │   └── music/                     Level/menu tracks (empty for now)
    ├── data/                   (empty; upgrades later)
    ├── effects/
    │   ├── pixel_fall.gdshader       Per-pixel gravity crumble
    │   ├── destruction_effect.gd     Spawns detached sprite FX on destroy/die; reverse assemble on spawn
    │   ├── spawn_telegraph_effect.gd Pulsing ground ring at upcoming enemy spawn points
    │   └── dash_afterimage_effect.gd Spawns fading dash afterimages from AnimatedSprite2D frames
    ├── entities/
    │   ├── _base/
    │   │   ├── state.gd        Base State class (signal finished, enter/exit/update/handle_input)
    │   │   └── state_machine.gd  StateMachine: states_map, 2-deep stack, force_state()
    │   ├── entity_destroyed.wav / .tres   Shared death SFX (SoundEvent)
    │   ├── entity_damaged.wav / _2.wav / .tres   Shared non-fatal hit SFX
    │   ├── chaos_orb/
    │   │   ├── chaos_orb.tscn / chaos_orb.gd / orb.png / orb_in_focus.png   (active desert projectile)
    │   │   ├── chaos_orb_legacy.tscn / chaos_orb_legacy.png  (kept as alternate; script shared)
    │   │   ├── aim_arrow.gd
    │   │   └── last_orb_sfx/         bounce / begin_tether / release_tether clips + SoundEvents
    │   ├── player/
    │   │   ├── player.tscn / .gd / player_spritesheet.png / player_frames.tres
    │   │   ├── player.png / player.aseprite / player_2.aseprite  (legacy single-frame art)
    │   │   ├── attack_texture.png / .aseprite  6-frame 16x16 arc (96x16 sheet)
    │   │   ├── dash.wav / dash.tres   Dash SFX
    │   │   ├── player_action.gd    Per-action node; action string suffixed at runtime
    │   │   ├── controls.gd         Per-player input abstraction (move/aim/attack/tether/dash)
    │   │   └── states/
    │   │       ├── idle.gd
    │   │       ├── walk.gd
    │   │       ├── attack.gd
    │   │       └── dash.gd
    │   └── enemies/
    │       ├── spawner/
    │       │   ├── enemy_spawner.tscn / .gd   Wave director (timed overlapping waves, nav-valid spawns)
    │       │   ├── enemy_wave.gd              Resource: delay_before + spawn entries
    │       │   └── enemy_spawn_entry.gd       Resource: enemy scene + count
    │       ├── grunt/
    │       │   ├── grunt_knife.tscn / .gd / .png
    │       └── brute/
    │           └── brute.tscn / .gd / .png
    └── objects/
        ├── _base/
        │   ├── level_object_variant.gd   Per-variant texture + collision Resource
        │   ├── level_object.gd           Solid prop base (world layer, random variant)
        │   └── breakable.gd              Breakable props (breakables group + COMPONENTS dict)
        ├── cactai/
        │   ├── cactus.tscn               Breakable; picks cactus_1..4 at runtime
        │   ├── cactus_1..4.png
        │   └── variants/                 LevelObjectVariant .tres per art
        ├── mana/
        │   └── mana_picked_up.ogg        (design economy resource; pickup scene not wired yet)
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

| Name | Path | Purpose |
|------|------|---------|
| `AudioManager` | `res://audio/audio_manager.tscn` | Music A/B crossfade + pooled global/positional SFX on Music/SFX buses |

## Physics layers (from `project/project.godot`)

| Layer | Name |
|-------|------|
| 1 | world |
| 2 | player |
| 3 | enemy |
| 4 | orb |

---

## Key scenes & scripts (high-signal)

### Areas
- `project/areas/level/desert.tscn` — playable prototype arena (tile ground, baked `NavigationRegion2D`, walls, player, orb projectile, `EnemySpawner`, HUD, fixed `Camera2D`); `LowerGround`, `Cliffs`, `Objects`, and `Walls` are in the `navigation_source` group for navmesh baking; tilemap navigation is disabled; bake `agent_radius` is tuned to the brute-sized body to trim narrow pockets
- `project/areas/level/level.gd` — director: bakes navigation after props initialize, starts `EnemySpawner`, opening tether via `player.begin_level()`, win/lose/restart; connects `DestroyComponent.destroyed` for the player and debounced breakable re-bakes, plus orb `deflected` / `tethered` / `tether_released` / `launched` and spawner `wave_started` / `all_cleared`; optional `@export level_music` → `AudioManager.play_music()`

### Components
- `project/components/component_handler.gd` — `extends Node2D`; in `_ready()` registers all child components into `owner.COMPONENTS` keyed by script class
- `project/components/health_component.gd` — HP; red flash on hit; optional `invulnerable_seconds` + blink on non-fatal hits; `take_damage` returns bool; plays `damaged_sound` on non-fatal hits; calls `DestroyComponent.self_destroy()` at ≤ 0; signals `damage_taken`, `health_changed`; sprite via optional export or `DestroyComponent.sprite`
- `project/components/health_bar_component.gd` — world-space 18×2 px `_draw` bar; fill is `% of max_health` (same pixel width for every entity); hidden until `damage_taken`, then visible for 1.5 s (timer refreshes on each hit); `@export` offset/colors; instanced on player, grunt, brute, and cactus
- `project/components/damage_component.gd` — `damage: float`, `instigator: Node` (friendly-fire filter), `contact_damage_interval` (0 = once per overlap)
- `project/components/hitbox_component.gd` — `Area2D`; physics-frame overlap poll of attacker `HitboxComponent`s; frame dedup via `hit_dedup_frames`; contact ticks from `DamageComponent.contact_damage_interval`; skips if instigator == owner; `set_invulnerable(bool)` clears overlap state and toggles monitoring (deferred)
- `project/components/destroy_component.gd` — disables collisions, emits `destroyed(node)`, plays `destroy_sound`, plays `DestructionEffect`, frees owner
- `project/components/movement_component.gd` — `move(dir)` / `move_velocity(velocity)` / `stop()` on `CharacterBody2D` owner; optional sprite `flip_h` with `sprite_flip_inverted` for left-facing art
- `project/components/knockback_component.gd` — decaying shove; `apply(direction, force)`, `is_active()`
- `project/components/navigation_component.gd` — `NavigationAgent2D`; acquires the player by group, repaths on a short interval, feeds `velocity_computed` into `MovementComponent.move_velocity()`, enables enemy-enemy avoidance while yielding during knockback, and has a stuck watchdog that forces a repath after short no-progress stalls
- `project/components/attack_component.gd` — player `Area2D` arc; authored `%CollisionPolygon2D`; AnimationPlayer swing; knocks enemies via `KnockbackComponent`; orb deflect behind `deflect_orb_enabled` (default false); optional `swing_sound` (unassigned)
- `project/components/orb_tether_component.gd` — focus radius (32 px), `bind_orb()` / `begin_opening_tether()`; capture/release via `try_tether_press()` on the tether action; short post-release cooldown
- `project/components/dash_component.gd` — fixed-distance dash (50 px @ 400 px/s); i-frames via hitbox; clears body collision to phase through solids; applies ghost alpha while dashing; spawns distance-based afterimages; plays `dash_sound`; 4 s cooldown with a radial recharge ring drawn above the player (`_draw`); `start(dir)` / `is_dashing()` / `can_dash()`
- `project/components/directional_sprite_component.gd` — 8-way logical facing on an `AnimatedSprite2D` with 4-way diagonal visuals; `face(dir)` / `play(action)` / `facing_vector()`; animations named `<action>_<visual>` (`idle_sw`, later `walk_ne`, etc.); cardinals map to nearest diagonal suffix

### State machine base
- `project/entities/_base/state.gd` — `class_name State extends Node`; `signal finished(next_state_name)`; virtual `enter/exit/update/handle_input`
- `project/entities/_base/state_machine.gd` — `@export start_state: NodePath`; `states_map` (lowercase child names); 2-deep stack; `force_state(name)`; optional debug label

### Entities
- `project/entities/player/player.tscn` + `player.gd` — `COMPONENTS` dict; `player_index` export; `begin_level(orb)`; tree: Components (Health max 3 + 0.5s i-frames / HealthBar / Damage / Destroy / Movement / Attack / Dash / OrbTether / DirectionalSprite / Hitbox), Controls (PlayerAction children), StateMachine (Idle/Walk/Attack/Dash); `%PlayerSprite` is `AnimatedSprite2D` using `player_frames.tres`
- `project/entities/player/player_action.gd` — `class_name PlayerAction`; `@export action: String`; suffixed at runtime
- `project/entities/player/controls.gd` — `class_name Controls`; `apply_player_index(index)`; `get_move_vector()`, `get_aim_vector(origin)`, `is_attack_just_pressed()`, `is_tether_just_pressed()`, `is_dash_just_pressed()`
- `project/entities/player/states/idle.gd` — stops movement; transitions to walk, dash, or attack; tether action calls `try_tether_press()`; attack blocked while tethering; walk/dash blocked while tethering
- `project/entities/player/states/walk.gd` — moves from `controls.get_move_vector()`; transitions to idle, dash, or attack; tether action calls `try_tether_press()`; attack blocked while tethering; forces idle while tethering
- `project/entities/player/states/attack.gd` — snapshots aim, starts `AttackComponent`; returns to idle when swing ends
- `project/entities/player/states/dash.gd` — dashes along `directional_sprite.facing_vector()`; locked input until dash ends, then idle/walk
- `project/entities/chaos_orb/chaos_orb.tscn` + `chaos_orb.gd` — active circular projectile; `%CollisionShape2D` + `%OrbSprite` + overlay `%OrbInFocus` + `%TrailParticles`; `COMPONENTS` dict; `DamageComponent` + `HitboxComponent`; states FLYING/TETHERED; `begin_opening_tether()` / `deflect()` / `begin_tether()` / `release_tether()` / `break_tether(exit_velocity)` / `set_in_focus()` API; tether orbit probes world/player/enemy layers and breaks on contact or on dealing damage; flying bounce owned by `_integrate_forces` (contact normals; material bounce 0); opening release emits `launched` (no boost); mid-combat release / forced break emits `tether_released` (+10% boost); instigator-based player grace; trail particles while flying/tethered; world-surface impact bursts via `OrbImpactEffect`; SFX via `bounce_sound` / `begin_tether_sound` / `release_tether_sound`; signals `launched`, `deflected`, `tethered`, `tether_released`
- `project/entities/chaos_orb/chaos_orb_legacy.tscn` + `chaos_orb.gd` — alternate capsule-sprite projectile (kept for rollback); `%OrbSprite` + `%OrbInFocus` under `%Heading`
- `project/entities/chaos_orb/aim_arrow.gd` — drawn aim arrow during aim windows
- `project/entities/enemies/grunt/grunt_knife.tscn` + `grunt_knife.gd` — component-driven chaser; Health max 3 / HealthBar / Damage with 0.75s contact tick / Destroy / Movement / Knockback / Navigation / HitboxComponent
- `project/entities/enemies/brute/brute.tscn` + `brute.gd` — same path/avoidance stack as grunt; left-facing sprite via `MovementComponent.sprite_flip_inverted`; larger collision (r=15); Health max 10 / HealthBar / Damage 3.0 with 0.75s contact tick / Navigation
- `project/entities/enemies/spawner/enemy_spawner.tscn` + `enemy_spawner.gd` — wave director; inspector `waves` (`EnemyWave` / `EnemySpawnEntry`); nav-valid spawn points with player distance + pack separation; telegraph then reverse pixel-fall assemble; enemies stay inert until assemble finishes; `all_cleared` when every wave is issued and every instanced enemy is dead; desert default: 3 grunts, then 1 brute after 6s

### Objects
- `project/objects/_base/level_object.gd` — solid prop base (`StaticBody2D` on world layer; random variant; bounce material)
- `project/objects/_base/breakable.gd` — `extends LevelObject`; `COMPONENTS` dict; `breakables` group; destroyed via `COMPONENTS[HealthComponent].take_damage()` from orb `body_entered`
- `project/objects/_base/level_object_variant.gd` — Resource: texture + hand-tuned collision size/offset
- `project/objects/cactai/cactus.tscn` — breakable cactus; Components: HealthComponent + HealthBarComponent + DestroyComponent
- `project/objects/rocks/rock.tscn` — solid rock (no components; bounces only)

### Effects
- `project/effects/SmoothPixel.gdshader` — [CptPotato Smooth Pixel Filtering](https://github.com/CptPotato/GodotThings/tree/master/SmoothPixelFiltering) (requires Linear filter on sprites)
- `project/effects/smooth_pixel_material.tres` — shared `ShaderMaterial` for player, enemies, orb
- `project/effects/pixel_fall.gdshader` — canvas-item shader: staggered per-pixel fall + ground fade
- `project/effects/destruction_effect.gd` — `DestructionEffect.play_from_sprite()` (death: `progress` 0 → 1) and `play_assemble_from_sprite()` (spawn: `progress` 1 → 0); detached copy, tween `progress`, free when done
- `project/effects/spawn_telegraph_effect.gd` — `SpawnTelegraphEffect.play()`; pulsing ground ring at a spawn point, fades during assemble
- `project/effects/dash_afterimage_effect.gd` — `DashAfterimageEffect.spawn()`; clones the current animated frame into a fading world-space ghost
- `project/effects/particle_pixel.png` — 1×1 white pixel texture for orb particle VFX
- `project/effects/orb_impact.tscn` — one-shot `GPUParticles2D` burst for orb world-surface bounces
- `project/effects/orb_impact_effect.gd` — `OrbImpactEffect.play_at()`; spawns impact scene at position/normal, frees on `finished`

### Audio
- `project/audio/audio_manager.tscn` — autoload; Music A/B crossfade; 8 global + 16 positional pooled players (oldest-voice steal); `play` / `play_at` / `play_music` / bus volume helpers
- `project/audio/sound_event.gd` — `SoundEvent` Resource: stream variants, bus, volume_db, pitch range, retrigger cooldown, max voices, avoid_repeat
- Convention: author a `SoundEvent` `.tres` next to the clip it wraps (same pattern as `LevelObjectVariant`)
- Wired events: entity destroyed/damaged, dash, orb bounce (`impact_soft`), begin/release tether; attack swing export exists but unassigned

### Data
- `project/data/` — reserved for game data (upgrades, enemies, etc.); empty

---

## Groups

| Group | Used by |
|-------|---------|
| `player` | Player root |
| `enemies` | Enemy roots |
| `orb` | ChaosOrb root (`chaos_orb.gd`) |
| `breakables` | Breakable props (cactus, etc.) |
| `navigation_source` | Desert navmesh contributors (`LowerGround`, `Cliffs`, `Objects`, `Walls`) |

## Input actions

| Action | P1 binding | P2 binding (`_2` suffix) |
|--------|-----------|--------------------------|
| `move_up` | W, gamepad left-stick up (device 0), D-pad up | gamepad device 1 |
| `move_down` | S, gamepad left-stick down, D-pad down | gamepad device 1 |
| `move_left` | A, gamepad left-stick left, D-pad left | gamepad device 1 |
| `move_right` | D, gamepad left-stick right, D-pad right | gamepad device 1 |
| `attack` | left click, gamepad A (device 0) | gamepad A device 1 |
| `tether` | right click, gamepad X (device 0) | gamepad X device 1 |
| `dash` | Space, gamepad B (device 0) | gamepad B device 1 |
| `aim_up/down/left/right` | gamepad right-stick (device 0) | gamepad right-stick device 1 |
| `restart` | R | — |

P1 keyboard/mouse actions use `device: -1` (any keyboard/mouse). P2 is gamepad-only. `_3` / `_4` action sets not yet authored (add with device 2/3 when needed). Aim direction for P1 falls back to mouse when the right stick is at rest.

## Conventions
- Every combat/movable entity root declares `var COMPONENTS: Dictionary = {}`.
- Instance `component_handler.tscn` as the `Components` child; add component scenes as its children. `ComponentHandler._ready()` registers them into `owner.COMPONENTS` keyed by **script class** (e.g. `COMPONENTS[HealthComponent]`).
- Same-entity cross-component refs use `@export` NodePaths wired in the `.tscn`; cross-entity refs use `area.owner.COMPONENTS[SomeComponent]` at collision time.
- Enemy navigation comes from a baked `NavigationRegion2D`, not TileSet navigation layers. Source geometry is collected with the `navigation_source` group and `world`-layer colliders.
- State machine states are `Node` children of `StateMachine`; state scripts extend `State`; emit `finished("state_name")` to transition (lowercase child node name, or `"previous"`).
- Player input always goes through the `Controls` node's `PlayerAction` children; never hardcode action strings in state or component scripts. `apply_player_index(n)` appends `""` / `"_2"` / `"_3"` / `"_4"` suffix at `_ready` time.
- Prefer `%UniqueName` for required node references; fail fast on missing required nodes (see `.cursor/rules/godot-node-references.mdc`).
- Audio: define sounds as `SoundEvent` Resources colocated with their clips; play through `AudioManager.play` / `play_at` (pooled players, not per-entity `AudioStreamPlayer` nodes). Buses: Master / Music / SFX via `default_bus_layout.tres`.
- Player facing: 8-way logical facing; visuals use `<action>_<visual>` names (`idle_sw`, `walk_ne`, …) on a shared `SpriteFrames` resource; `DirectionalSpriteComponent` owns octant snap and cardinal→diagonal visual mapping.
- Do not hunt for an exported `.exe` to test; use in-editor play (see `.cursor/rules/godot-testing.mdc`).
- Level objects: origin is **bottom-center** of the art; collision size/offset lives in a per-variant `LevelObjectVariant` Resource; shapes are built in code so instances do not share a mutated sub-resource.
- Keep this file updated when autoloads, scenes, scripts, groups, or physics layers change.

## Scratch / experimental
None yet.
