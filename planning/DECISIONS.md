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
- **Why**: Forces constant spatial awareness; every redirect is a risk trade.
- **Alternatives**: Bullet only hurts enemies — loses the dodge fantasy; damage-over-time to player — less arcade-readable.
- **Status**: decided (design)

### Redirect via proximity + button, brief slow-mo, then choose direction
- **Decision**: Get close to the bullet, press Space, time slows briefly, player picks a new direction with A/D or mouse. Opening shot uses the same aim UX for 3 real-time seconds; redirects use 1.5s. Player movement is locked while aiming.
- **Why**: Gives agency without removing the skill of positioning and timing; shared aim UX keeps the opening shot teachable.
- **Alternatives**: Always-on aim control — removes tension; automatic wall-aim assist — too passive; allow walking while aiming — conflicts with A/D rotation.
- **Status**: decided (in-codebase)

### Single basic enemy: chase + contact kill
- **Decision**: First enemy type is a chaser (`grunt_knife`) that kills the player on contact. Prototype spawns 3.
- **Why**: Simple pressure while the bullet/redirect loop is proven.
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
- **Why**: Focus production on the bullet/redirect/shop loop.
- **Alternatives**: Heavy campaign narrative — distracts from the arcade core.
- **Status**: decided (design)

### Saloon stages with randomized enemies, obstacles, and breakables
- **Decision**: Each stage is a saloon layout with randomized enemies/obstacles; obstacles can interact with the bullet (e.g. TNT); breakables can drop powerups.
- **Why**: Variety and environmental play without leaving the fantasy setting.
- **Alternatives**: Static hand-authored only levels — less replay; pure empty arenas — less toy potential.
- **Status**: decided (design)

---

## Open design tensions

- **Redirect limits**: cooldown vs charges vs unlimited?
- **Gold vanish duration**: how long before drops disappear?
- **Shop draft size and reroll rules**: how many offers, costs, rerolls?
- **Camera / view perspective**: side-view character sprites in a flat arena; confirm long-term camera.

---

## Technical decisions (from current codebase)

### Engine: Godot 4.7, Forward Plus, viewport stretch
- **Decision**: Godot project at `project/` uses Godot **4.7**, Forward Plus, `window/stretch/mode="viewport"` with `aspect="expand"`, nearest-neighbour canvas texture filter, 640x360 base resolution.
- **Why**: Matches the current `project.godot` scaffold and keeps pixel art crisp.
- **Alternatives**: `canvas_items` stretch — softer scaling; filtered textures — blurry sprites.
- **Status**: decided (in-codebase)

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
- **Decision**: Opening aim is 3.0s and redirect aim is 1.5s of **wall-clock** time via `Time.get_ticks_msec()`, while `Engine.time_scale = 0.15` during aim.
- **Why**: Slow-mo must not stretch the intended aim deadline.
- **Alternatives**: Use scaled `delta` timers — windows become much longer than designed.
- **Status**: decided (in-codebase)

### Post-launch player grace
- **Decision**: After every launch (opening or redirect), the bullet ignores the player for 0.3s.
- **Why**: Redirect requires proximity; without grace the player dies on the same frame they fire.
- **Alternatives**: Teleport bullet away on redirect — less readable; disable player hit forever until leave range — easier to cheese.
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
