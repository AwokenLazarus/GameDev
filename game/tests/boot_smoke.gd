extends Node
## Attach/run via: godot --path game --headless -- --smoke
## Or call from main when --smoke arg present.


func _ready() -> void:
	print("BOOT_SMOKE_START")
	var ok := true
	if GameState == null:
		push_error("GameState missing")
		ok = false
	if RunState == null:
		push_error("RunState missing")
		ok = false
	if BoonDB == null:
		push_error("BoonDB missing")
		ok = false

	RunState.start_run("severin", "dust_meridian")
	var choices := BoonDB.get_choices(3)
	if choices.is_empty():
		push_error("No boon choices")
		ok = false
	else:
		RunState.add_boon(choices[0])
		print("BOON ", choices[0].get("name", "?"))

	RunState.register_kill(true)
	RunState.feed_on_human()
	print("REP ", RunState.reputation_label(), " KILLS ", RunState.kills)

	## Instance combat entities in tree
	var player_ps: PackedScene = load("res://scenes/entities/player.tscn")
	var enemy_ps: PackedScene = load("res://scenes/entities/enemy.tscn")
	var boss_ps: PackedScene = load("res://scenes/entities/marshal_hale.tscn")
	var p: Node = player_ps.instantiate()
	var e: Node = enemy_ps.instantiate()
	var b: Node = boss_ps.instantiate()
	add_child(p)
	add_child(e)
	add_child(b)
	if e.has_method("setup"):
		e.setup(p, true, false)
	await get_tree().process_frame
	print("ENTITIES_OK")

	## Load hub + sector packed scenes (don't enter full loop)
	for path in ["res://scenes/hub/ashwick.tscn", "res://scenes/sector/dust_meridian.tscn"]:
		var ps: PackedScene = load(path)
		if ps == null:
			push_error("Missing " + path)
			ok = false
		else:
			print("SCENE_OK ", path)

	if ok:
		print("BOOT_SMOKE_PASS")
		get_tree().quit(0)
	else:
		print("BOOT_SMOKE_FAIL")
		get_tree().quit(1)
