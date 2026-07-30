# Moonwake — Concept Bible

**Status:** Concept locked v1.0 (2026-07-30)  
**Engine:** Godot  
**Presentation:** Isometric / Hades-like 2.5D  
**UI:** Bloodlust-minimal  
**Music:** Gothic  
**Related:** [Game Mandate Charter](./GAME_MANDATE_CHARTER.md)

This document is the creative source of truth for *Moonwake*. Agents implement inside these bounds. IP rule: evoke *Vampire Hunter D: Bloodlust* mood and silhouette language; invent original names, plots, creatures, and designs.

---

## 1. Pitch

**Title:** Moonwake  

**One-liner:** Solo and co-op action roguelite where Aurelian’s dhampir brood raid the Crimson Dominion—short dungeon bursts into timed wild stages—cursed to rebirth under every full moon until the God-Emperor falls.

**Logline:** Born of different mothers and one galactic vampire tyrant, four siblings (and the brood that follows) hunt through gothic-western ruins and noble strongholds. They take faction pacts, risk feeding on enemy humans for power, and return to their ruined hometown between moons—until someone finally kills Aurelian the Undying atop the Pale Spire.

**Player fantasy:** Dry, stylish Bloodlust cool. Grim dominance that can still erase hordes with build + skill. Alone or as up to four siblings.

---

## 2. Tone & references

| Pull from | Use for |
|-----------|---------|
| Vampire Hunter D: Bloodlust | Atmosphere, gothic × western × post-apoc sci-fantasy, lonely cool, weapon variety, chromegoth vs dust |
| Hades | Boon choices, pact depth, readable 2.5D combat, hub that remembers you |
| Risk of Rain 2 | Director + difficulty timer, large wild stages, survivor unlock model, alt kits |
| SWORN | Co-op action-roguelite party fantasy |
| Vampire Survivors | Horde density as a *layer*, not the whole control scheme |
| Tears of Metal | Explicitly **not** using army/companions |
| Dune (vibes only) | God-emperor politics, worship/fear/collaborate/rebel; no Herbert IP |

**Tone keywords:** lonely melancholy, stylish cool, pulp horror undercurrent, dry wit. Not cozy, not carnival-goofy as the default power fantasy.

---

## 3. Core fantasy locks

| Topic | Lock |
|-------|------|
| Species | All player characters are **Dhampirs** (vampire father × non-vampire mother) |
| Father | **Aurelian the Undying**, God-Emperor of the galaxy |
| Mothers | Different per sibling (human or remnant peoples) |
| Party | Up to **4** siblings hunting together; solo = one sibling |
| Banter | Dry Bloodlust cool |
| Sun | Dhampirs **immune** to vampiric sun-sickness; true vampires are not |
| Feeding | Optional; **enemy humans only** during combat; never in Ashwick |
| Death | Run ends; rebirth next **full moon** from **moon-cast shadows** shaping the body |
| Win (v1) | Kill Aurelian → unlock **NG+** (heat + new generals) |

---

## 4. World

### 4.1 Setting

Futuristic post-apocalyptic **gothic dark western**: sun-bleached frontiers, rail ghosts, chromegoth noble ruins, orbital castle-tech. Sci-fantasy ruins and blood aristocracy coexist.

### 4.2 The Crimson Dominion

Aurelian rules in the flesh from **the Pale Spire**—a gothic castle fused to an orbital fortress. Humans worship, fear, reject, or serve him for power. Vampire aristocracy forms his **court and rival Great Houses** (Dune-like intrigue).

### 4.3 Remnant peoples (Bloodlust-like reskins)

Do **not** ship as stock “elf/dwarf/tiefling/Martian.” Use original remnant cultures with those *vibes*:

| Codename (internal) | Public name | Vibe |
|---------------------|-------------|------|
| Ash-long | **The Paleleaf Remnant** | Long-lived dust-forest folk; elegant, sun-etched |
| Forge-short | **The Hollowkiln Clans** | Bunker-mine smith peoples; stocky, slag-scarred |
| Hell-blood | **The Cinderborn** | Old-pact underclass; horn-shadow silhouettes, ember eyes |
| Red-world | **The Saffron Host** | Client-race of the Dominion from a rust world; ochre skin, respirator culture |

Later siblings may be Aurelian’s spawn through these mothers. Co-op may mix ancestries freely.

### 4.4 Ashwick (hub)

Ruined town of the brood’s human family ties. Path of Exile–style home base:

- Living relatives and townsfolk trying to get by  
- Oppressed by Dominion forces and human collaborators  
- **Human mayor** runs day-to-day oppression  
- Trade, vendors, missions, meta spending  
- Townsfolk often steer clear / distrust Dhampirs; some racist, some kind; all will *rely* on them when needed  

**No feeding in Ashwick.**

