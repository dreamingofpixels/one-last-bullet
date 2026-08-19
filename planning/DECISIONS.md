# A Final Spell — Decision Log

This is a living log of decisions that shape the game and codebase. Add entries when a choice affects multiple systems or would be costly to reverse.

## Format
- **Decision**: what we chose
- **Why**: the reason / constraint
- **Alternatives**: what we *didn't* choose (and why)
- **Status**: decided / revisit / superseded / planned

---

## Gameplay & design decisions

### One orb of chaos, fired at level start, bounces forever
- **Decision**: The player has a single spell — the **orb of chaos**. It enters play at the start of each level and travels/bounces indefinitely.
- **Why**: Scarcity and danger in the same object; the wizard has one wild spell left to survive the room.
- **Alternatives**: Multi-shot mana pool — dilutes the hook; orb that despawns — removes the constant threat.
- **Status**: decided (design); supersedes "One bullet, fired at level start"

### Orb damages enemies; hurts player on contact
- **Decision**: The same projectile is a weapon against enemies and a hazard for the player. Player and grunt start at **3 HP**; orb damage defaults to **1**. Player gets brief i-frames after a non-fatal hit.
- **Why**: Forces constant spatial awareness; multi-hit HP lets the dodge fantasy breathe without making every graze an instant run-ender.
- **Alternatives**: Instant-kill on player contact — previous design; too punishing once tether proximity is required; orb only hurts enemies — loses the dodge fantasy.
- **Status**: decided (in-codebase)

### Redirect via proximity + button, brief slow-mo, then choose direction
- **Decision**: Get close to the bullet, press Space, time slows briefly, player picks a new direction with the mouse. Opening shot uses the same aim UX for 3 real-time seconds; redirects use 1.5s. Player movement is locked while aiming.
- **Why**: Gave agency without removing positioning/timing skill; shared aim UX kept the opening shot teachable.
- **Alternatives**: Always-on aim control — removes tension; automatic wall-aim assist — too passive; keyboard rotation (A/D) — removed in favor of mouse-only aim.
- **Status**: superseded — mid-combat redirect replaced by arc attack, then tether; opening aim replaced by opening tether (see below).

### Arc attack deflects the orb; knocks enemies back
- **Decision**: Mid-combat steering is a mouse-aimed melee arc (authored `CollisionPolygon2D` on `AttackComponent`, 6-frame AnimationPlayer). The orb reflects off the radial normal when it overlaps the active hitbox; enemies hit by the same arc receive knockback (no melee damage). Opening shot later moved to tether (see opening tether entry).
- **Why**: One action, two jobs; more arcade and readable than proximity slow-mo redirect; removes global mid-combat `Engine.time_scale` pauses; keeps player control of orb direction via aim + contact point; scene-authored polygon is easier to tune against the arc art than a procedurally rebuilt wedge.
- **Alternatives**: Orbit-capture (attack holds the orb in a circle until second press) — previously rejected as too many steps / harder to read (now being re-tried; see tether entry below); keep mouse-aim slow-mo redirect — locks movement and slows all players in co-op; proximity-only redirect without a swing — weaker melee fantasy; runtime `ConvexPolygonShape2D` from radius/degrees exports — replaced by authored polygon.
- **Status**: revisit — orb deflect gated behind `AttackComponent.deflect_orb_enabled` (default false); swing + enemy knockback still active. Code kept for rollback.

### Same-direction chase hits push along aim
- **Decision**: When the orb's velocity aligns with the player→orb radial normal (dot above a tunable threshold, default 0.5), skip `Vector2.bounce` and set exit velocity to the attack aim direction. Side and inbound hits still use radial bounce.
- **Why**: Pure radial bounce flips ~180° when chasing from behind, which feels like the bat reversed the orb instead of carrying it forward along the swing.
- **Alternatives**: Always bounce on radial normal — unrealistic chase reversals; always set velocity to aim — loses readable glancing deflections; blend bounce + aim — more tuning for little gain; arc-surface contact normal — more accurate physically but harder to author and debug for a small polygon.
- **Status**: revisit — only matters when `deflect_orb_enabled` is true; code kept.

