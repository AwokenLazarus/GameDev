extends Node2D
## Headless (MW-006): the boon catalogue is 48 verb boons, rivals block as mapped (option C),
## one boon per slot replaces, Legendaries gate on prerequisites, a thin pool falls back to
## a heal, and every boon runs on every kit (all four slots, hurt, lethal, feed, room start)
## without a script error. Spot-checks the minimum verb slice: bleed, execute, shadowstep, smite.

const PLAYER := preload("res://scenes/entities/player.tscn")
const ENEMY := preload("res://scenes/entities/enemy.tscn")
const GENERAL := preload("res://scenes/entities/general.tscn")
const KITS := ["severin", "mira", "cassian", "odette", "vesper"]
const PATRONS := ["dust_compact", "red_petition", "house_veyra", "church"]
const DUMMY_HP := 100000.0
const LEGACY_IDS := [
	"dust_dash", "dust_bleed", "dust_reload", "dust_loot", "dust_sidestep",
	"petition_execute", "petition_trap", "petition_team", "petition_elite", "petition_sabotage", "petition_cell",
	"veyra_crit", "veyra_life", "veyra_shadowstep", "veyra_evolve", "veyra_contract", "veyra_pointe",
	"church_smite", "church_ward", "church_cleanse", "church_cooldown", "church_judgment", "church_procession",
]
const RIVALS_C := {
	"dust_compact": ["church"],
	"red_petition": ["church", "house_veyra"],
	"house_veyra": ["church", "red_petition"],
	"church": ["dust_compact", "red_petition", "house_veyra"],
}


class ErrorCounter extends Logger:
	var count: int = 0
	var first: String = ""

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, _error_type: int, _script_backtrace: Array[ScriptBacktrace]) -> void:
		count += 1
		if first == "":
			first = "%s:%d %s %s %s" % [file, line, function, code, rationale]

	func _log_message(_message: String, _error: bool) -> void:
		pass


var _fails: Array[String] = []
var _errors := ErrorCounter.new()
var _slot_hits: Dictionary = {}
var _scale: float = 1.0


func _ready() -> void:
	print("BOONS_SMOKE_START")
	OS.add_logger(_errors)
	GameState.selected_sector = "dust_meridian"
	_check_catalogue()
	_check_rivals()
	_check_slots()
	_check_offers()
	_scale = 4.0
	for id in KITS:
		await _check_kit(id)
	await _check_red_letter()
	await _check_tally()
	_scale = 1.0
	Engine.time_scale = 1.0
	Engine.physics_ticks_per_second = 60
	OS.remove_logger(_errors)
	if _errors.count > 0:
		_fail("%d engine/script errors; first: %s" % [_errors.count, _errors.first])
	if _fails.is_empty():
		print("BOONS_SMOKE_PASS")
		get_tree().quit(0)
		return
	for f in _fails:
		print("BOONS_SMOKE_FAIL ", f)
	get_tree().quit(1)


func _fail(msg: String) -> void:
	_fails.append(msg)


func _check_catalogue() -> void:
	if BoonDB.boons.size() != 48:
		_fail("catalogue has %d boons, want 48" % BoonDB.boons.size())
	var counts := {}
	var legendary := {}
	var ids := {}
	for b in BoonDB.boons:
		var id := str(b["id"])
		if ids.has(id):
			_fail("duplicate id " + id)
		ids[id] = true
		counts[b["patron"]] = int(counts.get(b["patron"], 0)) + 1
		if str(b["slot"]) not in ["attack", "special", "cast", "dash", "trigger"]:
			_fail("%s bad slot %s" % [id, b["slot"]])
		for stat in ["damage", "move", "attack_speed", "lifesteal", "dash", "max_hp", "crit", "cooldown"]:
			if b.has(stat):
				_fail("%s still carries flat stat %s" % [id, stat])
		if str(b["rarity"]) == "legendary":
			legendary[b["patron"]] = int(legendary.get(b["patron"], 0)) + 1
			if (b.get("requires", {}) as Dictionary).is_empty():
				_fail("legendary %s has no prerequisites" % id)
	for p in PATRONS:
		if int(counts.get(p, 0)) != 12:
			_fail("%s has %d boons" % [p, int(counts.get(p, 0))])
		if int(legendary.get(p, 0)) != 1:
			_fail("%s has %d legendaries" % [p, int(legendary.get(p, 0))])
		for s in BoonDB.SLOTS:
			var n := 0
			for b in BoonDB.boons:
				if b["patron"] == p and b["slot"] == s:
					n += 1
			if n != 1:
				_fail("%s has %d %s boons" % [p, n, s])
	for id in LEGACY_IDS:
		if not ids.has(id):
			_fail("legacy id %s dropped" % id)
	if ids.has("dust_jacket"):
		_fail("dust_jacket should be retired")
	print("BOONS catalogue ", counts)


