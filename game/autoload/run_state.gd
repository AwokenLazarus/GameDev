extends Node
## Per-run state. Cleared when a new raid begins.

signal timer_changed(seconds: float, difficulty: String)
signal kills_changed(current: int, needed: int)
signal boons_changed
signal alignment_changed(patron_id: String)
signal reputation_changed(value: int)
signal phase_changed(phase: String)
signal feed_buff_changed(stacks: int)
signal gear_changed
## A boon replaced another in the same slot (old may be empty).
signal boon_replaced(old: Dictionary, new: Dictionary)
## Deep pact reached (3rd boon from one patron). MWPactKit applies the passive + kit transform.
signal pact_formed(patron_id: String)
## A burst room or the wild map began (per-room boons reset on this).
signal room_started
signal greed_used(kind: String)

enum Phase { HUB, DUNGEON, WILD, BOSS, DEAD, VICTORY }

## Rival map option C (MW-018, approved; closes MW-007). Symmetric. Dust is the broker
## patron, Church stands alone.
const PATRON_RIVALS := {
	"dust_compact": ["church"],
	"red_petition": ["church", "house_veyra"],
	"house_veyra": ["church", "red_petition"],
	"church": ["dust_compact", "red_petition", "house_veyra"],
}

var phase: Phase = Phase.HUB
var character_id: String = "severin"
var alt_id: String = ""
var sector_id: String = "dust_meridian"
var player_count: int = 1

var run_time: float = 0.0
var timer_active: bool = false
var kills: int = 0
## Kill gate counts wild-stage kills only (burst kills no longer leak into it).
var wild_kills: int = 0
var kill_gate: int = 1150
## Moon altars push the director clock ahead without touching the sector timer.
var clock_bonus: float = 0.0
## Run-scoped chest haul, banked into meta currencies by grant_run_rewards.
var cache_blood: int = 0
var cache_ash: int = 0
var cache_tech: int = 0
var greed_log: Array[String] = []
var dungeon_index: int = 0
var dungeons_total: int = 5
var boon_picks_done: int = 0
var boon_picks_target: int = 8

var aligned_patron: String = ""
var blocked_patrons: Array[String] = []
var owned_boons: Array[Dictionary] = []
var patron_counts: Dictionary = {}
## One boon per slot (attack/special/cast/dash): slot -> boon id. Trigger boons have no cap.
var slot_boons: Dictionary = {}
## First patron to reach 3 boons; one pact per raid (it stays even if a boon is replaced).
var pact_patron: String = ""

var feed_count: int = 0
var reputation: int = 0
var feed_buff_stacks: int = 0
var feed_buff_timer: float = 0.0

var player_max_hp: float = 100.0
var player_hp: float = 100.0
var damage_mult: float = 1.0
var move_mult: float = 1.0
var attack_speed_mult: float = 1.0
var lifesteal: float = 0.0
var dash_mult: float = 1.0
var cooldown_mult: float = 1.0
var crit_chance: float = 0.0

## Light ARPG gear (run-only)
var gear_slots: Dictionary = {
	"charm": {},
	"relic": {},
	"coat": {},
}

var general_defeated: bool = false
var awaiting_boon: bool = false
var meta_mods: Dictionary = {}
var max_hit_taken: float = 0.0


