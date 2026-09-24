extends Node
## Headless autoplay entry. Driver is added to the root so it survives scene changes.


func _ready() -> void:
	var d := preload("res://tests/autoplay/autoplay_driver.gd").new()
	get_tree().root.add_child.call_deferred(d)