### 4.5 Hub factions

| Faction | Role |
|---------|------|
| **The Mayor’s Office** | Collaborator government; curfews, approved goods, wanted posters |
| **Church of the Pale Sun** | Worships Aurelian; charity + informants; hates public feeding |
| **The Dust Compact** | Smugglers; illicit gear; transactional tolerance |
| **Ashwick Kin** | Relatives + sympathetic neighbors; soft quests, fragile trust |
| **Red Petition** | Rebel cell; risky anti-Dominion jobs and unlocks |
| **House Veyra’s Eyes** | Rival Great House spies; noble-tech bargains with strings |

---

## 5. Player characters

### 5.1 Starting four (locked)

| Sibling | Signature weapon | Agency lean | Mother’s world |
|---------|------------------|-------------|----------------|
| **Severin** | Moon-edge longblade + peace-cord draw tricks | Manual melee | Ashwick gunsmith line |
| **Mira** | Wrist-rail silverstorm (seeking bolt rain) | Hybrid aim + auto volleys | Rail-town preacher’s daughter |
| **Cassian** | Twin crescent throwers (orbit + recall) | Mostly auto + positioning | Collaborator scholar fled from court |
| **Odette** | Sepulcher maul (shockwave anti-armor) | Manual commits | Mining colony survivor |

### 5.2 Unlock #5 (locked)

| Sibling | Signature | Agency | Notes |
|---------|-----------|--------|-------|
| **Vesper** | Soulspike astral projection | Spirit mostly auto; body is weak point; manual pierce/detonate | Glass cannon; unlock after starters |

### 5.3 Further unlocks

- More Emperor-spawn siblings (human + remnant mothers)  
- Per-character **alternate starting weapons and abilities** (Risk of Rain 2 survivor model)  
- Skins  

Character names and core identities above are **locked**.

---

## 6. Run structure

### 6.1 Loop

```
Ashwick (timer paused)
  → Choose / continue a sector raid
  → Timer + director ACTIVE
  → 4–5 dungeon bursts (boon picks, rare→rising elites)
  → Wild stage (large biome map, greed vs rising difficulty)
  → Kill threshold reached → Sector General available/spawns
  → Defeat general → return to Ashwick
```

- **Target:** ~**30 minutes** per sector clear  
- Runs can **chain** progression fantasy across raids, but **each general clear returns to Ashwick**  
- Difficulty timer runs **only while in sectors**, not in Ashwick  
- Director AI spawns enemies as you play (RoR2-like)  
- **Boss/general only via kill gate** (no early force shrine)  
- Kill threshold **scales with player count and difficulty**  
- Elites: rare early in a sector stay; more common as time rises  
- **Pale Spire** always available as scaled nightmare end raid (deletes underbuilt runs)

### 6.2 Dungeon bursts

Short Hades-like rooms/gauntlets inside the sector biome. Path/reward choices. ~4–5 before wild.

### 6.3 Wild stage

Large RoR2-like expanse in the same biome. Explore, fight director swarms, push kill count while difficulty climbs.

---

## 7. Combat

- **Hybrid agency** by character and weapons  
- Peak power: **grim stylish dominance** that can still **decimate hordes** with good build + skill  
- Readable telegraphs under chaos  
- Co-op 1–4; shared failure/run end; all return next moon  
- No Tears of Metal army layer  

---

## 8. Power systems

### 8.1 Boons (primary)

Hades-like boons. **No Risk of Rain item stacks.**

**Four patrons:**

| Patron | Themes | Example verbs | Rivals (blocked if aligned) |
|--------|--------|---------------|-----------------------------|
| Dust Compact | dust, scrap, gunsmoke, mobility | dash, reload, loot luck, bleed | Church of the Pale Sun |
| Red Petition | rebellion, sabotage, iron, execute | execute, trap, team buff, anti-elite | Mayor / Dominion loyalists |
| House Veyra | noble blood-tech, elegance, debt | crit, lifesteal, shadowstep, evolve | Church; tension with Petition |
| Church of the Pale Sun | hymn, judgment-light, ward, decree | aura, cleanse, smite, cooldown | Dust Compact + Veyra |

**Rules:**

- Boons are **theme + verb**  
- ~**8** boon picks per sector clear  
- Co-op: **shared alignment** — players cannot pull rival patrons in the same run  
- Taking a patron locks out rivals for that run  
- **Deep pact (3+ boons same patron):** transforms **core weapon behavior** + pact passive / FX  

Boons offered while raiding a sector lean toward factions opposing or exploiting that sector’s power structure.

### 8.2 Feeding

- Deliberate action on **enemy humans** killed in combat  
- Grants powerful buffs  
- Not feeding does **not** hurt the Dhampir  
- Consequences last **for that run**: humans fear → hate; worse trades, mission/item options mid-run / on return that moon  
- Church-leaning runs punish visible feeding harder  
- **Forbidden in Ashwick**

