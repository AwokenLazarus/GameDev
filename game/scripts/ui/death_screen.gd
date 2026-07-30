extends Control

@onready var title: Label = $Center/VBox/Title
@onready var body: Label = $Center/VBox/Body
@onready var continue_btn: Button = $Center/VBox/Continue
@onready var moon: Sprite2D = $Moon
@onready var shadow_birth: Sprite2D = $ShadowBirth


func _ready() -> void:
	title.text = "Moonwake"
	body.text = "The full moon pulls your shadow upright.\nBone from dust. Cape from night.\nAshwick waits — again."
	continue_btn.pressed.connect(_on_continue)
	if moon and ResourceLoader.exists("res://assets/textures/vfx/moon.png"):
		moon.texture = load("res://assets/textures/vfx/moon.png")
		moon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if shadow_birth and ResourceLoader.exists("res://assets/textures/vfx/shadow_birth.png"):
		shadow_birth.texture = load("res://assets/textures/vfx/shadow_birth.png")
		shadow_birth.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	modulate.a = 0.0
	if moon:
		moon.scale = Vector2(0.2, 0.2)
		moon.modulate.a = 0.0
	if shadow_birth:
		shadow_birth.modulate.a = 0.0
		shadow_birth.position = Vector2(640, 420)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.8)
	if moon:
		tw.parallel().tween_property(moon, "modulate:a", 1.0, 1.4)
		tw.parallel().tween_property(moon, "scale", Vector2(0.85, 0.85), 1.6).set_trans(Tween.TRANS_SINE)
	if shadow_birth:
		tw.tween_property(shadow_birth, "modulate:a", 1.0, 0.9)
		tw.parallel().tween_property(shadow_birth, "position:y", 380.0, 1.0)


func _on_continue() -> void:
	RunState.end_to_hub()
	get_tree().change_scene_to_file("res://scenes/hub/ashwick.tscn")
