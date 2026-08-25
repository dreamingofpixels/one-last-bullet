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
- **Status**: superseded — opening release now spawns a 3-orb spread volley for playtest (see below)

### Opening 3-orb launch from summoning circle
- **Decision**: At level start the player assembles in (~2 s), then **three** chaos orbs launch from the **summoning circle** `DepositArea` origin in **independent random directions** via `begin_flight(dir, player)`. No opening tether; mid-combat tether release stays a single orb. Player instigator grace still applies so assemble→launch does not instantly kill.
- **Why**: Ties the opening beat to the circle / mana fantasy; random fan creates immediate room pressure without teaching a separate sling shot; keeps the 3-orb playtest density.
- **Alternatives**: Opening tether + ±20° volley-on-release — previous; design-doc free aim from the player — may return; single orb from circle — weaker room pressure; shared random angle + spread — more readable but less chaotic.
- **Status**: superseded — replaced by typed Shadow/Poison/Electric opening volley (see below)

### Opening typed orb volley (Shadow / Poison / Electric)
- **Decision**: Level start launches **one Shadow**, **one Poison**, and **one Electric** orb from the summoning circle in independent random directions (`begin_flight`, player grace). No plain chaos orb is spawned. `chaos_orb.gd` / `.tscn` remain the shared `ChaosOrb` base (`class_name`, `FLYING` / `TETHERED` / `POSSESSED`). Typed scenes tint `orb.png` and override hit hooks. Enemies own a `StatusComponent` for Poison (persistent 3 s DoT stacks) and Shock (stun at 10 stacks / 2 s). Shadow follows its host in world space (not reparented) so enemy `queue_free` cannot free the orb. Electric current is a `Line2D` + enemy-mask capsule `Area2D` while a player is within 300 px.
- **Why**: Same 3-orb room pressure with readable elemental fantasies; shared bounce/tether/redirect code stays on ChaosOrb; status lives on victims so multiple sources can stack later.
- **Alternatives**: Keep three identical chaos orbs — no type fantasy; add three typed orbs on top of chaos (6 total) — too dense for the arena; per-orb timers instead of StatusComponent — duplicates DoT/stun logic; parent Shadow into the enemy — orb dies with host teardown; raycast-only current without Area2D — harder to tick continuous overlap cleanly.
- **Status**: decided (in-codebase)

### Poison stacks persist (no decay)
- **Decision**: Poison stacks stay on the enemy until death. Each tick still deals damage equal to current stacks; extra stacks do not reset the timer.
- **Why**: Repeated Poison orb hits should snowball into a lasting curse, not a fading DoT that needs babysitting.
- **Alternatives**: Remove 1 stack per tick (previous) — weaker investment and harder to read as committed poison; expire after a wall-clock duration — another clock besides the tick; reset the tick timer on add — delays damage already in progress.
- **Status**: decided (in-codebase)

### Opening 3-orb spread volley (playtest)
- **Decision**: Level start still uses a **single** opening tether. On that tether's first launch (`launched`), the level spawns **two** extra chaos orbs at the same position flying at **±20°** from the release tangent (tunable `opening_volley_spread_degrees`). All three persist and bounce for the rest of the level. Mid-combat tether release stays a **single** orb (no extra volleys). `OrbTetherComponent` targets the `orb` group: focus all in range, tap-capture / remote-channel the **closest** flying orb, **one tether at a time**. Extras enter via `ChaosOrb.begin_flight()` (grace + FLYING, no opening tether).
- **Why**: Cheap way to try multi-orb chaos without rewriting opening UX; volley-on-release keeps the sling lesson; group-based tether avoids hard-wiring three NodePaths.
- **Alternatives**: Three independent opening tethers — heavier UX; start with three already flying — skips the sling teach; only one tetherable "main" orb — simpler but weaker multi-orb play; extras despawn after a timer — less room pressure.
- **Status**: superseded — replaced by circle random launch (see above)

### Mana crystals: carry, throw, deposit into summoning circle
- **Decision**: Enemies have a **25%** chance to drop a `ManaCrystal` (default **5** mana, **20** HP). Tether within `focus_radius` picks up a crystal **before** capturing an orb. While carried: shown beside the player, dash disabled, Attack throws along aim (slide + sprite bounce, then settle). Pickup plays shared `item_picked_up` SFX. If a crystal enters the summoning circle `DepositArea` (including while carried), it detaches, freezes, and **sucks to the circle center** (cubic ease-in); on arrival it credits `SummoningCircle.mana_pool`, plays `mana_crystal_deposited`, then `DestroyComponent.self_destroy(false)` (pixel-fall, no generic destroy SFX). Orb hitbox damage can destroy crystals; that path does **not** credit the pool and still uses the default destroy SFX. Crystals use physics layer `item` (world mask only) so orbs punch through via hitbox rather than bouncing.
- **Why**: Makes mana a spatial risk (orb can smash loot; must deliver to the circle) and reuses tether/attack verbs without a new input. Suck-in makes the deposit readable; splitting pickup vs deposit SFX keeps item pickup generic for future loot.
- **Alternatives**: Auto-collect vanishing mana orbs — less skill; walking into crystals — weaker than tether priority; crystals on `world` layer (orb bounce) — turns loot into pinball obstacles; instant deposit `queue_free` — previous, no suck/VFX; reuse pickup clip for deposit — less feedback that mana reached the pool; vanish timer — deferred (open question).
- **Status**: decided (in-codebase); pool UI + spend/activate ritual added on the circle (see "Summoning circle activation ritual")

