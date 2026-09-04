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
│       ├── level.gd        Level director (nav bake, win/lose, starts EnemySpawner, applies RunStartConfig)
│       ├── run_start_config.gd / glyph_entry_config.gd / run_start_default.tres  Editor starting mana / orbs / glyphs
│       └── desert_tilemap.png
    ├── components/             Reusable component scripts + scenes
    │   ├── component_handler.gd / .tscn   Registers children into owner.COMPONENTS
│   ├── health_component.gd / .tscn    HP; flash + optional i-frames; DestroyComponent on death; floating damage labels via DamageKind; last_damage_source + optional source on take_damage
│   ├── health_bar_component.gd / .tscn  Damage-reveal 18×2 px percentage bar above entities
│   ├── damage_component.gd / .tscn    Damage + instigator + optional contact tick interval + damage_kind
    │   ├── hitbox_component.gd / .tscn    Area2D; polls overlaps; frame dedup + contact ticks; optional attacker `should_apply_hitbox_damage` / `resolve_hitbox_damage` / `on_hitbox_hit`
    │   ├── destroy_component.gd / .tscn   Disables collisions, destroy SFX, pixel-fall FX, emits destroyed(node)
    │   ├── movement_component.gd / .tscn  move(dir) / move_velocity() / stop() with optional sprite flip
    │   ├── knockback_component.gd / .tscn Decaying shove (CharacterBody2D / RigidBody2D / Node2D); `push_distance` for fixed-distance bowling with collision damage
    │   ├── navigation_component.gd / .tscn  NavigationAgent2D chase + avoidance for enemies
    │   ├── status_component.gd / .tscn   Enemy Poison (1 dmg/stack/s, persistent) + Shock (stun + 50 burst at 10 stacks) + Burn (death explosion) + Chill (move/attack slow)
