extends CanvasLayer
## Raid and hub pause. ALWAYS so the buttons still run while the tree is paused.
## One menu pauses every local player together. Boon select keeps the screen while it is open.

const RAID_SCENE := "res://scenes/sector/sector_run.tscn"
const HUB_SCENE := "res://scenes/hub/ashwick.tscn"

@onready var resume_btn: Button = $Root/Center/Panel/VBox/Resume
@onready var restart_btn: Button = $Root/Center/Panel/VBox/Restart
@onready var ashwick_btn: Button = $Root/Center/Panel/VBox/Ashwick
@onready var quit_btn: Button = $Root/Center/Panel/VBox/Quit


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	resume_btn.pressed.connect(_resume)
	restart_btn.pressed.connect(_restart)
	ashwick_btn.pressed.connect(_to_ashwick)
	quit_btn.pressed.connect(_quit)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo() or not event.is_action_pressed("pause_menu"):
		return
	if _boon_open():
		return
	if visible:
		_resume()
	else:
		_open()
	get_viewport().set_input_as_handled()


func _boon_open() -> bool:
	for node: Node in get_tree().get_nodes_in_group("boon_select"):
		var layer := node as CanvasLayer
		if layer != null and layer.visible:
			return true
		var item := node as CanvasItem
		if item != null and item.visible:
			return true
	return false


func _open() -> void:
	visible = true
	get_tree().paused = true


func _resume() -> void:
	visible = false
	get_tree().paused = false


func _restart() -> void:
	_go(RAID_SCENE)


func _to_ashwick() -> void:
	_go(HUB_SCENE)


func _go(path: String) -> void:
	visible = false
	get_tree().paused = false
	get_tree().change_scene_to_file(path)


func _quit() -> void:
	get_tree().quit()
