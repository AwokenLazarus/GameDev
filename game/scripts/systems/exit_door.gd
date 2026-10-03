class_name ExitDoor
extends Area2D
## Walk-in (or E) reward door after a burst clear.

signal chosen(door: ExitDoor)

## Light through the doorway says what is behind it: gilt pact, steel cache, red wild.
const PACT := Color(1.0, 0.72, 0.3)
const CACHE := Color(0.5, 0.74, 0.98)
const WILD := Color(0.95, 0.26, 0.2)

var reward: String = "boon"
var label_text: String = "Pact"
var next_room: String = ""
var claimed: bool = false

var _player_inside: bool = false

@onready var arch: SetPiece = $Arch
@onready var light: VotiveLight = $Light
@onready var caption: WorldLabel = $Caption


func _ready() -> void:
	add_to_group("exit_door")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_dress()


func setup(reward_id: String, text: String, next_id: String, pos: Vector2) -> void:
	reward = reward_id
	label_text = text
	next_room = next_id
	position = pos
	if is_node_ready():
		_dress()


func choose() -> void:
	if claimed:
		return
	claimed = true
	chosen.emit(self)


func _unhandled_input(event: InputEvent) -> void:
	if claimed or not _player_inside:
		return
	if event.is_action_pressed("interact"):
		choose()
		get_viewport().set_input_as_handled()


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_inside = true
		choose()


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_inside = false


func _tint() -> Color:
	if reward.begins_with("wild"):
		return WILD
	return PACT if reward == "boon" else CACHE


func _dress() -> void:
	var tint := _tint()
	arch.tint = tint
	light.setup(tint, 1.1, 300.0)
	caption.text = label_text.to_upper()
	caption.tint = tint.lightened(0.35)
	caption.position = IsoView.up(118.0)
	queue_redraw()


## Threshold glow, flat on the floor.
func _draw() -> void:
	draw_circle(Vector2.ZERO, 40.0, Color(_tint(), 0.14))
	draw_arc(Vector2.ZERO, 40.0, 0.0, TAU, 40, Color(_tint(), 0.55), 1.5, true)