func _check_rivals() -> void:
	for p in RIVALS_C:
		var want: Array = RIVALS_C[p]
		var got: Array = RunState.PATRON_RIVALS.get(p, [])
		if want.size() != got.size() or not want.all(func(r): return r in got):
			_fail("rivals of %s are %s, want %s" % [p, got, want])
		for r in got:
			if p not in RunState.PATRON_RIVALS.get(r, []):
				_fail("rival map not symmetric: %s/%s" % [p, r])
	for p in PATRONS:
		RunState.start_run("severin", "dust_meridian")
		RunState.add_boon(_first_of(p, "trigger"))
		if RunState.aligned_patron != p:
			_fail("first %s boon did not align" % p)
		for r in RIVALS_C[p]:
			if r not in RunState.blocked_patrons:
				_fail("%s did not block %s" % [p, r])
			var before := RunState.owned_boons.size()
			RunState.add_boon(_first_of(r, "trigger"))
			if RunState.owned_boons.size() != before:
				_fail("%s boon accepted after %s aligned" % [r, p])
		for i in 40:
			for c in BoonDB.get_choices(3):
				if str(c.get("patron", "")) in RIVALS_C[p]:
					_fail("offer %s from blocked %s" % [c["id"], c["patron"]])
	print("BOONS rivals ok")


func _check_slots() -> void:
	RunState.start_run("severin", "dust_meridian")
	RunState.add_boon(BoonDB.get_boon("dust_bleed"))
	RunState.add_boon(BoonDB.get_boon("dust_reload"))
	RunState.add_boon(BoonDB.get_boon("dust_loot"))
	RunState.add_boon(BoonDB.get_boon("petition_execute")) ## Dust + Petition may mix
	if RunState.has_boon("dust_bleed"):
		_fail("attack boon was not replaced")
	if str(RunState.slot_boons.get("attack", "")) != "petition_execute":
		_fail("attack slot holds %s" % RunState.slot_boons.get("attack", ""))
	if not (RunState.has_boon("dust_reload") and RunState.has_boon("dust_loot")):
		_fail("trigger boons should not replace each other")
	if int(RunState.patron_counts.get("dust_compact", 0)) != 2:
		_fail("patron count not reduced by replacement")
	var n := RunState.owned_boons.size()
	RunState.add_boon(BoonDB.get_boon("dust_reload"))
	if RunState.owned_boons.size() != n:
		_fail("duplicate boon accepted")
	## Deep pact: 3rd boon from one patron, one pact per raid.
	RunState.add_boon(BoonDB.get_boon("dust_smoke"))
	if not RunState.has_pact("dust_compact"):
		_fail("3 Dust boons did not form a pact")
	RunState.add_boon(BoonDB.get_boon("petition_trap"))
	RunState.add_boon(BoonDB.get_boon("petition_team"))
	if RunState.has_pact("red_petition"):
		_fail("a second pact formed in one raid")
	print("BOONS slots ok")


