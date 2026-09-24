class_name MWEliteAffixes
extends RefCounted
## Named elite affixes. Aura color + combat modifiers. Curve (rare→common) stays on the spawner.

const IDS: Array[String] = ["armored", "frenzied", "blood_linked", "void_pull"]

const DEFS := {
	"armored": {
		"id": "armored",
		"name": "Armored",
		"color": Color(0.55, 0.62, 0.78),
		"incoming_mult": 0.55,
		"speed_mult": 0.88,
		"damage_mult": 1.0,
	},
	"frenzied": {
		"id": "frenzied",
		"name": "Frenzied",
		"color": Color(0.95, 0.42, 0.18),
		"incoming_mult": 1.0,
		"speed_mult": 1.28,
		"damage_mult": 1.15,
	},
	"blood_linked": {
		"id": "blood_linked",
		"name": "Blood-Linked",
		"color": Color(0.82, 0.16, 0.28),
		"incoming_mult": 1.0,
		"speed_mult": 1.0,
		"damage_mult": 1.0,
	},
	"void_pull": {
		"id": "void_pull",
		"name": "Void-Pull",
		"color": Color(0.52, 0.28, 0.78),
		"incoming_mult": 1.0,
		"speed_mult": 1.0,
		"damage_mult": 1.0,
	},
}


static func all_ids() -> Array[String]:
	return IDS.duplicate()


static func def(id: String) -> Dictionary:
	return DEFS.get(id, DEFS["armored"]).duplicate(true)


static func roll() -> String:
	return IDS[randi() % IDS.size()]


static func apply(enemy: Node, id: String) -> void:
	var d: Dictionary = def(id)
	if enemy.has_method("apply_affix_def"):
		enemy.apply_affix_def(d)
	elif "affix_id" in enemy:
		enemy.affix_id = str(d.get("id", id))
