extends Node
## Render-cost probe for the raid stage (MW-029). Needs a display and a GPU:
##   xvfb-run -a -s "-screen 0 3440x1440x24" godot --path game --resolution 3440x1440 \
##     --disable-vsync res://tests/shots/render_probe.tscn -- stage=wild
## Prints RENDER_PROBE with the viewport's measured GPU and CPU render time per frame,
## averaged over SAMPLE frames after WARMUP. This excludes the window blit, so it holds
## under Xvfb, where presenting is a software copy. Args: stage=burst|wild  sector=<id>

const WARMUP := 180
const SAMPLE := 600

var _stage := "burst"
var _sector := "dust_meridian"


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("stage="):
			_stage = a.substr(6)
		elif a.begins_with("sector="):
			_sector = a.substr(7)
	SmokeSeed.begin(1)
	GameState.selected_sector = _sector
	GameState.party = [{"character_id": "severin", "alt_id": "", "device": -1}]
	var scene: PackedScene = load("res://scenes/sector/sector_run.tscn")
	var run := scene.instantiate()
	add_child(run)
	if _stage == "wild":
		run.call("_start_wild")
	var vp := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	for i: int in WARMUP:
		_keep_going()
		await get_tree().process_frame
	var gpu := 0.0
	var cpu := 0.0
	for i: int in SAMPLE:
		_keep_going()
		await get_tree().process_frame
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(vp)
	var size := get_window().size
	print(
		(
			"RENDER_PROBE stage=%s sector=%s %dx%d gpu=%.2fms cpu=%.2fms frames=%d enemies=%d"
			% [
				_stage,
				_sector,
				size.x,
				size.y,
				gpu / SAMPLE,
				cpu / SAMPLE,
				SAMPLE,
				get_tree().get_nodes_in_group("enemy").size()
			]
		)
	)
	get_tree().quit(0)


## Boon picks would pause the run, and a dead lead would end it.
func _keep_going() -> void:
	if get_tree().paused:
		get_tree().paused = false
		RunState.awaiting_boon = false
	var p := get_tree().get_first_node_in_group("player")
	if p:
		var h: Health = p.get_node_or_null("Health")
		if h:
			h.hp = h.max_hp
