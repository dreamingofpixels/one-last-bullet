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
- **Status**: superseded — source design now starts with one **Blank Orb** from the circle and lets the player buy more (see below); prototype still uses a 3-typed opening volley

### Opening launch: one Blank Orb from the summoning circle
- **Decision (design)**: Each level starts with the **summoning circle** shooting **one Blank Orb** in a **random direction**. The player starts with that single orb and can **acquire more** later (buy from the ritual menu). Mid-combat steer is **proximity redirect** — each redirect raises that orb's speed and damage (to enemies and the player).
- **Why**: Source doc (`A Final Spell.txt`) dropped player free-aim and the between-level shop; the circle is both the opening beat and the upgrade station. One orb at start preserves the dodge-your-weapon hook; extra orbs are a purchased escalation.
- **Alternatives**: Player free-aim from center-bottom — previous source doc; three typed orbs at start (Ghost / Rot / Conduit) — current prototype, more room pressure but skips the Blank→specialist upgrade fantasy; tether-orbit then release — previous source steer; keep a between-level shop as a second upgrade layer — no longer in the source doc.
- **Status**: decided (design); prototype still launches Ghost / Rot / Conduit (see "Opening typed orb volley")

### Blank Orb → 20 specialist orbs; Attunement as a second upgrade
- **Decision (design)**: Socketing glyphs boosts one of the orb's 12 attributes (Common / Rare / Unique values). **Three glyphs on a Blank Orb** can upgrade it into one of **20** specialist orbs with special effects. **Three glyphs on a non-Blank orb** can, with the right combination, trigger **Attunement**. After **two** glyphs are socketed, the ritual menu shows hints of the **four possible** results: recipe **name** if the row exists (prototype always "discovered"), `???` if no matching row.
- **Why**: Gives Blank Orbs a craft identity and specialist orbs a further chase; the two-glyph hint teaches recipes without inventing names for missing data.
- **Alternatives**: Glyphs only ever flat-add stats — no orb identity change; auto-upgrade on any three glyphs without recipes — less discovery; show all recipe names immediately without a discovery seam — harder to add meta later.
- **Status**: decided (in-codebase) for Blank→specialist Transform when `scene_path` exists (Ghost/Rot/Conduit); Attunement Transform not playable yet (no scenes); full 20-orb table still incomplete

### Ritual menu: all-orb inventory; Blank Orb buy scales
- **Decision (design)**: The ritual menu shows info about the captured orb **and** an **inventory of all current orbs** at the bottom of the screen. **Buy a new Blank Orb** starts at **20 mana** and **goes up by 10** each purchase. Recycle is **5 / 10 / 20** mana for Common / Rare / Unique (already in prototype). Circle activation is first-use free, then **+5 mana** per use (already in prototype). Cap **3 orbs** in play.
- **Why**: Multi-orb runs need a way to see and choose among orbs without capturing each one first; escalating buy cost paces extra-orb snowball.
- **Alternatives**: Only show the captured orb — previous prototype; flat 20 mana forever — cheaper extra orbs late-run; a between-level shop instead of in-level buy — superseded (see shop entries).
- **Status**: decided (in-codebase) for inventory bar, recycle-by-drop, Transform, 3-orb cap, flat-20 buy; +10 buy scaling still planned

### Ritual menu v2: drag socketing, Transform, always-on discovery
- **Decision**: Replaced the button-row ritual UI with `ritual_menu.tscn` + bottom `OrbInventoryBar`. Glyphs move via **mouse hold-drag** or **controller** (dash grab → move_up snap to orb slots → move_left/right across `[recycle, slot0, slot1, slot2]` → dash confirm; tether cancels). Focus stays on the circle-captured orb. After **2** socketed glyphs, four hints appear (one per third element) from `OrbRecipes` over GameData `orbs` / `attunements`. **Transform** enables only when 3 glyphs match a row with a non-null `scene_path`; level swaps the captured orb via `SummoningCircle.swap_captured_orb` + `BlankOrb.assume_circle_capture`. Discovery is provisionally **always on** (`OrbRecipes.is_discovered` → true) so authored names show; `???` only for missing combos.
- **Why**: Matches the authored v2 layout; one drag model for mouse and pad; Transform gated on playable scenes avoids spawning broken orbs; discovery seam keeps meta-unlock work deferred.
- **Alternatives**: Godot `_get_drag_data` only — no pad path; selectable focus among all inventory orbs — deferred; Transform on any 3 glyphs / failed ritual — rejected; persistent discovery save — deferred.
- **Status**: decided (in-codebase)

