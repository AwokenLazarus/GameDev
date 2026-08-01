extends Node
## Headless: instance a raid and assert player/enemies are present and unpaused.


func _ready() -> void:
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
		push_error("RAID_VIS_FAIL paused at start")
		get_tree().quit(1)
		return
	var players := get_tree().get_nodes_in_group("player")
	var enemies := get_tree().get_nodes_in_group("enemy")
	print("PLAYERS ", players.size())
	print("ENEMIES ", enemies.size())
	if players.is_empty() or enemies.is_empty():
		push_error("RAID_VIS_FAIL missing actors")
		get_tree().quit(1)
		return
	var p: Node = players[0]
	var av = p.get_node_or_null("ActorVisual")
	if av == null:
		push_error("RAID_VIS_FAIL no ActorVisual")
		get_tree().quit(1)
		return
	print("PLAYER_POS ", p.global_position)
	print("ANIM ", av.current_anim() if av.has_method("current_anim") else "?")
	print("RAID_VIS_PASS")
	get_tree().quit(0)
