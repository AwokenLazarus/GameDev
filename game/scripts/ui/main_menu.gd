extends Control

@onready var start_btn: Button = $Center/VBox/Start
@onready var quit_btn: Button = $Center/VBox/Quit
@onready var subtitle: Label = $Center/VBox/Subtitle


func _ready() -> void:
	start_btn.pressed.connect(_on_start)
	quit_btn.pressed.connect(func(): get_tree().quit())
	subtitle.text = "Full mandate build · 5 siblings · 7 sectors + Pale Spire · co-op"


func _on_start() -> void:
	get_tree().change_scene_to_file("res://scenes/hub/ashwick.tscn")
