class_name GearDrop
extends Area2D
## Light run-only gear pickup.

var item: Dictionary = {}

@onready var visual: CanvasItem = $Visual
@onready var label: Label = $Label


func _ready() -> void:
	body_entered.connect(_on_body)
	collision_layer = 16
	collision_mask = 2


func setup(data: Dictionary) -> void:
	item = data
	var rarity := str(data.get("rarity", "common"))
	var col := Color(0.7, 0.65, 0.4)
	match rarity:
		"rare":
			col = Color(0.35, 0.55, 0.85)
		"epic":
			col = Color(0.65, 0.35, 0.8)
	if visual is Polygon2D:
		(visual as Polygon2D).color = col
	else:
		visual.modulate = col
	if visual is Sprite2D:
		var path := "res://assets/textures/vfx/gear.png"
		if ResourceLoader.exists(path):
			(visual as Sprite2D).texture = load(path)
	if label:
		label.text = str(data.get("name", "Relic"))


func _on_body(body: Node) -> void:
	if body.is_in_group("player"):
		var slot := str(item.get("slot", "relic"))
		RunState.equip_gear(slot, item)
		queue_free()


static func roll_item() -> Dictionary:
	var pool := [
		{"slot": "charm", "name": "Dust Charm", "rarity": "common", "move": 0.06},
		{"slot": "charm", "name": "Blood Bead", "rarity": "rare", "lifesteal": 0.05},
		{"slot": "relic", "name": "Rail Spike", "rarity": "common", "damage": 0.08},
		{"slot": "relic", "name": "Veyra Seal", "rarity": "epic", "damage": 0.12, "crit": 0.05},
		{"slot": "coat", "name": "Ash Coat", "rarity": "common", "max_hp": 15.0},
		{"slot": "coat", "name": "Iron Mantle", "rarity": "rare", "max_hp": 25.0, "damage": 0.04},
	]
	return pool[randi() % pool.size()].duplicate()
