# One Last Bullet — Decision Log

This is a living log of decisions that shape the game and codebase. Add entries when a choice affects multiple systems or would be costly to reverse.

## Format
- **Decision**: what we chose
- **Why**: the reason / constraint
- **Alternatives**: what we *didn't* choose (and why)
- **Status**: decided / revisit / superseded / planned

---

## Gameplay & design decisions

### One bullet, fired at level start, bounces forever
- **Decision**: The player has a single bullet. It is fired at the start of each level and travels/bounces indefinitely.
- **Why**: The whole fantasy is "one last bullet" — scarcity and danger in the same object.
- **Alternatives**: Multi-shot ammo pool — dilutes the hook; bullet that despawns — removes the constant threat.
- **Status**: decided (design)

### Bullet damages enemies; kills player on contact
- **Decision**: The same projectile is a weapon against enemies and an instant-death hazard for the player.
- **Why**: Forces constant spatial awareness; every deflect is a risk trade.
- **Alternatives**: Bullet only hurts enemies — loses the dodge fantasy; damage-over-time to player — less arcade-readable.
- **Status**: decided (design)

### Redirect via proximity + button, brief slow-mo, then choose direction
- **Decision**: Get close to the bullet, press Space, time slows briefly, player picks a new direction with the mouse. Opening shot uses the same aim UX for 3 real-time seconds; redirects use 1.5s. Player movement is locked while aiming.
- **Why**: Gave agency without removing positioning/timing skill; shared aim UX kept the opening shot teachable.
- **Alternatives**: Always-on aim control — removes tension; automatic wall-aim assist — too passive; keyboard rotation (A/D) — removed in favor of mouse-only aim.
- **Status**: superseded — mid-combat redirect replaced by arc attack (see below). Opening aim (3s slow-mo) remains.

### Arc attack deflects the orb; knocks enemies back
- **Decision**: Mid-combat steering is a mouse-aimed 90° melee arc (radius 16 px, 6-frame AnimationPlayer). The orb reflects off the radial normal when it overlaps the active hitbox; enemies hit by the same arc receive knockback (no melee damage). Opening shot still uses the 3s slow-mo aim window.
- **Why**: One action, two jobs; more arcade and readable than proximity slow-mo redirect; removes global mid-combat `Engine.time_scale` pauses; keeps player control of orb direction via aim + contact point.
- **Alternatives**: Orbit-capture (attack holds the orb in a circle until second press) — too many steps / harder to read; keep mouse-aim slow-mo redirect — locks movement and slows all players in co-op; proximity-only redirect without a swing — weaker sheriff fantasy.
- **Status**: decided (in-codebase)

### Single basic enemy: chase + contact kill
- **Decision**: First enemy type is a chaser (`grunt_knife`) that kills the player on contact. Prototype spawns 3.
- **Why**: Simple pressure while the bullet/attack loop is proven.
- **Alternatives**: Ranged enemies first — more systems before the core loop is solid; brute enemy — deferred.
- **Status**: decided (in-codebase)

### Gold drops vanish if not picked up quickly
- **Decision**: Enemies drop gold that disappears after a short window.
- **Why**: Creates risk/reward: leave safe space to grab loot while the bullet and enemies threaten.
- **Alternatives**: Permanent gold until leave — less tension; auto-collect — removes the skill beat.
- **Status**: decided (design); vanish duration TBD; not in prototype yet

### Run structure: clear level → shop → repeat; 10 levels to win
- **Decision**: Clear all enemies to finish a level; shop between levels; win the run after 10 clears. Death ends the run.
- **Why**: Classic roguelike cadence with a defined climax length.
- **Alternatives**: Endless mode only — no climax; shorter runs — less room for synergy builds.
- **Status**: decided (design); shop/multi-level not in prototype yet

### Shop upgrades: bullet / player / enemy curses; synergies matter
- **Decision**: Between-level shop offers randomized upgrades that improve the bullet, the player, or curse enemies. Synergies are intentional fun.
- **Why**: Keeps runs distinct and rewards build-crafting without a huge combat ruleset.
- **Alternatives**: Fixed upgrade tree — less replay discovery; only player buffs — thinner fantasy.
- **Status**: decided (design)

