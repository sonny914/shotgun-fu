# Vertical Slice 01 — "One Room, One Shotgun"

**Goal:** one neon-lit arena where a 60-second fight shows the whole core loop and
is good enough to clip and post. If a feature doesn't serve that clip, it's out.

**Loop:** shoot → stagger → stock strike / grab → throw → refill shells → shoot.
Dodge threads through all of it.

Status: **spec only — no gameplay implemented.** Numbers are starting values; they
live in `data/*.tres` once implemented. Ticks are physics ticks at 60/s.

---

## Scope

**In:** player + shotgun, 5 verbs below, 3 enemy archetypes, 1 arena (~2×1 screens),
wave spawner (3 waves), HUD (shells, health), neon lighting rig, debug overlay.

**Out (explicitly):** RPG progression, inventory, dialogue, multiple rooms, save
system, menus beyond restart, audio beyond placeholder SFX, controller remapping UI,
story. RPG systems come *after* the slice proves the combat is fun.

## Controls (draft input map)

| Action | KB/M | Pad |
|---|---|---|
| `move_*` | WASD | Left stick |
| `aim` | Mouse | Right stick |
| `fire` | LMB | RT |
| `melee` | RMB / F | X / Square |
| `grab` | E | Y / Triangle |
| `dodge` | Space / Shift | A / Cross |
| `restart` (debug) | R | Select |

Top-down 8-direction movement with free 360° aim (assumption — confirm before M1).

---

## Verbs

### 1. Shotgun fire
- 2-shell tube (double-barrel feel), max carried 6. Fire spends 1.
- 7 pellets, 28° spread, seeded pattern with slight per-shot jitter.
- Pellet: hitscan-ish fast projectile, range ~96 px falloff to 0 damage at ~144 px.
- Recoil pushes player back 6 px; muzzle light spike (see Lighting).
- Frame data: startup 1 | active 1 | recovery 14 | dodge-cancel from tick 4.
- Empty: dry-click SFX + shell HUD flash; no auto-reload — shells come from the loop.
- Slow passive trickle: +1 shell every 4 s if at 0, so you're never soft-locked.

**Done when**
- [ ] Unit: `SpreadPattern.directions()` returns exactly N vectors, all within ±spread/2 of aim, deterministic for a given seed.
- [ ] Unit: damage falloff returns full at ≤96 px, 0 at ≥144 px, monotonic between.
- [ ] Smoke: firing at a dummy at 48 px with 2 shells → dummy takes ≥5 pellet hits, shells = 1.
- [ ] Smoke: firing at 0 shells emits `shell_empty` and spawns no pellets.

### 2. Stock strike
- Short-range arc (~28 px, 100°) in aim direction. Works at 0 shells.
- Damage 1, high stagger (breaks Grunt poise in 1 hit), knockback 160.
- **+1 shell on hit** (max once per strike).
- Frame data: startup 4 | active 3 | recovery 10 | dodge-cancel from tick 7.