### In-level ritual replaces between-level shop
- **Decision (design)**: Run progression is the **in-level summoning circle ritual** (glyphs, orb upgrades, Attunement, buying Blank Orbs). The source doc no longer has a post-level shop of randomized orb / player / enemy-curse upgrades.
- **Why**: Glyph socketing and orb identity already supply the synergy layer; a second shop would split the economy.
- **Alternatives**: Keep a between-level shop as an additional layer — previous source doc; shop-only upgrades with no in-level ritual — weaker circle fantasy.
- **Status**: decided (design); shop entries below are superseded. Multi-level run structure (10 clears) is unchanged.

### Opening 3-orb launch from summoning circle
- **Decision**: At level start the player assembles in (~2 s), then **three** chaos orbs launch from the **summoning circle** `DepositArea` origin in **independent random directions** via `begin_flight(dir, player)`. No opening tether; mid-combat tether release stays a single orb. Player instigator grace still applies so assemble→launch does not instantly kill.
- **Why**: Ties the opening beat to the circle / mana fantasy; random fan creates immediate room pressure without teaching a separate sling shot; keeps the 3-orb playtest density.
- **Alternatives**: Opening tether + ±20° volley-on-release — previous; player free-aim from center-bottom — previous source doc, no longer current; single orb from circle — now the source design; shared random angle + spread — more readable but less chaotic.
- **Status**: superseded — replaced by typed Shadow/Poison/Electric opening volley (see below)

### Opening typed orb volley (Ghost / Rot / Conduit)
- **Decision**: Level start launches **one Ghost**, **one Rot**, and **one Conduit** orb from the summoning circle in independent random directions (`begin_flight`, player grace). No plain blank orb is spawned. `blank_orb.gd` / `.tscn` remain the shared `BlankOrb` base (`class_name`, `FLYING` / `TETHERED` / `POSSESSED`). Typed scenes tint `blank_orb.png` and override hit hooks where needed (Ghost possession). Each orb loads **12 core stats** from GameData via `orb_id`. Enemies own a `StatusComponent` for Poison, Shock, Burn, and Chill. Ghost follows its host in world space (not reparented) so enemy `queue_free` cannot free the orb. Conduit current is a `Line2D` + enemy-mask capsule `Area2D` while the closest player is within 130 px.
- **Why**: Same 3-orb room pressure with readable elemental fantasies; shared bounce/tether/redirect code stays on BlankOrb; status lives on victims so multiple sources can stack later.
- **Alternatives**: Keep three identical chaos orbs — no type fantasy; add three typed orbs on top of chaos (6 total) — too dense for the arena; per-orb timers instead of StatusComponent — duplicates DoT/stun logic; parent Shadow into the enemy — orb dies with host teardown; raycast-only current without Area2D — harder to tick continuous overlap cleanly; **one Blank Orb at start** — current source design (see "Opening launch: one Blank Orb").
- **Status**: decided (in-codebase); playtest — source design now wants one Blank Orb at start

