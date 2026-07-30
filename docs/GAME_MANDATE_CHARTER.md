# Game Mandate Charter

**Status:** Draft v0.1 — core decisions locked; open questions marked `OPEN`  
**Engine:** Godot  
**Audience:** AI agent game studio + human creative director  
**Authority:** This charter is the source of truth. Agents may invent systems, lore, and content *inside* locked pillars. Agents must not contradict **LOCKED** decisions. `OPEN` items require human approval or explicit “agent decides” authorization before shipping as final.

---

## 1. One-line mandate

Build a **solo + co-op action roguelite** in **Godot**: hybrid skill/auto combat by character and weapon, **Hades-style dungeon bursts** alternating with **Risk of Rain 2–scale outdoor stages**, in an **original gothic-frontier world** that evokes *Vampire Hunter D: Bloodlust* **without copying protected IP**.

---

## 2. Elevator pitch (working)

In a sun-bleached, noble-haunted frontier long after the old world fell, hunters and cursed wanderers cut through short, brutal dungeon gauntlets and vast hostile wilds—stacking strange arms and blood-powers until the night breaks, alone or with companions who remember every failed hunt.

**Working title / codename:** `OPEN`  
**Logline refinement:** `OPEN` (see §11)

---

## 3. Locked decisions (do not reopen without human sign-off)

| ID | Decision | Detail |
|----|----------|--------|
| **L1** | Combat agency | **Hybrid.** Manual vs automatic (and mixes) depend on **character type** and **weapons/abilities acquired** in the run. |
| **L2** | Run structure | **Hybrid RoR2 + Hades.** Short dungeon bursts (Hades-like rooms/gauntlets). Every **~4–5 dungeons**, a **large RoR2-like open stage** (explore, farm power, timed pressure, teleporter/objective → boss or exit). |
| **L3** | Multiplayer | **Solo and co-op** are both first-class. Co-op must not be a bolted-on afterthought. |
| **L4** | Aesthetic / IP | **As close as legally safe** to *Vampire Hunter D: Bloodlust* mood, silhouette language, and world contrast—**original IP only**. No names, likenesses, plots, or unique creatures from Kikuchi/Amano/Madhouse works. |
| **L5** | Engine | **Godot** (version `OPEN`; default toward current stable 4.x unless human specifies). |

---

## 4. Design pillars

Agents use these as filters for every feature. If a proposal fails a pillar, cut or redesign it.

### P1 — Escalating hunt power
Runs reward greed and synergy until the player (or party) becomes a storm. Late-run builds should feel *dangerous and expressive*, not merely numerically bigger.

### P2 — Readable skill under chaos
Even with auto-weapons and screen density, telegraphs, spacing, and player decisions must remain readable. Auto-fire never excuses unfair deaths.

### P3 — Rhythm of pressure: burst → expanse
Dungeon bursts deliver tight, authored combat intensity. Wild stages deliver exploration, item economy, and RoR2-style time/greed tension. The alternation is the game’s heartbeat.

### P4 — Death continues the story
Failure advances hub relationships, lore crumbs, unlocks, or world reaction (Hades-inspired). Runs are chapters, not wasted time.

### P5 — Gothic frontier atmosphere
Every biome, enemy, and UI cue should feel like a **post-collapse frontier** colliding with **baroque noble horror**: dust and moonlight, ruin and ornament, loneliness and blood ritual. Style > generic dark fantasy.

### P6 — Together or alone, same fantasy
Solo must feel complete. Co-op must create *new* synergies (revive, shared risk, build interaction), not just parallel solo runs in one lobby.

---

## 5. Anti-pillars (explicit non-goals)

| Anti-pillar | Meaning |
|-------------|---------|
| **Not a Bloodlust clone** | No D, Left Hand as IP, named Nobles, Marcus brothers, or shot-for-shot set pieces. |
| **Not pure Vampire Survivors AFK** | Movement-only with zero attack decisions for *all* kits is invalid as the default fantasy. Hybrid means some kits lean auto; the game as a whole still rewards skill. |
| **Not pure Hades room slog** | Long stretches of only identical room clears without wild-stage breathing room violate L2. |
| **Not live-service treadmill** | No battle pass / FOMO economy in v1 mandate. |
| **Not cozy / whimsical** | Tone stays adult gothic pulp—melancholy, stylish, lethal. |
| **Not Souls-punishment-first** | Challenge yes; opaque cruelty and progress erasure no. |
| **Not purple-default AI look** | Avoid generic neon-purple “AI dark fantasy” and flat void backgrounds. Prefer painterly dust, crimson, bone, iron, moonlight. |

---

## 6. Reference hierarchy (conflict resolution)

When inspirations conflict, resolve in this order unless a **LOCKED** row says otherwise:

