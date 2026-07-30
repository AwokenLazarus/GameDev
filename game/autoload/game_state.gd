extends Node
## Persistent meta progression between moons.

signal currencies_changed
signal ashwick_changed

var blood: int = 0
var ash: int = 0
var tech: int = 0

## Unlocked character ids. Severin always available in V0.
var unlocked_characters: Array[String] = ["severin"]

## Ashwick rebuild flags (V0 stub).
var vendor_unlocked: bool = true
var kin_met: bool = false
var mayor_met: bool = false
var moons_survived: int = 0

const SAVE_PATH := "user://moonwake_save.json"


func _ready() -> void:
	load_game()


func add_currency(kind: String, amount: int) -> void:
	match kind:
		"blood":
			blood += amount
		"ash":
			ash += amount
		"tech":
			tech += amount
	currencies_changed.emit()
	save_game()


func can_spend(kind: String, amount: int) -> bool:
	match kind:
		"blood":
			return blood >= amount
		"ash":
			return ash >= amount
		"tech":
			return tech >= amount
	return false


func spend(kind: String, amount: int) -> bool:
	if not can_spend(kind, amount):
		return false
	match kind:
		"blood":
			blood -= amount
		"ash":
			ash -= amount
		"tech":
			tech -= amount
	currencies_changed.emit()
	save_game()
	return true


func mark_moon() -> void:
	moons_survived += 1
	save_game()


func save_game() -> void:
	var data := {
		"blood": blood,
		"ash": ash,
		"tech": tech,
		"unlocked_characters": unlocked_characters,
		"vendor_unlocked": vendor_unlocked,
		"kin_met": kin_met,
		"mayor_met": mayor_met,
		"moons_survived": moons_survived,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var data: Dictionary = parsed
	blood = int(data.get("blood", 0))
	ash = int(data.get("ash", 0))
	tech = int(data.get("tech", 0))
	var chars: Array = data.get("unlocked_characters", ["severin"])
	unlocked_characters.clear()
	for c in chars:
		unlocked_characters.append(str(c))
	vendor_unlocked = bool(data.get("vendor_unlocked", true))
	kin_met = bool(data.get("kin_met", false))
	mayor_met = bool(data.get("mayor_met", false))
	moons_survived = int(data.get("moons_survived", 0))