### Orb tether capture: focus range, orbit, release on tangent
- **Decision**: Mid-combat steering is proximity tether. When the flying orb is within 48 px (`focus_radius`), it shows an `OrbInFocus` overlay. The dedicated `tether` input (right click / gamepad X; `TetherAction` under Controls) captures it; the orb keeps its current position and **spirals in** to the fixed **24 px** (`min_tether_radius`) orbit while continuing to travel. A second tether press or **two full revolutions** releases it along the current tangent at full orb speed. Attack remains melee-only and does not capture/release. Player movement and dash are locked while tethered. Each release multiplies orb `speed` and `DamageComponent.damage` by `tether_release_boost` (default **1.1 / +10%**), stacking for the rest of the level; `speed` is clamped to `max_speed` (**1500**). While tethered the orb damages enemies; the tethering player is immune via `DamageComponent.instigator` for the whole tether plus post-release grace. Short cooldown after release (~0.25s) prevents instant re-grab. Driven by `OrbTetherComponent` on the player + `begin_tether` / `release_tether` / `break_tether` on the orb.
- **Why**: Separate tether from attack so melee knockback stays available near the orb; clearer "grab and sling" fantasy than batting; locking the player while the orb orbits makes the sling a committed stance; stacking speed/damage rewards repeated successful slings.
- **Alternatives**: Variable orbit radius (capture distance) — removed because orbit size was unpredictable; teleport on tap to min radius — felt like a snap, spiral is more readable; one revolution — too short, especially at close range; free movement while tethered — weaker commitment and easier to cheese positioning; no release boost — less reward for risking the tether; aim-directed slingshot on release — more UI and less "continue forward" readability; inert tether (no enemy damage) — weaker as a spinning weapon.
- **Status**: decided (in-codebase); playtest may restore arc deflect.

### Remote tether channel (hold 2s to pull distant orb)
- **Decision**: Holding the tether button for 2 s when the orb is flying but out of `focus_radius` **teleports** the orb to the player→orb axis at **`min_tether_radius` (24 px)** and begins orbiting immediately (no spiral). A short tap when in range still captures instantly (unchanged). Player movement, dash, and attack are locked during the channel. Releasing early cancels; no tether occurs. Visual feedback: progress ring above player (orange) and a pulsing line to the orb. Input is now centralized in `OrbTetherComponent._process()` instead of player states.
- **Why**: Gives the player a committed way to retrieve a far-away orb without waiting for it to bounce back into range; the 2 s lock prevents it from being a free "teleport orb to me" button.
- **Alternatives**: Instant pull regardless of distance — removes the dodge/positioning challenge; pull orb gradually toward player over 2 s — more complex physics (orb still bouncing); snap to `focus_radius` (48 px) instead of `min_tether_radius` (24 px) — inconsistent with tap-capture orbit; complete channel early if orb enters range mid-hold — conflates tap and hold UX; no movement lock during channel — too safe, trivializes orb retrieval.
- **Status**: decided (in-codebase)

### Tether breaks on solid/entity contact and on dealing damage
- **Decision**: While tethered, the orb shape-probes its orbit step against world / player / enemy layers. Any solid or entity body contact calls `break_tether(exit_velocity)` with a bounce off the contact normal. Dealing damage to any entity with a `HealthComponent` (via the orb hitbox, excluding instigator grace) also breaks the tether along the orbit tangent. Forced breaks apply the same +10% speed/damage boost as intentional mid-combat release; opening tether still has no boost. Bounce SFX plays on forced break (not release SFX). While flying, the orb's rigid-body mask includes player and enemy layers so it also **bounces off** `CharacterBody2D` entities (damage still via hitbox).
- **Why**: Orbit previously teleported through rocks and entities because the tethered orb is kinematic; clipping felt broken. Breaking on damage keeps the spinning weapon from chewing through a pack without cost. Entity bounce makes the flying orb readable as a physical projectile.
- **Alternatives**: Shrink orbit radius to avoid walls — still fails on props mid-arena and does not cover enemy hits; keep tether through solids but stop damaging — weaker fantasy and still clips visually; punch-through enemies while tethered — rewards careless orbits; no boost on forced break — punishes contact twice (lose tether + no reward) and feels inconsistent with release-as-commit; only break on rocks (not damage) — leaves multi-enemy orbits unbroken.
- **Status**: decided (in-codebase)

### Forced tether release never parks the orb
- **Decision**: Forced tether breaks (solid/entity contact or dealing damage) launch into free space instead of trusting a raw tangent bounce. Exit direction uses a real contact normal (`get_rest_info`, center-to-center only as fallback) and `_safe_exit_direction`: reflect only when inbound, then bias outbound if the result still points into the surface. Hitbox-triggered breaks are deferred one physics tick so freeze/velocity are not mutated mid-solver after a kinematic orbit teleport. `_finish_tether_release` depenetrates up to the body radius (8 px, 2 px steps) before asserting velocity. Flying bounce reflects **once** off the summed inbound contact normals (avoids two opposite surfaces cancelling back into the first). A never-still watchdog unsticks the orb after 12 consecutive stalled physics ticks (~0.06 s at 200 Hz) by depenetrating and picking an escape along overlapping normals (fallback: invert `aim_direction`). `can_sleep` is off. Collision layers/masks are unchanged.
- **Why**: Tethered orbit teleports a frozen rigid body, so a break can leave the orb overlapping a grunt/wall/player. Inspector dumps showed `FLYING`, non-zero velocity, `freeze`/`sleeping` false, and a frozen transform — the solver refused the motion. Sequential per-contact bounce made two-body wedges permanent.
- **Alternatives**: Add the orb layer to grunt/player masks so `move_and_slide` also treats the orb as solid — changes the whole game into "orb is a moving obstacle"; remove player/enemy from the orb body mask and script entity bounce — different flying feel; only `sleeping = false` on release — inspector already showed awake; only nudge along tangent — still launches into the blocker when the tangent is inbound.
- **Status**: decided (in-codebase); see also "Tether breaks on solid/entity contact and on dealing damage"