### Minimal story; gameplay-first arcade
- **Decision**: Story is lean (Sheriff defending the saloon). No deep narrative required for v1.
- **Why**: Focus production on the bullet/attack/shop loop.
- **Alternatives**: Heavy campaign narrative — distracts from the arcade core.
- **Status**: decided (design)

### Saloon stages with randomized enemies, obstacles, and breakables
- **Decision**: Each stage is a saloon layout with randomized enemies/obstacles; obstacles can interact with the bullet (e.g. TNT); breakables can drop powerups.
- **Why**: Variety and environmental play without leaving the fantasy setting.
- **Alternatives**: Static hand-authored only levels — less replay; pure empty arenas — less toy potential.
- **Status**: decided (design)

---

## Open design tensions

- **Attack cooldown / charges**: current cooldown is 0.35s; revisit if spam-steering feels too strong.
- **Gold vanish duration**: how long before drops disappear?
- **Shop draft size and reroll rules**: how many offers, costs, rerolls?
- **Camera / view perspective**: side-view character sprites in a flat arena; prototype uses a fixed centered `Camera2D` on the 640×360 arena.
- **Co-op opening aim**: `Engine.time_scale` during the level-start aim is still global.

---

## Technical decisions (from current codebase)

### Engine: Godot 4.7, Forward Plus, canvas_items stretch + integer scale
- **Decision**: Godot project at `project/` uses Godot **4.7**, Forward Plus, `window/stretch/mode="canvas_items"` with `aspect="expand"`, `scale_mode="integer"`, nearest-neighbour canvas texture filter, snap 2D transforms to pixel, 640x360 base resolution.
- **Why**: Matches the current `project.godot` scaffold and keeps pixel art crisp.
- **Alternatives**: `canvas_items` stretch — softer scaling; filtered textures — blurry sprites.
- **Status**: decided (in-codebase)

### Component architecture: COMPONENTS dict + ComponentHandler

- **Decision**: Every combat/movable entity root declares `var COMPONENTS: Dictionary = {}`. A child `Node2D` running `component_handler.gd` registers every grandchild component into that dict keyed by its GDScript class reference (e.g. `COMPONENTS[HealthComponent]`). Same-entity refs use `@export` NodePaths; cross-entity refs use `area.owner.COMPONENTS[SomeComponent]` at collision time. No base `Component` class.
- **Why**: Composition over inheritance; components stay independent; easy to add/remove per entity type without changing a class hierarchy.
- **Alternatives**: Inheritance (`Enemy extends Character`) — becomes flag soup for diverse entities; NodePath exports without dict — O(n) get_node calls; signal bus — more indirection than needed for a small game.
- **Status**: decided (in-codebase)

### Health: one-hit-kill expressed as max_health = 1.0

- **Decision**: `HealthComponent.max_health` defaults to `1.0`. Player, grunt, and cactus all have `max_health = 1.0`, preserving the one-hit-kill design. Multi-HP entities will just set a higher value.
- **Why**: Keeps gameplay rules encoded in data rather than special-casing HP logic; multi-hit enemies are a future slider, not a code change.
- **Alternatives**: A bool `is_one_shot` — extra flag for something already handled by the value itself.
- **Status**: decided (in-codebase)

### Damage flow: HitboxComponent area-vs-area

- **Decision**: Hit detection uses `HitboxComponent` (`Area2D`) on both attackers and victims. `area_entered` on the victim's hitbox reads `area.owner.COMPONENTS[DamageComponent]` to get damage and instigator, then calls the victim's `HealthComponent.take_damage()`. Breakables are the exception: they stay body-contact (bullet `body_entered`) so the bounce impulse resolves before `queue_free()`.
- **Why**: Decouples hit registration from physics; friendly-fire filter is a single instigator check; no new physics layers.
- **Alternatives**: Area-vs-body — can't filter on DamageComponent; signal bus — extra indirection.
- **Status**: decided (in-codebase)

### Instigator-based player grace (replaces timestamp check)