### Orb folder layout and class rename (`entities/orbs/`)
- **Decision**: Orbs live under `project/entities/orbs/` with one subfolder per type: `blank/` (shared `BlankOrb` base), `ghost/`, `rot/`, `conduit/`. Shared SFX in `orb_sfx/`. Typed `class_name`s are `GhostOrb`, `RotOrb`, `ConduitOrb` (all extend `BlankOrb`). The old `ChaosOrb` class name and `entities/chaos_orb/` path are retired.
- **Why**: Clearer per-type organization as more orb variants are added; `BlankOrb` matches the neutral base scene; Ghost/Rot/Conduit names match the current design vocabulary.
- **Alternatives**: Keep flat `chaos_orb/` with Shadow/Poison/Electric names — mismatched with current art/naming; rename only paths but keep `ChaosOrb` class — conflicts with blank-base fantasy.
- **Status**: decided (in-codebase)

### Poison stacks persist (no decay)
- **Decision**: Poison stacks stay on the enemy until death. Each tick deals damage equal to current stacks every **1 s**; extra stacks do not reset the timer.
- **Why**: Repeated Poison orb hits should snowball into a lasting curse, not a fading DoT that needs babysitting.
- **Alternatives**: Remove 1 stack per tick (previous) — weaker investment and harder to read as committed poison; expire after a wall-clock duration — another clock besides the tick; reset the tick timer on add — delays damage already in progress.
- **Status**: decided (in-codebase)

### Opening 3-orb spread volley (playtest)
- **Decision**: Level start still uses a **single** opening tether. On that tether's first launch (`launched`), the level spawns **two** extra orbs at the same position flying at **±20°** from the release tangent (tunable `opening_volley_spread_degrees`). All three persist and bounce for the rest of the level. Mid-combat tether release stays a **single** orb (no extra volleys). `OrbTetherComponent` targets the `orb` group: focus all in range, tap-capture / remote-channel the **closest** flying orb, **one tether at a time**. Extras enter via `BlankOrb.begin_flight()` (grace + FLYING, no opening tether).
- **Why**: Cheap way to try multi-orb chaos without rewriting opening UX; volley-on-release keeps the sling lesson; group-based tether avoids hard-wiring three NodePaths.
- **Alternatives**: Three independent opening tethers — heavier UX; start with three already flying — skips the sling teach; only one tetherable "main" orb — simpler but weaker multi-orb play; extras despawn after a timer — less room pressure.
- **Status**: superseded — replaced by circle random launch (see above)

### Glyphs replace mana crystals; carry, throw, circle inventory
- **Decision**: Enemies (and, per source design, obstacles) roll **`glyph_drop`** from the killing orb (GameData `orbs` row; level fallback export). On success, spawn a **`Glyph`** (one of 12 ids from GameData `glyphs`, weighted **Common 70% / Rare 25% / Unique 5%**). Same carry/throw/deposit flow as crystals: tether pickup in focus, Attack throw, dash blocked while carried, **20 HP** orb-destroyable. Deposit into `SummoningCircle`: suck to center → **`receive_glyph`** stores `{id, rarity}` in a **3-slot** inventory; overflow credits mana (**5 / 10 / 20**). Element icon from four PNGs (`fire/water/air/earth_glyph.png`); rarity tint (white / blue / gold). `ManaCrystal` retired.
- **Why**: Glyphs are the upgrade vector for the ritual menu; mana comes from discard/overflow rather than every pickup.
- **Alternatives**: Keep crystals as mana and add separate glyph drops — two loot types to juggle; auto-socket on deposit — removes ritual menu choice.
- **Status**: decided (in-codebase)

### Summoning circle ritual: escalating activation, orb capture, paused menu
- **Decision**: `try_activate()` is repeatable: cost **`activation_step × activation_count`** (default step **5** → first activation **free**, then 5, 10, 15…). While active, first flying **`BlankOrb`** entering `DepositArea` is sucked to center → **`ritual_started`** → **`RitualMenu`** opens with **`get_tree().paused = true`**. Menu shows orb **12 stats**, drag-socket / recycle glyphs, **Transform** (playable recipes), **Buy Blank Orb** (flat 20 mana, max 3 orbs), bottom **orb inventory**, **Done**. Socketing flat-adds the glyph's `attribute` value from GameData by rarity. **Done** → `release_orb` (random launch) + `deactivate`. `AudioManager` uses `PROCESS_MODE_ALWAYS` so SFX still play while paused.
- **Why**: Separates mana delivery (inventory) from orb customization (ritual); pause keeps menu readable in co-op chaos.
- **Alternatives**: Real-time menu — orb and enemies keep moving; one-shot 5-mana activate — no escalating cost; button Socket/Discard rows — superseded by ritual menu v2 drag model.
- **Status**: decided (in-codebase); +10 buy scaling still planned

