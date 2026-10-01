extends Node
## Headless: instance a raid and assert player/enemies are present and unpaused.

const DEFAULT_SEED := 2

var _seed: int = 0


func _ready() -> void:
	_seed = SmokeSeed.begin(DEFAULT_SEED)
	print("RAID_VIS_START")
	GameState.party = [{"character_id": "severin", "alt_id": "", "device": -1}]
	GameState.selected_sector = "dust_meridian"
	get_tree().paused = false
	var packed: PackedScene = load("res://scenes/sector/sector_run.tscn")
	var raid: Node = packed.instantiate()
	add_child(raid)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.2).timeout
	if get_tree().paused:
		_fail("paused at start")
		return
	var players := get_tree().get_nodes_in_group("player")
	var enemies := get_tree().get_nodes_in_group("enemy")
	print("PLAYERS ", players.size())
	print("ENEMIES ", enemies.size())
	if players.is_empty() or enemies.is_empty():
		_fail("missing actors")
		return
	var p: Node = players[0]
	var av: Node = p.get_node_or_null("ActorVisual")
	if av == null:
		_fail("no ActorVisual")
		return
	print("PLAYER_POS ", p.global_position)
	print("ANIM ", av.current_anim() if av.has_method("current_anim") else "?")
	print("RAID_VIS_PASS")
	get_tree().quit(0)


func _fail(detail: String) -> void:
	var msg := SmokeSeed.fail_line("RAID_VIS_FAIL", _seed, detail)
	push_error(msg)
	print(msg)
	get_tree().quit(1)