│   ├── attack_component.gd / .tscn   Player arc swing (parked behind melee_enabled); knocks enemies when melee on; orb deflect gated by flag; proximity redirect consumes cooldown without swing
│   ├── orb_tether_component.gd / .tscn  Focus + Attack redirect; capture/channel gated by capture_enabled; crystal pickup + circle activate; redirect particle preview on closest orb
│   ├── dash_component.gd / .tscn     Fixed-distance dash with i-frames, ghost alpha, afterimages, dash SFX, + 4s cooldown ring (reset on Attack redirect)
    │   └── directional_sprite_component.gd / .tscn  8-way logical facing (4-way visual) via AnimatedSprite2D
    ├── audio/
    │   ├── audio_manager.gd / .tscn   Autoload: Music/SFX pools + bus helpers
    │   ├── sound_event.gd             SoundEvent Resource (streams, pitch, cooldown)
    │   └── music/                     Level/menu tracks (empty for now)
    ├── data/                   Excel → JSON game data (orbs, glyphs, motion)
    │   ├── game_data.xlsx      Source workbook (schema sheet + data sheets)
    │   ├── export_game_data.py / .bat / requirements.txt
    │   └── game_data.json      Exported runtime data (regenerate via .bat)
    ├── globals/
    │   ├── game_data.gd        GameData autoload: loads JSON, generic sheet lookup
    │   └── orb_recipes.gd      OrbRecipes: element-combo lookups for ritual Transform / hints
    ├── effects/
    │   ├── pixel_fall.gdshader       Per-pixel gravity crumble
    │   ├── destruction_effect.gd     Spawns detached sprite FX on destroy/die; reverse assemble on spawn
    │   ├── spawn_telegraph_effect.gd Pulsing ground ring at upcoming enemy spawn points
    │   ├── dash_afterimage_effect.gd Spawns fading dash afterimages from AnimatedSprite2D frames
    │   ├── damage_label.tscn / .gd / damage_label_effect.gd  Floating damage numbers (white / poison green / shadow black)
    │   └── …
    ├── entities/
    │   ├── _base/
    │   │   ├── state.gd        Base State class (signal finished, enter/exit/update/handle_input)
    │   │   └── state_machine.gd  StateMachine: states_map, 2-deep stack, force_state()
    │   ├── entity_destroyed.wav / .tres   Shared death SFX (SoundEvent)
    │   ├── entity_damaged.wav / _2.wav / .tres   Shared non-fatal hit SFX
    │   ├── orbs/
    │   │   ├── blank/blank_orb.tscn / blank_orb.gd   Shared BlankOrb base (FLYING/TETHERED/POSSESSED); not launched at level start
    │   │   ├── ghost/ghost_orb.tscn / .gd          Possess host on hit; 3 DPS; dark flash; emerge on death
    │   │   ├── rot/rot_orb.tscn / .gd              Impact + 3 Poison stacks on enemy hit
    │   │   ├── conduit/conduit_orb.tscn / .gd      Impact + current beam (Line2D / capsule Area2D) within 130 px of closest player
    │   │   ├── orb_in_focus.png / aim_arrow.gd
    │   │   └── orb_sfx/         bounce / begin_tether / release_tether clips + SoundEvents
    │   ├── player/
    │   │   ├── player.tscn / .gd / player_spritesheet.png / player_frames.tres
    │   │   ├── players.gd          Static roster helpers over the `player` group
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
│   ├── items/
│   │   ├── glyphs/glyph.tscn / .gd / glyph_rarity.gdshader / glyph_rarity_particles.tscn  Carry/throw/deposit + unison blink + particles
│   │   ├── glyphs/                         fire/water/air/earth_glyph.png + glyph_socket.png
│   │   ├── item_picked_up.ogg / .tres      Shared item pickup SoundEvent
│   │   └── mana_crystal_deposited.ogg / .tres  Glyph deposit SoundEvent (legacy name)
│   ├── ui/
│   │   ├── attributes/attribute_box.tscn / .gd   Stat row (icon + value); `@tool` PNG picker from folder
│   │   ├── inventory/orb_inventory.tscn / .gd    Bottom ritual orb + glyph socket bar (`OrbInventoryBar`)
│   │   ├── ritual_menu/ritual_menu.tscn / .gd  Paused summoning ritual UI (drag socket / Transform / buy)
│   │   └── fonts/
│   │       └── pixel_medium.fnt / .png   BMFont (atlas PNG is skip-imported; assign the .fnt)
│   └── objects/
        ├── _base/
        │   ├── level_object_variant.gd   Per-variant texture + collision Resource
        │   ├── level_object.gd           Solid prop base (world layer, random variant)
        │   └── breakable.gd              Breakable props (breakables group + COMPONENTS dict)
        ├── summoning_circle/
        │   └── summoning_circle.tscn / .gd / .png   Deposit Area2D + mana_pool label; activate ritual; opening orb origin
        ├── cactai/
        │   ├── cactus.tscn               Breakable; picks cactus_1..4 at runtime
        │   ├── cactus_1..4.png
        │   └── variants/                 LevelObjectVariant .tres per art
        ├── animal_skull.tscn             Breakable skull prop; 20 HP; single variant (16×16)
        ├── animal_skull.png
        ├── animal_skull_variant.tres     LevelObjectVariant for the skull (collision 14×12)
        └── rocks/
            ├── rock.tscn                 Solid; picks from rock variants at runtime (no health)
            ├── big_rock.tscn             Breakable rock; 60 HP; single variant (big_rock.png 28×22)
            ├── rock_1.png
            ├── big_rock.png
            └── variants/                 rock_1.tres + big_rock.tres (LevelObjectVariant resources)
```

## Godot project entry
- **Project config**: `project/project.godot`
- **Main scene**: `res://areas/level/desert.tscn` (`uid://drul7vfq10oin`)
- **Engine**: Godot 4.7, Forward+, stretch `canvas_items` + `expand`, **integer scale mode**, nearest project default texture filter, **snap 2D transforms to pixel off** (conflicts with smooth pixel shader), **physics interpolation off**, 640x360 base resolution
- **UI font**: project default is `res://ui/fonts/pixel_medium.fnt` (BMFont, native size 16, integer scaling). Assign the `.fnt`, not the atlas PNG.
- **Physics**: 3D uses Jolt; 2D gameplay uses built-in Godot 2D physics
- **Editor plugins**: none

## Autoloads (from `project/project.godot`)

| Name | Path | Purpose |
|------|------|---------|
| `AudioManager` | `res://audio/audio_manager.tscn` | Music A/B crossfade + pooled global/positional SFX on Music/SFX buses |
| `GameData` | `res://globals/game_data.gd` | `@tool` autoload: loads `res://data/game_data.json`; `get_table(sheet)` / `get_row(sheet, id)` / `has_row(sheet, id)` over exported sheets (`orbs`, `glyphs`, `attunements`, `motion`, …) |