func _check_offers() -> void:
	RunState.start_run("severin", "dust_meridian")
	var tally := BoonDB.get_boon("dust_tally")
	if BoonDB.requirements_met(tally):
		_fail("legendary offered without prerequisites")
	RunState.add_boon(BoonDB.get_boon("dust_bleed"))
	RunState.add_boon(BoonDB.get_boon("dust_smoke"))
	if not BoonDB.requirements_met(tally) or tally not in BoonDB.available_pool():
		_fail("legendary not unlocked by prerequisites")
	## Church stands alone: once most of its pool is taken, one offer falls back to a heal.
	RunState.start_run("severin", "dust_meridian")
	for b in BoonDB.boons:
		if b["patron"] == "church" and b["rarity"] != "legendary" and RunState.owned_boons.size() < 9:
			RunState.add_boon(b)
	var choices := BoonDB.get_choices(3)
	if choices.size() != 3 or not choices.any(func(c): return bool(c.get("is_fallback", false))):
		_fail("thin church pool did not fall back to a heal: %s" % [choices.map(func(c): return c["id"])])
	var hp := RunState.player_hp
	RunState.player_hp = 10.0
	RunState.add_boon(BoonDB.FALLBACK_HEAL.duplicate())
	if RunState.player_hp <= 10.0:
		_fail("fallback heal did nothing")
	RunState.player_hp = hp
	print("BOONS offers ok")


func _first_of(patron: String, slot: String) -> Dictionary:
	for b in BoonDB.boons:
		if b["patron"] == patron and b["slot"] == slot and b["rarity"] == "common":
			return b
	return {}


## Loadout = the boon plus its prerequisites, written straight to RunState (bypasses rivals).
func _equip(boon: Dictionary) -> void:
	RunState.start_run("severin", "dust_meridian")
	RunState.player_max_hp = 1000.0
	RunState.player_hp = 1000.0
	var req: Dictionary = boon.get("requires", {})
	var ids: Array = [str(boon["id"])]
	ids.append_array(req.get("all", []))
	if not (req.get("any", []) as Array).is_empty():
		ids.append(req["any"][0])
	for id in ids:
		RunState.owned_boons.append(BoonDB.get_boon(str(id)))
	RunState.boons_changed.emit()


func _check_kit(kit: String) -> void:
	var bled := false
	var executed := false
	var stepped := false
	var smote := false
	for boon in BoonDB.boons:
		var id := str(boon["id"])
		_equip(boon)
		var arena := Node2D.new()
		add_child(arena)
		var p: Node = PLAYER.instantiate()
		p.configure(0, kit)
		arena.add_child(p)
		p.global_position = Vector2.ZERO
		_slot_hits = {}
		p.slot_hit.connect(func(s: String, _t: Node, _d: float): _slot_hits[s] = true)
		var dummies: Array[Node] = []
		for x in [50.0, 100.0, 150.0, 200.0]:
			dummies.append(_dummy(arena, Vector2(x, 0.0), DUMMY_HP))
		var frail := _dummy(arena, Vector2(60.0, 26.0), 30.0)
		var elite := _dummy(arena, Vector2(90.0, -26.0), DUMMY_HP, true)
		if id == "petition_execute":
			for d in dummies:
				d.health.hp = DUMMY_HP * 0.1
		RunState.begin_room()
		for slot in ["attack", "special", "cast", "attack", "attack"]:
			p.facing = Vector2.RIGHT
			p.use_slot(slot)
			await _wait(0.45)
		p.facing = Vector2.RIGHT
		p.use_slot("dash")
		await _wait(0.05)
		if id == "veyra_shadowstep" and get_tree().get_nodes_in_group("decoy").size() > 0:
			stepped = true
		await _wait(0.4)
		if id == "dust_reload" and not p.chambered:
			_fail("%s: Quick Chamber did not chamber after dash" % kit)
		p.use_slot("attack")
		p.health.invuln_timer = 0.0
		p.apply_hit(10.0, elite.global_position)
		p.health.invuln_timer = 0.0
		if id == "veyra_poise":
			p.health.hp = 20.0 ## a single hit is capped at MAX_HIT, so bring HP into range
			p.apply_hit(30.0, elite.global_position)
			if p.dead or p.health.hp > 1.0 or p.debt <= 0.0:
				_fail("%s: Noble Poise did not turn lethal damage into Debt" % kit)
		p.fed.emit()
		RunState.begin_room()
		await _wait(0.8)
		if id == "dust_bleed" and dummies.any(func(d): return is_instance_valid(d) and MWBoonStatus.peek(d) != null and MWBoonStatus.peek(d).bleed > 0):
			bled = true
		if id == "petition_execute" and dummies.any(func(d): return not is_instance_valid(d) or not d.health.is_alive()):
			executed = true
		if id == "church_smite" and _slot_hits.has("smite"):
			smote = true
		if id == "church_vow" and p.wards < 2:
			_fail("%s: Vow of Abstinence gave %d wards" % [kit, p.wards])
		if id == "dust_doublehold" and p.cast_max < 2:
			_fail("%s: Double Hold did not add a cast charge" % kit)
		if p.dead:
			_fail("%s + %s: player died in a smoke test" % [kit, id])
		arena.queue_free()
		await _wait(0.05)
		for f in get_tree().get_nodes_in_group("boon_field"):
			f.queue_free()
	if not bled:
		_fail("%s: Scrap Teeth applied no Bleed" % kit)
	if not executed:
		_fail("%s: Widow's Writ executed nothing" % kit)
	if not stepped:
		_fail("%s: Ledger Step left no afterimage" % kit)
	if not smote:
		_fail("%s: Pale Decree's third Attack called no Smite" % kit)
	print("BOONS kit ", kit, " ok=", bled and executed and stepped and smote, " errors=", _errors.count)


