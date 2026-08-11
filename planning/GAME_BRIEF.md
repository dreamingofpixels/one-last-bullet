# One Last Bullet — Game Brief

## Summary
Western saloon arcade roguelike. You are a Sheriff with **one bullet**. The run starts with that bullet fired into the room: it bounces forever, damages enemies on hit, and **kills you instantly** on contact. Steer it by getting close and redirecting; clear the saloon; spend gold on synergistic upgrades; survive **10 levels**.

## Story (current)
Very lean. You are a Sheriff defending your town's saloon from enemies. No deeper plot required — the game is gameplay-first arcade.

## Player fantasy
Dodge your own bullet while aiming it at enemies. Risk the floor for vanishing gold. Build a run from shop synergies that twist the bullet, you, or the enemies.

## Core loop
- **Level start**: player stands center-bottom; **3 real-time seconds** of slow-mo free aim, then the bullet launches in the chosen direction.
- **Combat**: bullet travels and bounces indefinitely. Enemies chase the player (contact kill). Solid props and breakables bounce the bullet; breakables are destroyed on that hit. Obstacles can interact further later (e.g. TNT barrels explode). Breakables can later drop powerups.
- **Redirect**: get close to the bullet, press **Space** → **1.5 real-time seconds** of slow-mo → aim a new direction (A/D rotate, mouse aim). Player movement is locked while aiming.
- **Loot**: enemies drop gold that must be picked up quickly before it disappears. *(not in prototype yet)*
- **Clear**: kill all enemies → level win.
- **Shop**: spend gold on randomized upgrades (bullet / player / enemy curses). Synergies are a design pillar. *(not in prototype yet)*
- **Next level**: repeat until 10 clears (run win) or death (enemy contact or own bullet).

## Win / lose
- **Level win**: all enemies dead.
- **Run win**: clear 10 levels.
- **Lose**: player dies from an enemy or from the bullet.

## The bullet
- Fired at the beginning of the level from the player's position (center bottom of the screen) after a **3s opening aim** window.
- Travels and bounces freely forever (perfectly elastic walls; constant speed).
- Damages enemies on hit; kills the player on contact.
- Speed should be slow enough to interact with (redirect) but fast enough that avoiding it is a challenge.
- Redirect: proximity + Space → 1.5s slow-mo → pick new direction. Brief post-launch grace so redirecting does not instantly kill the player. Limits (cooldown, charges, unlimited) are still open — see open questions.

## Input (prototype)
- **Move**: WASD
- **Redirect**: Space (when near the bullet)
- **Aim rotate**: A (counter-clockwise) / D (clockwise); mouse motion switches to mouse aim
- **Confirm aim early**: Space or left click (otherwise window auto-locks)
- **Restart**: R

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
- More enemy types planned later.

## Economy
- **Single resource**: gold (from enemy drops; may also come from breakables — open).
- Spent in the between-level shop on upgrades.

## Open questions / design tensions to resolve
- **Redirect limits**: cooldown, charges, or unlimited?
- **Gold vanish duration**: how long before dropped gold disappears?
- **Shop draft**: how many offers, rerolls, price scaling?
- **Powerup types**: what breakables drop, and how they stack with shop upgrades.
- **Camera / view**: side-view sprites in a top-down-ish arena; confirm long-term camera.
- **Difficulty curve**: how enemy count, obstacles, and layout pressure scale across 10 levels.
