# A Final Spell — Game Brief

## Summary
Arcade tavern roguelike. You are a **wizard** whose starting weapon is a **Blank Orb**. Each level starts with the **summoning circle** launching that orb in a **random direction** — it bounces forever, damages enemies on hit, and **hurts you on contact** (player has **3 HP** with brief i-frames after a hit). Steer it by getting close and **redirecting**; each redirect makes it faster and more damaging (to you and enemies). Clear the room; socket **glyphs** into orbs at the circle; survive **10 levels**.

## Story (current)
Very lean. You are a wizard defending yourself from various nefarious beings. No deeper plot required — the game is gameplay-first arcade.

## Player fantasy
Dodge your own orb while batting it at enemies. Risk the floor for glyphs. Build a run by socketing glyphs, upgrading Blank Orbs into specialist orbs, and chasing Attunements.

## Core loop
- **Level start (design)**: player stands center-bottom; **one Blank Orb** shoots from the **summoning circle** in a **random direction**. More orbs can be bought later. *(Prototype: player first **assembles in** over ~2 s via reverse pixel-fall, then **three typed orbs** (Ghost, Rot, Conduit) launch from the circle — no opening tether.)*
- **Combat**: orbs travel and bounce indefinitely after the opening launch. Enemies chase the player and deal **contact damage on a short tick** (~0.75s). Solid props and breakables bounce orbs; breakables are destroyed on that hit. Obstacles can interact further (e.g. TNT barrels explode). Enemies and obstacles drop **glyphs**.
- **Attack**: when the **closest** flying orb is within **48 px**, Attack **redirects** that orb along aim (mouse / right stick) — no melee arc, no enemy knockback; also **resets dash cooldown** and **+10%** speed/damage on that orb (stacks, speed capped at **1500**). Out of range, Attack does nothing (melee swing / knockback parked behind `AttackComponent.melee_enabled`). Movement stays unlocked during redirect; **locked while tethered**. Attack does not capture or release the orb. Redirect uses the ~0.35 s attack cooldown. Glyph throw still uses Attack while carrying.
- **Orb tether** *(capture parked for playtest)*: when a flying orb is within **48 px** (`focus_radius`), it shows an in-focus overlay (all in-range orbs); the **closest** also shows a **chevron chain** along the player's aim (three `>` marks outside the orb). Mid-combat steer is **Attack redirect** only (`OrbTetherComponent.capture_enabled = false` on the player — orbit capture / remote channel code kept dormant). Tether still **picks up glyphs** in focus range. Standing in the summoning circle `DepositArea` and pressing tether **activates** the circle (first activation free, then **5 / 10 / 15…** mana per use — sprite blink + rising arcane particles). While active, the **next orb** entering the circle is sucked in and opens the **ritual menu** (combat pauses). Capture/release/orbit path remains in code for later: spiral to **24 px**, second press or two revolutions to release, remote hold channel, +10% boost, world-solid break, time-slow vignette — not reachable while capture is off.
- **Dash**: press Space (or gamepad B) to dash **50 px** toward current facing (8 directions: N/S/E/W + diagonals). While dashing the player is immune to damage, phases through props/enemies, and cannot move or attack. Outer arena walls still block the dash. **4s** cooldown, shown as a small ring above the player's head (drawn by `DashComponent`); cannot start mid-swing or while **carrying a glyph**. A proximity **Attack redirect** clears the dash cooldown so the player can dash immediately after batting the orb.
- **Loot**: enemies (and, per source design, obstacles) roll **`glyph_drop`** from the killing orb (default **10%** per orb row; level fallback **25%**). Drops are one of **12 glyphs** (4 elements × 3 types) at **Common / Rare / Unique** rarity (default weights **70 / 25 / 5**). Pick up with **tether** in focus range. Carrying blocks dash; **Attack** throws the glyph. Deliver into the **summoning circle**: glyph is sucked to center and stored in circle inventory (**max 3**); overflow converts to mana (**5 / 10 / 20** by rarity). Orbs can destroy grounded glyphs (no inventory credit).
- **Clear**: kill all enemies → level win.
- **Ritual (in-level)**: activate the summoning circle (first use free, then **+5 mana** per use). The next orb that enters opens a paused menu: that orb's stats, **all current orbs** in a bottom inventory (focused orb highlighted), drag-and-drop glyph socketing / recycle (glyphs can also be pulled back off orb slots), Transform (when 3 glyphs match a playable recipe), buy a new Blank Orb (max **3** orbs). Circle inventory starts with one Common **Air** glyph (`static`).
- **Next level**: repeat until 10 clears (run win) or death (HP depleted by enemy contact or own orb).

## Win / lose
- **Level win**: all enemies dead.
- **Run win**: clear 10 levels.
- **Lose**: all players' HP reach 0 from enemy contact or the orb (co-op: one player dying leaves the others playing).

