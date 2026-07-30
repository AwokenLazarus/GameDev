extends Node2D
const BiomePresenterScript = preload("res://scripts/visuals/biome_presenter.gd")
## Full Ashwick hub — factions, sector map, roster, meta, difficulty, co-op party.

@onready var status: Label = $UI/Root/Status
@onready var dialogue: Label = $UI/Root/Dialogue
@onready var currencies: Label = $UI/Root/Currencies
@onready var ng_label: Label = $UI/Root/NGLabel
@onready var buttons: VBoxContainer = $UI/Root/LeftButtons
@onready var sector_box: VBoxContainer = $UI/Root/SectorBox
@onready var roster_box: VBoxContainer = $UI/Root/RosterBox
@onready var meta_box: VBoxContainer = $UI/Root/MetaBox
@onready var party_label: Label = $UI/Root/PartyLabel
@onready var diff_btn: OptionButton = $UI/Root/DiffBtn
@onready var raid_btn: Button = $UI/Root/RaidBtn
@onready var menu_btn: Button = $UI/Root/MenuBtn
@onready var add_p2_btn: Button = $UI/Root/AddP2Btn


func _ready() -> void:
	RunState.timer_active = false
	RunState.set_phase(RunState.Phase.HUB)
	var biome := BiomePresenterScript.new()
	add_child(biome)
	biome.present_ashwick()
	## Hide old flat polygons if present
	for n in ["BG", "Road", "Building1", "Building2", "Chapel", "Steeple"]:
		var node := get_node_or_null(n)
		if node:
			node.visible = false
	_build_faction_buttons()
	_build_sectors()
	_build_roster()
	_build_meta()
	_build_difficulty()
	raid_btn.pressed.connect(_on_raid)
	menu_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main.tscn"))
	add_p2_btn.pressed.connect(_on_add_p2)
	GameState.currencies_changed.connect(_refresh)
	GameState.unlocks_changed.connect(_on_unlocks)
	_refresh()
	_apply_reputation_flavor()


func _on_unlocks() -> void:
	_build_roster()
	_build_meta()
	_build_sectors()
	_refresh()


func _build_difficulty() -> void:
	diff_btn.clear()
	diff_btn.add_item("Dust", 0)
	diff_btn.add_item("Blood", 1)
	diff_btn.add_item("Eclipse", 2)
	match GameState.selected_difficulty:
		"blood":
			diff_btn.select(1)
		"eclipse":
			diff_btn.select(2)
		_:
			diff_btn.select(0)
	diff_btn.item_selected.connect(func(i):
		GameState.selected_difficulty = ["dust", "blood", "eclipse"][i]
		GameState.save_game()
		_refresh()
	)


func _build_faction_buttons() -> void:
	for c in buttons.get_children():
		c.queue_free()
	_add_faction_btn("Mayor's Office", _on_mayor)
	_add_faction_btn("Ashwick Kin", _on_kin)
	_add_faction_btn("Dust Compact", _on_vendor_dust)
	if GameState.hub_flags.get("vendor_church", false) or GameState.meta_rank("ash_vendor_church") > 0:
		_add_faction_btn("Church of the Pale Sun", _on_church)
	else:
		_add_faction_btn("Church (rebuild with Ash)", func(): dialogue.text = "The chapel stall is ash and silence. Fund the Churchyard Stall rite.")
	if GameState.hub_flags.get("vendor_petition", false) or GameState.meta_rank("ash_mission_petition") > 0 or GameState.hub_flags.get("mission_board", false) or GameState.hub_flags.get("unlock_mission_petition", false):
		_add_faction_btn("Red Petition", _on_petition)
	else:
		_add_faction_btn("Red Petition (locked)", func(): dialogue.text = "Rebels won't show until the Petition Board rises from ash.")
	if GameState.hub_flags.get("vendor_veyra", false) or GameState.meta_rank("ash_veyra_eyes") > 0 or GameState.hub_flags.get("ashwick_vendor_veyra", false):
		_add_faction_btn("House Veyra's Eyes", _on_veyra)
	else:
		_add_faction_btn("Veyra Eyes (locked)", func(): dialogue.text = "A noble spy needs a rebuilt nest. Spend Ash on their safehouse.")
	_add_faction_btn("Blood Rite Chamber", _on_rite_hint)


