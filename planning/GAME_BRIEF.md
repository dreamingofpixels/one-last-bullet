# A Final Spell — Game Brief

## Summary
Arcade tavern roguelike. You are a **wizard** with **one spell left**: the **orb of chaos**. Each level starts with that orb in play — it bounces forever, damages enemies on hit, and **hurts you on contact** (player has **3 HP** with brief i-frames after a hit). Steer it mid-combat by getting close and tethering it into an orbit, then releasing it along a chosen tangent; clear the room; spend **mana** on synergistic upgrades; survive **10 levels**.

## Story (current)
Very lean. You are a wizard defending yourself from various nefarious beings. No deeper plot required — the game is gameplay-first arcade.

## Player fantasy
Dodge your own chaos orb while slinging it at enemies. Risk the floor for vanishing mana. Build a run from shop synergies that twist the orb, you, or the enemies.

## Core loop
- **Level start (design)**: player stands center-bottom and **fires the orb in any direction**. *(Prototype: player first **assembles in** over ~2 s via reverse pixel-fall, then **one** orb appears **tethered 24 px above** the player; tether or two full revolutions releases it along the orbit tangent and spawns a **3-orb spread volley** (±20° extras) — see open questions.)*
- **Combat**: **three** orbs travel and bounce indefinitely after the opening volley. Enemies chase the player and deal **contact damage on a short tick** (~0.75s). Solid props and breakables bounce orbs; breakables are destroyed on that hit. Obstacles can interact further (e.g. TNT barrels explode). Breakables can drop powerups.
- **Attack**: when the **closest** flying orb is within **48 px**, Attack **redirects** that orb along aim (mouse / right stick) instead of swinging — no melee arc, no enemy knockback; also **resets dash cooldown**. Otherwise press attack to swing a melee **arc** toward the mouse / right stick (hitbox is an authored polygon on `AttackComponent`). Enemies in the arc get **knocked back**. Movement stays unlocked during swings; **locked while tethered**. Attack does not capture or release the orb. Swing / redirect share the ~0.35 s attack cooldown.
- **Orb tether**: when a flying orb is within **48 px** (`focus_radius`), it shows an in-focus overlay (all in-range orbs); the **closest** also shows an aim arrow toward the player's aim. Press tether to capture the **closest** in-range orb (**one tether at a time**); it keeps its current position and **spirals in** to the fixed **24 px** orbit radius (`min_tether_radius`). Press tether again (or wait two full revolutions) to release it along its current tangent at full speed (mid-combat release is still a single orb — no extra volley). **Hold tether for 2 s** when no orb is in range to channel a remote pull toward the **closest** flying orb — that orb **teleports** onto the player→orb axis at **24 px** and begins orbiting immediately (movement locked during channel; visual progress ring + line to that orb). Player cannot move or dash while tethered or channeling. Each release permanently increases **that** orb's **speed and damage by 10%** (speed capped at **1500**). While tethered it damages enemies but not the tethering player; after release the player stays immune to that orb for **1 s** (ghostly tint + shrinking halo on the orb). The tether **breaks on contact** with rocks/walls/props (world solids only); forced breaks bounce the orb off the contact normal and still apply the +10% boost (opening tether excepted). Orbs **punch through** player and enemies (and each other) while still damaging them. Arc-contact deflect of the orb is disabled (code kept behind a flag); proximity Attack redirect is the mid-combat aim steer. **While tethered** (including the opening sling), time slows to **50%** speed over a **0.3 s** real-time ramp; a fullscreen vignette (dark edge + purple-blue tint) fades in to match. Time and overlay snap back instantly on release.
- **Dash**: press Space (or gamepad B) to dash **50 px** toward current facing (8 directions: N/S/E/W + diagonals). While dashing the player is immune to damage, phases through props/enemies, and cannot move or attack. Outer arena walls still block the dash. **4s** cooldown, shown as a small ring above the player's head (drawn by `DashComponent`); cannot start mid-swing. A proximity **Attack redirect** clears the dash cooldown so the player can dash immediately after batting the orb.
- **Loot**: enemies drop **mana** that must be picked up quickly before it disappears. *(not in prototype yet; `mana_picked_up.ogg` exists)*
- **Clear**: kill all enemies → level win.
- **Shop**: spend mana on randomized upgrades (orb / player / enemy curses). Synergies are a design pillar. *(not in prototype yet)*
- **Next level**: repeat until 10 clears (run win) or death (HP depleted by enemy contact or own orb).

## Win / lose
- **Level win**: all enemies dead.
- **Run win**: clear 10 levels.
- **Lose**: player HP reaches 0 from enemy contact or the orb.

