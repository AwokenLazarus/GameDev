extends Area2D
class_name ExitDoor
## Walk-in (or E) reward door after a burst clear.

signal chosen(door: ExitDoor)

var reward: String = "boon"
var label_text: String = "Pact"
var next_room: String = ""
var claimed: bool = false

var _label: Label
var _player_inside: bool = false


func _ready() -> void:
	add_to_group("exit_door")
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_build_visual()


func setup(reward_id: String, text: String, next_id: String, pos: Vector2) -> void:
	reward = reward_id
	label_text = text
	next_room = next_id
	position = pos
	if _label:
		_label.text = text


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


func _build_visual() -> void:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(56, 80)
	shape.shape = rect
	add_child(shape)

	var arch := Polygon2D.new()
	arch.color = Color(0.42, 0.22, 0.2, 0.92) if reward.begins_with("wild") else Color(0.28, 0.18, 0.14, 0.95)
	arch.polygon = PackedVector2Array([
		Vector2(-26, 38), Vector2(-26, -18), Vector2(-12, -36),
		Vector2(12, -36), Vector2(26, -18), Vector2(26, 38),
	])
	add_child(arch)

	var slit := Polygon2D.new()
	slit.color = Color(0.85, 0.62, 0.28, 0.85) if reward == "boon" else Color(0.55, 0.72, 0.85, 0.8)
	if reward.begins_with("wild"):
		slit.color = Color(0.75, 0.35, 0.28, 0.9)
	slit.polygon = PackedVector2Array([
		Vector2(-8, 22), Vector2(-8, -10), Vector2(8, -10), Vector2(8, 22),
	])
	add_child(slit)

	_label = Label.new()
	_label.text = label_text
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.position = Vector2(-48, -62)
	_label.size = Vector2(96, 22)
	_label.add_theme_font_size_override("font_size", 14)
	_label.modulate = Color(0.95, 0.88, 0.75)
	add_child(_label)
