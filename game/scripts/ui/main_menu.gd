extends Control

@onready var start_btn: Button = $Center/VBox/Start
@onready var quit_btn: Button = $Center/VBox/Quit
@onready var subtitle: Label = $Center/VBox/Subtitle
@onready var moon: Sprite2D = $Moon
@onready var hero: Sprite2D = $Hero


func _ready() -> void:
	start_btn.pressed.connect(_on_start)
	quit_btn.pressed.connect(func(): get_tree().quit())
	subtitle.text = "Bloodlust-inspired gothic frontier · original brood"
	## Cinematic backdrop
	var vista_path := "res://assets/textures/tiles/ashwick_vista.png"
	if ResourceLoader.exists(vista_path):
		var bg_sprite := Sprite2D.new()
		bg_sprite.texture = load(vista_path)
		bg_sprite.centered = false
		bg_sprite.position = Vector2.ZERO
		var sz: Vector2 = bg_sprite.texture.get_size()
		bg_sprite.scale = Vector2(1280.0 / sz.x, 720.0 / sz.y)
		bg_sprite.z_index = -10
		bg_sprite.modulate = Color(0.55, 0.45, 0.48, 1.0)
		add_child(bg_sprite)
		move_child(bg_sprite, 0)
	if moon and ResourceLoader.exists("res://assets/textures/vfx/moon.png"):
		moon.texture = load("res://assets/textures/vfx/moon.png")
		moon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if hero and ResourceLoader.exists("res://assets/textures/characters/severin.png"):
		hero.texture = load("res://assets/textures/characters/severin.png")
		hero.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		hero.scale = Vector2(1.8, 1.8)
	if moon:
		var tw := create_tween().set_loops()
		tw.tween_property(moon, "position:y", moon.position.y - 8.0, 2.4).set_trans(Tween.TRANS_SINE)
		tw.tween_property(moon, "position:y", moon.position.y + 8.0, 2.4).set_trans(Tween.TRANS_SINE)
	if hero:
		var tw2 := create_tween().set_loops()
		tw2.tween_property(hero, "position:y", hero.position.y - 4.0, 1.2)
		tw2.tween_property(hero, "position:y", hero.position.y + 4.0, 1.2)


func _on_start() -> void:
	get_tree().change_scene_to_file("res://scenes/hub/ashwick.tscn")
