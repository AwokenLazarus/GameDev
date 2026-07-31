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

- Painterly cutout heroes: Severin, Mira, Cassian, Odette, Vesper (green-keyed)
- **Full anim states** per actor: idle / walk / run / attack / dodge (heroes); idle / walk / attack (enemies & generals); idle / walk / talk (hub NPCs)
- 8 named generals including Aurelian
- Enemy cast (enforcers, zealots, grubs, elites, beasts, void wretches)
- Ashwick hub NPCs: Mayor, Kin, Dust Compact, Church, Petition, Veyra Eye
- Painterly props: chapel, crate, rail, ruin
- Cinematic combat VFX: slash, blood, bolt, crescent, moon, telegraph, shadow rebirth
- Full-bleed biome vistas for all sectors + Ashwick
- Runtime: `ActorVisual` state machine, `BiomePresenter`, `HubNpc`
- Pipelines: `process_bloodlust_art.py`, `process_anim_sheets.py`

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