## Physics layers (from `project/project.godot`)

| Layer | Name |
|-------|------|
| 1 | world |
| 2 | player |
| 3 | enemy |
| 4 | orb |
| 5 | wall |
| 6 | item |

---

## Key scenes & scripts (high-signal)

### Areas
- `project/areas/level/desert.tscn` — playable prototype arena (tile ground, baked `NavigationRegion2D`, walls on `world` + `wall`, `%Players` / `%Player1`, `%SummoningCircle` under Objects, `%Items` for glyph drops, `%RitualMenu`, `EnemySpawner`, HUD with `TimeSlowOverlay` + `StatusLabel`, fixed `Camera2D`); inspector export `bounce_orbs_off_entities` (default false); `@export run_start: RunStartConfig` (`run_start_default.tres`); no pre-placed orb — typed orbs spawn at launch from config; `LowerGround`, `Cliffs`, `Objects`, and `Walls` are in the `navigation_source` group for navmesh baking
- `project/areas/level/level.gd` — director: bakes navigation, starts `EnemySpawner`, awaits parallel `begin_level()`; applies `RunStartConfig` to the circle then launches configured orbs (default **Ghost + Rot + Conduit**) from `%SummoningCircle`; on kills rolls **glyph** spawn via orb `glyph_drop` or `glyph_drop_chance` export; weighted glyph rarity **70 / 25 / 5**; `SummoningCircle.ritual_started` → pause + `%RitualMenu.open` (passes live `orb` group); menu `closed` → `release_orb` + unpause; `inspect_closed` → unpause only (no release); `pause` action → `%RitualMenu.open_inspect`; `new_blank_orb_requested` → spawn blank orb at circle (max 3); `transform_requested` → swap captured orb scene via `swap_captured_orb`; co-op P2 hot-join; win/lose when all players dead; orb tether/time-slow hooks
- `project/areas/level/run_start_config.gd` + `glyph_entry_config.gd` + `run_start_default.tres` — editor Resource for starting mana, opening orb scenes, and circle glyph inventory (`GlyphEntryConfig` glyph-id dropdown from GameData)

