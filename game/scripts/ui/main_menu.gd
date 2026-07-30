extends Control

@onready var start_btn: Button = $Center/VBox/Start
@onready var quit_btn: Button = $Center/VBox/Quit
@onready var subtitle: Label = $Center/VBox/Subtitle
@onready var moon: Sprite2D = $Moon
@onready var hero: Sprite2D = $Hero


func _ready() -> void:
	start_btn.pressed.connect(_on_start)
	quit_btn.pressed.connect(func(): get_tree().quit())
	subtitle.text = "Full mandate build · gothic 2.5D frontier"
	if moon and ResourceLoader.exists("res://assets/textures/vfx/moon.png"):
		moon.texture = load("res://assets/textures/vfx/moon.png")
		moon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if hero and ResourceLoader.exists("res://assets/textures/characters/severin.png"):
		hero.texture = load("res://assets/textures/characters/severin.png")
		hero.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
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
