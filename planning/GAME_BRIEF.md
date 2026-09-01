# A Final Spell — Game Brief

## Summary
Arcade tavern roguelike. You are a **wizard** with **one spell left**: the **orb of chaos**. Each level starts with that orb in play — it bounces forever, damages enemies on hit, and **hurts you on contact** (player has **3 HP** with brief i-frames after a hit). Steer it mid-combat by getting close and tethering it into an orbit, then releasing it along a chosen tangent; clear the room; spend **mana** on synergistic upgrades; survive **10 levels**.

## Story (current)
Very lean. You are a wizard defending yourself from various nefarious beings. No deeper plot required — the game is gameplay-first arcade.

## Player fantasy
Dodge your own chaos orb while slinging it at enemies. Risk the floor for vanishing mana. Build a run from shop synergies that twist the orb, you, or the enemies.

## Core loop
- **Level start (design)**: player stands center-bottom; **three typed orbs** (Shadow, Poison, Electric) shoot from the **summoning circle** in **random directions** after the player assembles in. *(Prototype: player first **assembles in** over ~2 s via reverse pixel-fall, then orbs launch from the circle — no opening tether.)*
- **Combat**: **three** typed orbs travel and bounce indefinitely after the opening launch. Enemies chase the player and deal **contact damage on a short tick** (~0.75s). Solid props and breakables bounce orbs; breakables are destroyed on that hit. Obstacles can interact further (e.g. TNT barrels explode). Breakables can drop powerups.
- **Attack**: when the **closest** flying orb is within **48 px**, Attack **redirects** that orb along aim (mouse / right stick) — no melee arc, no enemy knockback; also **resets dash cooldown** and **+10%** speed/damage on that orb (stacks, speed capped at **1500**). Out of range, Attack does nothing (melee swing / knockback parked behind `AttackComponent.melee_enabled`). Movement stays unlocked during redirect; **locked while tethered**. Attack does not capture or release the orb. Redirect uses the ~0.35 s attack cooldown. Crystal throw still uses Attack while carrying.
- **Orb tether** *(capture parked for playtest)*: when a flying orb is within **48 px** (`focus_radius`), it shows an in-focus overlay (all in-range orbs); the **closest** also shows a **chevron chain** along the player's aim (three `>` marks outside the orb). Mid-combat steer is **Attack redirect** only (`OrbTetherComponent.capture_enabled = false` on the player — orbit capture / remote channel code kept dormant). Tether still **picks up mana crystals** in focus range. Standing in the summoning circle `DepositArea` and pressing tether **spends 5** from `mana_pool` to **activate** the circle once (sprite blink + rising arcane particles). Capture/release/orbit path remains in code for later: spiral to **24 px**, second press or two revolutions to release, remote hold channel, +10% boost, world-solid break, time-slow vignette — not reachable while capture is off.
- **Dash**: press Space (or gamepad B) to dash **50 px** toward current facing (8 directions: N/S/E/W + diagonals). While dashing the player is immune to damage, phases through props/enemies, and cannot move or attack. Outer arena walls still block the dash. **4s** cooldown, shown as a small ring above the player's head (drawn by `DashComponent`); cannot start mid-swing or while **carrying a mana crystal**. A proximity **Attack redirect** clears the dash cooldown so the player can dash immediately after batting the orb.
- **Loot**: enemies have a **25%** chance to drop a **mana crystal** (5 mana, 20 HP). Pick up with the **tether** action when in focus range. Carrying blocks dash; **Attack** throws the crystal so it slides and settles. Deliver it into the **summoning circle**: the crystal is sucked to the circle center, then credits `mana_pool` (shown on `%ManaPoolLabel`) and plays destroy VFX. Orbs can destroy grounded crystals (no pool credit).
- **Clear**: kill all enemies → level win.
- **Shop**: spend mana on randomized upgrades (orb / player / enemy curses). Synergies are a design pillar. *(not in prototype yet)*
- **Next level**: repeat until 10 clears (run win) or death (HP depleted by enemy contact or own orb).