### Components
- `project/components/component_handler.gd` — `extends Node2D`; in `_ready()` registers all child components into `owner.COMPONENTS` keyed by script class
- `project/components/health_component.gd` — HP; red flash on hit; optional `invulnerable_seconds` + blink on non-fatal hits; `start_invulnerability(seconds)` for shared co-op grace (e.g. opening volley); `take_damage(amount, kind := STANDARD, source := null)` returns bool; stores `last_damage_source`; `DamageKind` (STANDARD / POISON / SHADOW / CRIT / BURN) tints floating damage labels; plays `damaged_sound` on non-fatal hits; calls `DestroyComponent.self_destroy()` at ≤ 0; signals `damage_taken`, `health_changed`; sprite via optional export or `DestroyComponent.sprite`
- `project/components/health_bar_component.gd` — world-space 18×2 px `_draw` bar; fill is `% of max_health` (same pixel width for every entity); hidden until `damage_taken`, then visible for 1.5 s (timer refreshes on each hit); `@export` offset/colors; instanced on player, grunt, brute, and cactus
- `project/components/damage_component.gd` — `damage: float`, `instigator: Node` (friendly-fire filter), `contact_damage_interval` (0 = once per overlap), `damage_kind` (label tint; Ghost orb sets SHADOW)
- `project/components/hitbox_component.gd` — `Area2D`; physics-frame overlap poll of attacker `HitboxComponent`s; frame dedup via `hit_dedup_frames`; contact ticks from `DamageComponent.contact_damage_interval`; skips if instigator == owner; optional attacker hooks `should_apply_hitbox_damage(victim)` / `resolve_hitbox_damage(victim)` / `on_hitbox_hit(victim)` for typed orbs; applies orb damage the same way as other attackers (entities punch-through; breakables stay on body contact); `set_invulnerable(bool)` clears overlap state and toggles monitoring (deferred)
- `project/components/destroy_component.gd` — disables collisions, emits `destroyed(node)`, optionally plays `destroy_sound` (`self_destroy(play_sound := true)`), plays `DestructionEffect`, frees owner
- `project/components/movement_component.gd` — `move(dir)` / `move_velocity(velocity)` / `stop()` on `CharacterBody2D` owner; optional sprite `flip_h` with `sprite_flip_inverted` for left-facing art; skips `move_and_slide` when the body is not in a physics space
- `project/components/knockback_component.gd` — decaying shove; `apply(direction, force)`, `push_distance(direction, distance, collision_damage)`, `is_active()`; bowling deals collision damage once per enemy per push via slide collisions; same physics-space guard before `move_and_slide`
- `project/components/navigation_component.gd` — `NavigationAgent2D`; acquires the **nearest** player by group (retarget every ~0.5 s with ~32 px hysteresis so co-op packs do not dither), repaths on a short interval, feeds `velocity_computed` into `MovementComponent.move_velocity()`, enables enemy-enemy avoidance while yielding during knockback, and has a stuck watchdog that forces a repath after short no-progress stalls; `set_chasing(bool)` pauses avoidance + physics so assembling enemies do not slide
- `project/components/status_component.gd` — enemy statuses: **Poison** (every 1 s deal `stacks` HP; stacks persist until death; ticks call `take_damage(..., POISON)` for green labels) and **Shock** (at 10 stacks deal 50 HP + stun 2 s via `NavigationComponent.set_chasing(false)` + `MovementComponent.stop()`, then clear Shock; no Shock while stunned) and **Burn** (on `DestroyComponent.destroyed`, explode for `5 * stacks` in `50 * (1 + 5% * stacks)` px; enemies only; BURN labels) and **Chill** (`5% * stacks` move + attack-speed slow, max 90%); `add_stacks(id, amount, source)` tracks per-status source for drops/explosions; instanced on grunt/brute with health/nav/movement/destroy/damage wired
- `project/components/attack_component.gd` — player `Area2D` arc; authored `%CollisionPolygon2D`; AnimationPlayer swing; knocks enemies via `KnockbackComponent` when `melee_enabled` (default false on player — parked); orb deflect behind `deflect_orb_enabled` (default false); `consume_cooldown()` for proximity redirect without a swing; hides `%AttackSpriteHint` while a redirect target exists or melee is off; optional `swing_sound` (unassigned)
- `project/components/orb_tether_component.gd` — focus radius (48 px on player scene), … **`capture_enabled`** (false on player) gates tap capture + remote channel; tether press order: release owned tether → **summoning circle `try_activate()`** if in `DepositArea` → **glyph** pickup → orb capture (if capture on); …
- `project/components/dash_component.gd` — … **`can_dash()`** (false while carrying a **glyph**) …
- `project/components/directional_sprite_component.gd` — 8-way logical facing on an `AnimatedSprite2D` with 4-way diagonal visuals; `face(dir)` / `play(action)` / `facing_vector()`; animations named `<action>_<visual>` (`idle_sw`, later `walk_ne`, etc.); cardinals map to nearest diagonal suffix

### State machine base
- `project/entities/_base/state.gd` — `class_name State extends Node`; `signal finished(next_state_name)`; virtual `enter/exit/update/handle_input`
- `project/entities/_base/state_machine.gd` — `@export start_state: NodePath`; `states_map` (lowercase child names); 2-deep stack; `force_state(name)`; optional debug label

