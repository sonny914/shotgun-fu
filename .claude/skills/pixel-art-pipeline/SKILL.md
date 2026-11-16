---
name: pixel-art-pipeline
description: SHOTGUN-FU pixel art and neon lighting pipeline — resolution, palette, sprite sizes, Aseprite export, Godot import settings, normal maps, CanvasTexture, 2D lights, HDR glow, and pixel-perfect camera rules. Use before creating, importing, or wiring any sprite, tileset, animation, light, or post-process effect.
---

# Pixel Art Pipeline (SHOTGUN-FU)

## Canvas & scale

- Internal resolution **480×270**, integer-scaled to the window (`stretch/mode=viewport`,
  `scale_mode=integer`). 1080p = 4×, 1440p ≈ 5× letterboxed, 4K = 8×.
- Tile size **16×16**. Player sprite ~ **24×32** canvas. Grunt enemies similar; heavy enemies ≤ 40×40.
- Never scale sprites by non-integer factors. Never rotate pixel sprites except
  muzzle flashes/pellets/particles (where shimmer is acceptable).
- Camera: `Camera2D` with position smoothing done on a sub-pixel *target*, while the
  rendered position is rounded (`snap_2d_transforms_to_pixel` is on).

## Palette

- One master palette file: `assets/palette/shotgun-fu.gpl` (to be authored, ≤ 32 colors).
- Structure: deep near-black blues/purples for the world (lighting does the work),
  2–3 neon accent ramps (magenta, cyan, acid amber), skin/material ramps.
- Sprites are painted **lit-neutral** (flat mid-values). Lights add the drama. Do
  not paint neon rim light into the diffuse — that comes from normal maps + lights.

## Source → export

```
assets/src/<entity>/<entity>.aseprite      # source, committed (Git LFS if > 5 MB total grows)
assets/sprites/<entity>/<entity>.png       # exported sheet
assets/sprites/<entity>/<entity>_n.png     # normal map, same layout
assets/sprites/<entity>/<entity>.json      # Aseprite frame/tag data (if used)
```

- Aseprite export: sprite sheet, "By Rows", padding 1 px, trim off (stable frame rects).
- Tags in Aseprite = animation names in Godot (`idle`, `run`, `shoot`, `stock`,
  `grab`, `throw`, `dodge`, `hurt`, `die`).
- Normal maps: hand-painted or generated (e.g. Laigter / SpriteIlluminator) then
  hand-cleaned. Same frame layout as the diffuse sheet.

## Godot import settings

- Project default texture filter = **Nearest** (set in `project.godot`).
- Per texture: Compress mode **Lossless**, Mipmaps **off**, Fix Alpha Border **on**.
- Use `CanvasTexture` for lit sprites: `diffuse_texture` = sheet, `normal_texture` = `_n` sheet,
  `specular` low (0.1–0.3) for metal on the shotgun only.

## Neon lighting rig

- `CanvasModulate` near-black blue (≈ `#0d0a1a`) for the room base.
- `rendering/viewport/hdr_2d = true` (on) so emissive values > 1.0 bloom.
- `WorldEnvironment` → Environment background **Canvas**, Glow **on**, blend Additive or
  Screen, HDR threshold ~1.0, intensity tuned per room.
- Neon signs/tubes: sprite with `modulate` > 1.0 (e.g. `Color(2.2, 0.4, 1.8)`) +
  a `PointLight2D` behind it with a soft gradient texture; optional `LightFlicker` component.
- Muzzle flash: `PointLight2D` energy spike for 2–3 ticks, then decay over ~6 ticks.
  This is the most important light in the game — it's the protagonist talking.
- Shadows: `LightOccluder2D` on walls and large props only; `PointLight2D.shadow_enabled`
  only on the 2–4 key lights per room (cost).
- Budget: ≤ 12 active `PointLight2D` per screen on the slice; profile before adding more.

## Validation notes

- Headless CI uses a dummy renderer: it **cannot** verify lighting or glow. It only
  verifies that textures/resources import and scenes load.
- Visual review happens via screenshots from a real-GPU run (local machine) or a
  later Xvfb+software-GL capture job. Don't claim a visual change "looks right"
  without a screenshot.