### Tether time-slow: 50% speed, 0.5 s ramp, vignette overlay
- **Decision**: Whenever the orb enters `TETHERED` state (including the opening sling at level start), `Engine.time_scale` ramps from its current value down to **0.5** over **0.3 real-world seconds** via a `Tween` set to `ignore_time_scale`. It holds at 0.5 until the orb leaves `TETHERED` (intentional release, forced break, or opening launch), then snaps back to 1.0. A `TimeSlowOverlay` `CanvasLayer` owns the tween and drives a `time_slow.gdshader` shader uniform (`intensity` 0 → 1) in sync, producing a dark-edge vignette with a purple-blue tint. The overlay is a `CanvasLayer` child of HUD in `desert.tscn`; `level.gd` connects `chaos_orb.tethered` / `tether_released` / `launched` to `begin()` / `end()`.
- **Why**: Slowing time during the tether gives the player a meaningful window to judge the orbit and plan the release angle without removing the spatial/positional commitment. The vignette makes the slow state immediately readable. A real-world ramp avoids the instant cut from the previous aim-window approach; snapping back on release makes the sling feel punchy.
- **Alternatives**: Scaled-delta ramp — window stretches as time already slows, so 0.5 s becomes 1 s of game time; keep full speed during tether — loses the "deliberate sling" feel; per-player time scale (Godot does not support it natively) — not viable; fade out on release instead of snap — tested as slower and less punchy; shader-only overlay without actual slow — visual only, less impactful.
- **Status**: decided (in-codebase)

### Level start: opening tether instead of slow-mo aim
- **Decision**: At level start the orb spawns already tethered **24 px above** the player (`begin_opening_tether`). Tether (or two full revolutions) releases it along the tangent into `FLYING`. Opening release emits `launched` and does **not** apply the +10% tether boost. `OpeningAimComponent`, the Aim state, and the old free-aim global slow-mo are removed. `OrbTetherComponent` owns the orb reference via `bind_orb()`. The opening tether now triggers the same 50%/0.5 s time-slow as mid-combat captures (see tether time-slow entry above).
- **Why**: One tether UX for start and mid-combat; teaches capture/release immediately; the new tether slow replaces the previous co-op-hostile opening slow-mo without reintroducing a separate system.
- **Alternatives**: Keep 3s slow-mo free aim — separate system and co-op time_scale issues; **design-doc free aim-and-fire at start** — may return to match source doc; auto-launch upward without tether — skips the core sling lesson; apply boost on opening release — unfair free power on every level start.
- **Status**: decided (in-codebase); **revisit** — design doc says player fires orb in any direction at level start

### Single basic enemy: chase + contact kill
- **Decision**: First enemy type is a chaser (`grunt_knife`) that kills the player on contact. A second chaser (`brute`) uses the same chase/contact-damage model. Desert delivers them as waves (3 grunts, then 1 brute) rather than all at once.
- **Why**: Simple pressure while the orb/attack loop is proven. Brute is a size/art variant of that loop, not a new AI.
- **Alternatives**: Ranged enemies first — more systems before the core loop is solid; brute as unique club-melee AI — not needed yet (contact hitbox matches grunt).
- **Status**: decided (in-codebase)

### Timed overlapping enemy waves
- **Decision**: Each level owns an `EnemySpawner` with inspector-authored `EnemyWave` / `EnemySpawnEntry` resources (enemy scene, count, `delay_before`). The next wave starts on a timer measured from when the previous wave **begins spawning**, so waves can overlap if the player does not clear the earlier one in time. Level clear waits until every wave has been issued **and** every instanced enemy is dead. Enemies stay in the physics world while assembling; collision shapes and hitboxes are disabled and `NavigationComponent.set_chasing(false)` turns off avoidance so `move_and_slide` is not called on a body with no physics space.
- **Why**: Fixed-total rooms still need a readable delivery cadence; a single dump of the whole roster is harder to read and easier to cheese by kiting a clump. Timer-from-start keeps pressure climbing without a "wave cleared" pause. Counting pending+alive avoids a false clear in the gap between waves. Zeroing `collision_layer`/`collision_mask` (or `PROCESS_MODE_DISABLED` alone) left the `NavigationAgent2D` on the nav map, which kept emitting `velocity_computed` and spammed `body->get_space() is null`.
- **Alternatives**: Spawn the whole roster at once — previous prototype; wait until a wave is fully killed before the delay — calmer but less arcade; overlap from wave *end* (assemble finished) — hides the authored delay behind VFX time; random encounter tables with no wave list — harder to author a specific room; clear physics layers / disable process_mode to freeze spawns — unregisters the body while avoidance still slides it.
- **Status**: decided (in-codebase)

