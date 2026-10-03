class_name WorldLabel
extends Node2D
## A caption standing in the world (doors, shrines, elite names): upright on the iso
## stage and never hidden behind an actor. Place it with `position = IsoView.up(pixels)`.

@export var text: String = "":
	set(value):
		text = value
		if is_node_ready():
			label.text = value
@export var tint: Color = MWPalette.BONE:
	set(value):
		tint = value
		if is_node_ready():
			label.modulate = value

@onready var label: Label = $Text


func _ready() -> void:
	IsoView.stand(self)
	IsoView.lift(self)
	label.text = text
	label.modulate = tint
