# One Last Bullet — Game Brief

## Summary
Western saloon arcade roguelike. You are a Sheriff with **one bullet**. The run starts with that bullet fired into the room: it bounces forever, damages enemies on hit, and **kills you instantly** on contact. Steer it by getting close and redirecting; clear the saloon; spend gold on synergistic upgrades; survive **10 levels**.

## Story (current)
Very lean. You are a Sheriff defending your town's saloon from enemies. No deeper plot required — the game is gameplay-first arcade.

## Player fantasy
Dodge your own bullet while aiming it at enemies. Risk the floor for vanishing gold. Build a run from shop synergies that twist the bullet, you, or the enemies.

## Core loop
- **Level start**: player stands center-bottom; fires the one bullet in a chosen direction.
- **Combat**: bullet travels and bounces indefinitely. Enemies chase the player (contact kill). Obstacles can interact with the bullet and environment (e.g. TNT barrels explode). Breakables can drop powerups.
- **Redirect**: get close to the bullet, press the redirect button → brief time slow → choose a new direction.
- **Loot**: enemies drop gold that must be picked up quickly before it disappears.
- **Clear**: kill all enemies → level win.
- **Shop**: spend gold on randomized upgrades (bullet / player / enemy curses). Synergies are a design pillar.
- **Next level**: repeat until 10 clears (run win) or death (enemy contact or own bullet).

## Win / lose
- **Level win**: all enemies dead.
- **Run win**: clear 10 levels.
- **Lose**: player dies from an enemy or from the bullet.

## The bullet
- Fired at the beginning of the level from the player's position (design: center bottom of the screen) in any direction the player chooses.
- Travels and bounces freely forever.
- Damages enemies on hit; kills the player on contact.
- Speed should be slow enough to interact with (redirect) but fast enough that avoiding it is a challenge.
- Redirect: proximity + button → brief slow-mo → pick new direction. Limits (cooldown, charges, unlimited) are still open — see open questions.

## Stage
- Every stage is a saloon with **randomized** enemies and obstacles.
- Obstacles interact with the bullet and environment (example: TNT barrel explosion).
- Breaking some objects can yield powerups.
- Enemy gold drops vanish after a short time (exact duration TBD).

## Progression
- After each level, a **shop** sells randomized upgrades:
  - improve the **bullet**
  - improve the **player**
  - **curse** enemies
- Fun should come from discovering interesting synergies across those categories.

## Enemies
- For now: one basic enemy that **chases the player** and kills on contact.
- More enemy types planned later.

## Economy
- **Single resource**: gold (from enemy drops; may also come from breakables — open).
- Spent in the between-level shop on upgrades.

## Open questions / design tensions to resolve
- **Redirect limits**: cooldown, charges, or unlimited?
- **Gold vanish duration**: how long before dropped gold disappears?
- **Shop draft**: how many offers, rerolls, price scaling?
- **Powerup types**: what breakables drop, and how they stack with shop upgrades.
- **Camera / view**: top-down vs other perspective (assets lean top-down so far).
- **Input scheme**: move, aim/fire at start, redirect button, pickup.
- **Difficulty curve**: how enemy count, obstacles, and layout pressure scale across 10 levels.
- **Starting fire**: free aim at level start only, or also a fixed default direction?