### Glyph stat upgrades: flat-add from GameData `attribute`
- **Decision**: Each `glyphs` row names an **`attribute`** (`damage`, `burn`, `glyph_drop`, etc.). Socketing adds **`rarity_common` / `rarity_rare` / `rarity_unique`** flat to that stat. `splash`, `crit_chance`, `glyph_drop` clamp to **0–1**; `damage`, `self_damage`, `speed`, `weight` floor at **0**. Negative values in data (e.g. `soft`, `drag`) reduce stats as authored.
- **Why**: Matches spreadsheet authoring; one code path for all 12 glyphs.
- **Alternatives**: Percent-of-base multiplier — rejected after data moved to absolute adds for core stats.
- **Status**: decided (in-codebase)

### Mana crystals: carry, throw, deposit into summoning circle
- **Decision**: Enemies have a **25%** chance to drop a `ManaCrystal` (default **5** mana, **20** HP). Tether within `focus_radius` picks up a crystal **before** capturing an orb. While carried: shown beside the player, dash disabled, Attack throws along aim (slide + sprite bounce, then settle). Pickup plays shared `item_picked_up` SFX. If a crystal enters the summoning circle `DepositArea` (including while carried), it detaches, freezes, and **sucks to the circle center** (cubic ease-in); on arrival it credits `SummoningCircle.mana_pool`, plays `mana_crystal_deposited`, then `DestroyComponent.self_destroy(false)` (pixel-fall, no generic destroy SFX). Orb hitbox damage can destroy crystals; that path does **not** credit the pool and still uses the default destroy SFX. Crystals use physics layer `item` (world mask only) so orbs punch through via hitbox rather than bouncing.
- **Why**: Makes mana a spatial risk (orb can smash loot; must deliver to the circle) and reuses tether/attack verbs without a new input. Suck-in makes the deposit readable; splitting pickup vs deposit SFX keeps item pickup generic for future loot.
- **Alternatives**: Auto-collect vanishing mana orbs — less skill; walking into crystals — weaker than tether priority; crystals on `world` layer (orb bounce) — turns loot into pinball obstacles; instant deposit `queue_free` — previous, no suck/VFX; reuse pickup clip for deposit — less feedback that mana reached the pool; vanish timer — deferred (open question).
- **Status**: superseded — replaced by glyph drops + circle inventory (see "Glyphs replace mana crystals")

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

- **Status**: superseded — replaced by glyph drops + circle inventory (see "Glyphs replace mana crystals")

### Summoning circle activation ritual
- **Decision**: `SummoningCircle` shows `mana_pool` on `%ManaPoolLabel` (updates on `deposit` / `spend`). `DepositArea` masks player + item. Standing in the circle and pressing tether calls `try_activate()`: spends **5** mana once, then blinks the sprite and emits rising `%ArcaneParticles`. Already-activated or unaffordable presses fall through to crystal pickup. Group `summoning_circle`; further ritual effects TBD.
- **Why**: Makes the pool readable and gives tether a circle verb while orb capture is parked; 5 mana matches one crystal deposit so activation is one-crystal commit.
- **Alternatives**: Auto-activate when pool ≥ 5 — less intentional; spend on Attack instead — competes with redirect; deactivate / toggle — deferred until ritual content exists.
- **Status**: superseded — replaced by escalating activation + ritual menu (see "Summoning circle ritual")