### Entities
- `project/entities/player/player.tscn` + `player.gd` — … carry API for **glyphs** (`pick_up_item` / `try_throw_item` / `is_carrying_item`); …
- `project/entities/player/players.gd` — `class_name Players`; static roster helpers over the `player` group (`all` / `closest_to` / `count`); used by level lose, electric current, and any co-op nearest-player query
- `project/entities/player/player_action.gd` — `class_name PlayerAction`; `@export action: String`; suffixed at runtime
- `project/entities/player/controls.gd` — `class_name Controls`; `apply_player_index(index)`; `uses_mouse()` (P1 only); `get_move_vector()`, `get_aim_vector(origin)`, `is_attack_just_pressed()`, `is_tether_just_pressed()`, `is_dash_just_pressed()`
- `project/entities/player/states/idle.gd` — stops movement; transitions to walk, dash; attack throws a carried crystal first, else tries `try_redirect_attack()` (stays idle on success); out-of-range Attack does nothing while melee parked; mouse GUI gate only when `controls.uses_mouse()`; attack blocked while tethering; walk/dash blocked while tethering
- `project/entities/player/states/walk.gd` — moves from `controls.get_move_vector()`; transitions to idle, dash; attack throws a carried crystal first, else tries `try_redirect_attack()` (stays walk on success); out-of-range Attack does nothing while melee parked; mouse GUI gate only when `controls.uses_mouse()`; attack blocked while tethering; forces idle while tethering
- `project/entities/player/states/attack.gd` — snapshots aim, starts `AttackComponent`; returns to idle when swing ends (reachable only if `melee_enabled`)
- `project/entities/player/states/dash.gd` — dashes along `directional_sprite.facing_vector()`; locked input until dash ends, then idle/walk
- `project/entities/orbs/blank/blank_orb.tscn` + `blank_orb.gd` (`class_name BlankOrb`) — … **`glyph_drop`** + **3 sparse glyph slots** (`apply_glyph` / `apply_glyph_at` / `has_glyph_at` / `socketed_count` / `remove_glyph`, `get_stat_snapshot`); **`begin_circle_capture`** / **`release_from_circle`** / **`assume_circle_capture`** for summoning ritual; …
- `project/entities/orbs/ghost/ghost_orb.tscn` + `ghost_orb.gd` (`class_name GhostOrb`) — dark-purple tint; skips enemy impact HP; on hit enters `POSSESSED` (hide, follow host in world space, 3 DPS via `take_damage(..., SHADOW)`, dark `damage_flash_color`); calls `super.on_hitbox_hit` for weight/splash/status; `DamageComponent.damage_kind = SHADOW` for player/breakable contact labels; emerges on `DestroyComponent.destroyed` with random `begin_flight` (no grace)
- `project/entities/orbs/rot/rot_orb.tscn` + `rot_orb.gd` (`class_name RotOrb`) — green tint; poison stacks from GameData `poison` stat via base `on_hitbox_hit`
- `project/entities/orbs/conduit/conduit_orb.tscn` + `conduit_orb.gd` (`class_name ConduitOrb`) — yellow-cyan tint; `%CurrentLine` + `%CurrentArea` / `%CurrentShape` (enemy-mask capsule); while closest player within 130 px, beam ticks 5 HP + 3 Shock per second (skip Shock while stunned); impact shock stacks from GameData
- `project/entities/orbs/aim_arrow.gd` — three pulsing chevrons outside the orb along player aim (`set_redirect_preview`)
- `project/entities/enemies/grunt/grunt_knife.tscn` + `grunt_knife.gd` — component-driven chaser; Health max 20 / HealthBar / Damage with 0.75s contact tick / Destroy / Movement / Knockback / Navigation / Status / HitboxComponent
- `project/entities/enemies/brute/brute.tscn` + `brute.gd` — same path/avoidance stack as grunt; left-facing sprite via `MovementComponent.sprite_flip_inverted`; larger collision (r=15); Health max 50 / HealthBar / Damage 3.0 with 0.75s contact tick / Navigation / Status
- `project/entities/enemies/spawner/enemy_spawner.tscn` + `enemy_spawner.gd` — wave director; inspector `waves` (`EnemyWave` / `EnemySpawnEntry`); nav-valid **and physics-clear** spawn points that stay `min_spawn_distance` from **any** living player and path to at least one; pack separation (enemy body overlap vs `world` colliders rejected at spawn-time); telegraph then reverse pixel-fall assemble; assembling enemies keep physics layers but disable shapes/hitbox/chase until assemble finishes; a short depenetration pass runs when collision is re-enabled before chase resumes; `all_cleared` when every wave is issued and every instanced enemy is dead; desert default: 3 grunts, then 1 brute after 6s

