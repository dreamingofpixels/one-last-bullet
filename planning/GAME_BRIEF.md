# One Last Bullet — Game Brief

## Summary
Western saloon arcade roguelike. You are a Sheriff with **one bullet**. The run starts with that bullet fired into the room: it bounces forever, damages enemies on hit, and **kills you instantly** on contact. Steer it mid-combat by getting close and tethering it into an orbit, then releasing it along a chosen tangent; clear the saloon; spend gold on synergistic upgrades; survive **10 levels**.

## Story (current)
Very lean. You are a Sheriff defending your town's saloon from enemies. No deeper plot required — the game is gameplay-first arcade.

## Player fantasy
Dodge your own bullet while batting it at enemies. Risk the floor for vanishing gold. Build a run from shop synergies that twist the bullet, you, or the enemies.

## Core loop
- **Level start**: player stands center-bottom; the orb spawns **tethered 32 px above** the player. Tether (or one full revolution) releases it along the orbit tangent into combat.
- **Combat**: bullet travels and bounces indefinitely. Enemies chase the player (contact kill). Solid props and breakables bounce the bullet; breakables are destroyed on that hit. Obstacles can interact further later (e.g. TNT barrels explode). Breakables can later drop powerups.
- **Attack**: press attack to swing a melee **arc** toward the mouse / right stick (hitbox is an authored polygon on `AttackComponent`). Enemies in the arc get **knocked back**. Movement stays unlocked during swings; **locked while tethered**. Attack does not capture or release the orb.
- **Orb tether**: when the flying orb is within **32 px**, it shows an in-focus overlay. Press tether to capture it so it circles the player; press tether again (or wait one full revolution) to release it along its current tangent at full speed. Player cannot move or dash while tethered. Each release permanently increases the orb's **speed and damage by 10%** (speed capped at **1500**). While tethered it damages enemies but not the tethering player. Arc-deflect of the orb is disabled (code kept behind a flag).
- **Dash**: press Space (or gamepad B) to dash **50 px** toward current facing (8 directions: N/S/E/W + diagonals). While dashing the player is immune to damage, phases through props/enemies/walls, and cannot move or attack. Short cooldown (~0.5s); cannot start mid-swing.
- **Loot**: enemies drop gold that must be picked up quickly before it disappears. *(not in prototype yet)*
- **Clear**: kill all enemies → level win.
- **Shop**: spend gold on randomized upgrades (bullet / player / enemy curses). Synergies are a design pillar. *(not in prototype yet)*
- **Next level**: repeat until 10 clears (run win) or death (enemy contact or own bullet).

## Win / lose
- **Level win**: all enemies dead.
- **Run win**: clear 10 levels.
- **Lose**: player dies from an enemy or from the bullet.

## The bullet
- Starts the level already tethered **32 px above** the player; tether releases it along the current tangent (no opening-aim slow-mo).
- Travels and bounces freely forever (perfectly elastic walls; constant speed).
- Damages enemies on hit; kills the player on contact.
- Speed should be slow enough to interact with (tether capture) but fast enough that avoiding it is a challenge.
- Mid-combat steer: get within **32 px**, press tether to capture the orb into an orbit around the player, then press tether again (or wait one full revolution) to release it along the current tangent. Player cannot move or dash while tethered. Each release permanently increases orb **speed and damage by 10%** (speed capped at **1500**). While tethered the orb damages enemies; the tethering player is immune via instigator grace for the whole tether and briefly after release. Brief post-release grace so the player is not instantly killed. Arc-deflect of the orb is parked (code kept). Attack swing still knocks enemies and has a short cooldown (~0.35s); it is independent of tether capture/release.

## Input
- **Move**: WASD (keyboard) or left stick / D-pad (gamepad)
- **Attack**: left click (keyboard); A button (gamepad)
- **Tether**: right click (keyboard); X button (gamepad)
- **Dash**: Space (keyboard); B button (gamepad)
- **Aim**: mouse for the keyboard player; right stick for gamepad players
- **Restart**: R
- **Co-op**: up to 4 local players supported by the input system; P1 uses keyboard + mouse + gamepad device 0; P2 uses gamepad device 1; P3/P4 action bindings not yet authored in project.godot

## Stage
- Every stage is a saloon with **randomized** enemies and obstacles.
- Prototype arena: `desert.tscn` with border wall colliders (tileset has no physics yet).
- Solid props (rocks) and breakables (cacti) block movement and bounce the bullet.
- The bullet **bounces off** a breakable and **destroys it in one hit** on the same contact.
- Breaking some objects can later yield gold/powerups *(hook only; drops not in prototype yet)*.
- Obstacles can interact with the bullet and environment (example: TNT barrel explosion — later).
- Enemy gold drops vanish after a short time (exact duration TBD).

## Progression
- After each level, a **shop** sells randomized upgrades:
  - improve the **bullet**
  - improve the **player**
  - **curse** enemies
- Fun should come from discovering interesting synergies across those categories.

## Enemies
- For now: one basic enemy (`grunt_knife`) that **chases the player** and kills on contact.
- Prototype spawns **3** grunts. Brute deferred.
- Player attack knocks enemies back (no melee damage).
- More enemy types planned later.

## Economy
- **Single resource**: gold (from enemy drops; may also come from breakables — open).
- Spent in the between-level shop on upgrades.

## Open questions / design tensions to resolve
- **Tether feel**: orbit radius, auto-release after one turn, and wall/prop clipping while tethered — revisit after playtest.
- **Attack cooldown / charges**: current cooldown is 0.35s on swings; tether capture/release has its own short post-release cooldown (~0.25s).
- **Gold vanish duration**: how long before dropped gold disappears?
- **Shop draft**: how many offers, rerolls, price scaling?
- **Powerup types**: what breakables drop, and how they stack with shop upgrades.
- **Camera / view**: player uses 4-direction diagonal sprites in a top-down-ish arena; confirm long-term camera for larger stages.
- **Difficulty curve**: how enemy count, obstacles, and layout pressure scale across 10 levels.
- **Arc deflect rollback**: `AttackComponent.deflect_orb_enabled` is false; may restore if tether does not pan out.
