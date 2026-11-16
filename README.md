# SHOTGUN-FU

Action RPG. **The shotgun is really the main character.**

Godot 4.5.1 · GDScript (typed) · Forward+ · 480×270 pixel art with neon 2D lighting.

## Status

Pre-production. Tooling and specs only — no gameplay yet.
First target: [Vertical Slice 01](docs/vertical-slice.md).

## Setup

```bash
tools/install_godot.sh                 # fetch pinned Godot into .toolchain/ (SHA-512 verified)
git config core.hooksPath .githooks    # run fast validation on every commit
tools/validate.sh                      # fast headless check
tools/validate.sh --full               # + unit tests + smoke scenes
tools/checkpoint.sh <name>             # tag a known-good state (doesn't push)
```

Already have Godot? `GODOT=/path/to/godot tools/validate.sh`.

## Docs

- [`CLAUDE.md`](CLAUDE.md) — architecture, design pillars, dev rules (the contract)
- [`docs/vertical-slice.md`](docs/vertical-slice.md) — slice 01 spec + milestones
- `.claude/skills/` — `godot-gameplay`, `gunfu-combat`, `pixel-art-pipeline`
