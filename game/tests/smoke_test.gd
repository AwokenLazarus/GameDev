extends SceneTree
## Headless smoke test: load core scripts/scenes and exercise run state.


func _init() -> void:
	print("MOONWAKE_SMOKE_START")
	var errors: Array[String] = []

	## Autoloads exist when running as main project; as --script they may not.
	## Validate resources instead.
	var required := [
		"res://autoload/game_state.gd",
		"res://autoload/run_state.gd",
		"res://autoload/boon_db.gd",
		"res://scenes/main.tscn",
		"res://scenes/hub/ashwick.tscn",
		"res://scenes/sector/dust_meridian.tscn",
		"res://scenes/entities/player.tscn",
		"res://scenes/entities/enemy.tscn",
		"res://scenes/entities/marshal_hale.tscn",
		"res://scenes/ui/death_screen.tscn",
		"res://scenes/ui/hud.tscn",
		"res://scenes/ui/boon_select.tscn",
	]
	for path in required:
		if not ResourceLoader.exists(path):
			errors.append("Missing: %s" % path)
		else:
			var res := load(path)
			if res == null:
				errors.append("Failed load: %s" % path)
			else:
				print("OK ", path)

	## Instantiate key scenes
	for path in [
		"res://scenes/entities/player.tscn",
		"res://scenes/entities/enemy.tscn",
		"res://scenes/entities/marshal_hale.tscn",
		"res://scenes/ui/main_menu.tscn" if ResourceLoader.exists("res://scenes/ui/main_menu.tscn") else "res://scenes/main.tscn",
	]:
		var ps: PackedScene = load(path)
		if ps == null:
			errors.append("PackedScene null: %s" % path)
			continue
		var node: Node = ps.instantiate()
		if node == null:
			errors.append("Instantiate failed: %s" % path)
		else:
			print("INSTANCED ", path)
			node.free()

	if errors.is_empty():
		print("MOONWAKE_SMOKE_PASS")
		quit(0)
	else:
		for e in errors:
			push_error(e)
			print("ERR ", e)
		print("MOONWAKE_SMOKE_FAIL")
		quit(1)
