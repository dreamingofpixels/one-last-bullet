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
- **Decision**: Get close to the bullet, press a button, time slows briefly, player picks a new direction.
- **Why**: Gives agency without removing the skill of positioning and timing.
- **Alternatives**: Always-on aim control — removes tension; automatic wall-aim assist — too passive.
- **Status**: decided (design)

### Single basic enemy: chase + contact kill
- **Decision**: First enemy type is a chaser that kills the player on contact.
- **Why**: Simple pressure while the bullet/redirect loop is proven.
- **Alternatives**: Ranged enemies first — more systems before the core loop is solid.
- **Status**: decided (design)

### Gold drops vanish if not picked up quickly
- **Decision**: Enemies drop gold that disappears after a short window.
- **Why**: Creates risk/reward: leave safe space to grab loot while the bullet and enemies threaten.
- **Alternatives**: Permanent gold until leave — less tension; auto-collect — removes the skill beat.
- **Status**: decided (design); vanish duration TBD

### Run structure: clear level → shop → repeat; 10 levels to win
- **Decision**: Clear all enemies to finish a level; shop between levels; win the run after 10 clears. Death ends the run.
- **Why**: Classic roguelike cadence with a defined climax length.
- **Alternatives**: Endless mode only — no climax; shorter runs — less room for synergy builds.
- **Status**: decided (design)

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
- **Camera / view perspective**: top-down assumed from current assets; confirm.

---

## Technical decisions (from current codebase)

### Engine: Godot 4.7, Forward Plus, canvas_items stretch
- **Decision**: Godot project at `project/` uses Godot **4.7**, Forward Plus, `window/stretch/mode="canvas_items"` with `aspect="expand"`.
- **Why**: Matches the current `project.godot` scaffold.
- **Alternatives**: Different stretch modes — revisit when resolution/pixel art pipeline is locked.
- **Status**: decided (in-codebase)

### No autoloads, scripts, or main scene yet
- **Decision**: Defer autoloads, gameplay scripts, and `run/main_scene` until the first playable slice.
- **Why**: Project is asset/folder scaffolding only (`areas/level`, `entities/player`, empty `enemies/grunt`, empty `data/`).
- **Alternatives**: Premature architecture — avoid until bullet + player + one enemy exist.
- **Status**: planned
