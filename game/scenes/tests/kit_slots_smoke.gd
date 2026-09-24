extends Node2D
## Headless (MW-023): for every starter kit, an idle player deals no damage, and each
## of attack / special / cast / dash fires and the three combat slots land hits.

const PLAYER := preload("res://scenes/entities/player.tscn")
const ENEMY := preload("res://scenes/entities/enemy.tscn")
const KITS := ["severin", "mira", "cassian", "odette", "vesper"]
const DUMMY_HP := 100000.0

var _used: Dictionary = {}
var _hits: Dictionary = {}


func _ready() -> void:
	print("KIT_SLOTS_START")
	var failures: Array[String] = []
	for id in KITS:
		failures.append_array(await _check_kit(id))
	## Alts that swap kit_type get that kit's slots, not the native ones.
	var gunsmith: Dictionary = CharacterDB.get_slots("severin", "severin_gunsmith")
	if str(gunsmith.get("attack", {}).get("name", "")) != "Rail Shot":
		failures.append("severin_gunsmith did not resolve hybrid_gun slots")
	if failures.is_empty():
		print("KIT_SLOTS_PASS")
		get_tree().quit(0)
		return
	for f in failures:
		push_error("KIT_SLOTS_FAIL " + f)
		print("KIT_SLOTS_FAIL ", f)
	get_tree().quit(1)


func _check_kit(id: String) -> Array[String]:
	var fails: Array[String] = []
	RunState.player_max_hp = 1000.0
	RunState.player_hp = 1000.0
	var arena := Node2D.new()
	add_child(arena)
	var p: Node = PLAYER.instantiate()
	p.configure(0, id)
	arena.add_child(p)
	p.global_position = Vector2.ZERO
	_used = {}
	_hits = {}
	p.slot_used.connect(func(s: String): _used[s] = true)
	p.slot_hit.connect(func(s: String, _t: Node, _d: float): _hits[s] = true)
	var dummies: Array[Node] = []
	for x in [50.0, 100.0, 150.0, 200.0]:
		var e: Node = ENEMY.instantiate()
		arena.add_child(e)
		e.global_position = Vector2(x, 0.0)
		e.health.max_hp = DUMMY_HP
		e.health.hp = DUMMY_HP
		e.set_physics_process(false) ## stationary target dummies
		dummies.append(e)

	await _wait(1.5)
	if _damage(dummies) > 0.0:
		fails.append("%s dealt %.0f damage with no input" % [id, _damage(dummies)])

	for slot in ["attack", "special", "cast"]:
		var before := _damage(dummies)
		p.facing = Vector2.RIGHT
		if not p.use_slot(slot):
			fails.append("%s %s would not fire" % [id, slot])
		await _wait(1.3)
		if _damage(dummies) <= before or not _hits.has(slot):
			fails.append("%s %s landed no hit" % [id, slot])
	if id == "severin" and not dummies.any(func(e: Node): return p.mark_bonus(e) > 0.0):
		fails.append("severin blood stake marked nothing")
	p.facing = Vector2.RIGHT
	if not p.use_slot("dash"):
		fails.append("%s dash would not fire" % id)
	for slot in ["attack", "special", "cast", "dash"]:
		if not _used.has(slot):
			fails.append("%s %s never emitted slot_used" % [id, slot])
	print("KIT ", id, " kit=", p.kit_type, " dmg=", int(_damage(dummies)), " fails=", fails.size())
	arena.queue_free()
	await _wait(0.1)
	return fails


func _damage(dummies: Array[Node]) -> float:
	var total := 0.0
	for e in dummies:
		if is_instance_valid(e):
			total += DUMMY_HP - e.health.hp
	return total


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout
