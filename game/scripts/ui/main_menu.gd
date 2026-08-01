extends Control

@onready var start_btn: Button = $Center/VBox/Start
@onready var quit_btn: Button = $Center/VBox/Quit
@onready var subtitle: Label = $Center/VBox/Subtitle
@onready var moon: Sprite2D = $Moon
@onready var hero: Sprite2D = $Hero

var _hub_btn: Button
var _hint: Label


func _ready() -> void:
	start_btn.text = "PLAY RAID — Dust Meridian"
	start_btn.custom_minimum_size = Vector2(360, 56)
	start_btn.pressed.connect(_on_play_raid)
	quit_btn.pressed.connect(func(): get_tree().quit())
	subtitle.text = "Fight first. Town hub is optional."
	_hub_btn = Button.new()
	_hub_btn.text = "Ashwick Town Hub"
	_hub_btn.custom_minimum_size = Vector2(360, 44)
	_hub_btn.pressed.connect(_on_hub)
	start_btn.get_parent().add_child(_hub_btn)
	start_btn.get_parent().move_child(_hub_btn, start_btn.get_index() + 1)
	_hint = Label.new()
	_hint.text = "In raid: WASD move · J / Click attack · Space dodge · F feed corpses"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.modulate = Color(0.75, 0.68, 0.6)
	start_btn.get_parent().add_child(_hint)
	start_btn.get_parent().move_child(_hint, _hub_btn.get_index() + 1)
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
		hero.modulate = Color(1.35, 1.25, 1.2)
		hero.scale = Vector2(1.8, 1.8)
	if moon:
		var tw := create_tween().set_loops()
		tw.tween_property(moon, "position:y", moon.position.y - 8.0, 2.4).set_trans(Tween.TRANS_SINE)
		tw.tween_property(moon, "position:y", moon.position.y + 8.0, 2.4).set_trans(Tween.TRANS_SINE)
	if hero:
		var tw2 := create_tween().set_loops()
		tw2.tween_property(hero, "position:y", hero.position.y - 4.0, 1.2)
		tw2.tween_property(hero, "position:y", hero.position.y + 4.0, 1.2)


func _on_play_raid() -> void:
	## Skip confusing hub — go straight into combat with defaults.
	if GameState.party.is_empty():
		GameState.party = [{"character_id": "severin", "alt_id": "", "device": -1}]
	if GameState.selected_sector == "":
		GameState.selected_sector = "dust_meridian"
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/sector/sector_run.tscn")


func _on_hub() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/hub/ashwick.tscn")