### Proximity Attack redirect (chevron chain + dash reset)
- **Decision**: While a flying orb is within `focus_radius` (48 px), the **closest** in-range orb shows `%AimArrow` as **three pulsing chevrons** outside the orb body along the player's aim (`aim_arrow.gd`, start ~12 px). Pressing **Attack** then calls `BlankOrb.deflect()` along that aim — **no melee swing**, no enemy knockback. Each redirect multiplies that orb's `speed` and `DamageComponent.damage` by `tether_release_boost` (default **1.1 / +10%**), stacking for the rest of the level; `speed` is clamped to `max_speed` (**1500**). The same Attack also calls `DashComponent.reset_cooldown()` so the player can dash immediately. Shares the normal **0.35 s** attack cooldown (`AttackComponent.consume_cooldown()`). Redirect works even during the short tether recapture cooldown. Multiple in-range orbs still all get `OrbInFocus`; only the closest gets the chevrons and is redirected. Out of range (or while tethered/channeling), Attack does nothing while melee is parked. Arc-contact `deflect_orb_enabled` stays false.
- **Why**: Tiny internal arrow was clear but cramped; a through-orb particle stream was muddy. Chevrons sit outside the sprite so direction is readable without covering the orb; pulse sells “pending launch” without fighting the trail.
- **Alternatives**: Tiny in-body arrow — previous, ugly at 8 px; GPU particle stream — previous, weak directionality; dashed Line2D ray — deferred; ghost bounce path — more work; re-enable arc-contact deflect — couples melee with orb hits; redirect every in-range orb — chaotic with the 3-orb volley.
- **Status**: decided (in-codebase)

### Playtest toggle: bounce orbs off entities
- **Decision**: Desert root `@export bounce_orbs_off_entities` (default off on `desert.tscn`) sets `BlankOrb.bounce_off_entities` in `level.gd` `_ready`. When on, flying orbs add player + enemy layers to their rigid-body mask and bounce via existing `_integrate_forces` normals. When off, mask is world-only (punch-through). Player/enemy body masks do **not** include the orb layer (characters still walk through orbs). Entity HP stays on hitbox poll; `_on_body_entered` skips player/enemy damage to avoid double-hits. Post-redirect grace adds a collision exception vs the batter. Ghost re-emergence and new spawns read the static flag.
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
- **Decision**: Whenever the orb enters `TETHERED` state (including the opening sling at level start), `Engine.time_scale` ramps from its current value down to **0.5** over **0.3 real-world seconds** via a `Tween` set to `ignore_time_scale`. It holds at 0.5 until the orb leaves `TETHERED` (intentional release, forced break, or opening launch), then snaps back to 1.0. A `TimeSlowOverlay` `CanvasLayer` owns the tween and drives a `time_slow.gdshader` shader uniform (`intensity` 0 → 1) in sync, producing a dark-edge vignette with a purple-blue tint. The overlay is a `CanvasLayer` child of HUD in `desert.tscn`; `level.gd` connects orb `tethered` / `tether_released` / `launched` to `begin()` / `end()`.
- **Why**: Slowing time during the tether gives the player a meaningful window to judge the orbit and plan the release angle without removing the spatial/positional commitment. The vignette makes the slow state immediately readable. A real-world ramp avoids the instant cut from the previous aim-window approach; snapping back on release makes the sling feel punchy.
- **Alternatives**: Scaled-delta ramp — window stretches as time already slows, so 0.5 s becomes 1 s of game time; keep full speed during tether — loses the "deliberate sling" feel; per-player time scale (Godot does not support it natively) — not viable; fade out on release instead of snap — tested as slower and less punchy; shader-only overlay without actual slow — visual only, less impactful.
- **Status**: decided (in-codebase)