### Spawn telegraph + reverse pixel-fall assemble
- **Decision**: Before an enemy becomes active, a pulsing ground ring marks the spawn point (`SpawnTelegraphEffect`, ~0.6s). The enemy sprite then plays `pixel_fall.gdshader` **backwards** (`progress` 1 → 0 over ~2s) via `DestructionEffect.play_assemble_from_sprite()`, reusing the death look so spawn and destroy read as the same material.
- **Why**: The ring is readable at a glance so the player can move off the point; reverse crumble makes the new body feel like it is being built rather than popping in. Sharing the death shader keeps one VFX language.
- **Alternatives**: Instant spawn with no warning — cheap deaths on the spawn point; particles-only telegraph — weaker link to the existing pixel-fall language; animate on the live sprite instead of a detached copy — fights hidden-sprite assemble and death's detached-FX pattern.
- **Status**: decided (in-codebase)

### Game title: A Final Spell
- **Decision**: The game is titled **A Final Spell**. Code, scenes, groups, and physics layer names use **orb** / **ChaosOrb** (not bullet).
- **Why**: The fantasy is one remaining spell, not a gun; the old title no longer matched the orb-of-chaos loop.
- **Alternatives**: Keep "One Last Bullet" — mismatches wizard/orb fantasy; "Tavern Roguelike" — genre label, not a title; "Orbital" / "Chaos Orb" puns — less clear about the one-spell hook.
- **Status**: decided (in-codebase)

### Wizard fantasy; orb of chaos (replaces sheriff / one bullet)
- **Decision**: Player is a **wizard** with one spell left — the **orb of chaos**. Setting is **tavern roguelike** with varied stages/environments, not a western sheriff defending a saloon.
- **Why**: Design doc refocused on magic arcade survival; orb tether/redirect is the core hook, not gun fantasy.
- **Alternatives**: Keep sheriff + bullet western theme — superseded by design doc; generic fantasy mage with many spells — dilutes the one-spell scarcity.
- **Status**: decided (design); prototype still uses a desert arena

### Mana drops vanish if not picked up quickly
- **Decision**: Enemies drop **mana** that disappears after a short window. Mana is spent in the between-level shop.
- **Why**: Creates risk/reward: leave safe space to grab loot while the orb and enemies threaten; mana fits the wizard fantasy.
- **Alternatives**: Permanent mana until leave — less tension; auto-collect — removes the skill beat; gold currency — superseded (western theme dropped).
- **Status**: decided (design); vanish duration TBD; not in prototype yet (only `mana_picked_up.ogg` asset)

### Run structure: clear level → shop → repeat; 10 levels to win
- **Decision**: Clear all enemies to finish a level; shop between levels; win the run after 10 clears. Death ends the run.
- **Why**: Classic roguelike cadence with a defined climax length.
- **Alternatives**: Endless mode only — no climax; shorter runs — less room for synergy builds.
- **Status**: decided (design); shop/multi-level not in prototype yet

### Shop upgrades: orb / player / enemy curses; synergies matter
- **Decision**: Between-level shop offers randomized upgrades that improve the orb, the player, or curse enemies. Synergies are intentional fun.
- **Why**: Keeps runs distinct and rewards build-crafting without a huge combat ruleset.
- **Alternatives**: Fixed upgrade tree — less replay discovery; only player buffs — thinner fantasy.
- **Status**: decided (design)

### Minimal story; gameplay-first arcade
- **Decision**: Story is lean (wizard defending against nefarious beings). No deep narrative required for v1.
- **Why**: Focus production on the orb/tether/shop loop.
- **Alternatives**: Heavy campaign narrative — distracts from the arcade core.
- **Status**: decided (design); supersedes sheriff/saloon story

### Varied stages with randomized enemies, obstacles, and breakables
- **Decision**: Stages use **different environments** (tavern is one option) with randomized enemies/obstacles; obstacles can interact with the orb (e.g. TNT); breakables can drop powerups.
- **Why**: Variety and environmental play without locking to one room type.
- **Alternatives**: Saloon-only stages — superseded; static hand-authored only levels — less replay; pure empty arenas — less toy potential.
- **Status**: decided (design); prototype is still a single desert arena

---

## Open design tensions

- **Tether feel**: orbit radius / auto-release after forced breaks; radius shrink less critical now that contact breaks the tether.
- **Attack cooldown / charges**: swing cooldown 0.35s; tether post-release cooldown 0.25s.
- **Opening shot UX**: design doc says free aim-and-fire at level start; prototype uses opening tether.
- **Mana vanish duration**: how long before drops disappear?
- **Shop draft size and reroll rules**: how many offers, costs, rerolls?
- **Camera / view perspective**: player uses 4-direction diagonal sprites in a flat arena; prototype uses a fixed centered `Camera2D` on the 640×360 arena. Confirm long-term camera for larger stages.
- **Arc deflect rollback**: flip `deflect_orb_enabled` if tether does not pan out.

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