### Objects
- `project/objects/_base/level_object.gd` — solid prop base (`StaticBody2D` on world layer; random variant; bounce material)
- `project/objects/_base/breakable.gd` — `extends LevelObject`; `COMPONENTS` dict; `breakables` group; destroyed via `COMPONENTS[HealthComponent].take_damage()` from orb `_try_apply_orb_damage` on `body_entered`
- `project/objects/_base/level_object_variant.gd` — Resource: texture + hand-tuned collision size/offset
- `project/objects/cactai/cactus.tscn` — breakable cactus; `max_health = 5.0`; Components: HealthComponent + HealthBarComponent + DestroyComponent
- `project/objects/rocks/rock.tscn` — solid rock (no components; bounces only)
- `project/objects/rocks/big_rock.tscn` — breakable rock; `max_health = 60.0`; single variant (`big_rock.tres`); scene remains, not currently placed in `desert.tscn`
- `project/objects/animal_skull.tscn` — breakable skull; `max_health = 20.0`; single variant (`animal_skull_variant.tres`); scene remains, not currently placed in `desert.tscn`
- `project/objects/summoning_circle/summoning_circle.tscn` + `.gd` — floor circle with `%DepositArea` (player + item + **orb** mask), `%ManaPoolLabel`, `%ArcaneParticles`; owns `mana_pool` + **3-slot `glyph_inventory`**; `deposit` / `spend` / **`try_activate()`** (escalating cost **0, 5, 10…**) / **`deactivate()`** / **`receive_glyph`** / **`add_inventory_entry`** / **`insert_inventory_entry`** / **`apply_start_config`** / **`capture_orb`** / **`release_orb`** / **`swap_captured_orb`**; signals `ritual_started` / `ritual_ended` / `inventory_changed`; group `summoning_circle`
- `project/items/glyphs/glyph.tscn` + `.gd` — RigidBody2D pickup on `item` layer; `glyph_id` + **Rarity**; element texture + **unison center-rune blink** (`glyph_rarity.gdshader` via `Glyph.apply_rarity_visual`) + Rare/Unique rising motes; tether pickup, carry, Attack throw, deposit → circle inventory or overflow mana; group **`glyphs`**
- `project/items/glyphs/glyph_rarity.gdshader` — canvas_item: recolors bright/white center-rune pixels to a rarity base tint and blinks toward a darker tint (Common white / Rare jade / Unique purple); per-item duplicated ShaderMaterial
- `project/items/glyphs/glyph_rarity_particles.tscn` — rising pixel motes; color via node modulate; amount 8 Rare / 16 Unique
- `project/ui/attributes/attribute_box.tscn` + `.gd` — **`AttributeBox`** (`@tool` `HBoxContainer`); `@export icon_id` dropdown scans `res://ui/attributes/*.png` and applies to `%Icon`; `@export value` + `value_format` (`DECIMAL` / `PERCENT`, fraction × 100 for %) + `decimal_places` (`0` / `1` / `2`) drive `%Value`; `@export unknown` shows `"?"` instead of a formatted number (ritual ??? hint preview)
- `project/ui/inventory/orb_inventory.tscn` + `.gd` — **`OrbInventoryBar`**: 3 orb sockets + mana label + 3 glyph sockets; outline on the ritual-captured / inspect-selected orb; ritual: inventory orbs not focusable; inspect: emits `orb_selected` on click; emits `glyph_grab_requested` when glyphs are interactive
- `project/ui/ritual_menu/ritual_menu.tscn` + `.gd` — **`RitualMenu`** (`CanvasLayer`, `PROCESS_MODE_WHEN_PAUSED`); modes **ritual** / **inspect**; ritual: focused orb stats/effect, sparse-slot drag-and-drop socket/recycle with swap; **2-glyph** four hints + **3-glyph** single centered larger result hint when a recipe exists (controller-focusable / mouse-hoverable; white outline; preview name/effect/stats in the main panel, `???` placeholders; uppercase hint + orb names); no Transform side info panel; Transform, Buy, Done; controller confirm picks socketed glyphs back up; inspect (`open_inspect`): hides Transform / recycle / buy / hints, blocks mutations, inventory orbs selectable, `inspect_closed` on Done / pause; `pause` closes either mode
- `project/globals/orb_recipes.gd` — **`OrbRecipes`**: unordered element-multiset lookups over `orbs` / `attunements`; `hints_for` / `result_for` / `is_playable` / provisional `is_discovered`
- `project/items/item_picked_up.ogg` + `.tres` — shared SoundEvent for picking up items
- `project/items/mana_crystal_deposited.ogg` + `.tres` — SoundEvent played when a crystal finishes depositing

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
- `project/effects/damage_label.tscn` + `damage_label.gd` — world-space floating damage number (`%Label`, `pixel_medium.fnt` size 8); rises ~20 px over 1 s and fades in the last 0.3 s (`ignore_time_scale`)
- `project/effects/damage_label_effect.gd` — `DamageLabelEffect.spawn_at(origin, amount, kind)`; parents detached label to `current_scene`; colors STANDARD white / POISON green / SHADOW black / CRIT gold / BURN orange (light outline on black)
- `project/effects/time_slow.gdshader` — canvas-item shader: vignette + purple-blue tint; `intensity` uniform (0 = off, 1 = full)
- `project/effects/time_slow_overlay.tscn` + `time_slow_overlay.gd` — `TimeSlowOverlay` (`CanvasLayer`, layer −1); owns a fullscreen `ColorRect` with the time-slow shader; `begin()` ramps `Engine.time_scale` 1.0 → 0.5 over 0.5 real seconds and drives shader intensity; `end()` snaps both back; instanced in `desert.tscn` HUD (before `StatusLabel`)