## Orbs
- **Design**: a **Blank Orb** enters play at level start from the summoning circle in a **random direction**, then travels and bounces freely forever. You start with **one** orb and can acquire more. Speed slow enough to interact but fast enough that avoiding it is a challenge. Speed and damage increase each time you redirect it.
- **Upgrade path (design)**: each orb has **3 glyph slots**. Socketing boosts one of the 12 attributes (value depends on Common / Rare / Unique). Three glyphs on a **Blank Orb** can upgrade it into one of **20** specialist orbs with special effects (Transform button; only enabled when the element combo maps to an authored orb with a scene). Three glyphs on a **non-Blank** orb can, with the right combination, trigger **Attunement**. After two glyphs are socketed, the menu shows hints of the **four possible** results (one per third element) — name if the recipe row exists (prototype treats all as discovered), `???` if no matching row.
- **Core stats** (all orbs; authored in GameData `orbs` sheet, loaded at runtime via `orb_id`): `damage` (enemy HP), `self_damage` (player HP), `splash` (% of resolved hit damage to others within **50 px**), `speed`, `weight` (knockback distance in px; bowling collisions deal **weight** damage to both enemies; breakables take **+5% damage per weight**), `crit_chance`, `crit_damage`, `glyph_drop` (glyph drop chance on kill), `burn`, `chill`, `shock`, `poison` (stacks applied on enemy hit only). Each orb has **3 glyph slots**; socketing applies flat-add upgrades from GameData `glyphs` rows (`attribute` column + rarity tier values).
- **Statuses** (enemy-only application from orb hits; all persist until death): **Poison** — 1 damage per stack per second; **Chill** — +5% move and attack-speed slow per stack (capped 90%); **Burn** — on death, explosion deals **5 × stacks** damage in **50 × (1 + 5% × stacks)** px radius (enemies only); **Shock** — at 10 stacks, stun **2 s**, deal **50** damage, clear stacks.
- **Prototype (playtest)**: player first assembles over ~2 s, then **three typed orbs** launch from the **summoning circle** center in **independent random directions** (`begin_flight`, with player instigator grace): **Ghost**, **Rot**, and **Conduit**. No plain blank orb is launched (`blank_orb.gd` / `.tscn` remain the shared `BlankOrb` base). All three persist and bounce for the rest of the level.
- Travels and bounces freely forever (perfectly elastic walls, rocks, and breakables; constant speed). Default playtest: **punches through** player and enemy bodies while still damaging them. Desert scene export **`bounce_orbs_off_entities`** (inspector on `desert.tscn`) toggles flying orbs to bounce off player/enemy bodies instead (`BlankOrb.bounce_off_entities`). Script owns bounce via contact normals (`_integrate_forces`); physics material bounce is 0 so the solver does not fight it.
- Damages enemies and player on hit based on the orb `DamageComponent` value (**10** impact for Rot/Conduit/player contact; Ghost skips impact HP on enemies). Player has brief i-frames after a non-fatal hit.
- **Ghost**: on enemy hit, **enters** the host (hidden `POSSESSED` state, not tetherable). Deals **3 DPS** while inside. Host uses a **dark damage flash** while possessed. On host death the orb reappears at the corpse and flies in a **random** direction (no player grace).
- **Rot**: on enemy hit, applies **Poison** stacks from GameData (`poison` stat, currently **3**). Poison ticks every **1 s** for damage equal to current stacks; stacks persist until the enemy dies.
- **Conduit**: while the closest player is within **130 px**, draws an electric **current** (Line2D + capsule Area2D). Enemies touching the current take **5 HP/s** and **3 Shock/s** (first tick on enter). At **10 Shock**, the enemy is **stunned 2 s**, takes **50** burst damage, and Shock clears. Current does not hurt the player; no wall LOS check. Impact hits also apply the orb's `shock` stacks from GameData.
- Mid-combat steer *(playtest)*: get within **48 px** of a flying orb — all in-range orbs show focus; the **closest** shows a chevron chain along aim. Press **Attack** to redirect the closest in-range orb along aim (no melee swing; **+10%** speed/damage via `tether_release_boost`, speed clamped to **1500**; resets dash cooldown; shares ~0.35 s attack cooldown). Orb **capture / orbit tether** is parked (`capture_enabled = false`); code kept. Flying orbs default to **punch through** player and enemy bodies (and each other) while still dealing damage; optional desert export `bounce_orbs_off_entities` enables entity bounce. Possessed Ghost orbs are not flying and cannot be redirected. Post-redirect grace lasts **1 s** (ghostly orb tint + shrinking halo; collision exception vs batter while grace runs). Arc-contact deflect of the orb is parked (code kept). Out-of-range Attack does nothing while melee is parked.

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
- Breaking some objects can drop **glyphs** (design); prototype breakables have a powerup hook only (drops not wired yet).
- `big_rock.tscn` (28×22 px) and `animal_skull.tscn` (16×16 px) are 3-HP breakables placed in `desert_2.tscn`.
- Obstacles can interact with the orb and environment (example: TNT barrel explosion — later).
- Enemy glyph drops vanish after a short time (exact duration TBD).

