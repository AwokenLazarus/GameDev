extends Node
## Per-run state. Cleared when a new raid begins.

signal timer_changed(seconds: float, difficulty: String)
signal kills_changed(current: int, needed: int)
signal boons_changed
signal alignment_changed(patron_id: String)
signal reputation_changed(value: int)
signal phase_changed(phase: String)
signal feed_buff_changed(stacks: int)

enum Phase { HUB, DUNGEON, WILD, BOSS, DEAD, VICTORY }

const PATRON_RIVALS := {
	"dust_compact": ["church"],
	"red_petition": ["mayor"],
	"house_veyra": ["church"],
	"church": ["dust_compact", "house_veyra"],
}

var phase: Phase = Phase.HUB
var character_id: String = "severin"
var sector_id: String = "dust_meridian"

var run_time: float = 0.0
var timer_active: bool = false
var kills: int = 0
var kill_gate: int = 40
var dungeon_index: int = 0
var dungeons_total: int = 5
var boon_picks_done: int = 0
var boon_picks_target: int = 8

var aligned_patron: String = ""
var blocked_patrons: Array[String] = []
var owned_boons: Array[Dictionary] = []
var patron_counts: Dictionary = {} ## patron_id -> count

var feed_count: int = 0
var reputation: int = 0 ## 0 neutral, negative = feared/hated this run
var feed_buff_stacks: int = 0
var feed_buff_timer: float = 0.0

var player_max_hp: float = 100.0
var player_hp: float = 100.0
var damage_mult: float = 1.0
var move_mult: float = 1.0
var attack_speed_mult: float = 1.0
var lifesteal: float = 0.0
var dash_mult: float = 1.0

var general_defeated: bool = false
var awaiting_boon: bool = false


func start_run(char_id: String = "severin", sector: String = "dust_meridian") -> void:
	character_id = char_id
	sector_id = sector
	phase = Phase.DUNGEON
	run_time = 0.0
	timer_active = true
	kills = 0
	kill_gate = _scaled_kill_gate(1)
	dungeon_index = 0
	dungeons_total = 5
	boon_picks_done = 0
	aligned_patron = ""
	blocked_patrons.clear()
	owned_boons.clear()
	patron_counts.clear()
	feed_count = 0
	reputation = 0
	feed_buff_stacks = 0
	feed_buff_timer = 0.0
	player_max_hp = 100.0
	player_hp = 100.0
	damage_mult = 1.0
	move_mult = 1.0
	attack_speed_mult = 1.0
	lifesteal = 0.0
	dash_mult = 1.0
	general_defeated = false
	awaiting_boon = false
	phase_changed.emit("dungeon")
	kills_changed.emit(kills, kill_gate)


func _scaled_kill_gate(player_count: int) -> int:
	## V0 solo baseline; scales with players later.
	return 40 + 12 * max(player_count - 1, 0)


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
			_recompute_stats()


func get_difficulty_label() -> String:
	if run_time < 90.0:
		return "Dust"
	if run_time < 180.0:
		return "Blood"
	if run_time < 300.0:
		return "Eclipse"
	return "Pale"


func get_director_intensity() -> float:
	## 0..1+ spawn pressure for director.
	return clampf(run_time / 240.0, 0.15, 1.8)


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


func register_kill(is_human: bool = false) -> void:
	kills += 1
	kills_changed.emit(kills, kill_gate)
	if is_human:
		pass


func can_spawn_general() -> bool:
	return kills >= kill_gate and phase == Phase.WILD and not general_defeated


func try_align(patron_id: String) -> bool:
	if patron_id in blocked_patrons:
		return false
	if aligned_patron == "":
		aligned_patron = patron_id
		var rivals: Array = PATRON_RIVALS.get(patron_id, [])
		for r in rivals:
			if str(r) not in blocked_patrons:
				blocked_patrons.append(str(r))
		alignment_changed.emit(patron_id)
	elif aligned_patron != patron_id:
		## Allowed if not rival; multi-patron non-rival mixes OK until rival touch.
		if patron_id in blocked_patrons:
			return false
	return true


func add_boon(boon: Dictionary) -> void:
	var patron: String = str(boon.get("patron", ""))
	if not try_align(patron):
		return
	owned_boons.append(boon)
	boon_picks_done += 1
	patron_counts[patron] = int(patron_counts.get(patron, 0)) + 1
	_apply_boon_stats(boon)
	## Deep pact at 3+
	if int(patron_counts.get(patron, 0)) == 3:
		_apply_pact_transform(patron)
	boons_changed.emit()


func _apply_boon_stats(boon: Dictionary) -> void:
	damage_mult += float(boon.get("damage", 0.0))
	move_mult += float(boon.get("move", 0.0))
	attack_speed_mult += float(boon.get("attack_speed", 0.0))
	lifesteal += float(boon.get("lifesteal", 0.0))
	dash_mult += float(boon.get("dash", 0.0))
	player_max_hp += float(boon.get("max_hp", 0.0))
	player_hp = minf(player_hp + float(boon.get("max_hp", 0.0)), player_max_hp)


func _apply_pact_transform(patron: String) -> void:
	## Marks pact; player reads RunState.has_pact(patron).
	owned_boons.append({
		"id": "pact_%s" % patron,
		"patron": patron,
		"name": "Deep Pact",
		"desc": "Your moon-edge rewrites under %s." % patron_display(patron),
		"is_pact": true,
	})


func has_pact(patron: String) -> bool:
	return int(patron_counts.get(patron, 0)) >= 3


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
	return patron


func feed_on_human() -> void:
	feed_count += 1
	reputation -= 1
	feed_buff_stacks = mini(feed_buff_stacks + 1, 5)
	feed_buff_timer = 20.0
	_recompute_stats()
	reputation_changed.emit(reputation)
	feed_buff_changed.emit(feed_buff_stacks)


func _recompute_stats() -> void:
	## Feed buff: temporary damage/lifesteal from stacks (on top of boons).
	pass


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


func grant_run_rewards(victory: bool) -> void:
	var blood_gain := 5 + kills / 5 + feed_count * 2
	var ash_gain := 8 if victory else 3
	var tech_gain := 4 if victory else 1
	if victory:
		blood_gain += 15
		tech_gain += 6
	GameState.add_currency("blood", blood_gain)
	GameState.add_currency("ash", ash_gain)
	GameState.add_currency("tech", tech_gain)


func end_to_hub() -> void:
	timer_active = false
	set_phase(Phase.HUB)
