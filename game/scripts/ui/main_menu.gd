extends Control

var _hub_btn: Button
var _hint: Label
var _filling: bool = false

@onready var start_btn: Button = $Center/VBox/Start
@onready var quit_btn: Button = $Center/VBox/Quit
@onready var subtitle: Label = $Center/VBox/Subtitle
@onready var playtest_btn: Button = $Center/VBox/Playtest
@onready var picker: VBoxContainer = $Center/VBox/Picker
@onready var sibling_pick: OptionButton = $Center/VBox/Picker/Sibling
@onready var alt_pick: OptionButton = $Center/VBox/Picker/Alt
@onready var sector_pick: OptionButton = $Center/VBox/Picker/Sector
@onready var moon: Sprite2D = $Moon
@onready var hero: Sprite2D = $Hero


func _ready() -> void:
	start_btn.text = "PLAY RAID — Dust Meridian"
	start_btn.custom_minimum_size = Vector2(360, 56)
	start_btn.pressed.connect(_on_play_raid)
	quit_btn.pressed.connect(func() -> void: get_tree().quit())
	subtitle.text = "Fight first. Town hub is optional."
	_hub_btn = Button.new()
	_hub_btn.text = "Ashwick Town Hub"
	_hub_btn.custom_minimum_size = Vector2(360, 44)
	_hub_btn.pressed.connect(_on_hub)
	start_btn.get_parent().add_child(_hub_btn)
	start_btn.get_parent().move_child(_hub_btn, start_btn.get_index() + 1)
	_hint = Label.new()
	_hint.text = (
		"In raid: WASD move · J/LMB attack · K/RMB special · L/Q cast"
		+ " · Space dodge · F feed · Esc pause"
	)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.modulate = Color(0.75, 0.68, 0.6)
	start_btn.get_parent().add_child(_hint)
	start_btn.get_parent().move_child(_hint, _hub_btn.get_index() + 1)
	## Cinematic backdrop
	var vista_path := "res://assets/textures/tiles/ashwick_vista.png"
	if ResourceLoader.exists(vista_path):
		var bg_sprite := Sprite2D.new()
		bg_sprite.texture = load(vista_path)
		bg_sprite.centered = false
		bg_sprite.position = Vector2.ZERO
		var sz: Vector2 = bg_sprite.texture.get_size()
		bg_sprite.scale = Vector2(1280.0 / sz.x, 720.0 / sz.y)
		bg_sprite.z_index = -10
		bg_sprite.modulate = Color(0.55, 0.45, 0.48, 1.0)
		add_child(bg_sprite)
		move_child(bg_sprite, 0)
	if moon and ResourceLoader.exists("res://assets/textures/vfx/moon.png"):
		moon.texture = load("res://assets/textures/vfx/moon.png")
		moon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if hero and ResourceLoader.exists("res://assets/textures/characters/severin.png"):
		hero.texture = load("res://assets/textures/characters/severin.png")
		hero.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		hero.modulate = Color(1.35, 1.25, 1.2)
		hero.scale = Vector2(1.8, 1.8)
	if moon:
		var tw := create_tween().set_loops()
		tw.tween_property(moon, "position:y", moon.position.y - 8.0, 2.4).set_trans(
			Tween.TRANS_SINE
		)
		tw.tween_property(moon, "position:y", moon.position.y + 8.0, 2.4).set_trans(
			Tween.TRANS_SINE
		)
	if hero:
		var tw2 := create_tween().set_loops()
		tw2.tween_property(hero, "position:y", hero.position.y - 4.0, 1.2)
		tw2.tween_property(hero, "position:y", hero.position.y + 4.0, 1.2)
	playtest_btn.pressed.connect(_on_playtest_pressed)
	sibling_pick.item_selected.connect(_on_sibling_picked)
	alt_pick.item_selected.connect(_on_pick_changed)
	sector_pick.item_selected.connect(_on_pick_changed)
	GameState.unlocks_changed.connect(_apply_playtest_ui)
	_apply_playtest_ui()


func _on_playtest_pressed() -> void:
	GameState.set_playtest(not GameState.playtest_mode)


func _apply_playtest_ui() -> void:
	var on := GameState.playtest_mode
	playtest_btn.text = "PLAYTEST: ON" if on else "PLAYTEST: OFF"
	picker.visible = on
	if on:
		_fill_siblings()
	else:
		start_btn.text = "PLAY RAID — Dust Meridian"


func _fill_siblings() -> void:
	_filling = true
	sibling_pick.clear()
	var want := "severin"
	if GameState.party.size() > 0:
		want = str(GameState.party[0].get("character_id", "severin"))
	var select := 0
	var i := 0
	for ch: Dictionary in CharacterDB.all_characters():
		var id := str(ch.get("id", ""))
		sibling_pick.add_item(str(ch.get("name", id)))
		sibling_pick.set_item_metadata(i, id)
		if id == want:
			select = i
		i += 1
	sibling_pick.select(select)
	_fill_alts()
	_fill_sectors()
	_filling = false
	_apply_picks()


func _fill_alts() -> void:
	alt_pick.clear()
	var cid := _meta_id(sibling_pick)
	var want := ""
	if GameState.party.size() > 0:
		want = str(GameState.party[0].get("alt_id", ""))
	alt_pick.add_item("Base kit")
	alt_pick.set_item_metadata(0, "")
	var select := 0
	var i := 1
	for alt: Dictionary in CharacterDB.get_alts(cid):
		var aid := str(alt.get("id", ""))
		alt_pick.add_item(str(alt.get("name", aid)))
		alt_pick.set_item_metadata(i, aid)
		if aid == want:
			select = i
		i += 1
	alt_pick.select(select)


func _fill_sectors() -> void:
	sector_pick.clear()
	var want := GameState.selected_sector if GameState.selected_sector != "" else "dust_meridian"
	var select := 0
	var i := 0
	for sector: Dictionary in SectorDB.all_raidable_sectors():
		var id := str(sector.get("id", ""))
		sector_pick.add_item(str(sector.get("name", id)))
		sector_pick.set_item_metadata(i, id)
		if id == want:
			select = i
		i += 1
	sector_pick.select(select)


func _on_sibling_picked(_index: int) -> void:
	if _filling:
		return
	_filling = true
	_fill_alts()
	_filling = false
	_apply_picks()


func _on_pick_changed(_index: int) -> void:
	if _filling:
		return
	_apply_picks()


func _apply_picks() -> void:
	if not GameState.playtest_mode:
		return
	var cid := _meta_id(sibling_pick)
	if cid == "":
		return
	var alt := _meta_id(alt_pick)
	var sector := _meta_id(sector_pick)
	GameState.set_party_solo(cid, alt)
	if sector != "":
		GameState.selected_sector = sector
	if sector_pick.selected >= 0:
		start_btn.text = "PLAY RAID — %s" % sector_pick.get_item_text(sector_pick.selected)


func _meta_id(btn: OptionButton) -> String:
	var value: Variant = btn.get_selected_metadata()
	if value == null:
		return ""
	return str(value)


func _on_play_raid() -> void:
	## Skip confusing hub — go straight into combat with defaults.
	if GameState.playtest_mode:
		_apply_picks()
	if GameState.party.is_empty():
		GameState.party = [{"character_id": "severin", "alt_id": "", "device": -1}]
	if GameState.selected_sector == "":
		GameState.selected_sector = "dust_meridian"
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/sector/sector_run.tscn")


func _on_hub() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/hub/ashwick.tscn")
