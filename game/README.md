# Moonwake — Godot Mandate Build

Playable implementation of the [Concept Bible](../docs/MOONWAKE_CONCEPT_BIBLE.md).

## Requirements

- Godot **4.3+**

## Run

```bash
godot --path game
```

**First play:** click **PLAY RAID — Dust Meridian** on the title screen (skips the town hub).  
You should see Severin (red ring under feet) and enemies spawning around you.

- Move WASD · Attack J / Click · Special K / Right-click · Cast L / Q · Dodge Space · Feed F  
- After a burst clears, a **PICK A BOON** panel pauses combat — click one choice to continue.  
- **Ashwick Town Hub** is optional prep (roster / meta), not the fight.

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
| Special | Right-click / K | `/` |
| Cast | Q / L | `.` |
| Dodge | Space | Shift |
| Feed | F | F |

Gamepad: left stick move, right stick aim, X attack, B special, RB cast, A dodge, Y feed.

### Kits (attack · special · cast · dash)

Slot data lives in `CharacterDB.KIT_SLOTS`. Nothing deals damage without an input.

| Sibling | Attack | Special | Cast |
|--|--|--|--|
| Severin (melee) | 3-hit combo, wide finisher | Lunging Cleave | Blood Stake: marks, +30% damage from every hunter |
| Mira (hybrid_gun) | Aimed piercing rail shot | Silverstorm Volley (seeking) | Silver Flare (fused AoE) |
| Cassian (orbit) | Crescent throw, hits out and back | Recall Burst ring | Court Sigil (ticking zone) |
| Odette (maul) | Frontal slam | Travelling shockwave | Grave Hook (pulls target in) |
| Vesper (astral) | Spirit Spike from the spirit | Collapse (detonate spirit) | Projection (spirit dashes through foes, anchors) |

## Headless checks

Run from `game/` (or pass `--path game`). **`--fixed-fps 60` is required for autoplay** so the bot is fast and deterministic with no display.

```bash
godot --headless --import
godot --headless res://scenes/tests/boot_smoke.tscn
godot --headless res://scenes/tests/raid_visibility_smoke.tscn
godot --headless --fixed-fps 60 res://tests/autoplay/autoplay.tscn -- mode=kill sectors=all
```

Autoplay args after `--`:

| Arg | Values | Default |
|-----|--------|---------|
| `mode` | `kill` (bot + invuln) · `idle` (no input, reports time-to-death) · `human` (no bot) | `kill` |
| `sectors` | `all` or comma ids (`dust_meridian,cinder_barrens`, …) | `all` |
| `char` | character id | `severin` |
| `seed` | integer (same seed → same RESULT lines) | `1` |

Each sector prints one `RESULT …` line (outcome, run_time, phases, kills, gate, boons, feeds, dmg_taken, max_hit). The run ends with `AUTOPLAY_DONE`. **`mode=kill` exits 1** if any sector does not reach Ashwick.

`mode=idle` is the time-to-death probe (`outcome=DIED`, `run_time` ≈ seconds to wipe).