1. **LOCKED decisions (L1–L5)**  
2. **Pillars P1–P6**  
3. **Bloodlust-adjacent atmosphere** (mood, contrast, loneliness, chromegoth-vs-frontier)  
4. **Hades** — combat clarity, hub narrative, boon-like choice quality, death-as-progress  
5. **Risk of Rain 2** — wild-stage loop, greed vs timer, item stacking fantasy  
6. **Vampire Survivors** — horde density, frequent power choices, evolution/synergy juice  
7. **SWORN** — co-op blessing/build interplay, mythic cast structure (not art clone)  
8. **Tears of Metal** — optional army/companion spectacle (only if adopted in OPEN answers)

---

## 7. Core loop

### 7.1 Run spine (LOCKED shape)

```
Hub
  → Dungeon Burst 1 (short rooms / gauntlet)
  → Dungeon Burst 2
  → Dungeon Burst 3
  → Dungeon Burst 4
  → [optional Burst 5]
  → Wild Stage (large RoR2-like map: explore, kill, loot, pressure, objective)
  → Boss or stage exit
  → repeat biome cycle / escalate
  → Run climax boss or escape
  → Return to Hub (win or death)
```

**Cadence rule:** roughly **4–5 dungeon bursts per wild stage**. Exact counts may vary by biome if the *feel* of “short bursts then expanse” holds.

### 7.2 Dungeon burst (Hades-leaning)

- Tight arenas or linked rooms; clear → choose path/reward.
- High authored enemy choreography; strong readability.
- Rewards: boons/emblems/weapons/currency (`OPEN` exact economy).
- Duration target per burst: `OPEN` (suggested 3–8 minutes).

### 7.3 Wild stage (RoR2-leaning)

- Large navigable space; multiple interactables/chests/shrines.
- Enemy density and threat escalate with **time and/or player greed**.
- Core tension: linger for power vs push objective before the stage turns lethal.
- Objective pattern inspired by teleporter charge / boss hold — rename and reskin for original IP.
- Duration target: `OPEN` (suggested 8–15 minutes).

### 7.4 Full run length

`OPEN` — suggested design target **30–50 minutes** for a standard clear.

---

## 8. Combat mandate (L1 detail)

### 8.1 Hybrid model

- **Character archetypes** define a baseline control scheme (e.g. striker manual melee; gun-witch hybrid aim + auto familiars; cursed automaton mostly auto with active overclock). Exact roster: `OPEN`.
- **Weapons and pickups** can shift agency mid-run (picking up an orbiting blood-halo may add auto layers; a greatsword may demand manual commits).
- Co-op: kits should complement (crowd clear, disrupt, sustain, execute) without requiring voice chat.

### 8.2 Non-negotiable combat qualities

- Hit feedback and silhouette readability at horde density.
- Dodge/mobility as a first-class verb for skill kits.
- Bosses teach patterns; wild elites punish greed.
- Accessibility options planned early (`OPEN` list: god-mode-like assist, remaps, colorblind, etc.).

---

## 9. Progression & buildcraft

| Layer | Intent | Status |
|-------|--------|--------|
| In-run choices | Frequent meaningful upgrades; synergies that “break” runs | Direction locked; systems `OPEN` |
| Stacking items | RoR2-like multiplicative fantasy on wild stages | Desired |
| Choice boons | Hades-like offered upgrades in dungeon bursts | Desired |
| Evolutions / combos | VS-like “combine X+Y → evolved form” allowed | `OPEN` whether mandatory |
| Meta progression | Hub unlocks, weapons, characters, story; not empty grind | Desired; economy `OPEN` |
| Permanent army (ToM) | Companions that persist / can be lost | `OPEN` — opt-in pillar, not required |

**Broken-build policy (draft):** Late successful runs *should* feel godlike for stretches, then face a climax that reasserts threat. Exact tuning `OPEN`.

---

## 10. World & IP-safe Bloodlust DNA

### 10.1 Allowed inspiration (transform, don’t copy)

| Bloodlust quality | Translate to original IP as… |
|-------------------|------------------------------|
| Lonely hunter silhouette (hat, cloak, blade) | Original hunter cast with distinct silhouettes; no “D” identity |
| Gothic nobility + sci-fantasy ruins | “Old Blood” aristocracy / fallen star-courts in baroque metal & bone |
| Frontier human settlements | Dust towns, rail ghosts, sun-sick caravans |
| Day as threat / night as hunting ground | Own ruleset for light, curse, and noble activity |
| Beast-hybrid servants | Original bestiary taxonomy |
| Painterly cinematic action | Godot art direction: high-contrast, dusty air, ornate interiors |

### 10.2 Hard IP bans

- Names, titles, and unique terms from Vampire Hunter D novels/films/games  
- Character likenesses (D, Left Hand design-as-D’s-hand, specific nobles/hunters)  
- Plot lifts (kidnapping contract structure, specific castle set pieces as copies)  
- Amano design tracings or Madhouse still reproductions in shipping assets  

### 10.3 Narrative posture

- Tone: adult gothic pulp, melancholy cool, occasional dry wit.  
- Story weight: `OPEN` (recommended: Hades-like reactive hub dialogue + environmental lore).  
- Hub: `OPEN` (candidates: frontier waystation, ruined chapel-fort, moving hearse-caravan).  
- Death fiction: `OPEN` (candidates: dhampir-like regeneration, blood-pact recall, “the Hunt rewrites you”).

