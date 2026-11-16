---
name: gunfu-combat
description: SHOTGUN-FU combat design and game-feel rules — shotgun fire, stock strikes, grapple, throw, dodge, enemy reactions, hitstop, shake, slow-mo, shell economy, and frame data. Use before implementing or tuning any combat verb, hit reaction, enemy attack, or juice effect.
---

# Gun-Fu Combat (SHOTGUN-FU)

The shotgun is the protagonist. Combat is a close-range loop:
**shoot → stagger → strike/grab → throw → refill shells → shoot.**

Spec for each verb lives in `docs/vertical-slice.md`. This skill is the shared
grammar every verb follows.

## Frame data (60 ticks/s)

Every action is described as **startup / active / recovery** in ticks, plus
cancel windows. Write it in the tuning resource, and as a comment table:

```
# stock_strike: startup 4 | active 3 | recovery 10 | cancel→dodge from tick 7
```

Rules:
- Player startup ≤ 6 ticks for anything mapped to a face button. Responsiveness beats realism.
- **Dodge cancels recovery** of every player action after its active frames
  (not during startup). This is the core expressive tool.
- Enemy tells: ≥ 18 ticks of readable windup, with a light/color cue.
- Input buffer: 8 ticks. Coyote/late-press grace on grabs: 4 ticks.

## Hit resolution

One function decides everything: `HitResolver.resolve(hit: HitData, target: Hurtbox) -> HitResult`.

`HitData`: `damage`, `knockback` (Vector2), `stagger` (int), `hitstop_ticks`,
`tags` (`&"pellet"`, `&"stock"`, `&"thrown"`, `&"wall_splat"`), `source`.

Order of operations:
1. I-frames / invulnerability → ignore.
2. Apply damage via `Health`.
3. Add stagger to the target's poise meter; break poise → `Staggered` state (grabbable).
4. Apply knockback (scaled by target `weight`).
5. Emit `Events.hit_landed(result)` → FX layer reacts. **Gameplay never calls FX directly.**

## Feel budget (per hit type, starting values — tune in data/)

| Hit | Hitstop | Shake | Flash | Light pulse |
|---|---|---|---|---|
| Single pellet | 0 | — | 1 tick white | — |
| Full blast (≥4 pellets on one target) | 4 ticks | 0.25 | 2 ticks | muzzle light 1.6× |
| Stock strike | 6 ticks | 0.35 | 3 ticks | — |
| Throw impact | 5 ticks | 0.4 | 2 ticks | — |
| Wall splat | 8 ticks | 0.6 | 3 ticks | rim flash |
| Kill | +3 ticks on top | +0.1 | — | — |

- Hitstop freezes **attacker and target** only (per-entity `time_scale` / skip
  physics ticks), never the whole tree — other enemies keep moving.
- Shake uses trauma (0–1), decays, `offset = max_offset * trauma²` with noise.
- Global slow-mo (`Engine.time_scale`) is reserved for **perfect dodge** and
  **multi-kill**; ≤ 0.35 s real time, eased back. Never stack.

## Verb grammar

| Verb | Input | Role in loop |
|---|---|---|
| Shoot | Fire | Damage + stagger at range ≤ ~6 tiles. Spends 1 shell. |
| Stock strike | Melee | Close stagger/damage; usable at 0 shells. Refills 1 shell on hit. |
| Grapple | Grab (on staggered or light enemy in range) | Hold enemy as shield; you move slower. Enemy shots hit them. |
| Throw | Grab again / Melee while holding | Body becomes a `player_hitbox`; hits enemies/walls. Refills 2 shells on impact. |
| Dodge | Dodge | Short burst with i-frames; cancels recovery. Perfect dodge (hit lands in first 4 i-frame ticks) → slow-mo + 1 shell. |

## Enemy reaction contract

Every enemy must implement these states: `Idle`, `Pursue`, `Windup`, `Attack`,
`Recover`, `HitReact`, `Staggered`, `Grabbed`, `Thrown`, `Dead`.
Missing any one makes the verbs inconsistent — don't ship an enemy without them.

## Anti-patterns

- Damage numbers in `_on_area_entered` callbacks scattered across scripts.
- Random spread without a seed (untestable, unrepeatable clips).
- Screen shake on every pellet (noise ≠ feel).
- Long un-cancellable player animations.
- Slow-mo on a timer rather than as a reward.