- **Decision**: On `_launch()`, `DamageComponent.instigator` is set to the player who aimed and cleared after `player_grace_seconds`. `HitboxComponent` skips damage when `instigator == owner`. This replaces the previous `player_grace_until_msec` wall-clock guard in `_resolve_hit`.
- **Why**: Co-op correctness — only the aiming/deflecting player is briefly immune, not all players; the logic lives in data rather than in a custom branch inside `_resolve_hit`.
- **Alternatives**: Timestamp guard — correct for single-player but breaks for multi-player (which player to protect?).
- **Status**: decided (in-codebase)

### Signal-based player state machine (finished signal + 2-deep stack)

- **Decision**: Player states are `Node` children of `StateMachine`. Each state emits `signal finished(next_state_name)` (lowercase child name, or `"previous"`). The machine maps child names to nodes at `_ready`; all state lifecycle calls go through `update(delta)` / `handle_input(event)` / `enter()` / `exit()`. A `State` base class with `class_name` provides typed virtuals.
- **Why**: Decouples transition logic from the machine; states are scene-tree nodes (easy to inspect/debug); `"previous"` enables one-level undo without a full stack.
- **Alternatives**: Return-value transitions — state must know the machine's state set; full stack — over-engineered for 3 states; node-group polling — no explicit lifecycle.
- **Status**: decided (in-codebase); states: Idle, Walk, Aim, Attack

### Per-player input: static action duplication + runtime suffix

- **Decision**: P1 actions (`move_up`, `attack`, etc.) are authored in `project.godot` with keyboard/mouse + gamepad device 0. P2 duplicates (`move_up_2`, etc.) are hand-authored in `project.godot` with gamepad device 1 only. At runtime, `Controls.apply_player_index(n)` appends `""` / `"_2"` suffix to every `PlayerAction.action`. P3/P4 action sets (`_3`, `_4`) are added in the same pattern when needed.
- **Why**: No autoload needed; all bindings visible in Project Settings → Input Map; Godot's built-in action system handles device filtering.
- **Alternatives**: Runtime duplication autoload (clone base actions to `_2/_3/_4` at startup) — adds an autoload and makes bindings invisible in Project Settings; plain `InputEvent.device` filtering in every script — more per-script boilerplate.
- **Status**: decided (in-codebase); P1 + P2 authored; P3/P4 not yet authored

### Main scene is desert level; no autoloads yet
- **Decision**: `run/main_scene` is `areas/level/desert.tscn`. Level logic lives on the scene root (`level.gd`). No autoloads yet.
- **Why**: Prototype is a single scene; avoid global state until shop/run flow needs it.
- **Alternatives**: Early GameManager autoload — premature for one arena.
- **Status**: decided (in-codebase)

### Arena walls as StaticBody2D border slabs
- **Decision**: Bullet/player world collision uses four `StaticBody2D` wall slabs around the viewport, not TileMap physics polygons.
- **Why**: Current desert tileset has no physics layer; border slabs keep the bullet on-screen cheaply.
- **Alternatives**: Author per-tile collision — more setup before the loop is proven.
- **Status**: decided (in-codebase)

### Bullet is RigidBody2D with circle bounce + capsule hitbox
- **Decision**: `LastBullet` is a `RigidBody2D` with a circular body shape (world bounce only), locked rotation, gravity 0, bounce 1 / friction 0 material, continuous CCD, and per-frame speed renormalization. Hits use a separate capsule `Area2D` under a `%Heading` pivot that rotates with travel direction.
- **Why**: Circle bounces are angle-independent; capsule matches the sprite silhouette for hits; Godot 2D has no per-shape layers so the capsule cannot live on the rigid body.
- **Alternatives**: `CharacterBody2D` + manual `bounce(normal)` — more code, same outcome; capsule on the rigid body — lopsided wall bounces.
- **Status**: decided (in-codebase)

### Aim windows measured in real time under Engine.time_scale
- **Decision**: Opening aim is 3.0s of **wall-clock** time via `Time.get_ticks_msec()`, while `Engine.time_scale = 0.15` during aim. Mid-combat redirect aim windows are gone.
- **Why**: Slow-mo must not stretch the intended aim deadline.
- **Alternatives**: Use scaled `delta` timers — windows become much longer than designed.
- **Status**: decided (in-codebase)

### Post-launch player grace
- **Decision**: After every launch (opening or deflect), the bullet ignores the player for 0.3s.
- **Why**: Deflecting requires proximity; without grace the player dies on the same frame they bat the orb.
- **Alternatives**: Teleport bullet away on deflect — less readable; disable player hit forever until leave range — easier to cheese.
- **Status**: decided (in-codebase)

