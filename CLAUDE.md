# SHOTGUN-FU — Project Rules for Claude

Action RPG in Godot 4. **The shotgun is the real main character.** Every system is
judged by one question: *does this make the shotgun feel better to hold?*

This file is the contract. If code and this file disagree, fix one of them in the
same commit — never leave them drifting.

---

## 0. Isolation (non-negotiable)

- This repo is SHOTGUN-FU only. Do **not** read from, copy from, or write to any
  other game or project repository (e.g. Spirited-Frozen-Fortress, the website
  repos). No shared code, assets, skills, or configs by copy-paste.
- Project skills live in `.claude/skills/` here and apply only here.
- Third-party code enters only as a pinned, vendored addon under `addons/`, with
  its license kept, and only after the user approves it.
- No external services, telemetry, or network calls from game code.

## 1. Stack

| Thing | Choice | Where pinned |
|---|---|---|
| Engine | Godot **4.5.1-stable** (standard, not .NET) | `tools/godot-version.env` |
| Language | GDScript, **fully typed** | `project.godot` warnings |
| Renderer | Forward+ | `project.godot` |
| Resolution | 480×270 internal, integer-scaled | `project.godot` |
| Physics | 60 ticks/s, Godot Physics 2D | `project.godot` |
| Tests | GUT 9.x (pending approval — not vendored yet) | `addons/gut/` |
| AI tooling | CLI-first (`godot --headless`). No MCP server in cloud sessions. | — |

Upgrading the engine = edit `tools/godot-version.env` + `project.godot`
`config/features`, run full validation, own commit, own checkpoint.

## 2. Architecture

```
src/
  core/        autoloads: Events (signal bus), Game (run state), Tuning (resource registry)
  components/  reusable node scenes: Health, Hurtbox, Hitbox, Grabbable, Knockback, LightFlicker
  player/      Player scene + state machine + states/
  weapons/     Shotgun (the protagonist), pellets, shell economy
  enemies/     enemy scenes, AI states, archetype resources
  combat/      hit resolution, hitstop, stagger, damage math (pure functions where possible)
  fx/          camera shake, hit flashes, muzzle lights, slow-mo, particles
  world/       rooms, spawners, props, lighting rigs
  ui/          HUD (shells, health), debug overlay
data/          .tres tuning resources (all numbers live here)
scenes/        top-level runnable scenes (boot, slice arena)
assets/        art/audio sources + imports (see pixel-art-pipeline skill)
tests/unit     GUT tests for pure logic
tests/smoke    headless scripted-input runs of real scenes
tools/         validation, install, checkpoint scripts
```

### Rules of composition
1. **Composition over inheritance.** Entities are a `CharacterBody2D` root plus
   component children. Max inheritance depth: 2 (e.g. `EnemyBase` → `Grunt`).
2. **Call down, signal up.** Parents call methods on children; children emit
   signals. Siblings never reference each other directly — the parent wires them.
3. **Global signals only through `Events`** and only for cross-system facts
   (`enemy_killed`, `player_damaged`, `shell_gained`). Not for local plumbing.
4. **Explicit state machines** for Player and every enemy. One state = one script
   in `states/`. States own `enter()`, `exit()`, `physics_update(delta)`,
   `handle_input(event)`. No boolean soup (`is_dodging && !is_grappling ...`).
5. **Data-driven tuning.** Every gameplay number (damage, frames, speeds, spread,
   knockback) lives in a `Resource` under `data/`. Code references the resource.
   A literal number in gameplay code is a review failure unless it's 0, 1, or a
   math constant.
6. **Frame-based combat timing.** Startup/active/recovery, i-frames, and hitstop
   are counted in physics ticks (60/s), never in wall-clock seconds or `_process`.
7. **Pure combat math.** Damage, knockback vectors, spread patterns, stagger
   thresholds live in static functions in `src/combat/` so they're unit-testable
   without a scene tree.