### Health: multi-hit via max_health (player/grunt = 3; multi-hit breakables = 3)

- **Decision**: `HealthComponent.max_health` defaults to `1.0` (one-shot breakables like cactus). Player and grunt set `max_health = 3.0`. `big_rock.tscn` and `animal_skull.tscn` also use `max_health = 3.0` — three orb hits to destroy. On any `take_damage`, the entity sprite modulates to red (`damage_flash_color`) then tweens back (non-fatal) or stays red into the destruction FX (fatal). Sprite comes from an optional `HealthComponent.sprite` export, else `DestroyComponent.sprite`. Non-fatal hits can start gameplay i-frames (see below).
- **Why**: Keeps rules in data; multi-hit is a slider per entity, not special-case code. Shared flash covers entities and breakables without per-scene VFX scripts. Multi-hit props give the orb a reason to revisit the same obstacle and create longer spatial fights around tougher terrain.
- **Alternatives**: One-hit-kill for everyone (`max_health = 1.0`) — previous design; too harsh with tether proximity; a bool `is_one_shot` — extra flag for something already handled by the value; shader hit flash — heavier for a short modulate.
- **Status**: decided (in-codebase); supersedes "one-hit-kill expressed as max_health = 1.0"; `big_rock` / `animal_skull` multi-hit breakables added (not yet placed in any level)

### Damage-reveal percentage health bars
- **Decision**: Every `HealthComponent` owner (player, enemies, breakables) instances `HealthBarComponent`: an 18×2 px world-space bar drawn with `_draw`, fill width = `% of max_health` (not absolute HP, so a 10-HP brute and a 100-HP boss use the same pixel width). Hidden until `damage_taken`; stays visible for **1.5 s**, refreshing on each hit. Per-scene `offset` places it above the sprite.
- **Why**: Upcoming damaging effects can push HP past 100; a percentage bar stays readable without growing. Reveal-on-hit keeps the 640×360 arena uncluttered. Same component on breakables so future multi-hit props get the UI for free.
- **Alternatives**: Always-visible overhead bars — clutter at higher enemy counts; discrete pips — breaks once max HP is no longer 3; screen-only player HUD — enemies would still need hit confirmation for orb grazes; `ProgressBar`/`ColorRect` nodes — extra nodes and softer pixel alignment vs `_draw`.
- **Status**: decided (in-codebase)

### Damage flow: HitboxComponent overlap polling

- **Decision**: Hit detection uses `HitboxComponent` (`Area2D`) on both attackers and victims. Each physics frame the victim hitbox polls `get_overlapping_areas()`, resolves the attacker's `COMPONENTS[DamageComponent]`, and applies damage when the overlap is fresh (or when a contact-damage interval elapses). A short `hit_dedup_frames` grace (default 2) keeps an attacker "seen" after leaving so bounce flicker does not count as a new hit. Entries prune themselves once past that grace. Breakables stay body-contact (orb `body_entered`) so the bounce impulse resolves before `queue_free()`.
- **Why**: Decouples hit registration from physics enter/exit chatter; sustained enemy contact can tick repeatedly; self-cleaning state avoids unbounded cooldown dictionaries.
- **Alternatives**: `area_entered` only — one damage forever while glued, and bounce flicker double-hits; wall-clock per-attacker cooldown — magic number that can swallow legitimate late-run hits; signal bus — extra indirection.
- **Status**: decided (in-codebase)

### Contact damage interval on DamageComponent

- **Decision**: `DamageComponent.contact_damage_interval` (seconds). `0` = one hit per continuous overlap (orb). Grunt uses `~0.75s` so a chase that sticks keeps dealing damage.
- **Why**: Chasers overlap continuously; without a tick they deal damage once and then never again.
- **Alternatives**: Always re-hit every frame — melts the player; rely only on player i-frames — couples chase DPS to hit-react length; put the interval on the victim — wrong ownership for an attacker property.
- **Status**: decided (in-codebase)

### Player i-frames on HealthComponent

- **Decision**: `HealthComponent.invulnerable_seconds` (player `0.5`). Non-fatal `take_damage` starts the window; further `take_damage` calls no-op until it expires. Visual: red flash, then alpha blink for the remainder. Lives on `take_damage` so direct callers (breakable body hits) are covered too. Enemies/cactus leave it at `0`.
- **Why**: Multi-hit health needs readable recovery; separates gameplay invuln from the physics-frame hitbox dedup guard.
- **Alternatives**: Wall-clock hitbox cooldown as the only guard — papered over orb bounce bugs and could eat real hits; dash-only i-frames — no recovery after a graze; no i-frames — stacked orb + grunt same-frame feels unfair.
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
- **Status**: decided (in-codebase); states: Idle, Walk, Attack, Dash

### Per-player input: static action duplication + runtime suffix