**Done when**
- [ ] Unit: hit on a Grunt with full poise → Grunt enters `Staggered`.
- [ ] Smoke: strike connects → shells +1, hitstop of 6 ticks applied to attacker and target only (another enemy's position still changes during those ticks).

### 3. Grapple
- Grab a `Staggered` enemy (or any Grunt from behind) within ~20 px.
- Held enemy is a shield: enemy projectiles hitting it damage it, not you.
- Player move speed ×0.6 while holding. Can fire while holding (one-handed, spread 40°).
- Auto-drop after 3 s or when shield dies.
- Frame data: grab startup 3 | whiff recovery 12.

**Done when**
- [ ] Smoke: enemy projectile fired at player while holding a shield → shield HP decreases, player HP unchanged.
- [ ] Smoke: grab on a non-staggered Brute from the front → whiff, no state change on Brute.

### 4. Throw
- Release held enemy in aim direction at 380 px/s; it becomes a `player_hitbox`.
- Hits other enemies: damage 2 + stagger. Hits a wall: **wall splat** (damage 2, big hitstop).
- **+2 shells on impact** (enemy or wall, once per throw).

**Done when**
- [ ] Smoke: throw held Grunt into a second Grunt → both take damage, shells +2.
- [ ] Smoke: throw into wall → `wall_splat` tag in the emitted `hit_landed`, hitstop 8 ticks.

### 5. Dodge
- 0.2 s dash (~48 px), 10 i-frame ticks starting tick 1, then 8 recovery ticks.
- Cancels recovery of shoot/strike/throw after their active frames.
- **Perfect dodge:** an enemy hit would have landed in i-frame ticks 1–4 → 0.3 s slow-mo
  (`Engine.time_scale` 0.3), +1 shell, cyan flash. Cooldown 1.5 s on perfect-dodge reward.

**Done when**
- [ ] Unit: hit arriving on i-frame tick 3 → classified perfect; tick 6 → dodged but not perfect; tick 12 → hit lands.
- [ ] Smoke: dodge during stock-strike recovery tick 8 → dodge starts that tick.
- [ ] Smoke: perfect dodge → `Engine.time_scale` returns to 1.0 within 0.5 s real time.

---

## Enemies

All implement the reaction contract in the `gunfu-combat` skill.

| Archetype | HP | Poise | Weight | Behavior | Tell |
|---|---|---|---|---|---|
| **Grunt** | 4 | 1 | 1.0 | approaches, melee swipe | 20-tick windup, eyes flare magenta |
| **Shooter** | 3 | 2 | 0.8 | keeps ~120 px, fires slow bolt | 24-tick charge, barrel glows amber |
| **Brute** | 12 | 4 | 2.5 | slow, charge attack; can't be grabbed from front until staggered | 30-tick crouch, red floor light |

Waves: (1) 3 Grunts · (2) 2 Grunts + 2 Shooters · (3) 1 Brute + 3 Grunts + 1 Shooter.

---

## Cinematic neon lighting

- Arena: dark back-alley/club hybrid. `CanvasModulate` ≈ `#0d0a1a`.
- 3–4 neon signs (magenta, cyan, amber) with `PointLight2D` + `LightFlicker` (one
  sign buzzes and stutters).
- HDR 2D glow via `WorldEnvironment` (Canvas background, glow on).
- Normal-mapped player, enemies, walls so neon rims characters as they move.
- **Muzzle flash = key light:** `PointLight2D` energy spike 2–3 ticks, decays over ~6,
  warm white. Every shot relights the room for a beat.
- Hit flashes: 1–3 tick white `modulate` on target.
- Camera: trauma shake; slight punch-zoom (2%) on wall splat and kill.
- Slow-mo: perfect dodge and 3+ kills within 1 s only.

**Done when**
- [ ] Headless: arena scene loads, ≤ 12 `PointLight2D` nodes, glow enabled in its Environment.
- [ ] Visual (manual, real GPU): screenshot set — idle in room, mid-shot muzzle flash, wall splat, perfect-dodge slow-mo. Approved by the user.

---

## Milestones (each ends in a checkpoint tag)

| # | Milestone | Checkpoint |
|---|---|---|
| M0 | Tooling green in CI; GUT vendored; input map; debug overlay | `checkpoint/…-m0-tooling` |
| M1 | Player movement + aim + dodge (graybox) | `…-m1-move-dodge` |
| M2 | Shotgun fire + shell economy + Grunt dummy | `…-m2-shotgun` |
| M3 | Stock strike + stagger + hitstop/shake/flash | `…-m3-stock` |
| M4 | Grapple + throw + wall splat | `…-m4-grab-throw` |
| M5 | Shooter + Brute + 3 waves | `…-m5-enemies` |
| M6 | Neon lighting pass + slow-mo + HUD | `…-m6-neon` |
| M7 | Tuning pass → record the clip | `…-m7-slice` |

## Open questions (need the user)

1. Top-down free-aim (assumed) vs side-on? It changes movement, aim and art angles.
2. Does the shotgun have a voice/personality on screen (barks, UI face) in the slice, or later?
3. Target platform for the slice: desktop only, or web export too? Web pushes the renderer to Compatibility.
4. Art: who authors sprites — you, commissioned, or placeholder-only for the slice?
