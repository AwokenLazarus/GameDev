extends Node
## Screenshot run for presentation review (MW-029). Needs a display (not --headless):
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path game --resolution 1920x1080 \
##     --fixed-fps 60 res://tests/shots/shots.tscn -- out=/tmp/shots tag=after
## Args after `--`: out=<dir>  tag=<prefix>  sector=<id>  char=<id>  seed=N
## Saves <tag>_<WxH>_{hub,burst,boon,doors,wild,general}.png, prints SHOTS_DONE, exit 0.

const HUB_SCENE := "res://scenes/hub/ashwick.tscn"
const SECTOR_SCENE := "res://scenes/sector/sector_run.tscn"
const SAVE_PATH := "user://moonwake_save.json"

var out_dir := "user://shots"
var tag := "shot"
var sector_id := "dust_meridian"
var char_id := "severin"
var _save_bytes := PackedByteArray()
var _save_had_file := false
var _stage: Node

@onready var encode: CanvasLayer = $Encode


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var n := SmokeSeed.begin(1)
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out_dir = a.substr(4)
		elif a.begins_with("tag="):
			tag = a.substr(4)
		elif a.begins_with("sector="):
			sector_id = a.substr(7)
		elif a.begins_with("char="):
			char_id = a.substr(5)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	_snapshot_save()
	await _run()
	_restore_save()
	print("SHOTS_DONE SEED=%d out=%s" % [n, out_dir])
	get_tree().quit(0)


func _process(_delta: float) -> void:
	## Keep the lead alive so every stage is reachable.
	var p := get_tree().get_first_node_in_group("player")
	if p == null:
		return
	var h: Health = p.get_node_or_null("Health")
	if h and h.hp < h.max_hp:
		h.hp = h.max_hp


func _run() -> void:
	GameState.selected_sector = sector_id
	GameState.party = [{"character_id": char_id, "alt_id": "", "device": -1}]
	await _load(HUB_SCENE)
	await _frames(90)
	await _shoot("hub")
	await _load(SECTOR_SCENE)
	await _frames(200)
	await _shoot("burst")
	## A few picks first so the HUD shows patron boons and cards show what they replace.
	for i: int in 3:
		var choices: Array[Dictionary] = BoonDB.get_choices(1)
		if not choices.is_empty():
			RunState.add_boon(choices[0])
	RunState.feed_buff_stacks = 2
	RunState.feed_buff_changed.emit(2)
	## Clear the room: the first burst pays a boon, then opens its doors.
	for e: Node in get_tree().get_nodes_in_group("enemy"):
		e.queue_free()
	_stage.set("_burst_left", 0)
	await _until_paused(240)
	await _frames(40)
	await _shoot("boon")
	_pick_open_boon()
	await _frames(90)
	await _shoot("doors")
	_stage.call("_start_wild")
	await _until_paused(60)
	_pick_open_boon()
	## Stand by the first shrine so the shot shows a wild-stage landmark.
	var shrines: Array = _stage.get("shrine_points")
	var lead := get_tree().get_first_node_in_group("player") as Node2D
	if lead and not shrines.is_empty():
		lead.global_position = (shrines[0] as Vector2) + Vector2(150.0, 90.0)
	await _frames(420)
	await _shoot("wild")
	RunState.wild_kills = RunState.kill_gate
	RunState.kills_changed.emit(RunState.wild_kills, RunState.kill_gate)
	await _frames(240)
	_pick_open_boon()
	await _shoot("general")


func _until_paused(max_frames: int) -> void:
	for i: int in max_frames:
		if get_tree().paused:
			return
		await get_tree().process_frame


func _pick_open_boon() -> void:
	if not get_tree().paused:
		return
	var boon_ui: CanvasLayer = _stage.get_node("BoonSelect")
	var choices: Array = boon_ui.get("_choices")
	if not choices.is_empty():
		boon_ui.call("_pick", choices[0])


func _load(path: String) -> void:
	if _stage:
		_stage.queue_free()
		await get_tree().process_frame
	get_tree().paused = false
	var scene: PackedScene = load(path)
	_stage = scene.instantiate()
	add_child(_stage)


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().process_frame


func _shoot(shot: String) -> void:
	## HDR 2D keeps the viewport linear; encode it on the GPU for the captured frame.
	var hdr := get_viewport().use_hdr_2d
	encode.visible = hdr
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	encode.visible = false
	img.convert(Image.FORMAT_RGB8)
	var win := get_window().size
	var path := "%s/%s_%dx%d_%s.png" % [out_dir, tag, win.x, win.y, shot]
	var err := img.save_png(path)
	print("SHOT %s err=%d" % [path, err])


func _snapshot_save() -> void:
	_save_had_file = FileAccess.file_exists(SAVE_PATH)
	if _save_had_file:
		_save_bytes = FileAccess.get_file_as_bytes(SAVE_PATH)


func _restore_save() -> void:
	if _save_had_file:
		var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if f:
			f.store_buffer(_save_bytes)
	elif FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