### Orb damages enemies; hurts player on contact
- **Decision**: The same projectile is a weapon against enemies and a hazard for the player. HP and orb damage are authored in scene `HealthComponent` / `DamageComponent` values (currently player **30 HP**, grunt **20 HP**, orb damage **10**). Player gets brief i-frames after a non-fatal hit.
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
- **Status**: revisit — orb deflect gated behind `AttackComponent.deflect_orb_enabled` (default false); melee swing + enemy knockback also gated behind `melee_enabled` (default false). Code kept for rollback.

### Same-direction chase hits push along aim
- **Decision**: When the orb's velocity aligns with the player→orb radial normal (dot above a tunable threshold, default 0.5), skip `Vector2.bounce` and set exit velocity to the attack aim direction. Side and inbound hits still use radial bounce.
- **Why**: Pure radial bounce flips ~180° when chasing from behind, which feels like the bat reversed the orb instead of carrying it forward along the swing.
- **Alternatives**: Always bounce on radial normal — unrealistic chase reversals; always set velocity to aim — loses readable glancing deflections; blend bounce + aim — more tuning for little gain; arc-surface contact normal — more accurate physically but harder to author and debug for a small polygon.
- **Status**: revisit — only matters when `deflect_orb_enabled` is true; code kept.

### Orb tether capture: focus range, orbit, release on tangent
- **Decision**: Mid-combat steering is proximity tether. When the flying orb is within 48 px (`focus_radius`), it shows an `OrbInFocus` overlay. The dedicated `tether` input (right click / gamepad X; `TetherAction` under Controls) captures it; the orb keeps its current position and **spirals in** to the fixed **24 px** (`min_tether_radius`) orbit while continuing to travel. A second tether press or **two full revolutions** releases it along the current tangent at full orb speed. Attack remains separate: out of range it is melee-only; in range it redirects (see proximity Attack redirect). Player movement and dash are locked while tethered. Each release multiplies orb `speed` and `DamageComponent.damage` by `tether_release_boost` (default **1.1 / +10%**), stacking for the rest of the level; `speed` is clamped to `max_speed` (**1500**). While tethered the orb damages enemies; the tethering player is immune via `DamageComponent.instigator` for the whole tether plus **1 s** post-release grace (ghostly tint + shrinking halo on the orb). Short cooldown after release (~0.25s) prevents instant re-grab. Driven by `OrbTetherComponent` on the player + `begin_tether` / `release_tether` / `break_tether` on the orb.
- **Why**: Separate tether from attack so melee knockback stays available near the orb; clearer "grab and sling" fantasy than batting; locking the player while the orb orbits makes the sling a committed stance; stacking speed/damage rewards repeated successful slings.
- **Alternatives**: Variable orbit radius (capture distance) — removed because orbit size was unpredictable; teleport on tap to min radius — felt like a snap, spiral is more readable; one revolution — too short, especially at close range; free movement while tethered — weaker commitment and easier to cheese positioning; no release boost — less reward for risking the tether; aim-directed slingshot on release — more UI and less "continue forward" readability; inert tether (no enemy damage) — weaker as a spinning weapon.
- **Status**: revisit — capture/channel parked via `capture_enabled = false` on the player (see "Park orb capture; Attack redirect only" below); code kept

### Park orb capture; Attack redirect only (playtest)
- **Decision**: Player `OrbTetherComponent.capture_enabled = false`. Tether no longer captures orbs or starts remote channel. Focus overlays, redirect chevron preview, Attack redirect, and mana-crystal pickup remain. Do **not** set `tether_enabled = false` (that also gates redirect). Owned-tether release still works if somehow tethered. Flip `capture_enabled` back on to restore orbit sling.
- **Why**: Experiment with Attack-only mid-combat aim steer without deleting the tether system.
- **Alternatives**: Delete tether code — harder to restore; disable `tether_enabled` — also kills redirect and crystal pickup wiring; keep both capture and redirect — previous playtest default.
- **Status**: decided (in-codebase); revisit after playtest

### Park melee swing and knockback (Attack redirect only)
- **Decision**: `AttackComponent.melee_enabled = false` on the player. Idle/Walk Attack no longer enters the Attack state after a failed redirect. Swing sprite, hint, hitbox, and enemy knockback stay in the scene/script but do nothing. Crystal throw via Attack still works. Flip `melee_enabled` to restore melee.
- **Why**: Playtesting steer-only Attack without deleting the arc system; knockback was fighting orb-focused combat feel.
- **Alternatives**: Delete Attack state / KnockbackComponent — harder to restore; keep out-of-range swing — mixed fantasy while redirect is the only useful Attack verb.
- **Status**: decided (in-codebase); revisit after playtest

### Summoning circle activation ritual
- **Decision**: `SummoningCircle` shows `mana_pool` on `%ManaPoolLabel` (updates on `deposit` / `spend`). `DepositArea` masks player + item. Standing in the circle and pressing tether calls `try_activate()`: spends **5** mana once, then blinks the sprite and emits rising `%ArcaneParticles`. Already-activated or unaffordable presses fall through to crystal pickup. Group `summoning_circle`; further ritual effects TBD.
- **Why**: Makes the pool readable and gives tether a circle verb while orb capture is parked; 5 mana matches one crystal deposit so activation is one-crystal commit.
- **Alternatives**: Auto-activate when pool ≥ 5 — less intentional; spend on Attack instead — competes with redirect; deactivate / toggle — deferred until ritual content exists.
- **Status**: decided (in-codebase)

### Proximity Attack redirect (chevron chain + dash reset)
- **Decision**: While a flying orb is within `focus_radius` (48 px), the **closest** in-range orb shows `%AimArrow` as **three pulsing chevrons** outside the orb body along the player's aim (`aim_arrow.gd`, start ~12 px). Pressing **Attack** then calls `ChaosOrb.deflect()` along that aim — **no melee swing**, no enemy knockback. Each redirect multiplies that orb's `speed` and `DamageComponent.damage` by `tether_release_boost` (default **1.1 / +10%**), stacking for the rest of the level; `speed` is clamped to `max_speed` (**1500**). The same Attack also calls `DashComponent.reset_cooldown()` so the player can dash immediately. Shares the normal **0.35 s** attack cooldown (`AttackComponent.consume_cooldown()`). Redirect works even during the short tether recapture cooldown. Multiple in-range orbs still all get `OrbInFocus`; only the closest gets the chevrons and is redirected. Out of range (or while tethered/channeling), Attack does nothing while melee is parked. Arc-contact `deflect_orb_enabled` stays false.
- **Why**: Tiny internal arrow was clear but cramped; a through-orb particle stream was muddy. Chevrons sit outside the sprite so direction is readable without covering the orb; pulse sells “pending launch” without fighting the trail.
- **Alternatives**: Tiny in-body arrow — previous, ugly at 8 px; GPU particle stream — previous, weak directionality; dashed Line2D ray — deferred; ghost bounce path — more work; re-enable arc-contact deflect — couples melee with orb hits; redirect every in-range orb — chaotic with the 3-orb volley.
- **Status**: decided (in-codebase)

### Playtest toggle: bounce orbs off entities
- **Decision**: Desert root `@export bounce_orbs_off_entities` (default off on `desert.tscn`) sets `ChaosOrb.bounce_off_entities` in `level.gd` `_ready`. When on, flying orbs add player + enemy layers to their rigid-body mask and bounce via existing `_integrate_forces` normals. When off, mask is world-only (punch-through). Player/enemy body masks do **not** include the orb layer (characters still walk through orbs). Entity HP stays on hitbox poll; `_on_body_entered` skips player/enemy damage to avoid double-hits. Post-redirect grace adds a collision exception vs the batter. Shadow re-emergence and new spawns read the static flag.
- **Why**: Cheap A/B for punch-through vs pinball feel without forking combat code; inspector export applies from the first frame of play.
- **Alternatives**: Hard-code bounce permanently — loses the current punch-through default; hard-code punch-through only — cannot experiment mid-session; runtime HUD checkbox — previous; add orb to player/enemy masks — would push characters when colliding.
- **Status**: decided (in-codebase); revisit after playtest

### Remote tether channel (hold 2s to pull distant orb)
- **Decision**: Holding the tether button for 2 s when the orb is flying but out of `focus_radius` **teleports** the orb to the player→orb axis at **`min_tether_radius` (24 px)** and begins orbiting immediately (no spiral). A short tap when in range still captures instantly (unchanged). Player movement, dash, and attack are locked during the channel. Releasing early cancels; no tether occurs. Visual feedback: progress ring above player (orange) and a pulsing line to the orb. Input is now centralized in `OrbTetherComponent._process()` instead of player states.
- **Why**: Gives the player a committed way to retrieve a far-away orb without waiting for it to bounce back into range; the 2 s lock prevents it from being a free "teleport orb to me" button.
- **Alternatives**: Instant pull regardless of distance — removes the dodge/positioning challenge; pull orb gradually toward player over 2 s — more complex physics (orb still bouncing); snap to `focus_radius` (48 px) instead of `min_tether_radius` (24 px) — inconsistent with tap-capture orbit; complete channel early if orb enters range mid-hold — conflates tap and hold UX; no movement lock during channel — too safe, trivializes orb retrieval.
- **Status**: decided (in-codebase)

### Tether breaks on world solids only; orb punches through entities (toggleable)
- **Decision**: While tethered, the orb shape-probes its orbit step against the **world** layer only. Contact with rocks/walls/breakables calls `break_tether(exit_velocity)` with a bounce off the contact normal. Forced breaks apply the same +10% speed/damage boost as intentional mid-combat release; opening tether still has no boost. Bounce SFX plays on forced break (not release SFX). Flying default: the orb **punches through** player and enemy bodies (rigid-body mask is world-only); entity damage comes from victim `HitboxComponent` overlap polls against the orb's hitbox Area2D (`contact_damage_interval = 0` → one hit per continuous overlap). Desert export can enable flying bounce off player/enemy bodies without changing tether probes. Instigator grace still skips the tethering player. Breakables keep `body_entered` → `_try_apply_orb_damage` so bounce resolves before destroy.
- **Why**: Entity bounce made the projectile feel like a pinball against packs and blocked clean sling paths; punch-through keeps the orb a continuous threat and a usable spinning weapon while tethered. World solids still reshape paths and punish careless orbits into props. The level export lets feel-testing restore entity bounce without a code fork.
- **Alternatives**: Bounce off entities always — previous; readable but fights sling aim through packs; break tether on dealing damage — prevents chewing through a pack, but also stops intentional multi-enemy orbits; punch-through flying only / tether still breaks on entities — inconsistent feel between states.
- **Status**: decided (in-codebase); supersedes "Tether breaks on solid/entity contact and on dealing damage"; entity bounce is optional via desert `bounce_orbs_off_entities` export

### Forced tether release never parks the orb
- **Decision**: Forced tether breaks (world-solid contact) launch into free space instead of trusting a raw tangent bounce. Exit direction uses a real contact normal (`get_rest_info`, center-to-center only as fallback) and `_safe_exit_direction`: reflect only when inbound, then bias outbound if the result still points into the surface. `_finish_tether_release` depenetrates against **world** overlaps only (up to the body radius, 8 px, 2 px steps) before asserting velocity. Flying bounce reflects **once** off the summed inbound contact normals (avoids two opposite surfaces cancelling back into the first). A never-still watchdog unsticks the orb after 12 consecutive stalled physics ticks (~0.06 s at 200 Hz) by depenetrating and picking an escape along overlapping normals (fallback: invert `aim_direction`). `can_sleep` is off.
- **Why**: Tethered orbit teleports a frozen rigid body, so a break can leave the orb overlapping a wall/prop. Inspector dumps showed `FLYING`, non-zero velocity, `freeze`/`sleeping` false, and a frozen transform — the solver refused the motion. Sequential per-contact bounce made two-body wedges permanent.
- **Alternatives**: Add the orb layer to grunt/player masks so `move_and_slide` also treats the orb as solid — changes the whole game into "orb is a moving obstacle"; keep player/enemy on the orb body mask — superseded by punch-through; only `sleeping = false` on release — inspector already showed awake; only nudge along tangent — still launches into the blocker when the tangent is inbound.
- **Status**: decided (in-codebase); see also "Tether breaks on world solids only; orb punches through entities"

### Tether time-slow: 50% speed, 0.5 s ramp, vignette overlay
- **Decision**: Whenever the orb enters `TETHERED` state (including the opening sling at level start), `Engine.time_scale` ramps from its current value down to **0.5** over **0.3 real-world seconds** via a `Tween` set to `ignore_time_scale`. It holds at 0.5 until the orb leaves `TETHERED` (intentional release, forced break, or opening launch), then snaps back to 1.0. A `TimeSlowOverlay` `CanvasLayer` owns the tween and drives a `time_slow.gdshader` shader uniform (`intensity` 0 → 1) in sync, producing a dark-edge vignette with a purple-blue tint. The overlay is a `CanvasLayer` child of HUD in `desert.tscn`; `level.gd` connects `chaos_orb.tethered` / `tether_released` / `launched` to `begin()` / `end()`.
- **Why**: Slowing time during the tether gives the player a meaningful window to judge the orbit and plan the release angle without removing the spatial/positional commitment. The vignette makes the slow state immediately readable. A real-world ramp avoids the instant cut from the previous aim-window approach; snapping back on release makes the sling feel punchy.
- **Alternatives**: Scaled-delta ramp — window stretches as time already slows, so 0.5 s becomes 1 s of game time; keep full speed during tether — loses the "deliberate sling" feel; per-player time scale (Godot does not support it natively) — not viable; fade out on release instead of snap — tested as slower and less punchy; shader-only overlay without actual slow — visual only, less impactful.
- **Status**: decided (in-codebase)