func _add_faction_btn(text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(220, 36)
	b.pressed.connect(cb)
	buttons.add_child(b)


func _build_sectors() -> void:
	for c in sector_box.get_children():
		c.queue_free()
	var title := Label.new()
	title.text = "Raids"
	title.modulate = Color(0.86, 0.78, 0.7)
	sector_box.add_child(title)
	for s in SectorDB.all_raidable_sectors():
		var id := str(s.get("id", ""))
		var b := Button.new()
		var clears := int(GameState.sectors_cleared.get(id, 0))
		var mark := "★" if clears > 0 else ""
		var nightmare := " [NIGHTMARE]" if bool(s.get("nightmare", false)) else ""
		b.text = "%s%s%s" % [s.get("name", id), nightmare, (" " + mark) if mark else ""]
		b.custom_minimum_size = Vector2(260, 32)
		if GameState.selected_sector == id:
			b.modulate = Color(1.0, 0.85, 0.7)
		b.pressed.connect(_select_sector.bind(id, str(s.get("description", ""))))
		sector_box.add_child(b)


func _select_sector(id: String, desc: String) -> void:
	GameState.selected_sector = id
	dialogue.text = desc
	_build_sectors()
	_refresh()


func _build_roster() -> void:
	for c in roster_box.get_children():
		c.queue_free()
	var title := Label.new()
	title.text = "Brood Roster"
	title.modulate = Color(0.86, 0.78, 0.7)
	roster_box.add_child(title)
	for ch in CharacterDB.all_characters():
		var id := str(ch.get("id", ""))
		var unlocked := CharacterDB.is_unlocked(id)
		var b := Button.new()
		if unlocked:
			b.text = "%s — select" % ch.get("name", id)
			b.pressed.connect(_select_character.bind(id))
		else:
			var cost: Dictionary = ch.get("unlock_cost", {})
			b.text = "%s — unlock B%d/A%d/T%d" % [ch.get("name", id), int(cost.get("blood", 0)), int(cost.get("ash", 0)), int(cost.get("tech", 0))]
			b.pressed.connect(_unlock_character.bind(id))
		b.custom_minimum_size = Vector2(260, 32)
		if GameState.party.size() and str(GameState.party[0].get("character_id", "")) == id:
			b.modulate = Color(0.85, 0.95, 1.0)
		roster_box.add_child(b)
		## Alts
		if unlocked:
			for alt in CharacterDB.get_alts(id):
				var aid := str(alt.get("id", ""))
				var ab := Button.new()
				if aid in GameState.unlocked_alts:
					ab.text = "  alt: %s" % alt.get("name", aid)
					ab.pressed.connect(_select_alt.bind(id, aid))
				else:
					var ac: Dictionary = alt.get("unlock_cost", {})
					ab.text = "  unlock alt %s (B%d/A%d/T%d)" % [alt.get("name", aid), int(ac.get("blood", 0)), int(ac.get("ash", 0)), int(ac.get("tech", 0))]
					ab.pressed.connect(_unlock_alt.bind(aid, ac))
				ab.custom_minimum_size = Vector2(260, 28)
				roster_box.add_child(ab)


func _build_meta() -> void:
	for c in meta_box.get_children():
		c.queue_free()
	var title := Label.new()
	title.text = "Meta — Blood / Ash / Tech"
	title.modulate = Color(0.86, 0.78, 0.7)
	meta_box.add_child(title)
	for branch in ["blood", "ash", "tech"]:
		var bl := Label.new()
		bl.text = branch.capitalize()
		bl.modulate = Color(0.7, 0.65, 0.55)
		meta_box.add_child(bl)
		for up in MetaDB.get_branch(branch):
			var id := str(up.get("id", ""))
			var rank := GameState.meta_rank(id)
			var max_r := int(up.get("max_rank", 1))
			var b := Button.new()
			b.text = "%s [%d/%d]" % [up.get("name", id), rank, max_r]
			b.tooltip_text = str(up.get("desc", ""))
			b.disabled = rank >= max_r
			b.custom_minimum_size = Vector2(260, 28)
			b.pressed.connect(func():
				if GameState.buy_meta(id):
					dialogue.text = "Rite taken: %s" % up.get("name", id)
					_build_meta()
					_build_faction_buttons()
					_refresh()
				else:
					dialogue.text = "Not enough tribute for %s." % up.get("name", id)
			)
			meta_box.add_child(b)


func _refresh() -> void:
	currencies.text = "Blood %d   Ash %d   Tech %d   ·   Moons %d" % [
		GameState.blood, GameState.ash, GameState.tech, GameState.moons_survived
	]
	var heats := ", ".join(GameState.heat_modifiers) if GameState.heat_modifiers.size() else "none"
	ng_label.text = "NG+ %d · Heats: %s · Diff: %s" % [GameState.ng_plus, heats, GameState.difficulty_label()]
	status.text = "Ashwick — ruined family town · Sector: %s" % GameState.selected_sector.replace("_", " ").capitalize()
	var parts: PackedStringArray = []
	for i in GameState.party.size():
		var p: Dictionary = GameState.party[i]
		parts.append("P%d:%s" % [i + 1, str(p.get("character_id", "?"))])
	party_label.text = "Party (%d): %s" % [GameState.party.size(), ", ".join(parts)]
	raid_btn.text = "Raid %s" % GameState.selected_sector.replace("_", " ").capitalize()


func _apply_reputation_flavor() -> void:
	match RunState.reputation_label():
		"Hated":
			dialogue.text = "Shutters slam. Last moon's feeding still stains their tongues."
		"Feared":
			dialogue.text = "Folk cross the street. The mayor smiles too wide."
		"Wary":
			dialogue.text = "Whispers follow your cape. Still, they need you."
		_:
			if dialogue.text == "":
				dialogue.text = "Dust wind through broken rails. Your kin still keep a light on."


func _select_character(id: String) -> void:
	var alt := ""
	if GameState.party.size():
		alt = str(GameState.party[0].get("alt_id", ""))
	GameState.party[0] = {"character_id": id, "alt_id": alt if alt.begins_with(id) else "", "device": -1}
	dialogue.text = str(CharacterDB.get_character(id).get("description", id))
	_build_roster()
	_refresh()


func _select_alt(char_id: String, alt_id: String) -> void:
	GameState.party[0] = {"character_id": char_id, "alt_id": alt_id, "device": -1}
	dialogue.text = "Alt kit bound: %s" % alt_id
	_refresh()


func _unlock_character(id: String) -> void:
	if GameState.unlock_character(id):
		dialogue.text = "%s joins the brood." % CharacterDB.get_character(id).get("name", id)
		_build_roster()
	else:
		dialogue.text = "Not enough Blood/Ash/Tech to wake that sibling."


func _unlock_alt(alt_id: String, cost: Dictionary) -> void:
	if GameState.unlock_alt(alt_id, cost):
		dialogue.text = "Alt unbound: %s" % alt_id
		_build_roster()
	else:
		dialogue.text = "Cannot afford that alt kit."


func _on_raid() -> void:
	RunState.reputation = 0
	get_tree().change_scene_to_file("res://scenes/sector/sector_run.tscn")


func _on_add_p2() -> void:
	if GameState.party.size() >= 4:
		dialogue.text = "Four is the brood's limit."
		return
	## Next unlocked character not in party, keyboard P2 / joypad
	var used: Array[String] = []
	for p in GameState.party:
		used.append(str(p.get("character_id", "")))
	var pick := "severin"
	for ch in CharacterDB.all_characters():
		var id := str(ch.get("id", ""))
		if CharacterDB.is_unlocked(id) and id not in used:
			pick = id
			break
	var dev := 0 if GameState.party.size() == 1 else GameState.party.size() - 1
	if GameState.party.size() == 1:
		dev = -2 ## flag for arrow keys P2
	GameState.party.append({"character_id": pick, "alt_id": "", "device": 0 if GameState.party.size() > 1 else -2})
	## Fix device: P1 keyboard -1, P2 arrows as index with device -2 handled in player as index 1
	GameState.party[GameState.party.size() - 1]["device"] = 0 if GameState.party.size() > 2 else -2
	dialogue.text = "P%d joins as %s. Arrows/Ctrl/Shift or gamepad." % [GameState.party.size(), pick]
	_refresh()


func _on_mayor() -> void:
	GameState.mayor_met = true
	GameState.save_game()
	if RunState.reputation <= -5:
		dialogue.text = "Mayor: \"Monster. Raid if you must—the Church is watching.\""
	else:
		dialogue.text = "Mayor: \"The Dominion wants bodies, not scandals. Clear a sector. Quietly.\""


func _on_kin() -> void:
	GameState.kin_met = true
	GameState.add_currency("ash", 2)
	dialogue.text = "Kin: \"You look like him when the moon's wrong. Still—come home between hunts. (+2 Ash)\""
	_refresh()


func _on_vendor_dust() -> void:
	var cost := 6 if RunState.reputation > -3 else 12
	if RunState.reputation_label() == "Hated":
		dialogue.text = "Smuggler won't open. You're hated this moon."
		return
	if GameState.spend("ash", cost):
		GameState.add_currency("tech", 2)
		dialogue.text = "Dust Compact: \"Rail scrap and a prayer.\" (-%d Ash, +2 Tech)" % cost
	else:
		dialogue.text = "Dust Compact: \"Come back with ash.\""
	_refresh()


func _on_church() -> void:
	GameState.church_met = true
	if RunState.feed_count > 0 or RunState.reputation < 0:
		dialogue.text = "Cantor's aide: \"We smell the feed on you. Tithe Blood or leave.\""
		if GameState.spend("blood", 8):
			dialogue.text = "Church: \"Absolved—thinly. Do not feed on a hymn-night.\""
	else:
		dialogue.text = "Church: \"Aurelian's light judges. Buy a ward for 10 Blood?\""
		if GameState.can_spend("blood", 10) and GameState.spend("blood", 10):
			dialogue.text = "You carry a pale ward into the next raid. (+8 max HP via blood spent rite — flavor)"
	GameState.save_game()
	_refresh()


func _on_petition() -> void:
	GameState.petition_met = true
	dialogue.text = "Red Petition: \"Hit a sector general. We'll tip Ash your way.\" (+5 Ash retainer)"
	GameState.add_currency("ash", 5)
	_refresh()


func _on_veyra() -> void:
	GameState.veyra_met = true
	if GameState.spend("tech", 8):
		GameState.add_currency("blood", 6)
		dialogue.text = "Veyra Eyes: \"Noble tech for imperial blood. Don't tell the Church.\" (-8 Tech, +6 Blood)"
	else:
		dialogue.text = "Veyra Eyes: \"Bring tech. We don't barter in kindness.\""
	_refresh()


func _on_rite_hint() -> void:
	dialogue.text = "Blood rites are bought in the Meta panel. The moon keeps the receipt."
