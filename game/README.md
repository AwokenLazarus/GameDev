# Moonwake — Godot V0

Playable vertical slice for the concept bible.

## Requirements

- Godot **4.3+**

## Run

```bash
godot --path game
```

Or open `game/project.godot` in the Godot editor and press Play.

## V0 contents

- Main menu → **Ashwick** hub (mayor, vendor, kin, blood rite, currencies)
- Raid **Dust Meridian** as **Severin** (moon-edge longblade)
- **5 dungeon bursts** → **wild stage** (director + difficulty timer) → kill gate → **Marshal Corvin Hale**
- Boon picks (~8) from faction patrons with rival restrictions + deep pact at 3
- **Feed** on enemy human corpses (`F`) for buffs + run-scoped Ashwick reputation
- Death → **moon rebirth** screen → return to Ashwick
- Victory → rewards → Ashwick

## Controls

| Action | Input |
|--------|-------|
| Move | WASD / Arrows |
| Attack | Left click / J |
| Dodge | Space / Shift |
| Feed | F |
| Interact (hub) | Buttons |

## Headless smoke test

```bash
godot --path game --headless --script res://tests/smoke_test.gd
```