## Red Letter Day: a general below 8% dies to a Special; without it, generals are immune.
func _check_red_letter() -> void:
	for with_legendary in [false, true]:
		_equip(BoonDB.get_boon("petition_redletter") if with_legendary else BoonDB.get_boon("petition_execute"))
		var arena := Node2D.new()
		add_child(arena)
		var p: Node = PLAYER.instantiate()
		p.configure(0, "severin")
		arena.add_child(p)
		var g: Node = GENERAL.instantiate()
		arena.add_child(g)
		g.global_position = Vector2(190, 0) ## the cleave lunges 150 px first
		g.set_physics_process(false)
		g.health.max_hp = DUMMY_HP ## big pool: normal hits can't finish 5%
		g.health.hp = DUMMY_HP * 0.05
		p.facing = Vector2.RIGHT
		p.use_slot("special")
		await _wait(0.5)
		p.facing = Vector2.RIGHT
		p.use_slot("attack")
		await _wait(0.3)
		var dead: bool = not is_instance_valid(g) or not g.health.is_alive()
		if dead != with_legendary:
			_fail("general at 5%% %s with legendary=%s" % ["died" if dead else "lived", with_legendary])
		arena.queue_free()
		await _wait(0.05)
	print("BOONS red letter ok")



## Dead Man's Tally: capping Bleed at 5 through the player (the real source) must fire the Legendary.
func _check_tally() -> void:
	_equip(BoonDB.get_boon("dust_tally"))
	var arena := Node2D.new()
	add_child(arena)
	var p: Node = PLAYER.instantiate()
	p.configure(0, "severin")
	arena.add_child(p)
	var e := _dummy(arena, Vector2(60, 0), DUMMY_HP)
	await _wait(0.05)
	var st := MWBoonStatus.of(e)
	st.add_bleed(5, p)
	if st.bleed != 0:
		_fail("Dead Man's Tally did not fire when Bleed capped (bleed=%d)" % st.bleed)
	arena.queue_free()
	await _wait(0.05)
	print("BOONS tally ok")


func _dummy(arena: Node, pos: Vector2, hp: float, elite: bool = false) -> Node:
	var e: Node = ENEMY.instantiate()
	arena.add_child(e)
	if elite:
		e.setup(null, false, true)
	e.global_position = pos
	e.health.max_hp = hp
	e.health.hp = hp
	e.set_physics_process(false)
	return e


## Game-time wait at the test's time scale (hitstop resets Engine.time_scale to 1).
func _wait(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		if Engine.time_scale > 0.5 and not MWVFX._hitstopping:
			Engine.time_scale = _scale
		## Same physics step length at any scale, so fast shots don't tunnel.
		Engine.physics_ticks_per_second = int(60.0 * _scale)
		Engine.max_physics_steps_per_frame = int(8.0 * _scale)
		var step := minf(left, 0.1)
		await get_tree().create_timer(step).timeout
		left -= step
