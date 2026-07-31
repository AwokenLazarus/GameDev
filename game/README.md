# Moonwake — Godot Mandate Build

Playable implementation of the [Concept Bible](../docs/MOONWAKE_CONCEPT_BIBLE.md).

## Requirements

- Godot **4.3+**

## Run

```bash
godot --path game
```

## Contents

| System | Status |
|--------|--------|
| Ashwick hub (6 factions, rebuild gates) | Yes |
| Brood roster: Severin, Mira, Cassian, Odette, Vesper | Yes |
| Alt kits (unlockable) | Yes |
| 7 sectors + Pale Spire | Yes |
| Named generals + unique patterns | Yes |
| Bursts → wild director → kill gate → general | Yes |
| 4 patrons, rival locks, deep pact @3 | Yes |
| Feeding + run reputation | Yes |
| Light run-only gear drops | Yes |
| Blood / Ash / Tech meta trees | Yes |
| Story difficulty Dust/Blood/Eclipse | Yes |
| NG+ after Aurelian (heats) | Yes |
| Local co-op up to 4 | Yes (keyboard P2 + pads) |
| Hybrid kits (melee/gun/orbit/maul/astral) | Yes |
| **2.5D graphics pass** | Yes — sprites, biomes, VFX, lighting |

## Graphics

**Bloodlust-inspired** gothic-western cinematic art (original IP — no VHD character/plot copies):

- Painterly hero sprites for Severin, Mira, Cassian, Odette, Vesper
- 8 named generals including Aurelian
- Enemy cast (thralls, enforcers, elites, beasts, void wretches)
- Full-bleed biome vistas for all sectors + Ashwick
- Moon rebirth / menu presentation
- Color grade: dust ochre, dried crimson, cold moonlight, chromegoth violets
- Runtime: `ActorVisual`, `BiomePresenter` (vista + floor + particles + lights + vignette)

Showcase sources: `assets/art_showcase/`  
Runtime sheets: `assets/textures/`

## Controls

| | P1 | P2 |
|--|----|----|
| Move | WASD | Arrows |
| Attack | Click / J | Ctrl |
| Dodge | Space | Shift |
| Feed | F | F |

Gamepad: left stick move, X attack, A dodge, Y feed.

## Smoke test

```bash
godot --path game --headless res://scenes/tests/boot_smoke.tscn
```