func start_run(char_id: String = "severin", sector: String = "dust_meridian", alt: String = "", players: int = 1) -> void:
	character_id = char_id
	alt_id = alt
	sector_id = sector
	player_count = maxi(players, 1)
	phase = Phase.DUNGEON
	run_time = 0.0
	timer_active = true
	kills = 0
	wild_kills = 0
	clock_bonus = 0.0
	cache_blood = 0
	cache_ash = 0
	cache_tech = 0
	greed_log.clear()
	dungeon_index = 0
	boon_picks_done = 0
	boon_picks_target = 8
	aligned_patron = ""
	blocked_patrons.clear()
	owned_boons.clear()
	patron_counts.clear()
	slot_boons.clear()
	pact_patron = ""
	feed_count = 0
	reputation = 0
	feed_buff_stacks = 0
	feed_buff_timer = 0.0
	damage_mult = 1.0
	move_mult = 1.0
	attack_speed_mult = 1.0
	lifesteal = 0.0
	dash_mult = 1.0
	cooldown_mult = 1.0
	crit_chance = 0.0
	gear_slots = {"charm": {}, "relic": {}, "coat": {}}
	general_defeated = false
	awaiting_boon = false
	max_hit_taken = 0.0

	var sector_data: Dictionary = SectorDB.get_sector(sector_id) if SectorDB else {}
	dungeons_total = int(sector_data.get("burst_count", 5))
	var gate_base := int(sector_data.get("kill_gate_base", 1150))
	kill_gate = _scaled_kill_gate(gate_base, player_count)

	var char_data: Dictionary = CharacterDB.get_character(character_id) if CharacterDB else {}
	var base_hp := float(char_data.get("base_hp", 100.0))
	meta_mods = MetaDB.apply_ranks_to_run({"meta_ranks": GameState.meta_ranks}) if MetaDB else {}
	base_hp += float(meta_mods.get("max_hp_bonus", 0.0))
	damage_mult += float(meta_mods.get("damage_bonus", 0.0))
	move_mult += float(meta_mods.get("move_bonus", 0.0))
	attack_speed_mult += float(meta_mods.get("attack_speed_bonus", 0.0))
	lifesteal += float(meta_mods.get("lifesteal_bonus", 0.0))
	dash_mult += float(meta_mods.get("dash_bonus", 0.0))
	## Killgate Scanner rank = −2 in the old 40-kill scale; keep its share (5 %/rank).
	var scanner := float(meta_mods.get("kill_gate_bonus", 0)) * 0.025
	kill_gate = maxi(int(float(gate_base) * 0.4), int(float(kill_gate) * (1.0 + scanner)))
	boon_picks_target += int(meta_mods.get("boon_picks_bonus", 0))
	if alt_id != "" and CharacterDB:
		var alts: Array = CharacterDB.get_alts(character_id)
		for a in alts:
			if str(a.get("id", "")) == alt_id:
				var mods: Dictionary = a.get("kit_modifiers", {})
				base_hp += float(mods.get("base_hp", 0.0))
				break
	player_max_hp = base_hp
	player_hp = base_hp

	phase_changed.emit("dungeon")
	kills_changed.emit(wild_kills, kill_gate)
	gear_changed.emit()


## Tuning (MW-025): ~30 min sector at a human kill rate (~1 kill / 1.2 s);
## the wild stage is ~80 % of it. See game/README.md "Pacing".
const CLOCK_FULL := 1500.0 ## director / enemy scaling reaches 1.0 at 25 min
const GATE_PER_EXTRA_PLAYER := 0.35


func _scaled_kill_gate(base: int, players: int) -> int:
	## Co-op kills faster; the director also spawns more per player (see get_director_intensity).
	var g: int = int(float(base) * (1.0 + GATE_PER_EXTRA_PLAYER * float(maxi(players - 1, 0))))
	match GameState.selected_difficulty:
		"blood":
			g = int(float(g) * 1.15)
		"eclipse":
			g = int(float(g) * 1.3)
	if "swarm" in GameState.heat_modifiers:
		g = int(float(g) * 1.1)
	return g


func _process(delta: float) -> void:
	if not timer_active:
		return
	if phase == Phase.HUB or phase == Phase.DEAD or phase == Phase.VICTORY:
		return
	run_time += delta
	timer_changed.emit(run_time, get_difficulty_label())
	if feed_buff_timer > 0.0:
		feed_buff_timer -= delta
		if feed_buff_timer <= 0.0:
			feed_buff_stacks = 0
			feed_buff_changed.emit(0)


func get_difficulty_label() -> String:
	## In-run escalating label (RoR2-like), distinct from story difficulty select.
	var prefix := GameState.difficulty_label()
	var c := difficulty_clock()
	if c < 300.0:
		return prefix
	if c < 720.0:
		return prefix + "→Blood"
	if c < 1200.0:
		return prefix + "→Eclipse"
	return prefix + "→Pale"


## Sector timer plus altar debt; drives the director, elites and enemy scaling.
func difficulty_clock() -> float:
	return run_time + clock_bonus


## 0 at sector start → 1 at 25 min on the difficulty clock; keeps creeping past it.
func difficulty_ramp() -> float:
	var c := difficulty_clock()
	if c <= CLOCK_FULL:
		return c / CLOCK_FULL
	return 1.0 + minf((c - CLOCK_FULL) / 1200.0, 0.5)