### Level start: opening tether instead of slow-mo aim
- **Decision**: At level start the player first assembles in over ~2 s using reverse `pixel_fall` (`DestructionEffect.play_assemble_from_sprite`), then **one** orb appears already tethered **24 px above** the player (`begin_opening_tether`). Tether (or two full revolutions) releases it along the tangent into `FLYING`. Opening release emits `launched` and does **not** apply the +10% tether boost; `level.gd` then spawns two extras at ±spread (`begin_flight`). `OpeningAimComponent`, the Aim state, and the old free-aim global slow-mo are removed. `OrbTetherComponent.bind_orb()` is only for the opening sling; mid-combat uses the `orb` group. The opening tether now triggers the same 50%/0.5 s time-slow as mid-combat captures (see tether time-slow entry above). `level.gd` starts `EnemySpawner` and the player intro from the same post-nav-ready moment, so enemy telegraphs run while the player is assembling and the tether begins as that intro finishes.
- **Why**: One tether UX for start and mid-combat; teaches capture/release immediately; adding a short player assemble gives the same material language as enemy spawns and avoids visible pop-in while nav bake settles. Letting enemy telegraphs start at the same time preserves the original room pressure timing instead of delaying wave pacing behind the intro.
- **Alternatives**: Keep 3s slow-mo free aim — separate system and co-op time_scale issues; player free-aim-and-fire at start — previous source doc, no longer current; auto-launch upward without tether — skips the core sling lesson; apply boost on opening release — unfair free power on every level start; keep player visible instantly while only enemies assemble — less coherent spawn language and more start-of-level pop-in; delay enemy spawns until after assembly — cleaner intro staging, but pushes combat pacing later than intended.
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
- **Decision**: The game is titled **A Final Spell**. Code, scenes, groups, and physics layer names use **orb** / **BlankOrb** (not bullet).
- **Why**: The fantasy is one remaining spell, not a gun; the old title no longer matched the orb-of-chaos loop.
- **Alternatives**: Keep "One Last Bullet" — mismatches wizard/orb fantasy; "Tavern Roguelike" — genre label, not a title; "Orbital" / "Chaos Orb" puns — less clear about the one-spell hook.
- **Status**: decided (in-codebase)

### Wizard fantasy; Blank Orb (replaces sheriff / one bullet)
- **Decision**: Player is a **wizard** whose starting weapon is a **Blank Orb**. Setting is **tavern roguelike** with varied stages/environments, not a western sheriff defending a saloon. More orbs can be acquired during the run.
- **Why**: Design doc refocused on magic arcade survival; proximity redirect of a dangerous orb is the core hook, not gun fantasy.
- **Alternatives**: Keep sheriff + bullet western theme — superseded by design doc; generic fantasy mage with many spells from the start — dilutes the opening scarcity; one orb of chaos forever — previous source scarcity, now extra orbs are purchased.
- **Status**: decided (design); prototype still uses a desert arena

### Mana drops vanish if not picked up quickly
- **Decision**: Enemies drop **mana** that disappears after a short window. Mana is spent in the between-level shop.
- **Why**: Creates risk/reward: leave safe space to grab loot while the orb and enemies threaten; mana fits the wizard fantasy.
- **Alternatives**: Permanent mana until leave — less tension; auto-collect — removes the skill beat; gold currency — superseded (western theme dropped).
- **Status**: superseded — glyphs are the authored floor loot; mana comes from recycle/overflow. Source overview still mentions vanishing mana drops (open tension).

### Run structure: clear level → shop → repeat; 10 levels to win
- **Decision**: Clear all enemies to finish a level; shop between levels; win the run after 10 clears. Death ends the run.
- **Why**: Classic roguelike cadence with a defined climax length.
- **Alternatives**: Endless mode only — no climax; shorter runs — less room for synergy builds.
- **Status**: superseded — source design now uses in-level ritual for upgrades; 10-level run structure still stands

### Shop upgrades: orb / player / enemy curses; synergies matter
- **Decision**: Between-level shop offers randomized upgrades that improve the orb, the player, or curse enemies. Synergies are intentional fun.
- **Why**: Keeps runs distinct and rewards build-crafting without a huge combat ruleset.
- **Alternatives**: Fixed upgrade tree — less replay discovery; only player buffs — thinner fantasy.
- **Status**: superseded — source design dropped the between-level shop in favor of in-level ritual (glyphs / orb upgrades / Attunement)