### 8.3 Gear (secondary)

Light ARPG layer: few slots, meaningful choices. **No persistent gear meta.** Gear does not carry between runs as the progression backbone.

### 8.4 Meta progression

**Three separate currencies:**

| Currency | Fantasy | Sinks |
|----------|---------|-------|
| **Blood** | Blood rites | Account passives, rite powers |
| **Ash** | Ashwick rebuilding | Vendors, missions, hub gameplay unlocks |
| **Tech** | Salvaged Dominion tech | Tech passives, tools, unlock gates |

Earn from sector clears, challenges, and feeding — **all three, different weights**. Spend freely (no per-moon soft cap).

**Unlocks (RoR2-like):** more siblings, character-specific alt starting weapons/abilities, skins. **No persistent gear stash.**

---

## 9. Sectors (7)

| # | Sector | Biome | General |
|---|--------|-------|---------|
| 1 | **Dust Meridian** | Bleached flats, rail wrecks | **Marshal Corvin Hale** — human enforcer |
| 2 | **Cinder Barrens** | Volcanic slag, mining pits | **Lady Sable Veyra** — rival-house industrialist |
| 3 | **Gloampine** | Fog redwoods, bridges, beasts | **Marrowfang** — beast-blood loyalist general |
| 4 | **Salt Choir** | Salt flats, drowned chapels | **Cantor Belis** — Church execution-saint |
| 5 | **Iron Orchard** | Feral agri-domes, thorn trains | **Provost Rhea Sol** — famine collaborator |
| 6 | **Noir Cathedral** | Chromegoth megacity under shade | **Duke Thane Orlokis** — court vampire rival-kin |
| 7 | **Umbral Marches** | Orbital scrap-rings to the Spire | **Admiral Kael Drus** — fleet-warden |

Generals are **unique, named, political**. Clearing a sector is run-based with unlocks (roguelike + ARPG), not a permanent overworld conquest sim.

### 9.1 Pale Spire

Always raidable. Scaled nightmare. Steep entry deletes underbuilt runs. Defeat **Aurelian the Undying** → **NG+** with heat modifiers **and** new generals.

---

## 10. Difficulty

Story-named difficulties (examples to finalize in design):

- **Dust** — standard  
- **Blood** — hardened  
- **Eclipse** — brutal  
- NG+ heats add modifiers + alternate/new generals  

Exact names/count may be tuned; **story terms preferred over generic Easy/Normal/Hard.**

---

## 11. Art, audio, UI

| Layer | Direction |
|-------|-----------|
| Camera / space | Iso **2.5D**, Hades-like readability |
| World | Painterly dust, crimson, bone, iron, moonlight; chromegoth interiors vs bleached flats |
| Characters | Strong silhouettes (cloak, rail-gun arm, crescents, maul, astral double-form) |
| UI | **Bloodlust-minimal** — sparse, cinematic, low chrome clutter |
| Music | **Gothic** — orchestra, choir fragments, dread motifs; western dust as seasoning not parody |
| Violence | Stylish blood ballet; readable carnage |

---

## 12. Multiplayer

- Solo complete; co-op 2–4 first-class  
- Shared patron alignment  
- Kill thresholds scale with party size  
- Mix ancestries/siblings freely  
- Run failure returns all next moon  

Netcode approach: implementation detail (Godot multiplayer); design assumes 1–4 from day one.

---

## 13. IP & originality rules

**Allowed:** mood, genre blend, lonely hunter cool, gothic-western-post-apoc contrast, hybrid weapon fantasy *inspired by* Bloodlust’s variety.

**Banned:** D, Left Hand, named Bloodlust/VHD characters, Sacred Ancestor, Marcus brothers, specific plot lifts, Amano tracings, Madhouse stills as assets, Dune proper nouns, 40K proper nouns.

---

## 14. First vertical slice (recommended)

Prove in ~20–30 minutes of play:

1. Ashwick stub (mayor + one vendor + Kin beat)  
2. One starter (Severin or Mira)  
3. Dust Meridian: 4–5 bursts → wild → Marshal Corvin Hale  
4. Timer + director + ~8 boon picks from 2 non-rival patrons  
5. Death → moon rebirth presentation  
6. Solo first; co-op immediately after  

---

## 15. Open polish (non-blocking)

- Exact difficulty name set and NG+ heat list  
- Exact currency earn weights  
- Full Vesper unlock condition  
- Enemy family bibles per sector  
- Detailed boon lists per patron  
- Godot version pin  
- Downed/revive co-op specifics  

---

## 16. Change log

| Version | Date | Notes |
|---------|------|-------|
| v1.0 | 2026-07-30 | Concept bible compiled from creative director Q&A. |
