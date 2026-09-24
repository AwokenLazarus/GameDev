extends Node2D
## Headless (MW-030): every general has >=2 HP phases and >=3 telegraphed moves, a phase-2
## move no other sector general has, and every move can land on a standing player.
## Phase thresholds switch the rotation, adds spawn where the table says, and rout on death.

const PLAYER := preload("res://scenes/entities/player.tscn")
const GENERAL := preload("res://scenes/entities/general.tscn")
const GENERALS := ["marshal_hale", "lady_sable", "marrowfang", "cantor_belis", "provost_rhea", "duke_orlokis", "admiral_drus", "aurelian"]
const BOSS_AT := Vector2(0, -100)
const PLAYER_AT := Vector2(0, 120)

var _hits: int = 0


func _ready() -> void:
	print("BOSS_PHASES_START")
	var failures: Array[String] = []
	failures.append_array(_check_tables())
	for gid in GENERALS:
		failures.append_array(await _check_general(gid))
	if failures.is_empty():
		print("BOSS_PHASES_PASS")
		get_tree().quit(0)
		return
	for f in failures:
		push_error("BOSS_PHASES_FAIL " + f)
		print("BOSS_PHASES_FAIL ", f)
	get_tree().quit(1)


func _moves_of(phase: Dictionary) -> Array:
	return phase.get("moves", [])


func _check_tables() -> Array[String]:
	var fails: Array[String] = []
	var p2_owner: Dictionary = {} ## phase-2-only move -> general
	for gid in GENERALS:
		var phases: Array = SectorDB.get_general(gid).get("phases", [])
		var need := 3 if gid == "aurelian" else 2
		if phases.size() < need:
			fails.append("%s has %d phases (< %d)" % [gid, phases.size(), need])
			continue
		var all: Dictionary = {}
		for ph in phases:
			for m in _moves_of(ph):
				all[m] = true
		if all.size() < 3:
			fails.append("%s has %d distinct moves (< 3)" % [gid, all.size()])
		var p1 := _moves_of(phases[0])
		var fresh: Array = _moves_of(phases[1]).filter(func(m): return not p1.has(m))
		if fresh.is_empty():
			fails.append("%s phase 2 adds no new move" % gid)
		if gid != "aurelian":
			for m in fresh:
				if p2_owner.has(m) and p2_owner[m] != gid:
					fails.append("%s phase-2 move %s also used by %s" % [gid, m, p2_owner[m]])
				p2_owner[m] = gid
		for i in range(1, phases.size()):
			var ph: Dictionary = phases[i]
			if ph.get("adds", {}).is_empty() and ph.get("hazard", {}).is_empty():
				fails.append("%s phase %d has neither adds nor hazard" % [gid, i + 1])
	var hale: Array = SectorDB.get_general("marshal_hale").get("phases", [])
	if hale.size() >= 2 and (hale[1] as Dictionary).get("adds", {}).is_empty():
		fails.append("marshal_hale phase 2 has no adds")
	print("TABLES_OK fails=", fails.size())
	return fails


func _check_general(gid: String) -> Array[String]:
	var fails: Array[String] = []
	var arena := Node2D.new()
	add_child(arena)
	var p: Node = PLAYER.instantiate()
	p.configure(0, "severin")
	arena.add_child(p)
	p.global_position = PLAYER_AT
	p.set_physics_process(false)
	var ph: Health = p.get_node("Health")
	ph.max_hp = 100000.0
	ph.hp = ph.max_hp
	ph.damaged.connect(func(_a: float, _r: float): _hits += 1)
	var b: Node = GENERAL.instantiate()
	arena.add_child(b)
	b.configure(gid)
	b.global_position = BOSS_AT
	b.set_physics_process(false) ## drive moves by hand
	b.set("_player", p)
	await get_tree().process_frame

	## Every move in every phase fires; count how many land on a standing player.
	var moves: Dictionary = {}
	for phase in b.phases:
		for m in _moves_of(phase):
			moves[m] = true
	var landed := 0
	for m in moves.keys():
		## Ranged moves are tried from 220 px, point-blank ones (slam, hymn, void) from 60 px.
		var hits := 0
		for at in [PLAYER_AT, BOSS_AT + Vector2(0, 60)]:
			b.global_position = BOSS_AT
			p.global_position = at
			ph.invuln_timer = 0.0
			ph.hp = ph.max_hp
			_hits = 0
			await b.call("_run_move", m)
			await _wait(0.9)
			hits = _hits
			if hits > 0:
				break
		if hits > 0:
			landed += 1
		print("MOVE ", gid, " ", m, " hits=", hits)
	if landed < moves.size():
		fails.append("%s: only %d/%d moves landed on a standing player" % [gid, landed, moves.size()])

	## Phase thresholds.
	b.global_position = BOSS_AT
	var h: Health = b.get_node("Health")
	for i in range(1, b.phases.size()):
		var at := float((b.phases[i] as Dictionary).get("at", 0.0))
		h.take_damage(h.hp - h.max_hp * (at - 0.02))
		await get_tree().process_frame
		if int(b.phase_index) != i:
			fails.append("%s at %.0f%% HP is phase %d, want %d" % [gid, at * 100.0, b.phase_index + 1, i + 1])
		var want_adds: bool = not (b.phases[i] as Dictionary).get("adds", {}).is_empty()
		var adds := get_tree().get_nodes_in_group("boss_add").size()
		if want_adds and adds == 0:
			fails.append("%s phase %d spawned no adds" % [gid, i + 1])
		print("PHASE ", gid, " ", i + 1, " ", b.phase_title, " adds=", adds)

	## Death routs adds.
	var down := [false]
	b.defeated.connect(func(): down[0] = true)
	h.take_damage(h.hp + 1.0)
	await get_tree().process_frame
	if not down[0]:
		fails.append("%s did not emit defeated" % gid)
	var left := 0
	for a in get_tree().get_nodes_in_group("boss_add"):
		var ah: Health = a.get_node_or_null("Health")
		if ah and ah.is_alive():
			left += 1
	if left > 0:
		fails.append("%s left %d adds alive after death" % [gid, left])
	arena.queue_free()
	await _wait(0.2)
	return fails


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout
