extends Node
## Headless: idle player must live 8s on Dust burst 1; no hit >35.

const DEFAULT_SEED := 3

var _seed: int = 0


func _ready() -> void:
	_seed = SmokeSeed.begin(DEFAULT_SEED)
	print("COMBAT_READ_START")
	GameState.selected_difficulty = "dust"
	GameState.selected_sector = "dust_meridian"
	GameState.party = [{"character_id": "severin", "alt_id": "", "device": -1}]
	var packed: PackedScene = load("res://scenes/sector/sector_run.tscn")
	var raid: Node = packed.instantiate()
	add_child(raid)
	await get_tree().create_timer(8.0, true, false, true).timeout
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		_fail("no player")
		return
	var p: Node = players[0]
	var hp := 0.0
	var h: Health = p.get_node_or_null("Health")
	if h:
		hp = h.hp
	var dead: bool = bool(p.get("dead"))
	var max_hit := RunState.max_hit_taken
	print("IDLE_HP ", hp, " DEAD ", dead, " MAX_HIT ", max_hit)
	if dead or hp <= 0.0:
		_fail("died before 8s")
		return
	if max_hit > 35.0:
		_fail("max hit %.1f" % max_hit)
		return
	print("IDLE_SURVIVE_PASS")
	print("COMBAT_READ_PASS")
	get_tree().quit(0)


func _fail(detail: String) -> void:
	var msg := SmokeSeed.fail_line("COMBAT_READ_FAIL", _seed, detail)
	push_error(msg)
	print(msg)
	get_tree().quit(1)