### Level start: opening tether instead of slow-mo aim
- **Decision**: At level start the player first assembles in over ~2 s using reverse `pixel_fall` (`DestructionEffect.play_assemble_from_sprite`), then **one** orb appears already tethered **24 px above** the player (`begin_opening_tether`). Tether (or two full revolutions) releases it along the tangent into `FLYING`. Opening release emits `launched` and does **not** apply the +10% tether boost; `level.gd` then spawns two extras at ±spread (`begin_flight`). `OpeningAimComponent`, the Aim state, and the old free-aim global slow-mo are removed. `OrbTetherComponent.bind_orb()` is only for the opening sling; mid-combat uses the `orb` group. The opening tether now triggers the same 50%/0.5 s time-slow as mid-combat captures (see tether time-slow entry above). `level.gd` starts `EnemySpawner` and the player intro from the same post-nav-ready moment, so enemy telegraphs run while the player is assembling and the tether begins as that intro finishes.
- **Why**: One tether UX for start and mid-combat; teaches capture/release immediately; adding a short player assemble gives the same material language as enemy spawns and avoids visible pop-in while nav bake settles. Letting enemy telegraphs start at the same time preserves the original room pressure timing instead of delaying wave pacing behind the intro.
- **Alternatives**: Keep 3s slow-mo free aim — separate system and co-op time_scale issues; **design-doc free aim-and-fire at start** — may return to match source doc; auto-launch upward without tether — skips the core sling lesson; apply boost on opening release — unfair free power on every level start; keep player visible instantly while only enemies assemble — less coherent spawn language and more start-of-level pop-in; delay enemy spawns until after assembly — cleaner intro staging, but pushes combat pacing later than intended.
- **Status**: superseded — opening launch is now from the summoning circle (see "Opening 3-orb launch from summoning circle")

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
- **Status**: superseded — prototype uses persistent mana crystals delivered to the summoning circle (vanish timer still an open question)

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
- **Status**: decided (design); prototype currently has two desert arenas (`desert.tscn`, `desert_2.tscn`)

---

## Open design tensions

- **Tether feel**: orbit capture parked (`capture_enabled`); Attack-only redirect playtest; entity punch-through is the default (desert export can enable bounce).
- **Attack cooldown / charges**: redirect cooldown 0.35s; tether post-release cooldown 0.25s; melee parked.
- **Opening shot UX**: design doc says free aim-and-fire at level start from the player; prototype launches three typed orbs (Shadow / Poison / Electric) from the summoning circle in random directions (conflicts with one-spell scarcity).
- **Mana vanish duration**: crystals currently persist until deposited or orb-destroyed; should grounded crystals still time out?
- **Shop draft size and reroll rules**: how many offers, costs, rerolls?
- **Camera / view perspective**: player uses 4-direction diagonal sprites in a flat arena; prototype uses a fixed centered `Camera2D` on the 640×360 arena. Confirm long-term camera for larger stages.
- **Arc deflect / melee rollback**: flip `deflect_orb_enabled` / `melee_enabled` if proximity Attack redirect needs the old swing again.
- **Entity bounce default**: keep punch-through or ship bounce-off-entities after desert export playtests.

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

- **Decision**: `HealthComponent.max_health` defaults to `1.0`, while concrete HP values are authored per scene/entity. Current examples: player `30`, grunt `20`, brute `50`, cactus `5`, `big_rock` `60`, `animal_skull` `20`. Orb damage to **entities** comes from the orb `DamageComponent.damage` (currently `10`) via victim `HitboxComponent` overlap polls; orb damage to **breakables** still uses `_try_apply_orb_damage` on flying `body_entered` / tether world-probe contact. On any `take_damage`, the entity sprite modulates to red (`damage_flash_color`) then tweens back (non-fatal) or stays red into the destruction FX (fatal). Sprite comes from an optional `HealthComponent.sprite` export, else `DestroyComponent.sprite`. Non-fatal hits can start gameplay i-frames (see below).
- **Why**: Keeps rules in data; multi-hit is a slider per entity, not special-case code. Shared flash covers entities and breakables without per-scene VFX scripts. Multi-hit props give the orb a reason to revisit the same obstacle and create longer spatial fights around tougher terrain.
- **Alternatives**: One-hit-kill for everyone (`max_health = 1.0`) — previous design; too harsh with tether proximity; a bool `is_one_shot` — extra flag for something already handled by the value; shader hit flash — heavier for a short modulate.
- **Status**: decided (in-codebase); supersedes "one-hit-kill expressed as max_health = 1.0"; `big_rock` / `animal_skull` multi-hit breakables are placed in `desert_2.tscn`

