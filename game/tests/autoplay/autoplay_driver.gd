extends Node
## Headless full-raid bot. Args after `--`:
##   mode=kill|idle|human  sectors=all|id,id  char=severin  seed=N
## Always run with `--fixed-fps 60`. Prints one RESULT line per sector, then AUTOPLAY_DONE.
## kill mode exits 1 if any sector does not reach Ashwick.
## Profiles (MW-025): kill = fast regression bot (1 kill / 0.4 s, random doors);
## human = pacing estimate (1 kill / 1.2 s, reads boons, walks to doors, prefers Pact doors).
## Both are invulnerable (HP refilled) and walk the wild greed interactables; idle does nothing.

const KILL_EVERY := 0.4
const HUMAN_KILL_EVERY := 1.2
const HUMAN_BOON_READ_S := 4.0
const HUMAN_DOOR_THINK_S := 2.0
const HUMAN_PACT_BIAS := 0.75
const HUMAN_FEED_EVERY := 15.0
const SECTOR_TIMEOUT := 3600.0
const SAVE_PATH := "user://moonwake_save.json"
const SAVE_BAK := "user://moonwake_save.autoplay.bak"

var mode := "kill"
var sectors: Array[String] = []
var char_id := "severin"
var seed_value := 1
var si := 0
var t := 0.0
var phase_t := {}
var kill_acc := 0.0
var feed_acc := 0.0
var dmg_taken := 0.0
var max_hit := 0.0
var run_start := 0.0
var hp_prev := -1.0
var closing := false
var failed := false
var hooked_health: Health
var rng := RandomNumberGenerator.new()
var save_had_file := false
var boon_wait := 0.0
var door_wait := -1.0
var greed_target: Node2D = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_parse_args()
	_snapshot_save()
	_reset_meta()
	_apply_seed()
	RunState.phase_changed.connect(_on_phase)
	print(
		"AUTOPLAY_START mode=%s sectors=%s char=%s seed=%d"
		% [mode, ",".join(sectors), char_id, seed_value]
	)
	_start()


func _parse_args() -> void:
	var raw_sectors := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("mode="):
			mode = a.substr(5).strip_edges()
		elif a.begins_with("sectors="):
			raw_sectors = a.substr(8).strip_edges()
		elif a.begins_with("char="):
			char_id = a.substr(5).strip_edges()
		elif a.begins_with("seed="):
			seed_value = int(a.substr(5))
	if mode not in ["kill", "idle", "human"]:
		push_warning("Unknown autoplay mode '%s', using kill" % mode)
		mode = "kill"
	if char_id.is_empty():
		char_id = "severin"
	sectors = _resolve_sectors(raw_sectors)


func _resolve_sectors(raw: String) -> Array[String]:
	var out: Array[String] = []
	if raw.is_empty() or raw == "all":
		for s in SectorDB.all_raidable_sectors():
			var id := str(s.get("id", ""))
			if not id.is_empty():
				out.append(id)
		return out
	for part in raw.split(",", false):
		var id := part.strip_edges()
		if id == "all":
			return _resolve_sectors("all")
		if not id.is_empty():
			out.append(id)
	return out


func _apply_seed() -> void:
	var s := seed_value + si * 10007
	seed(s)
	rng.seed = s


func _snapshot_save() -> void:
	save_had_file = FileAccess.file_exists(SAVE_PATH)
	if save_had_file:
		var src := FileAccess.open(SAVE_PATH, FileAccess.READ)
		var dst := FileAccess.open(SAVE_BAK, FileAccess.WRITE)
		if src and dst:
			dst.store_buffer(src.get_buffer(src.get_length()))


func _restore_save() -> void:
	if save_had_file and FileAccess.file_exists(SAVE_BAK):
		var src := FileAccess.open(SAVE_BAK, FileAccess.READ)
		var dst := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if src and dst:
			dst.store_buffer(src.get_buffer(src.get_length()))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_BAK))
	elif not save_had_file and FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func _reset_meta() -> void:
	## Isolate harness from a loaded user save (difficulty / NG+ / meta ranks).
	GameState.selected_difficulty = "dust"
	GameState.ng_plus = 0
	GameState.aurelian_defeated = false
	GameState.heat_modifiers.clear()
	GameState.meta_ranks.clear()
	GameState.sectors_cleared.clear()