## Progression
- **During the level**, activate the **summoning circle** (first activation free, then **+5 mana** each time). The next orb that enters opens the **ritual menu**:
  1. **Socket glyphs** by dragging from the bottom glyph inventory into the focused orb's 3 slots (mouse hold-drag, or controller d-pad / left-stick **flick** to move focus — one slot per flick — / dash to grab → up to snap to slots → left/right across recycle and slots → dash to drop; tether cancels). Socketed glyphs can be **removed** (mouse-drag off the slot, or controller focus + dash — returns to inventory if there is space). Three on a Blank Orb → Transform into a specialist when the element combo is playable. Three on a non-Blank with the right combo → **Attunement** (Transform gated the same way once attunements have scenes). After two glyphs, show four possible result hints (`???` vs name).
  2. **Recycle** by dropping a glyph on the recycle socket: **5** Common / **10** Rare / **20** Unique mana.
  3. **Buy** a new Blank Orb for **20 mana**; price **+10** each purchase (prototype still flat 20). Cap **3 orbs** in play; Buy disabled at the cap.
- The menu shows an **inventory of all current orbs** at the bottom; the circle-captured orb stays in focus (display-only for the other sockets). D-pad can highlight orbs and other menu controls.
- Circle glyph inventory starts with one Common Air glyph (`static`). Mana label in the inventory bar updates live on deposit/spend.

## Enemies
- Two chaser enemies (`grunt_knife`, `brute`) **path around obstacles toward the player** and use local avoidance so packs spread instead of body-stacking, while still dealing **1 contact damage** on a ~0.75s tick once overlapping.
- Grunts and brutes use scene-authored HP (`grunt` **20 HP**, `brute` **50 HP**); orb hits chip them. Melee knockback is parked (`melee_enabled = false`). Brute HP/damage can be tuned on the scene.
- Enemies arrive in **authored waves** (`EnemySpawner`: count, types, delay between waves). Desert prototype: **3 grunts**, then **1 brute** after **6s** (waves can overlap if the first is not cleared in time). Each spawn telegraphs with a pulsing ground ring, then assembles over **~2s** by playing the destruction pixel-fall in reverse.
- Player attack does not knock enemies (melee dormant); Attack redirects orbs only.
- More enemy types planned later.

## Economy
- **Single resource**: **mana** (from recycling stored glyphs, overflow deposits, and future breakables — open).
- Spent at the summoning circle ritual (**20 mana** for a new blank orb, **+10** each purchase — prototype is still a flat 20; max **3** orbs).
- **Summoning circle** holds a level `mana_pool` (label shows the current total) and a **3-slot glyph inventory**. Glyphs destroyed by orbs do **not** enter inventory. **Activation** costs escalate: **0**, then **5**, **10**, **15…** mana (`activation_step × activation_count`). While active, the next orb entering opens the **ritual menu** (tree paused): view all 12 stats on the focused orb, drag-socket or recycle stored glyphs, Transform when a playable 3-glyph recipe matches, buy a **blank orb** (capped at 3 orbs), then **Done** releases the orb and deactivates the circle.

## Open questions / design tensions to resolve
- **Opening volley**: design now starts with **one Blank Orb** from the circle; prototype launches three typed orbs (Ghost / Rot / Conduit). Reconcile after playtest.
- **Tether feel**: design now specifies proximity **redirect** (matches playtest). Orbit capture remains parked (`capture_enabled`); restore to revisit spiral / two-turn release.
- **Attack cooldown / charges**: current cooldown is 0.35s on redirect; tether capture/release has its own short post-release cooldown (~0.25s). Melee swing parked.
- **Mana vs glyphs as floor loot**: source overview still says enemies drop **mana** that must be picked up quickly; the Glyphs / Progression sections make **glyphs** the drop and mana the recycle/overflow currency. Treat glyphs as authored loot unless the overview sentence is restored as a second drop.
- **Glyph vanish duration**: glyphs currently persist until deposited or orb-destroyed; should grounded glyphs still time out?
- **Glyph rarity weights**: default 70 / 25 / 5 Common / Rare / Unique on drop — tune after playtest?
- **Attunement discovery**: prototype treats every authored recipe name as discovered (`OrbRecipes.is_discovered` always true). Persistent / per-run registry still TBD.
- **20 specialist orbs / Attunement recipes**: `orbs` / `attunements` sheets hold element combos; only Ghost / Rot / Conduit are playable (`scene_path`). Missing combos show `???` and cannot Transform.
- **Camera / view**: player uses 4-direction diagonal sprites in a top-down-ish arena; confirm long-term camera for larger stages.
- **Difficulty curve**: how enemy count, obstacles, and layout pressure scale across 10 levels.
- **Arc deflect rollback**: `AttackComponent.deflect_orb_enabled` is false; proximity Attack redirect covers aim-steer without arc contact.
- **Entity bounce**: desert inspector export `bounce_orbs_off_entities` playtests punch-through vs bounce-off-entities; pick a default after feel tests.
- **Melee rollback**: flip `AttackComponent.melee_enabled` to restore swing sprite + enemy knockback.