### Damage-reveal percentage health bars
- **Decision**: Every `HealthComponent` owner (player, enemies, breakables) instances `HealthBarComponent`: an 18×2 px world-space bar drawn with `_draw`, fill width = `% of max_health` (not absolute HP, so a 10-HP brute and a 100-HP boss use the same pixel width). Hidden until `damage_taken`; stays visible for **1.5 s**, refreshing on each hit. Per-scene `offset` places it above the sprite.
- **Why**: Upcoming damaging effects can push HP past 100; a percentage bar stays readable without growing. Reveal-on-hit keeps the 640×360 arena uncluttered. Same component on breakables so future multi-hit props get the UI for free.
- **Alternatives**: Always-visible overhead bars — clutter at higher enemy counts; discrete pips — breaks once max HP is no longer 3; screen-only player HUD — enemies would still need hit confirmation for orb grazes; `ProgressBar`/`ColorRect` nodes — extra nodes and softer pixel alignment vs `_draw`.
- **Status**: decided (in-codebase)

### Floating damage labels by DamageKind
- **Decision**: Every successful `HealthComponent.take_damage` spawns a detached world-space number (`DamageLabelEffect` → `damage_label.tscn`) at the owner, parented to `current_scene` so killing blows still show after `queue_free`. Uses `pixel_medium.fnt` at size 8; rises ~20 px over 1 s and fades in the last 0.3 s (`ignore_time_scale`). `DamageKind` selects color: **STANDARD** white (default), **POISON** green (poison DoT ticks only), **SHADOW** black (Shadow possession DPS + Shadow `DamageComponent`). Black numbers use a light outline for readability on dark possessed sprites; white/green use a dark outline. Callers pass the kind (`StatusComponent` → POISON, `ShadowOrb` possession → SHADOW, `DamageComponent.damage_kind` on hitbox/orb breakable paths); Poison orb impact stays STANDARD so hit vs tick stay distinct.
- **Why**: Instant readable confirmation of chip amounts and elemental source without cluttering permanent HUD; shared HealthComponent path covers player, enemies, breakables, and mana crystals for free.
- **Alternatives**: Always-white numbers — loses poison/shadow readability; color by attacker type at the label only — duplicates kind logic outside HP; parent labels to the entity — vanish on death before the float finishes; screen-space HUD popups — harder to attribute in a crowded arena.
- **Status**: decided (in-codebase)

### Damage flow: HitboxComponent overlap polling

- **Decision**: Hit detection uses `HitboxComponent` (`Area2D`) on attackers and victims. Each physics frame the victim hitbox polls `get_overlapping_areas()`, resolves the attacker's `COMPONENTS[DamageComponent]`, and applies damage when the overlap is fresh (or when a contact-damage interval elapses). A short `hit_dedup_frames` grace (default 2) keeps an attacker "seen" after leaving so flicker does not count as a new hit. Entries prune themselves once past that grace. **Orb → entity damage** uses this same poll (orb hitbox on the `orb` layer; victim masks include orb); `contact_damage_interval = 0` means one hit per continuous overlap. Instigator grace still skips the tethering player. **Orb → breakable damage** stays on `RigidBody2D.body_entered` / tether world-probe `_try_apply_orb_damage` so CCD bounce resolves before `queue_free()`. Breakables have no hitbox, so they cannot double-hit with the poll path.
- **Why**: Decouples contact-tick registration from physics enter/exit chatter; sustained enemy contact can tick repeatedly; self-cleaning state avoids unbounded cooldown dictionaries. Entity punch-through means body contact no longer fires for player/enemies, so the hitbox poll is the only entity damage path.
- **Alternatives**: `area_entered` only — one damage forever while glued, and bounce flicker double-hits; wall-clock per-attacker cooldown — magic number that can swallow legitimate late-run hits; signal bus — extra indirection; keep entity orb damage on `body_entered` only — requires entity body bounce; skip orb in victim poll — previous, when body contact owned entity hits.
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

- **Decision**: On launch / tether release / deflect, `DamageComponent.instigator` is set to the releasing player and cleared after `player_grace_seconds` (**1.0 s**). Body-contact and hitbox paths skip damage when `instigator == owner`. This replaces the previous `player_grace_until_msec` wall-clock guard in `_resolve_hit`.
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
- **Decision**: Orb/player world collision uses four `StaticBody2D` wall slabs around the viewport, not TileMap physics polygons. Those slabs live on both the `world` and `wall` physics layers so walking/orb bounce/nav bake stay on `world`, while dash can collide with `wall` without also hitting props.
- **Why**: Current desert tileset has no physics layer; border slabs keep the orb on-screen cheaply. Dual-layer membership lets dash stay inside the arena without giving up phase-through on rocks and enemies.
- **Alternatives**: Author per-tile collision — more setup before the loop is proven; move walls off `world` onto `wall` only — would require adding `wall` to every existing world mask.
- **Status**: decided (in-codebase)