## Win / lose
- **Level win**: all enemies dead.
- **Run win**: clear 10 levels.
- **Lose**: all players' HP reach 0 from enemy contact or the orb (co-op: one player dying leaves the others playing).

## The orb of chaos
- **Design**: enters play at level start from the summoning circle; then travels and bounces freely forever. Speed slow enough to tether but fast enough that avoiding it is a challenge. Speed and damage increase each time you redirect it.
- **Prototype (playtest)**: player first assembles over ~2 s, then **three typed orbs** launch from the **summoning circle** center in **independent random directions** (`begin_flight`, with player instigator grace): **Shadow**, **Poison**, and **Electric**. No plain chaos orb is launched (the chaos script/scene remains the shared projectile base). All three persist and bounce for the rest of the level.
- Travels and bounces freely forever (perfectly elastic walls, rocks, and breakables; constant speed). Default playtest: **punches through** player and enemy bodies while still damaging them. Desert scene export **`bounce_orbs_off_entities`** (inspector on `desert.tscn`) toggles flying orbs to bounce off player/enemy bodies instead (`ChaosOrb.bounce_off_entities`). Script owns bounce via contact normals (`_integrate_forces`); physics material bounce is 0 so the solver does not fight it.
- Damages enemies and player on hit based on the orb `DamageComponent` value (**10** impact for Poison/Electric/player contact; Shadow skips impact HP on enemies). Player has brief i-frames after a non-fatal hit.
- **Shadow**: on enemy hit, **enters** the host (hidden `POSSESSED` state, not tetherable). Deals **3 DPS** while inside. Host uses a **dark damage flash** while possessed. On host death the orb reappears at the corpse and flies in a **random** direction (no player grace).
- **Poison**: on enemy hit, applies **1 Poison** stack. Poison ticks every **3 s** for damage equal to current stacks; stacks persist until the enemy dies (extra stacks do not reset the timer).
- **Electric**: while any player is within **300 px**, draws an electric **current** (Line2D + capsule Area2D). Enemies touching the current take **5 HP/s** and **3 Shock/s** (first tick on enter). At **10 Shock**, the enemy is **stunned 2 s** and Shock clears; Shock does not stack during stun. Current does not hurt the player; no wall LOS check.
- Mid-combat steer *(playtest)*: get within **48 px** of a flying orb — all in-range orbs show focus; the **closest** shows a chevron chain along aim. Press **Attack** to redirect the closest in-range orb along aim (no melee swing; **+10%** speed/damage via `tether_release_boost`, speed clamped to **1500**; resets dash cooldown; shares ~0.35 s attack cooldown). Orb **capture / orbit tether** is parked (`capture_enabled = false`); code kept. Flying orbs default to **punch through** player and enemy bodies (and each other) while still dealing damage; optional desert export `bounce_orbs_off_entities` enables entity bounce. Possessed Shadow orbs are not flying and cannot be redirected. Post-redirect grace lasts **1 s** (ghostly orb tint + shrinking halo; collision exception vs batter while grace runs). Arc-contact deflect of the orb is parked (code kept). Out-of-range Attack does nothing while melee is parked.

## Input
- **Move**: WASD (keyboard) or left stick / D-pad (gamepad)
- **Attack**: left click (keyboard); A button (gamepad)
- **Tether**: right click (keyboard); X button (gamepad)
- **Dash**: Space (keyboard); B button (gamepad)
- **Aim**: mouse for the keyboard player; right stick for gamepad players
- **Restart**: R
- **Co-op**: up to 4 local players supported by the input system; P1 uses keyboard + mouse + gamepad device 0; **P2 is added automatically** when a second gamepad is connected (no join button) — instances `player.tscn` with `player_index = 2` and assembles in at the same time as P1; mid-level plug-in still hot-joins. P3/P4 action bindings not yet authored in project.godot. Run ends only when **all** players are dead.