func _start() -> void:
	closing = false
	_reset_meta()
	_apply_seed()
	GameState.selected_sector = sectors[si]
	GameState.set_party_solo(char_id, "")
	phase_t = {}
	run_start = t
	dmg_taken = 0.0
	max_hit = 0.0
	hp_prev = -1.0
	kill_acc = 0.0
	feed_acc = 0.0
	boon_wait = 0.0
	door_wait = -1.0
	greed_target = null
	hooked_health = null
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/sector/sector_run.tscn")


func _on_phase(p: String) -> void:
	phase_t[p] = snappedf(t - run_start, 0.1)
	if p == "dead":
		_finish("DIED")


func _finish(outcome: String) -> void:
	if closing:
		return
	closing = true
	if not phase_t.has(outcome.to_lower()):
		phase_t[outcome.to_lower()] = snappedf(t - run_start, 0.1)
	var line := (
		"RESULT sector=%s mode=%s char=%s seed=%d outcome=%s run_time=%.1f kills=%d wild_kills=%d gate=%d boons=%d feeds=%d greed=%d dmg_taken=%.0f max_hit=%.1f phases=%s dur=%s"
		% [
			sectors[si],
			mode,
			char_id,
			seed_value,
			outcome,
			RunState.run_time,
			RunState.kills,
			RunState.wild_kills,
			RunState.kill_gate,
			RunState.boon_picks_done,
			RunState.feed_count,
			RunState.greed_log.size(),
			dmg_taken,
			max_hit,
			JSON.stringify(phase_t),
			JSON.stringify(_durations()),
		]
	)
	print(line)
	if mode == "kill" and outcome != "CLEARED":
		failed = true
	si += 1
	if si >= sectors.size():
		_shutdown()
		return
	await get_tree().create_timer(0.15).timeout
	_start()


## Phase lengths in simulated seconds (includes boon-pause time; run_time does not).
func _durations() -> Dictionary:
	var d := {}
	if phase_t.has("wild"):
		d["bursts"] = phase_t["wild"]
		if phase_t.has("boss"):
			d["wild"] = snappedf(float(phase_t["boss"]) - float(phase_t["wild"]), 0.1)
			if phase_t.has("victory"):
				d["boss"] = snappedf(float(phase_t["victory"]) - float(phase_t["boss"]), 0.1)
	return d


func _shutdown() -> void:
	_restore_save()
	print("AUTOPLAY_DONE")
	get_tree().quit(1 if failed else 0)


func _process(delta: float) -> void:
	t += delta
	if closing:
		return
	if t - run_start > SECTOR_TIMEOUT:
		_finish("TIMEOUT")
		return
	var sc := get_tree().current_scene
	if sc == null:
		return
	var path := sc.scene_file_path
	if path.ends_with("ashwick.tscn"):
		_finish("CLEARED")
		return
	if path.ends_with("death_screen.tscn"):
		_finish("DIED")
		return
	var pl := get_tree().get_first_node_in_group("player")
	if pl:
		_hook_player(pl)
		_track_hp(pl)
	if mode == "idle":
		return
	_try_pick_boon(sc, delta)
	if get_tree().paused:
		return
	_try_pick_door(pl, delta)
	if pl:
		_greed_walk(pl, delta)
	_kill_tick(delta)
	_feed_tick(delta)


func _try_pick_boon(sc: Node, delta: float) -> void:
	var bui := sc.get_node_or_null("BoonSelect")
	if bui == null or not bui.visible:
		boon_wait = 0.0
		return
	var choices: Array = bui._choices
	if choices.is_empty():
		return
	if mode == "human":
		boon_wait += delta
		if boon_wait < HUMAN_BOON_READ_S:
			return
	boon_wait = 0.0
	bui._pick(choices[rng.randi() % choices.size()])