### KnockbackComponent for shove without damage
- **Decision**: `KnockbackComponent` applies a decaying shove to its owner (`CharacterBody2D` via velocity + `move_and_slide`, `RigidBody2D` via impulse, plain `Node2D` via position). Enemies yield chase AI while knockback is active. Built generic so breakables/objects can reuse it later.
- **Why**: Attack needs a non-damage response for enemies; keeps shove logic out of MovementComponent and entity scripts.
- **Alternatives**: Bake knockback into MovementComponent — couples walk and shove; one-off velocity in grunt script — not reusable for props.
- **Status**: decided (in-codebase)

### Level objects: shared script + per-variant Resource
- **Decision**: Solid and breakable props share `LevelObject` / `Breakable` scripts. Each object type is its own scene (`cactus.tscn`, `rock.tscn`) that holds an array of `LevelObjectVariant` Resources (texture + hand-tuned collision). Runtime picks a random variant.
- **Why**: Same behavior with different art/collision without duplicating scripts; avoids a flag-driven mega-scene; adding rock_2 is a new `.tres` + array entry.
- **Alternatives**: One general object scene with `is_destructible` exports — becomes flag soup for TNT later; fully separate scene/script per art file — duplicated physics setup.
- **Status**: decided (in-codebase)

### Breakables bounce then destroy via bullet body contact
- **Decision**: Breakables (cactus) live on the `world` physics layer like rocks/walls. The bullet destroys them via its `RigidBody2D.body_entered` contact (not the leading capsule `Hitbox` area), so the bounce impulse is solved before `queue_free()`.
- **Why**: Props should reshape bullet paths; using the leading hitbox would destroy the body before bounce. No fifth physics layer needed.
- **Alternatives**: Punch-through (no bounce) — less spatial play; dedicated `breakable` layer + hitbox area — destroys before bounce; multi-hit health — deferred.
- **Status**: decided (in-codebase)

### Pixel art rendering: smooth pixel shader + aligned bullet speed
- **Decision**: Character sprites (player, enemies, bullet) use shared `smooth_pixel_material.tres` (CptPotato-style derivative filtering) with **Linear** sprite filter. Bullet speed is **180 px/s** (3 px/frame at 60 Hz). Physics interpolation is **off**.
- **Why**: Nearest-neighbor + sub-pixel motion/rotation caused visible shimmer; the smooth pixel shader antialiases rotated/scaled sampling without blurring integer-scale art as badly as plain Linear. Disabling physics interpolation avoids in-between sub-pixel draw frames.
- **Alternatives**: `%VisualOffset` pixel snap — removed; fought the shader; 8-way rotation snap — removed; physics interpolation on — reintroduced jitter on pixel art; snap 2D transforms to pixel on — fights smooth pixel filtering.
- **Status**: decided (in-codebase)

### Fixed Camera2D centered on the arena
- **Decision**: `desert.tscn` uses a static `Camera2D` at `(320, 180)` — arena center for the 640×360 viewport. No smoothing, no player follow.
- **Why**: The prototype arena matches the viewport; a fixed camera shows the full playfield without sub-pixel pan jitter.
- **Alternatives**: Player-following camera with pixel rounding — useful for larger scrolling levels later; no camera — same outcome when the root is the view.
- **Status**: decided (in-codebase)

### Destruction VFX: detached sprite + canvas pixel-fall shader
- **Decision**: On breakable/enemy/player death, disable collision, emit gameplay signals immediately, spawn a detached `Sprite2D` copy with `pixel_fall.gdshader`, then `queue_free()` the entity. `DestructionEffect.play_from_sprite()` owns the FX life cycle (tween `progress` → free).
- **Why**: Gameplay stays snappy (win/lose and bounce timing unchanged) while pixels crumble visually; one helper works for props and characters without delaying entity teardown.
- **Alternatives**: Animate in-place and delay `queue_free()` — risks leftover collision and win-count timing bugs; GPU particles of colored quads — heavier setup and less 1:1 with sprite art; CPU `Image` pixel scatter — more code for the same look.
- **Status**: decided (in-codebase)