### Minimal story; gameplay-first arcade
- **Decision**: Story is lean (wizard defending against nefarious beings). No deep narrative required for v1.
- **Why**: Focus production on the orb / glyph / ritual loop.
- **Alternatives**: Heavy campaign narrative — distracts from the arcade core.
- **Status**: decided (design); supersedes sheriff/saloon story

### Varied stages with randomized enemies, obstacles, and breakables
- **Decision**: Stages use **different environments** (tavern is one option) with randomized enemies/obstacles; obstacles can interact with the orb (e.g. TNT); rocks can be broken; enemies **and obstacles** drop **glyphs**.
- **Why**: Variety and environmental play without locking to one room type.
- **Alternatives**: Saloon-only stages — superseded; static hand-authored only levels — less replay; pure empty arenas — less toy potential; breakables drop generic powerups — previous source doc, replaced by glyph drops.
- **Status**: decided (design); prototype currently has two desert arenas (`desert.tscn`, `desert_2.tscn`)

---

## Open design tensions

- **Opening volley**: source design starts with **one Blank Orb** from the circle; prototype launches Ghost / Rot / Conduit. Reconcile after playtest.
- **Tether feel**: source design now specifies proximity **redirect** (matches Attack-only playtest). Orbit capture remains parked (`capture_enabled`); entity punch-through is the default (desert export can enable bounce).
- **Attack cooldown / charges**: redirect cooldown 0.35s; tether post-release cooldown 0.25s; melee parked.
- **Mana vs glyphs as floor loot**: source overview still says enemies drop vanishing **mana**; Glyphs / Progression sections make **glyphs** the drop and mana the recycle/overflow currency.
- **Glyph vanish duration**: glyphs currently persist until deposited or orb-destroyed; should grounded glyphs still time out?
- **Attunement discovery**: prototype treats authored recipe names as discovered (`OrbRecipes.is_discovered` always true). Persistent / per-run registry still TBD.
- **20 specialist orbs / Attunement recipes**: `orbs` / `attunements` sheets hold element combos; only Ghost / Rot / Conduit are playable (`scene_path`). Missing combos show `???` and cannot Transform.
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
- **Decision**: Every successful `HealthComponent.take_damage` spawns a detached world-space number (`DamageLabelEffect` → `damage_label.tscn`) at the owner, parented to `current_scene` so killing blows still show after `queue_free`. Uses `pixel_medium.fnt` at size 8; rises ~20 px over 1 s and fades in the last 0.3 s (`ignore_time_scale`). `DamageKind` selects color: **STANDARD** white (default), **POISON** green (poison DoT ticks only), **SHADOW** black (Ghost possession DPS + Ghost `DamageComponent`). Black numbers use a light outline for readability on dark possessed sprites; white/green use a dark outline. Callers pass the kind (`StatusComponent` → POISON, `GhostOrb` possession → SHADOW, `DamageComponent.damage_kind` on hitbox/orb breakable paths); Rot orb impact stays STANDARD so hit vs tick stay distinct.
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

### Hot-join local co-op via joypad connection

- **Decision**: When **two or more** gamepads are connected (`Input.get_connected_joypads().size() >= 2`), `level.gd` instances `player.tscn` with `player_index = 2` immediately (no join button), places it near P1 on a physics-clear offset, and runs `begin_level()` **in parallel** with P1 so both reverse-assemble together. Mid-level plug-in still hot-joins via `Input.joy_connection_changed`. Cap is `MAX_PLAYERS = 2` until `_3`/`_4` actions exist. Scene reload (`R`) rescans pads so P2 returns without a PlayerManager autoload. Opening orb volley still uses P1 as instigator; all living players get `HealthComponent.start_invulnerability(1s)` so P2 is not instantly killed by the circle launch.
- **Why**: Matches "plug in a second pad and play" arcade co-op; existing `_2` input map and `player_index` export already support it; assembling together keeps the intro beat shared instead of making P2 a late arrival.
- **Alternatives**: Level-start-only scan — misses mid-session join; press-to-join on Attack/Start — extra UX step; wait until after P1 assembles before spawning P2 — previous, felt like a join prompt; PlayerManager autoload for restart persistence — unnecessary while reload rescans; spawn P2 instantly without assemble — pop-in and free hitbox risk.
- **Status**: decided (in-codebase); P3/P4 deferred