- **Decision**: P1 actions (`move_up`, `attack`, etc.) are authored in `project.godot` with keyboard/mouse + gamepad device 0. P2 duplicates (`move_up_2`, etc.) are hand-authored in `project.godot` with gamepad device 1 only. At runtime, `Controls.apply_player_index(n)` appends `""` / `"_2"` suffix to every `PlayerAction.action`. P3/P4 action sets (`_3`, `_4`) are added in the same pattern when needed.
- **Why**: No autoload needed; all bindings visible in Project Settings → Input Map; Godot's built-in action system handles device filtering.
- **Alternatives**: Runtime duplication autoload (clone base actions to `_2/_3/_4` at startup) — adds an autoload and makes bindings invisible in Project Settings; plain `InputEvent.device` filtering in every script — more per-script boilerplate.
- **Status**: decided (in-codebase); P1 + P2 authored; P3/P4 not yet authored

### Main scene is desert level; AudioManager is the first autoload
- **Decision**: `run/main_scene` is `areas/level/desert.tscn`. Level logic lives on the scene root (`level.gd`). First autoload is `AudioManager` for Music/SFX.
- **Why**: Prototype is still a single scene; audio needs a global owner before shop/run flow does.
- **Alternatives**: Early GameManager autoload — premature for one arena; no audio autoload (per-scene players) — harder to share buses/pools.
- **Status**: decided (in-codebase); supersedes "no autoloads yet"

### Arena walls as StaticBody2D border slabs
- **Decision**: Orb/player world collision uses four `StaticBody2D` wall slabs around the viewport, not TileMap physics polygons.
- **Why**: Current desert tileset has no physics layer; border slabs keep the orb on-screen cheaply.
- **Alternatives**: Author per-tile collision — more setup before the loop is proven.
- **Status**: decided (in-codebase)

### Enemy pathfinding uses a baked NavigationRegion2D plus agent avoidance
- **Decision**: Enemy movement now paths on one `NavigationRegion2D` baked at runtime from an explicit arena outline minus `world`-layer static colliders. `LowerGround`, `Cliffs`, `Objects`, and `Walls` contribute source geometry through a `navigation_source` group; `level.gd` bakes once, then waits until the NavigationServer can path from arena center to the player before `EnemySpawner.start()` (reload leaves the server map empty for a few physics frames after `bake_finished`). Re-bake on a short debounce when breakables die. The navmesh now erodes by **15 px** (the brute radius) so narrow cliff/rock pockets are removed. Each enemy owns a `NavigationComponent` (`NavigationAgent2D`) that repaths toward the player, uses avoidance against other enemies only, and triggers a stuck watchdog that stops and forces a repath if the body makes almost no progress for a short window. Enemy spawns are projected onto the navmesh and rejected if they are off-mesh or lack a valid path to the player's nav position; fallbacks try several inset points instead of stacking on one corner.
- **Why**: The desert TileSet's navigation polygons overlapped across `TileMapLayer`s and the ground layer re-filled the walkable space under cliff-face colliders, so tile-authored navigation would route enemies straight into walls. Baking against the runtime colliders keeps pathing aligned with the actual level, the larger erosion radius removes "looks open but is physically too tight" pockets, the watchdog recovers from knockback/corner stalls, and nav-validated spawns prevent enemies from starting in unreachable slivers.
- **Alternatives**: Keep TileSet navigation layers — one-nav-polygon-per-cell limits, no shared agent-radius inset, and plateau cells conflict across layers; keep the smaller **12 px** erosion radius — preserves routes that still trap the brute and sometimes the grunt in diagonal corners; rely on `NavigationObstacle2D` / physics separation only — enemies still path into blocked routes and then jam; remove enemy-enemy body collision and depend only on avoidance — weaker hard separation when avoidance fails.
- **Status**: decided (in-codebase)

### Orb is RigidBody2D with script-owned bounce + separate hitbox
- **Decision**: `ChaosOrb` is a `RigidBody2D` with a circular body shape (world + player + enemy mask), locked rotation, gravity 0, friction 0, **bounce 0** material, continuous CCD, `can_sleep` off, and constant-speed flight. All reflection is owned by `_integrate_forces`: inbound contact normals are summed, then `aim_direction` reflects **once** off that combined normal (only when moving into the surface), then `linear_velocity = aim_direction * speed`. `_physics_process` does **not** re-derive direction from solver velocity. Hits use a separate circle/capsule `HitboxComponent` Area2D. Bounce SFX and breakable damage still use `body_entered`.
- **Why**: Solver bounce + script bounce fought each other and caused sticky re-entry (double damage / double SFX). Real contact normals beat center-to-center approximations on capsules and rectangles. Single bounce authority keeps the projectile readable.
- **Alternatives**: PhysicsMaterial bounce 1 + velocity read-back — previous; double-reflect artifacts; radial bounce only in `body_entered` for CharacterBody2D — wrong normals and still fought the solver; world-only mask + area-driven entity bounce — reverses entity-body bounce feel; wall-clock hit cooldown — papers over the symptom.
- **Status**: decided (in-codebase)