func get_director_intensity() -> float:
	var base := 0.2 + 1.6 * difficulty_ramp()
	base *= GameState.difficulty_enemy_mult() * 0.65 + 0.35
	base *= 1.0 + 0.3 * float(maxi(player_count - 1, 0))
	return base


## Director spawns get tougher as the clock runs (burst rooms use it too).
func enemy_hp_time_mult() -> float:
	return 1.0 + 0.6 * difficulty_ramp()


func enemy_damage_time_mult() -> float:
	return 1.0 + 0.35 * difficulty_ramp()


func set_phase(p: Phase) -> void:
	phase = p
	var names := {
		Phase.HUB: "hub",
		Phase.DUNGEON: "dungeon",
		Phase.WILD: "wild",
		Phase.BOSS: "boss",
		Phase.DEAD: "dead",
		Phase.VICTORY: "victory",
	}
	phase_changed.emit(names.get(p, "unknown"))


func register_kill(_is_human: bool = false) -> void:
	kills += 1
	if phase == Phase.WILD:
		wild_kills += 1
	kills_changed.emit(wild_kills, kill_gate)


func can_spawn_general() -> bool:
	return wild_kills >= kill_gate and phase == Phase.WILD and not general_defeated


func note_greed(kind: String) -> void:
	greed_log.append(kind)
	greed_used.emit(kind)


func add_cache(blood: int, ash: int, tech: int) -> void:
	cache_blood += blood
	cache_ash += ash
	cache_tech += tech


func try_align(patron_id: String) -> bool:
	if patron_id in blocked_patrons:
		return false
	if aligned_patron == "":
		aligned_patron = patron_id
		var rivals: Array = PATRON_RIVALS.get(patron_id, [])
		for r in rivals:
			if str(r) not in blocked_patrons:
				blocked_patrons.append(str(r))
		## Feeding + church tension
		alignment_changed.emit(patron_id)
	elif patron_id in blocked_patrons:
		return false
	return true


func add_boon(boon: Dictionary) -> void:
	if bool(boon.get("is_fallback", false)):
		## Thin-pool heal: counts as a pick, doesn't align.
		boon_picks_done += 1
		player_hp = minf(player_hp + float(boon.get("heal", 0.0)), player_max_hp)
		for p in get_tree().get_nodes_in_group("player"):
			var h: Health = p.get_node_or_null("Health")
			if h:
				h.heal(float(boon.get("heal", 0.0)))
		boons_changed.emit()
		return
	var patron: String = str(boon.get("patron", ""))
	var id := str(boon.get("id", ""))
	if has_boon(id):
		return
	if not try_align(patron):
		return
	var slot := str(boon.get("slot", "trigger"))
	var old: Dictionary = {}
	if slot in ["attack", "special", "cast", "dash"]:
		if slot_boons.has(slot):
			old = remove_boon(str(slot_boons[slot]))
		slot_boons[slot] = id
	owned_boons.append(boon)
	boon_picks_done += 1
	patron_counts[patron] = int(patron_counts.get(patron, 0)) + 1
	if pact_patron == "" and int(patron_counts.get(patron, 0)) >= 3:
		_apply_pact_transform(patron)
	## Church hates feeding more
	if patron == "church" and feed_count > 0:
		reputation -= 1
		reputation_changed.emit(reputation)
	if not old.is_empty():
		boon_replaced.emit(old, boon)
	boons_changed.emit()


## Drops an owned boon (slot replacement). Returns it, or {} if not owned.
func remove_boon(id: String) -> Dictionary:
	for i in owned_boons.size():
		var b: Dictionary = owned_boons[i]
		if str(b.get("id", "")) != id:
			continue
		owned_boons.remove_at(i)
		var patron := str(b.get("patron", ""))
		patron_counts[patron] = maxi(0, int(patron_counts.get(patron, 0)) - 1)
		var slot := str(b.get("slot", ""))
		if str(slot_boons.get(slot, "")) == id:
			slot_boons.erase(slot)
		return b
	return {}


func has_boon(id: String) -> bool:
	for b in owned_boons:
		if str(b.get("id", "")) == id:
			return true
	return false


## What taking `boon` would replace (same slot), or {}.
func boon_in_slot(slot: String) -> Dictionary:
	if not slot_boons.has(slot):
		return {}
	return BoonDB.get_boon(str(slot_boons[slot])) if BoonDB else {}