### Run ends when all players are dead

- **Decision**: `_on_player_died` drops that player's carried crystal and only sets game-over when `Players.count()` reaches 0. A downed player stays out for the rest of the level (no revive). Status label shows "P# down — N left" while survivors remain.
- **Why**: Co-op should not end the run on the first death; matches local arcade "last player standing" feel without adding a revive system yet.
- **Alternatives**: Any player dying ends the run (previous single-player behavior) — too harsh for two players; downed/revive by partner — deferred until co-op is proven.
- **Status**: decided (in-codebase)

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
- **Decision**: `BlankOrb` is a `RigidBody2D` with a circular body shape (**world-only** mask by default; flying can also mask player + enemy when `bounce_off_entities` is true), locked rotation, gravity 0, friction 0, **bounce 0** material, continuous CCD, `can_sleep` off, and constant-speed flight. All reflection is owned by `_integrate_forces`: inbound contact normals are summed, then `aim_direction` reflects **once** off that combined normal (only when moving into the surface), then `linear_velocity = aim_direction * speed`. `_physics_process` does **not** re-derive direction from solver velocity. World bounce SFX and breakable damage use `body_entered`. Player/enemy damage uses the orb's `HitboxComponent` Area2D via victim hitbox polls (punch-through or bounce; body-entered skips entity HP to avoid double-hit). Tether probes use the same world-only mask. Post-launch grace adds a collision exception vs the batter so entity bounce does not immediately rebound off the redirecting player.
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

### Game data: Excel → JSON via schema sheet + generic GameData autoload
- **Decision**: `GameData` autoload loads JSON at startup. **`BlankOrb`** loads 12 core stats from `orbs` via `orb_id`; **`Glyph`** reads `glyphs` rows for `attribute` + rarity values; **`apply_glyph`** on orbs uses the same sheet. Glyphs/motion UI partially wired (motion not yet).
- **Why**: One spreadsheet source of truth for orb tuning and upcoming shop/glyph layer; same pipeline as TavernRPG without copying domain-specific parsers; generic lookup keeps new sheets free without autoload changes.
- **Alternatives**: Per-stat `.tres` Resources — drifts from the workbook; generate `.tres` from Excel — extra tooling; hard-coded `get_orb()` / `get_glyph()` on the autoload — new sheet = code change; inline `Dictionary` in GDScript — no designer-facing Excel; scene-only HP/damage — no single balance sheet.
- **Status**: decided (in-codebase); motion integration planned

### Orb core stats and status effects
- **Decision**: All orbs share 12 core stats on `BlankOrb`, loaded from GameData (`glyph_drop` replaces `crystal_drop`). Per-hit resolution uses `damage` vs `self_damage`, optional crit roll (`crit_chance` × `crit_damage`), splash AOE (50 px), weight knockback + bowling (`weight` collision damage), weight bonus to breakables (`+5% per weight`), and status stacks on enemy hit (`burn` / `chill` / `shock` / `poison`). `HealthComponent.take_damage` accepts an optional `source` node; `last_damage_source` drives per-orb `glyph_drop` on enemy/breakable death. **Glyph slots**: 3 per orb; socketing flat-adds from GameData `glyphs.attribute` by rarity.
- **Why**: Centralizes orb tuning in data; one combat path for typed orbs via `BlankOrb` hooks; statuses live on victims for multi-source stacking later.
- **Status**: decided (in-codebase); statuses: Poison 1 dmg/stack/s; Chill 5% move+attack slow/stack (max 90%); Burn explodes on death; Shock stuns at 10 stacks for 2 s after 50 burst damage. All stacks persist until death.
