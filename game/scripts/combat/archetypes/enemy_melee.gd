extends "res://scripts/combat/enemy.gd"
## Melee chaser — walk in, telegraph, poke. Dust rail grubs and similar.

func _ready() -> void:
	archetype = "melee"
	super._ready()
