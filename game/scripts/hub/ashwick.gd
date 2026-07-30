extends Node2D
## Ashwick hub stub — mayor, vendor, kin, raid start.

@onready var status: Label = $UI/Root/Status
@onready var dialogue: Label = $UI/Root/Dialogue
@onready var currencies: Label = $UI/Root/Currencies
@onready var btn_raid: Button = $UI/Root/Buttons/Raid
@onready var btn_mayor: Button = $UI/Root/Buttons/Mayor
@onready var btn_vendor: Button = $UI/Root/Buttons/Vendor
@onready var btn_kin: Button = $UI/Root/Buttons/Kin
@onready var btn_rite: Button = $UI/Root/Buttons/BloodRite
@onready var btn_menu: Button = $UI/Root/Buttons/Menu


func _ready() -> void:
	RunState.timer_active = false
	RunState.set_phase(RunState.Phase.HUB)
	btn_raid.pressed.connect(_on_raid)
	btn_mayor.pressed.connect(_on_mayor)
	btn_vendor.pressed.connect(_on_vendor)
	btn_kin.pressed.connect(_on_kin)
	btn_rite.pressed.connect(_on_rite)
	btn_menu.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn"))
	GameState.currencies_changed.connect(_refresh)
	_refresh()
	_apply_reputation_flavor()


func _refresh() -> void:
	currencies.text = "Blood %d   Ash %d   Tech %d   ·   Moons %d" % [
		GameState.blood, GameState.ash, GameState.tech, GameState.moons_survived
	]
	status.text = "Ashwick — ruined family town under Marshal law"
	_apply_reputation_flavor()


func _apply_reputation_flavor() -> void:
	var rep := RunState.reputation_label()
	match rep:
		"Hated":
			btn_vendor.disabled = true
			btn_vendor.text = "Vendor (refuses you)"
			dialogue.text = "They saw the blood on your mouth last moon. Shutters stay closed."
		"Feared":
			btn_vendor.disabled = false
			btn_vendor.text = "Vendor (prices worse)"
			dialogue.text = "Folk cross the street. The mayor smiles too wide."
		"Wary":
			btn_vendor.disabled = false
			btn_vendor.text = "Dust Compact stall"
			dialogue.text = "Whispers follow your cape. Still, they need you."
		_:
			btn_vendor.disabled = false
			btn_vendor.text = "Dust Compact stall"
			if dialogue.text == "":
				dialogue.text = "Dust wind through broken rails. Your kin still keep a light on."


func _on_raid() -> void:
	## Reset run-scoped reputation when starting fresh raid
	RunState.reputation = 0
	get_tree().change_scene_to_file("res://scenes/sector/dust_meridian.tscn")


func _on_mayor() -> void:
	GameState.mayor_met = true
	GameState.save_game()
	if RunState.reputation <= -5:
		dialogue.text = "Mayor Hale-kin: \"Monster. Raid if you must—but the Church is watching.\""
	elif RunState.reputation <= -2:
		dialogue.text = "Mayor: \"Keep the streets clean. The Dominion wants bodies, not scandals.\""
	else:
		dialogue.text = "Mayor: \"Dust Meridian's Marshal Corvin Hale bleeds this town dry. Remove him—quietly.\""


func _on_vendor() -> void:
	if btn_vendor.disabled:
		return
	var cost := 6 if RunState.reputation > -3 else 12
	if GameState.spend("ash", cost):
		GameState.add_currency("tech", 2)
		dialogue.text = "Smuggler: \"Rail scrap and a prayer. Don't feed near the chapel.\" (-%d Ash, +2 Tech)" % cost
	else:
		dialogue.text = "Smuggler: \"Come back with ash. We don't run charity for dhampirs.\""
	_refresh()


func _on_kin() -> void:
	GameState.kin_met = true
	GameState.save_game()
	dialogue.text = "Kin: \"You look like him when the moon's wrong. Still—come home between hunts.\""
	if not GameState.can_spend("blood", 0):
		pass
	GameState.add_currency("ash", 2)
	_refresh()


func _on_rite() -> void:
	if GameState.spend("blood", 10):
		dialogue.text = "Blood rite etched. (V0: flavor — meta tree expands later.)"
	else:
		dialogue.text = "Not enough blood. The moon remembers what you spend."
	_refresh()