### Enemy pathfinding uses a baked NavigationRegion2D plus agent avoidance
- **Decision**: Enemy movement now paths on one `NavigationRegion2D` baked at runtime from an explicit arena outline minus `world`-layer static colliders. `LowerGround`, `Cliffs`, `Objects`, and `Walls` contribute source geometry through a `navigation_source` group; `level.gd` bakes once, then waits until the NavigationServer can path from arena center to the player before `EnemySpawner.start()` (reload leaves the server map empty for a few physics frames after `bake_finished`). Re-bake on a short debounce when breakables die. The navmesh now erodes by **15 px** (the brute radius) so narrow cliff/rock pockets are removed. Each enemy owns a `NavigationComponent` (`NavigationAgent2D`) that repaths toward the player, uses avoidance against other enemies only, and triggers a stuck watchdog that stops and forces a repath if the body makes almost no progress for a short window. Enemy spawns are projected onto the navmesh, rejected if they are off-mesh or lack a valid path to the player's nav position, and now also rejected when the enemy body shape would overlap `world`-layer colliders at that point (with a small safety margin). After assemble re-enables collision, spawn activation runs a short depenetration step to push out of any residual overlap before chase starts. Fallbacks still try several inset points instead of stacking on one corner.
- **Why**: The desert TileSet's navigation polygons overlapped across `TileMapLayer`s and the ground layer re-filled the walkable space under cliff-face colliders, so tile-authored navigation would route enemies straight into walls. Baking against the runtime colliders keeps pathing aligned with the actual level, the larger erosion radius removes "looks open but is physically too tight" pockets, and the watchdog recovers from knockback/corner stalls. Nav-only spawn validation still allowed rare rock overlaps because the brute radius matches nav erosion and enemy body centers are slightly offset from sprite origin; the physics-clear query and depenetration close that gap.
- **Alternatives**: Keep TileSet navigation layers — one-nav-polygon-per-cell limits, no shared agent-radius inset, and plateau cells conflict across layers; keep the smaller **12 px** erosion radius — preserves routes that still trap the brute and sometimes the grunt in diagonal corners; rely on `NavigationObstacle2D` / physics separation only — enemies still path into blocked routes and then jam; remove enemy-enemy body collision and depend only on avoidance — weaker hard separation when avoidance fails.
- **Status**: decided (in-codebase)

### Orb is RigidBody2D with script-owned bounce + separate hitbox
- **Decision**: `ChaosOrb` is a `RigidBody2D` with a circular body shape (**world-only** mask by default; flying can also mask player + enemy when `bounce_off_entities` is true), locked rotation, gravity 0, friction 0, **bounce 0** material, continuous CCD, `can_sleep` off, and constant-speed flight. All reflection is owned by `_integrate_forces`: inbound contact normals are summed, then `aim_direction` reflects **once** off that combined normal (only when moving into the surface), then `linear_velocity = aim_direction * speed`. `_physics_process` does **not** re-derive direction from solver velocity. World bounce SFX and breakable damage use `body_entered`. Player/enemy damage uses the orb's `HitboxComponent` Area2D via victim hitbox polls (punch-through or bounce; body-entered skips entity HP to avoid double-hit). Tether probes use the same world-only mask. Post-launch grace adds a collision exception vs the batter so entity bounce does not immediately rebound off the redirecting player.
- **Why**: Solver bounce + script bounce fought each other and caused sticky re-entry (double damage / double SFX). Real contact normals beat center-to-center approximations on capsules and rectangles. World-only mask lets the orb cut through packs while still reading as a physical projectile against arena solids; the desert export restores entity bounce for A/B.
- **Alternatives**: PhysicsMaterial bounce 1 + velocity read-back — previous; double-reflect artifacts; world + player + enemy mask with entity bounce always — previous punch-stop feel; world-only mask without hitbox entity damage — orb phases harmlessly through targets.
- **Status**: decided (in-codebase)

### Aim windows measured in real time under Engine.time_scale
- **Decision**: Opening aim was 3.0s of **wall-clock** time via `Time.get_ticks_msec()`, while `Engine.time_scale = 0.15` during aim. Mid-combat redirect aim windows were already gone.
- **Why**: Slow-mo must not stretch the intended aim deadline.
- **Alternatives**: Use scaled `delta` timers — windows become much longer than designed.
- **Status**: superseded — opening aim replaced by opening tether; tether slow-mo ramp also uses `ignore_time_scale` tween for the same reason