## The orb of chaos
- **Design**: shot by the player at level start in any direction from center-bottom; then travels and bounces freely forever. Speed slow enough to tether but fast enough that avoiding it is a challenge. Speed and damage increase each time you redirect it.
- **Prototype (playtest)**: player first assembles over ~2 s, then **one** orb starts tethered **24 px above** the player; tether (or two full revolutions) releases it along the current tangent and immediately spawns **two more** orbs at **±20°** (same speed/damage). All three persist and bounce for the rest of the level. Opening tether triggers the same time-slow (50%, 0.5 s ramp) as mid-combat captures.
- Travels and bounces freely forever (perfectly elastic walls, rocks, and breakables; constant speed). **Punches through** player and enemy bodies while still damaging them. Script owns bounce via contact normals (`_integrate_forces`); physics material bounce is 0 so the solver does not fight it.
- Damages enemies and player on hit based on the orb `DamageComponent` value (**10** in the current scene setup, not instant kill). Player has brief i-frames after a non-fatal hit.
- Mid-combat steer: get within **48 px** of a flying orb — all in-range orbs show focus; the **closest** shows an aim arrow. Press tether to capture the **closest**; it spirals to a fixed **24 px** orbit. Press tether again (or wait two full revolutions) to release it along the current tangent. Alternatively, press **Attack** to redirect the closest in-range orb along aim (no melee swing, no +10% boost; resets dash cooldown; shares ~0.35 s attack cooldown). Player cannot move or dash while tethered. Each tether release permanently increases **that** orb's **speed and damage by 10%** (speed capped at **1500**). While tethered the orb damages enemies; the tethering player is immune via instigator grace for the whole tether and **1 s** after release. Contact with **world solids** (rocks/walls/breakables) **breaks the tether**, bounces the orb, and applies the same +10% boost as an intentional release (opening tether still has no boost). Flying and tethered orbs **punch through** player and enemy bodies (and each other) while still dealing damage. Post-release grace lasts **1 s** (ghostly orb tint + shrinking halo) so the player is not instantly hit again. Arc-contact deflect of the orb is parked (code kept). Out-of-range Attack still knocks enemies and has a short cooldown (~0.35s).

## Input
- **Move**: WASD (keyboard) or left stick / D-pad (gamepad)
- **Attack**: left click (keyboard); A button (gamepad)
- **Tether**: right click (keyboard); X button (gamepad)
- **Dash**: Space (keyboard); B button (gamepad)
- **Aim**: mouse for the keyboard player; right stick for gamepad players
- **Restart**: R
- **Co-op**: up to 4 local players supported by the input system; P1 uses keyboard + mouse + gamepad device 0; P2 uses gamepad device 1; P3/P4 action bindings not yet authored in project.godot

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
- Grunts and brutes use scene-authored HP (`grunt` **20 HP**, `brute` **50 HP**); orb hits chip them and melee still knocks back without damage. Brute HP/damage can be tuned on the scene.
- Enemies arrive in **authored waves** (`EnemySpawner`: count, types, delay between waves). Desert prototype: **3 grunts**, then **1 brute** after **6s** (waves can overlap if the first is not cleared in time). Each spawn telegraphs with a pulsing ground ring, then assembles over **~2s** by playing the destruction pixel-fall in reverse.
- Player attack knocks enemies back (no melee damage).
- More enemy types planned later.

## Economy
- **Single resource**: **mana** (from enemy drops; may also come from breakables — open).
- Spent in the between-level shop on upgrades.

## Open questions / design tensions to resolve
- **Opening shot UX**: design doc says free aim-and-fire at level start; prototype uses opening tether + 3-orb spread volley. Reconcile after playtest (also conflicts with one-spell scarcity).
- **Tether feel**: fixed 24 px orbit with spiral pull-in and two-turn auto-release — revisit after playtest.
- **Attack cooldown / charges**: current cooldown is 0.35s on swings; tether capture/release has its own short post-release cooldown (~0.25s).
- **Mana vanish duration**: how long before dropped mana disappears?
- **Shop draft**: how many offers, rerolls, price scaling?
- **Powerup types**: what breakables drop, and how they stack with shop upgrades.
- **Camera / view**: player uses 4-direction diagonal sprites in a top-down-ish arena; confirm long-term camera for larger stages.
- **Difficulty curve**: how enemy count, obstacles, and layout pressure scale across 10 levels.
- **Arc deflect rollback**: `AttackComponent.deflect_orb_enabled` is false; proximity Attack redirect covers aim-steer without arc contact.
