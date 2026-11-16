---
name: godot-gameplay
description: SHOTGUN-FU Godot 4 gameplay engineering patterns — typed GDScript, scene composition, component nodes, state machines, signals, tuning resources, and headless-testable code. Use before writing or restructuring any GDScript, .tscn scene, player/enemy state, autoload, or component in this repo.
---

# Godot Gameplay (SHOTGUN-FU)

Godot **4.5.x**, GDScript only, fully typed. Read `CLAUDE.md` §2 first; this skill
is the how-to for those rules.

## Godot 4 gotchas (don't write Godot 3 code)

| Godot 3 (wrong) | Godot 4 (right) |
|---|---|
| `KinematicBody2D`, `move_and_slide(vel)` | `CharacterBody2D`; set `velocity`, call `move_and_slide()` |
| `yield(obj, "sig")` | `await obj.sig` |
| `connect("sig", self, "_m")` | `sig.connect(_m)` |
| `export var x` / `onready var` | `@export var x: int` / `@onready var` |
| `tool` | `@tool` |
| `instance()` | `instantiate()` |
| `deg2rad`, `rand_range` | `deg_to_rad`, `randf_range` |
| `Light2D` | `PointLight2D` / `DirectionalLight2D` |

## Component pattern

```gdscript
# src/components/health.gd
class_name Health
extends Node

signal damaged(amount: int, source: Node)
signal died

@export var max_hp: int = 3
var hp: int

func _ready() -> void:
	hp = max_hp

func apply_damage(amount: int, source: Node) -> void:
	if hp <= 0:
		return
	hp = maxi(hp - amount, 0)
	damaged.emit(amount, source)
	if hp == 0:
		died.emit()
```

Owners wire components in `_ready()` — components never `get_parent()` to find siblings.

## State machine pattern

```gdscript
# src/core/state_machine.gd
class_name StateMachine
extends Node

@export var initial: State
var current: State

func _ready() -> void:
	for child: Node in get_children():
		if child is State:
			(child as State).machine = self
	current = initial
	current.enter({})

func transition(to: StringName, msg: Dictionary = {}) -> void:
	var next: State = get_node_or_null(NodePath(to)) as State
	assert(next != null, "Unknown state: %s" % to)
	current.exit()
	current = next
	current.enter(msg)

func _physics_process(delta: float) -> void:
	current.physics_update(delta)

func _unhandled_input(event: InputEvent) -> void:
	current.handle_input(event)
```

```gdscript
# src/core/state.gd
class_name State
extends Node

var machine: StateMachine

func enter(_msg: Dictionary) -> void: pass
func exit() -> void: pass
func physics_update(_delta: float) -> void: pass
func handle_input(_event: InputEvent) -> void: pass
```

- Timing inside states counts **ticks** (`_ticks += 1` in `physics_update`), not seconds.
- Input buffering: store the last press tick per action; a state consumes a
  buffered press if `now - pressed_tick <= tuning.buffer_ticks`.

## Tuning resources

```gdscript
# src/weapons/shotgun_tuning.gd
class_name ShotgunTuning
extends Resource

@export_range(1, 16) var pellets: int = 7
@export_range(0.0, 90.0) var spread_deg: float = 28.0
@export var pellet_damage: int = 1
@export var knockback: float = 220.0
@export var recovery_ticks: int = 14
```

Instances live in `data/*.tres`. Scenes `@export` the resource. Never duplicate
numbers into code.

## Testable code

- Put math in `static func` on a `RefCounted` class in `src/combat/`
  (e.g. `SpreadPattern.directions(aim: Vector2, count: int, spread_deg: float, rng_seed: int) -> Array[Vector2]`).
- Any randomness takes an explicit seed or `RandomNumberGenerator` so tests are deterministic.
- GUT test skeleton:

```gdscript
# tests/unit/test_spread_pattern.gd
extends GutTest

func test_pellet_count_matches() -> void:
	var dirs: Array[Vector2] = SpreadPattern.directions(Vector2.RIGHT, 7, 28.0, 1)
	assert_eq(dirs.size(), 7)
```

## Smoke tests

A smoke test is a scene under `tests/smoke/` whose root script drives inputs via
`Input.action_press()` / `Input.parse_input_event()` on fixed ticks, asserts
outcomes, prints `SMOKE PASS <name>` and calls `get_tree().quit(0)` (or `quit(1)`
with `SMOKE FAIL <name>: reason`). `tools/validate.sh --full` runs every
`tests/smoke/*.tscn`.

## Checklist before committing gameplay code

- [ ] All vars/params/returns typed
- [ ] No magic numbers outside `data/`
- [ ] Signals past-tense, connected in code by the owner
- [ ] New logic has a unit test; new verb has a smoke test
- [ ] `tools/validate.sh` green