### Post-launch player grace
- **Decision**: After every launch (opening tether release, deflect, or mid-combat tether release / forced break), the orb ignores the releasing player for **1.0 s** (`player_grace_seconds`). While the countdown runs, the orb shows a ghostly tint and a shrinking halo ring that tracks remaining grace. While tethered, `instigator` stays pinned to the tethering player for the whole orbit (countdown cleared mid-tether so the visual does not run during orbit).
- **Why**: Deflecting / tethering requires proximity; without grace the player dies on the same frame they bat or release the orb. 1 s gives a readable dodge window after a sling; the orb-side visual makes “this orb won’t hurt you yet” obvious without implying full player i-frames.
- **Alternatives**: 0.3 s grace — too short once orbit radius and release tangents put the player in the path; teleport orb away on deflect — less readable; disable player hit forever until leave range — easier to cheese; player-side blink — reads as full invulnerability to enemies too.
- **Status**: decided (in-codebase)

### KnockbackComponent for shove without damage
- **Decision**: `KnockbackComponent` applies a decaying shove to its owner (`CharacterBody2D` via velocity + `move_and_slide`, `RigidBody2D` via impulse, plain `Node2D` via position). Enemies yield chase AI while knockback is active. Built generic so breakables/objects can reuse it later.
- **Why**: Attack needs a non-damage response for enemies; keeps shove logic out of MovementComponent and entity scripts.
- **Alternatives**: Bake knockback into MovementComponent — couples walk and shove; one-off velocity in grunt script — not reusable for props.
- **Status**: decided (in-codebase)

### Dash: fixed distance with i-frames and phase-through
- **Decision**: Player dashes 50 px toward **current facing** (8-way via `DirectionalSpriteComponent.facing_vector()`) at 400 px/s via `DashComponent` + `Dash` state. Idle dash uses last facing; dash does not read mouse/aim. While dashing: hitbox monitoring off (immune to orb and enemies), body `collision_layer` cleared and `collision_mask` set to the `wall` layer so the player phases through props/enemies but is stopped by outer arena walls, no movement input, no attacking. Dash duration is consumed by intended distance (not actual travel) so a wall block cannot stall the dash. **4 s** cooldown, shown as a radial ring above the head drawn by `DashComponent` itself. Starts only from Idle/Walk (does not cancel an attack swing). Space is `dash`; attack keeps left click / gamepad A. Outer `Walls` bodies sit on both `world` and `wall` so walking, orb bounce, and nav bake are unchanged. Proximity Attack redirect calls `reset_cooldown()` so the player can dash immediately after batting an in-range orb. **Cannot dash while carrying a mana crystal.**
- **Why**: Readable dodge through the orb, chasers, and clutter; fixed distance is easy to learn and tune; facing-direction dash matches movement/strafe intent and frees aim for the attack arc; phase-through keeps the dash reliable in a prop-filled arena; leaving the arena by dashing through the border slabs was a hole; a 4 s wait is a committed dodge, so a world-space ring makes the recharge obvious. Cooldown UI lives on `DashComponent` because dash is player-only and 1:1 with that cooldown state. Clearing cooldown on redirect rewards standing near the orb and enables an immediate dodge after the bat. Blocking dash while carrying makes delivering mana to the circle a committed walk.
- **Alternatives**: Aim-direction dash (mouse / right stick) — coupled dodge to attack aim and fought strafe play; reuse `KnockbackComponent`'s decaying shove — wrong curve (fade-out vs constant speed) and no i-frame API; velocity-based dodge that keeps movement control — less committed and harder to read; interrupt attack with dash — too many cancel options for prototype; keep world collision during dash — props truncate the dash unpredictably; clear all collision during dash — previous; let the player leave the arena; separate `DashCooldownIndicator` component — extra scene wiring for a UI that nothing else reuses (health bar stays separate because it is shared across entities).
- **Status**: decided (in-codebase)

### Level objects: shared script + per-variant Resource
- **Decision**: Solid and breakable props share `LevelObject` / `Breakable` scripts. Each object type is its own scene (`cactus.tscn`, `rock.tscn`) that holds an array of `LevelObjectVariant` Resources (texture + hand-tuned collision). Runtime picks a random variant.
- **Why**: Same behavior with different art/collision without duplicating scripts; avoids a flag-driven mega-scene; adding rock_2 is a new `.tres` + array entry.
- **Alternatives**: One general object scene with `is_destructible` exports — becomes flag soup for TNT later; fully separate scene/script per art file — duplicated physics setup.
- **Status**: decided (in-codebase)

### Breakables bounce then destroy via orb body contact
- **Decision**: Breakables (cactus) live on the `world` physics layer like rocks/walls. The orb damages them via flying `RigidBody2D.body_entered` → `_try_apply_orb_damage` (and the tether world-probe path), not the Area2D hitbox poll, so the bounce impulse is solved before `queue_free()`.
- **Why**: Props should reshape orb paths; using a leading hitbox-only destroy would free the body before bounce. No fifth physics layer needed. Entities use hitbox poll instead because they are punch-through.
- **Alternatives**: Punch-through breakables too — less spatial play; dedicated `breakable` layer + hitbox area — destroys before bounce; multi-hit health — deferred.
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