func begin_room() -> void:
	room_started.emit()


func _apply_pact_transform(patron: String) -> void:
	## Each sibling's MWPactKit hears this and rewrites its weapon (no damage multiplier).
	pact_patron = patron
	pact_formed.emit(patron)


func has_pact(patron: String) -> bool:
	return patron != "" and pact_patron == patron


## The pact `player` fights under ("" = none). Every pact read goes through here. It is
## party-wide today because the loadout is shared (MW-006); per-player pacts (MW-027 /
## MW-011) only need to change this function.
func pact_of(_player: Node) -> String:
	return pact_patron


func patron_display(patron: String) -> String:
	match patron:
		"dust_compact":
			return "Dust Compact"
		"red_petition":
			return "Red Petition"
		"house_veyra":
			return "House Veyra"
		"church":
			return "Church of the Pale Sun"
		"mayor":
			return "Mayor's Office"
	return patron


func feed_on_human() -> void:
	feed_count += 1
	reputation -= 1
	if aligned_patron == "church":
		reputation -= 1
	feed_buff_stacks = mini(feed_buff_stacks + 1, 5)
	feed_buff_timer = 20.0
	reputation_changed.emit(reputation)
	feed_buff_changed.emit(feed_buff_stacks)


func get_feed_damage_bonus() -> float:
	return 0.12 * float(feed_buff_stacks)


func get_feed_lifesteal_bonus() -> float:
	return 0.04 * float(feed_buff_stacks)


func reputation_label() -> String:
	if reputation >= 0:
		return "Neutral"
	if reputation >= -2:
		return "Wary"
	if reputation >= -5:
		return "Feared"
	return "Hated"


func note_hit(amount: float) -> void:
	if amount > max_hit_taken:
		max_hit_taken = amount
	print("MW022_HIT amount=%.1f max_hit=%.1f" % [amount, max_hit_taken])


func equip_gear(slot: String, item: Dictionary) -> void:
	if not gear_slots.has(slot):
		return
	var old: Dictionary = gear_slots[slot]
	if not old.is_empty():
		_apply_gear_stats(old, -1.0)
	gear_slots[slot] = item
	_apply_gear_stats(item, 1.0)
	gear_changed.emit()


func _apply_gear_stats(item: Dictionary, sign: float) -> void:
	damage_mult += sign * float(item.get("damage", 0.0))
	move_mult += sign * float(item.get("move", 0.0))
	lifesteal += sign * float(item.get("lifesteal", 0.0))
	var hp_delta := sign * float(item.get("max_hp", 0.0))
	player_max_hp = maxf(1.0, player_max_hp + hp_delta)
	if sign > 0.0:
		player_hp = minf(player_hp + hp_delta, player_max_hp)
	else:
		player_hp = clampf(player_hp, 1.0, player_max_hp)


func grant_run_rewards(victory: bool) -> void:
	## Wild kills are now in the hundreds; keep the old ~8 Blood for a full gate.
	var blood_gain := 5 + (kills - wild_kills) / 5 + wild_kills / 125 + feed_count * 3
	## Chest haul survives death at half value.
	var keep := 1.0 if victory else 0.5
	blood_gain += int(float(cache_blood) * keep)
	var ash_gain := 8 if victory else 3
	var tech_gain := 4 if victory else 1
	ash_gain += int(float(cache_ash) * keep)
	tech_gain += int(float(cache_tech) * keep)
	if victory:
		blood_gain += 15
		tech_gain += 6
		ash_gain += 10
	if sector_id == "pale_spire" and victory:
		blood_gain += 40
		tech_gain += 25
		ash_gain += 20
	## Meta earn-weight bonuses
	blood_gain = int(blood_gain * (1.0 + float(meta_mods.get("blood_earn", 0.0))))
	ash_gain = int(ash_gain * (1.0 + float(meta_mods.get("ash_earn", 0.0))))
	tech_gain = int(tech_gain * (1.0 + float(meta_mods.get("tech_earn", 0.0))))
	GameState.add_currency("blood", blood_gain)
	GameState.add_currency("ash", ash_gain)
	GameState.add_currency("tech", tech_gain)


func end_to_hub() -> void:
	timer_active = false
	set_phase(Phase.HUB)