## Stage
- **Different stages and environments**, with randomized enemies and obstacles (tavern is one possible setting, not the only one).
- Prototype arenas: `desert.tscn` and `desert_2.tscn` with border wall colliders (tileset has no physics yet).
- Solid props (rocks) and breakables (cacti) block movement and bounce the orb.
- The orb **bounces off** a breakable on contact. Breakable HP is scene-authored (`cactus` `max_health = 5`, `animal_skull` `max_health = 20`, `big_rock` `max_health = 60`) and orb contact damage comes from the orb `DamageComponent` (**10** in the current scene setup).
- Breaking some objects can yield powerups *(hook only; drops not in prototype yet)*.
- `big_rock.tscn` (28×22 px) and `animal_skull.tscn` (16×16 px) are 3-HP breakables placed in `desert_2.tscn`.
- Obstacles can interact with the orb and environment (example: TNT barrel explosion — later).
- Enemy mana drops vanish after a short time (exact duration TBD).

## Progression
- After each level, a **shop** sells randomized upgrades:
  - improve the **orb**
  - improve the **player**
  - **curse** enemies
- Fun should come from discovering interesting synergies across those categories.

## Enemies
- Two chaser enemies (`grunt_knife`, `brute`) **path around obstacles toward the player** and use local avoidance so packs spread instead of body-stacking, while still dealing **1 contact damage** on a ~0.75s tick once overlapping.
- Grunts and brutes use scene-authored HP (`grunt` **20 HP**, `brute` **50 HP**); orb hits chip them. Melee knockback is parked (`melee_enabled = false`). Brute HP/damage can be tuned on the scene.
- Enemies arrive in **authored waves** (`EnemySpawner`: count, types, delay between waves). Desert prototype: **3 grunts**, then **1 brute** after **6s** (waves can overlap if the first is not cleared in time). Each spawn telegraphs with a pulsing ground ring, then assembles over **~2s** by playing the destruction pixel-fall in reverse.
- Player attack does not knock enemies (melee dormant); Attack redirects orbs only.
- More enemy types planned later.

## Economy
- **Single resource**: **mana** (from enemy mana crystals deposited into the summoning circle; may also come from breakables — open).
- Spent in the between-level shop on upgrades.
- **Summoning circle** holds a level `mana_pool` (label shows the current total). Crystals destroyed by orbs do **not** add to the pool. Pressing tether while standing in the circle spends **5** once to activate it (blink + arcane particles); further ritual effects TBD.

## Open questions / design tensions to resolve
- **Opening shot UX**: design doc says free aim-and-fire at level start from the player; prototype launches three typed orbs (Shadow / Poison / Electric) from the summoning circle in random directions. Reconcile after playtest (also conflicts with one-spell scarcity).
- **Tether feel**: orbit capture parked; playtesting Attack-only redirect. Restore `capture_enabled` to revisit spiral / two-turn release.
- **Attack cooldown / charges**: current cooldown is 0.35s on redirect; tether capture/release has its own short post-release cooldown (~0.25s). Melee swing parked.
- **Mana vanish duration**: crystals currently persist until deposited or orb-destroyed; should grounded crystals still time out?
- **Shop draft**: how many offers, rerolls, price scaling?
- **Powerup types**: what breakables drop, and how they stack with shop upgrades.
- **Camera / view**: player uses 4-direction diagonal sprites in a top-down-ish arena; confirm long-term camera for larger stages.
- **Difficulty curve**: how enemy count, obstacles, and layout pressure scale across 10 levels.
- **Arc deflect rollback**: `AttackComponent.deflect_orb_enabled` is false; proximity Attack redirect covers aim-steer without arc contact.
- **Entity bounce**: desert inspector export `bounce_orbs_off_entities` playtests punch-through vs bounce-off-entities; pick a default after feel tests.
- **Melee rollback**: flip `AttackComponent.melee_enabled` to restore swing sprite + enemy knockback.