---

## 11. Art, audio, feel

| Topic | Mandate | Status |
|-------|---------|--------|
| Presentation | Prefer **2D or 2.5D** readable combat for Godot agent velocity; 3D only if human mandates | `OPEN` confirm |
| Color | Dust ochre, dried crimson, bone, iron black, cold moonlight—not neon purple default | Locked direction |
| Violence | Stylish blood ballet; intensity `OPEN` (restrained vs gore-forward) | `OPEN` |
| Music | Gothic western hybrid—strings, choir fragments, lonely guitar/percussion | Directional |
| Signature moments | Cape/moon silhouette; swarm dissolve; ornate noble interiors vs bleached flats | Desired |

---

## 12. Multiplayer mandate (L3)

- **Netcode approach:** `OPEN` (Godot multiplayer API / dedicated / P2P). Favor simplest robust approach for 1–4 players.  
- **Scaling:** Enemy HP/density and reward rules must be designed for solo *and* 2–4 from the start.  
- **Failure:** Shared run failure vs individual down/revive — `OPEN` (recommend downed state + timed wipe).  
- **Drop-in/drop-out:** `OPEN`.  
- **Progression ownership:** `OPEN` (host-owned campaign vs personal unlocks).

---

## 13. Technical & production (AI agent studio)

| Topic | Mandate |
|-------|---------|
| Engine | **Godot** (L5) |
| Repo layout | `OPEN` — suggest `game/` Godot project, `docs/` mandates, `art/`, `audio/` |
| First milestone | `OPEN` — recommended: **Vertical Slice** = 2 dungeon bursts + 1 wild stage + 1 boss + hub stub, solo, 1 character, 1 weapon family auto + 1 manual |
| Platforms | PC first; Steam Deck stretch; consoles later | `OPEN` confirm |
| Generative assets | Allowed for prototyping; shipping art must pass IP-safe + style guide review | Draft |
| Tests | Core loop playable headless where feasible; combat regression scenes | Desired |
| Charter updates | Human approves LOCKED changes; agents may propose PRs updating `OPEN` → proposed |

---

## 14. Audience & success

| Topic | Status |
|-------|--------|
| Primary audience | Fans of Hades combat clarity + RoR2 item chaos + gothic anime atmosphere | Draft |
| Business model | `OPEN` (recommend premium / Early Access) |
| Near-term success | Charter locked → playable Godot vertical slice fun in 20–30 min | Draft |
| Pivot triggers | `OPEN` |

---

## 15. Agent operating rules

1. **Read this charter before designing or implementing systems.**  
2. **Never violate L1–L5 or hard IP bans.**  
3. Prefer inventing within pillars over expanding scope.  
4. When unsure, propose 2 options in a short ADR (`docs/adr/`) rather than silently picking forever-impactful systems.  
5. Keep the fantasy test: *“Would this still feel like a lonely/blooded frontier hunt if we removed genre buzzwords?”*  
6. Co-op and solo must both be considered in any combat or economy change.  
7. Reference hierarchy (§6) settles taste debates.

---

## 16. OPEN questions backlog (human input needed)

Answer these to promote items from draft → locked.

### Identity
1. Working title / codename?  
2. Final one-sentence pitch in your voice?  
3. Tone rank order: lonely melancholy / stylish cool / dark humor / tragic romance / pulp horror?

### Combat & content
4. Confirm camera: top-down 2D, isometric 2.5D, or third-person 3D?  
5. Starter character archetypes (how many at vertical slice / at v1)?  
6. Exact in-run currency & reward types?  
7. Include Tears of Metal–style army/companions?  
8. Target run length and wild-stage timer rules?

### Narrative
9. Hub fantasy pick?  
10. Death fiction pick?  
11. Story weight: light / reactive dialogue / cinematic?

### Production
12. Godot version pin?  
13. First milestone acceptance criteria?  
14. Co-op player count max (2 or 4)?  
15. Business model and content rating target?  
16. Any signature mechanic that *only this game* must own?

---

## 17. Change log

| Version | Date | Notes |
|---------|------|-------|
| v0.1 | 2026-07-30 | Initial charter from reference research + human locks: hybrid combat, RoR2/Hades run cadence, solo+co-op, Bloodlust-adjacent original IP, Godot. |

---

## 18. Appendix — inspiration cheat sheet (for agents)

- **Risk of Rain 2:** time/greed tension; item stacks; large stage → objective → boss; looping power fantasy.  
- **Vampire Survivors:** horde density; frequent upgrades; evolution synergies; low friction *as a layer*, not the whole game.  
- **Hades:** room clarity; boon choices; hub that remembers you; death advances narrative.  
- **SWORN:** co-op action-roguelite structure; blessing × weapon × character permutations.  
- **Tears of Metal:** horde hack-and-slash spectacle; optional battalion layer; objective nodes.  
- **Vampire Hunter D: Bloodlust:** gothic × western × post-apoc; painterly dread; noble ornament vs frontier dust; lonely hunter myth—**inspire, do not infringe**.