### Aim windows measured in real time under Engine.time_scale
- **Decision**: Opening aim was 3.0s of **wall-clock** time via `Time.get_ticks_msec()`, while `Engine.time_scale = 0.15` during aim. Mid-combat redirect aim windows were already gone.
- **Why**: Slow-mo must not stretch the intended aim deadline.
- **Alternatives**: Use scaled `delta` timers — windows become much longer than designed.
- **Status**: superseded — opening aim replaced by opening tether; tether slow-mo ramp also uses `ignore_time_scale` tween for the same reason

### Post-launch player grace
- **Decision**: After every launch (opening tether release, deflect, or mid-combat tether release), the orb ignores the player for 0.3s. While tethered, `instigator` stays pinned to the tethering player for the whole orbit (grace timer cleared mid-tether so it does not expire early).
- **Why**: Deflecting / tethering requires proximity; without grace the player dies on the same frame they bat or release the orb.
- **Alternatives**: Teleport orb away on deflect — less readable; disable player hit forever until leave range — easier to cheese.
- **Status**: decided (in-codebase)

### KnockbackComponent for shove without damage
- **Decision**: `KnockbackComponent` applies a decaying shove to its owner (`CharacterBody2D` via velocity + `move_and_slide`, `RigidBody2D` via impulse, plain `Node2D` via position). Enemies yield chase AI while knockback is active. Built generic so breakables/objects can reuse it later.
- **Why**: Attack needs a non-damage response for enemies; keeps shove logic out of MovementComponent and entity scripts.
- **Alternatives**: Bake knockback into MovementComponent — couples walk and shove; one-off velocity in grunt script — not reusable for props.
- **Status**: decided (in-codebase)

### Dash: fixed distance with i-frames and phase-through
- **Decision**: Player dashes 50 px toward **current facing** (8-way via `DirectionalSpriteComponent.facing_vector()`) at 400 px/s via `DashComponent` + `Dash` state. Idle dash uses last facing; dash does not read mouse/aim. While dashing: hitbox monitoring off (immune to orb and enemies), body `collision_layer`/`collision_mask` cleared so the player phases through props/enemies/walls, no movement input, no attacking. **4 s** cooldown, shown as a radial ring above the head drawn by `DashComponent` itself. Starts only from Idle/Walk (does not cancel an attack swing). Space is `dash`; attack keeps left click / gamepad A.
- **Why**: Readable dodge through the orb, chasers, and clutter; fixed distance is easy to learn and tune; facing-direction dash matches movement/strafe intent and frees aim for the attack arc; phase-through keeps the dash reliable in a prop-filled arena; a 4 s wait is a committed dodge, so a world-space ring makes the recharge obvious. Cooldown UI lives on `DashComponent` because dash is player-only and 1:1 with that cooldown state.
- **Alternatives**: Aim-direction dash (mouse / right stick) — coupled dodge to attack aim and fought strafe play; reuse `KnockbackComponent`'s decaying shove — wrong curve (fade-out vs constant speed) and no i-frame API; velocity-based dodge that keeps movement control — less committed and harder to read; interrupt attack with dash — too many cancel options for prototype; keep world collision during dash — props truncate the dash unpredictably; separate prop vs wall physics layers so walls still block — extra layer setup before it is needed; separate `DashCooldownIndicator` component — extra scene wiring for a UI that nothing else reuses (health bar stays separate because it is shared across entities).
- **Status**: decided (in-codebase)

### Level objects: shared script + per-variant Resource
- **Decision**: Solid and breakable props share `LevelObject` / `Breakable` scripts. Each object type is its own scene (`cactus.tscn`, `rock.tscn`) that holds an array of `LevelObjectVariant` Resources (texture + hand-tuned collision). Runtime picks a random variant.
- **Why**: Same behavior with different art/collision without duplicating scripts; avoids a flag-driven mega-scene; adding rock_2 is a new `.tres` + array entry.
- **Alternatives**: One general object scene with `is_destructible` exports — becomes flag soup for TNT later; fully separate scene/script per art file — duplicated physics setup.
- **Status**: decided (in-codebase)

### Breakables bounce then destroy via orb body contact
- **Decision**: Breakables (cactus) live on the `world` physics layer like rocks/walls. The orb destroys them via its `RigidBody2D.body_entered` contact (not the leading capsule `Hitbox` area), so the bounce impulse is solved before `queue_free()`.
- **Why**: Props should reshape orb paths; using the leading hitbox would destroy the body before bounce. No fifth physics layer needed.
- **Alternatives**: Punch-through (no bounce) — less spatial play; dedicated `breakable` layer + hitbox area — destroys before bounce; multi-hit health — deferred.
- **Status**: decided (in-codebase)