func _try_pick_door(pl: Node2D, delta: float) -> void:
	var doors := get_tree().get_nodes_in_group("exit_door")
	var open: Array[Node] = []
	for d in doors:
		if d != null and is_instance_valid(d) and not bool(d.get("claimed")):
			open.append(d)
	if open.is_empty():
		door_wait = -1.0
		return
	var pick: Node = open[rng.randi() % open.size()]
	if mode == "human":
		for d in open:
			if str(d.get("reward")) == "boon" and rng.randf() < HUMAN_PACT_BIAS:
				pick = d
				break
		if door_wait < 0.0:
			## Think, then walk over (door choice happens in real time; the timer runs).
			var dist := 0.0
			if pl and pick is Node2D:
				dist = pl.global_position.distance_to((pick as Node2D).global_position)
			door_wait = HUMAN_DOOR_THINK_S + dist / _walk_speed(pl)
		door_wait -= delta
		if door_wait > 0.0:
			return
	door_wait = -1.0
	if pick.has_method("choose"):
		pick.choose()


func _walk_speed(pl: Node) -> float:
	var sp := 220.0
	if pl and pl.get("move_speed") != null:
		sp = float(pl.get("move_speed"))
	return maxf(60.0, sp * RunState.move_mult)


## Walk the lead to the nearest unused greed interactable (real movement; channel happens in-game).
func _greed_walk(pl: Node2D, delta: float) -> void:
	if RunState.phase != RunState.Phase.WILD:
		greed_target = null
		return
	if greed_target == null or not is_instance_valid(greed_target) or bool(greed_target.get("used")):
		greed_target = null
		var best := INF
		for g in get_tree().get_nodes_in_group("greed_shrine"):
			if bool(g.get("used")):
				continue
			var dd := pl.global_position.distance_to((g as Node2D).global_position)
			if dd < best:
				best = dd
				greed_target = g
	if greed_target == null:
		return
	pl.global_position = pl.global_position.move_toward(greed_target.global_position, _walk_speed(pl) * delta)


func _hook_player(pl: Node) -> void:
	var h: Health = pl.get_node_or_null("Health")
	if h == null or h == hooked_health:
		return
	if hooked_health and is_instance_valid(hooked_health) and hooked_health.damaged.is_connected(_on_player_damaged):
		hooked_health.damaged.disconnect(_on_player_damaged)
	hooked_health = h
	if not h.damaged.is_connected(_on_player_damaged):
		h.damaged.connect(_on_player_damaged)


func _on_player_damaged(amount: float, _remaining: float) -> void:
	if amount > 0.0:
		dmg_taken += amount
		if amount > max_hit:
			max_hit = amount
	if mode != "idle" and hooked_health and is_instance_valid(hooked_health):
		## Restore before Health.take_damage emits died (it checks hp after this signal).
		hooked_health.hp = hooked_health.max_hp
		RunState.player_hp = hooked_health.hp


func _track_hp(pl: Node) -> void:
	var h: Health = pl.get_node_or_null("Health")
	if h == null:
		return
	if hp_prev >= 0.0 and h.hp < hp_prev:
		var hit := hp_prev - h.hp
		## Signal path already counted; this catches direct hp writes.
		if hooked_health != h:
			dmg_taken += hit
			if hit > max_hit:
				max_hit = hit
	if mode != "idle":
		h.hp = h.max_hp
		RunState.player_hp = h.hp
	hp_prev = h.hp


func _kill_tick(delta: float) -> void:
	kill_acc += delta
	if kill_acc < (HUMAN_KILL_EVERY if mode == "human" else KILL_EVERY):
		return
	kill_acc = 0.0
	var es := get_tree().get_nodes_in_group("enemy")
	if es.is_empty():
		return
	var e: Node = es[0]
	var eh: Health = e.get_node_or_null("Health")
	if eh == null:
		return
	var chunk := eh.max_hp * (0.05 if e.is_in_group("boss") else 1.0) + 1.0
	eh.take_damage(chunk)


func _feed_tick(delta: float) -> void:
	feed_acc += delta
	## Humans feed now and then (it costs them a beat); the kill bot feeds greedily.
	if feed_acc < (HUMAN_FEED_EVERY if mode == "human" else 0.35):
		return
	feed_acc = 0.0
	var corpses := get_tree().get_nodes_in_group("feedable_corpse")
	if corpses.is_empty():
		return
	if mode != "human" and rng.randf() >= 0.5:
		return
	var c: Node = corpses[0]
	RunState.feed_on_human()
	if c.has_method("consume"):
		c.consume()
	else:
		c.queue_free()