8. **Collision layers are fixed** (see §5). Never repurpose a layer.

## 3. Design pillars

1. **The shotgun is the protagonist.** It has weight, personality, and the
   loudest feedback in the game. Every verb routes through it — you shoot with it,
   strike with its stock, it's what you're protecting.
2. **Close range is the safe range.** The shell economy rewards aggression:
   melee and throws refill shells; hanging back starves you.
3. **Every hit is felt.** Hitstop, shake, flash, light pulse, sound — on every
   connect, scaled by impact. No silent hits.
4. **Readable chaos.** Pixel clarity first. Enemy tells read against the darkest
   background. Neon is lighting, not noise.
5. **Fair cinematic.** Slow-mo and camera moves are rewards for skill
   (perfect dodge, multi-kill), never interruptions to control.

## 4. Development rules

- **No gameplay without a spec.** New mechanics start as an entry in
  `docs/vertical-slice.md` (or a new doc) with "done when" assertions.
- **Typed GDScript everywhere:** `var speed: float = 120.0`,
  `func hit(dmg: int) -> void:`. Untyped declarations are errors in `project.godot`.
- **Naming:** `snake_case.gd` files, `PascalCase` `class_name`, `snake_case`
  methods/vars, `SCREAMING_CASE` consts, signals in past tense (`died`, `shell_spent`).
- **One script, one job.** >300 lines is a smell; split it.
- **`@export` for designer knobs, `@onready` for node refs.** No `get_node()`
  with string paths deeper than one level; use `%UniqueName`.
- **Never edit `.godot/`, `*.import` by hand.** Don't commit `.godot/`.
- **Scenes are text (`.tscn`) and diff-reviewed.** Keep them small; sub-scene
  instead of growing one giant scene.
- **Tests:** combat math and state transitions get unit tests in the same commit.
  Each slice verb gets a smoke test before it's called done.
- **Debug tools ship behind `OS.is_debug_build()`** (hitbox overlay, frame stepper,
  tuning hot-reload).

## 5. Collision layers

| # | Name | Used by |
|---|---|---|
| 1 | world | walls, floor, props |
| 2 | player | player body |
| 3 | enemy | enemy bodies |
| 4 | player_hitbox | pellets, stock strike, thrown body |
| 5 | enemy_hitbox | enemy attacks |
| 6 | player_hurtbox | player hurtbox |
| 7 | enemy_hurtbox | enemy hurtboxes |
| 8 | grabbable | grab detection |
| 9 | projectile_block | things pellets stop on |

## 6. Validation & checkpoints

Single entry point: `tools/validate.sh`.

```
tools/install_godot.sh        # one-time: fetch pinned Godot, verify SHA-512
tools/validate.sh             # fast: import + load every script/scene/resource
tools/validate.sh --full      # fast + GUT unit tests + smoke runs
tools/checkpoint.sh <name>    # full validation, then annotated tag checkpoint/<date>-<name>
git config core.hooksPath .githooks   # enable pre-commit (fast validation)
```

Rules for Claude:
- Run `tools/validate.sh` before every commit; `--full` before every push.
- **Never commit red.** If validation fails, fix it or don't commit.
- **Never** `--no-verify`, skip, or delete a test to get green.
- Commit small: one logical change per commit, message says *why*.
- Tag a checkpoint at each milestone in `docs/vertical-slice.md`. Tags are pushed
  only when the user asks.
- If Godot isn't installed in the session, say so plainly — don't claim validation ran.
  CI (`.github/workflows/validate.yml`) is the authoritative gate.

## 7. Skills

| Skill | Load when |
|---|---|
| `godot-gameplay` | writing/structuring any GDScript, scene, state machine |
| `gunfu-combat` | touching any verb, hit, enemy reaction, game-feel effect |
| `pixel-art-pipeline` | importing/authoring sprites, palettes, normal maps, lighting art |