### Audio
- `project/audio/audio_manager.tscn` — autoload; Music A/B crossfade; 8 global + 16 positional pooled players (oldest-voice steal); `play` / `play_at` / `play_music` / bus volume helpers
- `project/audio/sound_event.gd` — `SoundEvent` Resource: stream variants, bus, volume_db, pitch range, retrigger cooldown, max voices, avoid_repeat
- Convention: author a `SoundEvent` `.tres` next to the clip it wraps (same pattern as `LevelObjectVariant`)
- Wired events: entity destroyed/damaged, dash, orb bounce (`impact_soft`), begin/release tether, item pickup, mana crystal deposit; attack swing export exists but unassigned

### Data
- `project/data/game_data.xlsx` — source workbook; `schema` sheet lists column types per data sheet; current sheets: `orbs`, `glyphs`, `attunements`, `motion` (plus unused `objects_OLD` / `input` not in schema)
- `project/data/export_game_data.py` + `export_game_data.bat` + `requirements.txt` — Excel → JSON export (`openpyxl`); schema types: `string`, `int`, `float`, `boolean`
- `project/data/game_data.json` — runtime dump; regenerate after editing the xlsx (double-click `.bat` or `python export_game_data.py`)
- `project/globals/game_data.gd` — `GameData` autoload: `tables` / `tables_by_id`; `BlankOrb` loads `orbs` stats (**`glyph_drop`**); **`Glyph`** / ritual socketing read **`glyphs`** rows (`attribute`, rarity tiers); **`OrbRecipes`** reads `orbs` / `attunements` element recipes; motion not wired yet

---

## Groups

| Group | Used by |
|-------|---------|
| `player` | Player root |
| `enemies` | Enemy roots |
| `orb` | BlankOrb roots (`blank_orb.gd`); opening launch places multiple in this group |
| `breakables` | Breakable props (cactus, etc.) |
| `glyphs` | Glyph roots (`glyph.gd`) |
| `summoning_circle` | SummoningCircle roots (`summoning_circle.gd`) |
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
| `pause` | Esc, gamepad Start (any device) | — |

P1 keyboard/mouse actions use `device: -1` (any keyboard/mouse). P2 is gamepad-only (device 1). `_3` / `_4` action sets not yet authored (add with device 2/3 when needed). Aim direction for P1 falls back to mouse when the right stick is at rest. `level.gd` adds P2 automatically when two or more gamepads are connected (same assemble intro as P1; mid-level plug-in still hot-joins); run ends only when all players in the `player` group are dead. `pause` opens inspect inventory (view-only ritual menu) or closes an already-open ritual/inspect menu.

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
- UI text uses `res://ui/fonts/pixel_medium.fnt` (project `gui/theme/custom_font`). Keep the `.fnt` next to `pixel_medium.png`; import the PNG as Skip so only the BMFont importer consumes the atlas. Use font size 16 or integer multiples.
- Level objects: origin is **bottom-center** of the art; collision size/offset lives in a per-variant `LevelObjectVariant` Resource; shapes are built in code so instances do not share a mutated sub-resource.
- Keep this file updated when autoloads, scenes, scripts, groups, or physics layers change.

## Scratch / experimental
None yet.
