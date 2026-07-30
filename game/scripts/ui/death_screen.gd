extends Control

@onready var title: Label = $Center/VBox/Title
@onready var body: Label = $Center/VBox/Body
@onready var continue_btn: Button = $Center/VBox/Continue


func _ready() -> void:
	title.text = "Moonwake"
	body.text = "The full moon pulls your shadow upright.\nBone from dust. Cape from night.\nAshwick waits — again."
	continue_btn.pressed.connect(_on_continue)
	## Soft rebirth presentation
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 1.2)


func _on_continue() -> void:
	RunState.end_to_hub()
	get_tree().change_scene_to_file("res://scenes/hub/ashwick.tscn")
