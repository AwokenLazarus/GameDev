# Moonwake — Godot Mandate Build

Playable implementation of the [Concept Bible](../docs/MOONWAKE_CONCEPT_BIBLE.md).

## Requirements

- Godot **4.7.1** (standard build, not .NET). Forward Plus. A discrete GPU is required: `rendering/rendering_device/fallback_to_opengl3` is false, so machines without Vulkan, D3D12 or Metal get Godot's unsupported-GPU error instead of an untested OpenGL picture.

## Verify

One script runs the import, every smoke scene (`--fixed-fps 60`), the type-gate count (must be 0), `gdformat --check`, and autoplay `mode=kill sectors=all seed=1`. It exits non-zero on any failure, including a smoke that exits 0 without its `*_PASS` line or that prints `SCRIPT ERROR`.

From the repo root:

```bash
lazvault heavy --project moonwake -- game/tools/verify.sh
```

## Playtest build

Export presets `Linux x86_64` and `Windows x86_64` live in `game/export_presets.cfg` (PCK beside the executable, not embedded). Install the official 4.7.1 export templates into `~/.local/share/godot/export_templates/4.7.1.stable/` first. Builds stay outside the repo:

```bash
SHORT="$(git rev-parse --short HEAD)"
OUT="$HOME/work/builds/moonwake-$SHORT"
mkdir -p "$OUT"
godot --headless --path game --export-release "Linux x86_64" "$OUT/Moonwake.x86_64"
godot --headless --path game --export-release "Windows x86_64" "$OUT/Moonwake.exe"
```

Double-click `Moonwake.exe` on Windows, or run `./Moonwake.x86_64` on Linux. Both need the `Moonwake.pck` that sits next to them (one pack; the Linux and Windows exports write the same bytes). Local co-op (keyboard player 2 and gamepads, up to 4) is the same binary. Official templates refuse a scene path in front of the binary, so the headless check passes the scene after `--`:

```bash
"$OUT/Moonwake.x86_64" --headless -- res://scenes/tests/boot_smoke.tscn
```

That prints `BOOT_SMOKE_PASS`. Only `res://scenes/tests/` and `res://tests/` scenes are accepted.

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

Each smoke scene calls `seed()` before it does any work, prints `SEED=N` first, and puts `SEED=N` on every `*_FAIL` line. Override with `-- seed=N` (same form as autoplay). Defaults: boot `1`, raid visibility `2`, combat readability `3`, kit slots `4`, boss phases `5`, boons `6`, pacts `7`. Pass `--fixed-fps 60` when two runs must match byte for byte. Without it, combat's printed HP and boons' instance ids can shift.

Static types are an error (`gdscript/warnings/untyped_declaration=2` in `project.godot`). Count what is left with the per-file check. Godot exits 0 on these, so count lines. Run from `game/`. `git ls-files` prints repo-root paths (`game/…`), so strip that prefix. `--check-only` cannot see autoloads or `class_name` and reports `Identifier not found` / `not declared in the current scope` for them; count only `Warning treated as error`. The target is 0.

```bash
for f in $(git ls-files '*.gd' | sed 's|^game/||'); do
  godot --headless --path . --check-only --script "res://$f" 2>&1
done | grep -c 'Warning treated as error'
gdformat --check $(git ls-files '*.gd' | sed 's|^game/||')
gdlint $(git ls-files '*.gd' | sed 's|^game/||')
```

Autoplay args after `--`:

| Arg | Values | Default |
|-----|--------|---------|
| `mode` | `kill` (fast bot: 1 kill / 0.4 s, random doors, invuln) · `human` (pacing estimate: 1 kill / 1.2 s, 4 s boon reads, walks to doors, 75 % Pact bias, invuln) · `idle` (no input, reports time-to-death) | `kill` |
| `sectors` | `all` or comma ids (`dust_meridian,cinder_barrens`, …) | `all` |
| `char` | character id | `severin` |
| `seed` | integer (same seed → same RESULT lines) | `1` |

Each sector prints one `RESULT …` line (outcome, run_time, kills, wild_kills, gate, boons, feeds, greed, dmg_taken, max_hit, phase timestamps, `dur` = bursts/wild/boss seconds). The run ends with `AUTOPLAY_DONE`. **`mode=kill` exits 1** if any sector does not reach Ashwick. Both bots walk the lead to every wild greed interactable. `mode=kill sectors=all` takes ~4 min wall (each sector ~15 min simulated; the director, not the bot, sets the pace).

`mode=idle` is the time-to-death probe (`outcome=DIED`, `run_time` ≈ seconds to wipe).

## Pacing (MW-025)

Target ~30 min per sector (charter L3/L4), ~8 boons.

- **Kill gate** counts **wild-stage kills only** (`RunState.wild_kills`). `kill_gate_base` 1150 (Pale Spire 1500) × (1 + 0.35 per extra player) × difficulty/heat; Killgate Scanner −5 %/rank.
- **Difficulty clock** = run time + Moon Altar debt. Ramp reaches 1.0 at 25 min (`RunState.CLOCK_FULL`) and creeps on after. Director intensity `0.2 + 1.6·ramp` (× difficulty, × 1 + 0.3 per extra player): spawn every 1.6→0.5 s, 1→3 per spawn, alive cap 14 + 20·intensity (max 64). Enemy HP ×(1 + 0.6·ramp), damage ×(1 + 0.35·ramp); elite chance 2 % → 32 % over the clock. Labels: →Blood 5 min, →Eclipse 12 min, →Pale 20 min.
- **Bursts**: 6 + 2·index enemies (+3 nightmare) in waves of 5; the next wave lands when ≤ 1 remain.
- **Wild greed** (`GreedShrine`, stand to channel): 3 strongboxes (Blood/Ash/Tech haul, 35 % gear; haul banked at run end, half on death) · Moon Altar (boon, director clock +90 s) · Blood Well (boon, costs your feed stacks if ≥ 2, else 25 % max HP).
- **Boon offers**: burst 1 clear · Pact doors · wild entry (these stop at the soft target of 8) · Moon Altar · Blood Well · the general (always offer).
- Measured (seed 1, Severin, Dust Meridian): `mode=human` 1562 s (26 min: bursts 99 s, wild 1468 s, boss 24 s), 8 boons; `mode=kill` 879 s, 6–8 boons.