### Pixel art rendering: smooth pixel shader + aligned orb speed
- **Decision**: Character sprites (player, enemies, orb) use shared `smooth_pixel_material.tres` (CptPotato-style derivative filtering) with **Linear** sprite filter. Orb speed is **180 px/s** (3 px/frame at 60 Hz). Physics interpolation is **off**.
- **Why**: Nearest-neighbor + sub-pixel motion/rotation caused visible shimmer; the smooth pixel shader antialiases rotated/scaled sampling without blurring integer-scale art as badly as plain Linear. Disabling physics interpolation avoids in-between sub-pixel draw frames.
- **Alternatives**: `%VisualOffset` pixel snap — removed; fought the shader; 8-way rotation snap — removed; physics interpolation on — reintroduced jitter on pixel art; snap 2D transforms to pixel on — fights smooth pixel filtering.
- **Status**: decided (in-codebase)

### Fixed Camera2D centered on the arena
- **Decision**: `desert.tscn` uses a static `Camera2D` at `(320, 180)` — arena center for the 640×360 viewport. No smoothing, no player follow.
- **Why**: The prototype arena matches the viewport; a fixed camera shows the full playfield without sub-pixel pan jitter.
- **Alternatives**: Player-following camera with pixel rounding — useful for larger scrolling levels later; no camera — same outcome when the root is the view.
- **Status**: decided (in-codebase)

### Destruction VFX: detached sprite + canvas pixel-fall shader
- **Decision**: On breakable/enemy/player death, disable collision, emit gameplay signals immediately, spawn a detached `Sprite2D` copy with `pixel_fall.gdshader`, then `queue_free()` the entity. `DestructionEffect.play_from_sprite()` owns the FX life cycle (tween `progress` 0 → 1, then free). Enemy spawn reuses the same helper in reverse (`play_assemble_from_sprite()`, `progress` 1 → 0 over ~2s). For `AnimatedSprite2D` sources, the current frame is extracted via `sprite_frames.get_frame_texture` and flattened to an `ImageTexture` so the shader sees one frame's `tex_size` and full 0..1 UVs (not the whole sheet).
- **Why**: Gameplay stays snappy (win/lose and bounce timing unchanged) while pixels crumble visually; one helper works for props and characters without delaying entity teardown.
- **Alternatives**: Animate in-place and delay `queue_free()` — risks leftover collision and win-count timing bugs; GPU particles of colored quads — heavier setup and less 1:1 with sprite art; CPU `Image` pixel scatter — more code for the same look; pass the full spritesheet to the shader — crumbles all frames at once.
- **Status**: decided (in-codebase)

### Player facing: 8-way logical / 4-way visual AnimatedSprite2D + DirectionalSpriteComponent
- **Decision**: Logical facing is **8-way** (N, S, E, W, NE, NW, SE, SW) via octant snap in `DirectionalSpriteComponent.face()`. Player art remains a 128×32 sheet (four 32×32 diagonals only). Visual playback uses `<action>_<visual>` (`idle_sw`, later `walk_ne`, etc.); cardinals map to a diagonal suffix by keeping the other-axis bias of the previous visual (e.g. N → `ne` or `nw`). Facing comes from movement while walking and snaps to aim on attack; dash uses `facing_vector()` and does not retarget facing; idle keeps the last facing. `MovementComponent` / `DashComponent` no longer flip the player sprite.
- **Why**: Dash and movement need true cardinals; authored art is still 4-diagonal; the naming scheme lets walk/attack cycles drop in later without inventing cardinal PNGs; flipping a SW frame would invent a false SE facing.
- **Alternatives**: 4-way logical facing only — no straight N/S/E/W dash; require 8 sprite frames — art not ready; `flip_h` mirroring of two frames — fights the authored SW/SE and NW/NE pairs; always face aim — would spin the sprite while strafing.
- **Status**: decided (in-codebase)

### Audio: two buses + SoundEvent resources + pooled AudioManager
- **Decision**: `default_bus_layout.tres` exposes **Music** and **SFX** under Master. An `AudioManager` autoload owns Music A/B crossfade players plus pooled non-positional (`AudioStreamPlayer` × 8) and positional (`AudioStreamPlayer2D` × 16) voices. Exhausted pools steal the oldest voice. Sounds are authored as `SoundEvent` Resources (stream variants, volume, pitch range, retrigger cooldown, max voices) colocated with their clips; callers use `AudioManager.play` / `play_at`. Damaged SFX plays only on non-fatal hits; destroy SFX plays on death.
- **Why**: Bus split matches the requested two-channel design and future options UI; `SoundEvent` matches the existing `LevelObjectVariant` data pattern and lets designers tune without code; pooling + oldest-voice steal avoids QuizGame's silent drop when all players are busy; positional pool is not reparented to emitters so death sounds outlive `queue_free()`.
- **Alternatives**: Preloaded stream dictionary on the autoload (QuizGame style) — harder to tune pitch/cooldown per event; global-only playback — no stereo across the arena; per-entity `AudioStreamPlayer2D` nodes — death/teardown races and more scene boilerplate; fade-out/wait/fade-in music (QuizGame) — replaced with true A/B crossfade.
- **Status**: decided (in-codebase)
