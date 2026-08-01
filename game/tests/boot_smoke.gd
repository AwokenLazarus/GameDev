extends Node
## Full mandate boot smoke.


func _ready() -> void:
	print("BOOT_SMOKE_START")
	var ok := true

	for autoload_name in ["GameState", "RunState", "CharacterDB", "SectorDB", "MetaDB", "BoonDB"]:
		if get_node_or_null("/root/" + autoload_name) == null:
			push_error("Missing autoload " + autoload_name)
			ok = false

	## Characters
	var chars: Array = CharacterDB.all_characters()
	if chars.size() < 5:
		push_error("Expected 5 characters, got %d" % chars.size())
		ok = false
	else:
		print("CHARS ", chars.size())

	## Sectors
	var sectors: Array = SectorDB.all_raidable_sectors()
	if sectors.size() < 8:
		push_error("Expected 8 sectors, got %d" % sectors.size())
		ok = false
	else:
		print("SECTORS ", sectors.size())

	## Boons per patron
	var counts := {"dust_compact": 0, "red_petition": 0, "house_veyra": 0, "church": 0}
	for b in BoonDB.boons:
		var p := str(b.get("patron", ""))
		if counts.has(p):
			counts[p] = int(counts[p]) + 1
	for p in counts.keys():
		if int(counts[p]) < 6:
			push_error("Patron %s has %d boons" % [p, counts[p]])
			ok = false
	print("BOONS ", counts)

	## Meta branches
	for branch in ["blood", "ash", "tech"]:
		var nodes: Array = MetaDB.get_branch(branch)
		if nodes.is_empty():
			push_error("Empty meta branch " + branch)
			ok = false
		print("META ", branch, " ", nodes.size())

	## Run start + boon
	GameState.selected_sector = "dust_meridian"
	RunState.start_run("mira", "cinder_barrens", "", 2)
	var choices := BoonDB.get_choices(3)
	if choices.is_empty():
		push_error("No boon choices")
		ok = false
	else:
		RunState.add_boon(choices[0])
		print("BOON ", choices[0].get("name", "?"))

	## Entities
	var player_ps: PackedScene = load("res://scenes/entities/player.tscn")
	var enemy_ps: PackedScene = load("res://scenes/entities/enemy.tscn")
	var general_ps: PackedScene = load("res://scenes/entities/general.tscn")
	var p: Node = player_ps.instantiate()
	add_child(p)
	p.configure(0, "odette", "", -1)
	var e: Node = enemy_ps.instantiate()
	add_child(e)
	e.setup(p, true, true)
	var g: Node = general_ps.instantiate()
	add_child(g)
	g.configure("aurelian")
	await get_tree().process_frame
	print("ENTITIES_OK kit=", p.kit_type, " general=", g.display_name)

	for path in [
		"res://scenes/hub/ashwick.tscn",
		"res://scenes/sector/sector_run.tscn",
		"res://scenes/main.tscn",
		"res://scenes/ui/death_screen.tscn",
	]:
		if load(path) == null:
			push_error("Missing " + path)
			ok = false
		else:
			print("SCENE_OK ", path)

	## Generals all resolve
	for gid in ["marshal_hale", "lady_sable", "marrowfang", "cantor_belis", "provost_rhea", "duke_orlokis", "admiral_drus", "aurelian"]:
		var gd: Dictionary = SectorDB.get_general(gid)
		if gd.is_empty() or not gd.has("pattern"):
			push_error("General incomplete " + gid)
			ok = false
	print("GENERALS_OK")

	if ok:
		print("BOOT_SMOKE_PASS")
		get_tree().quit(0)
	else:
		print("BOOT_SMOKE_FAIL")
		get_tree().quit(1)
