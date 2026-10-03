extends Node
## Headless (MW-036): Esc/Start pauses and resumes; playtest unlocks the roster in
## memory only and leaves the save file byte-identical.

const MAIN := preload("res://scenes/main.tscn")
const HUD := preload("res://scenes/ui/hud.tscn")
const PAUSE_MENU := preload("res://scenes/ui/pause_menu.tscn")
const BOON := preload("res://scenes/ui/boon_select.tscn")
const DEATH := preload("res://scenes/ui/death_screen.tscn")
const DEFAULT_SEED := 36
const SIBLINGS: Array[String] = ["severin", "mira", "cassian", "odette", "vesper"]
const ALTS: Array[String] = [
	"severin_gunsmith",
	"mira_choir_rail",
	"cassian_scholar_orbit",
	"odette_pit_hammer",
	"vesper_anchor_spike",
]
const SECTORS: Array[String] = [
	"dust_meridian",
	"cinder_barrens",
	"gloampine",
	"salt_choir",
	"iron_orchard",
	"noir_cathedral",
	"umbral_marches",
	"pale_spire",
]

var _seed: int = 0
var _save_existed: bool = false
var _save_backup: PackedByteArray = PackedByteArray()
var _menu: CanvasLayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_seed = SmokeSeed.begin(DEFAULT_SEED)
	print("PAUSE_PLAYTEST_START")
	_snapshot_save()
	call_deferred("_begin")


func _begin() -> void:
	_persist()
	var detail := await _run()
	var restore_err := _restore_save()
	if restore_err != "":
		detail = restore_err if detail == "" else "%s; also %s" % [detail, restore_err]
	if detail != "":
		_fail(detail)
		return
	print("PAUSE_PLAYTEST_PASS")
	var quit_btn: Button = _menu.get_node("Root/Center/Panel/VBox/Quit")
	quit_btn.pressed.emit()
	await get_tree().create_timer(1.0, true, true, false).timeout
	_fail("quit did not exit")


func _persist() -> void:
	var tree := get_tree()
	if tree.current_scene != self:
		return
	var root := tree.root
	root.remove_child(self)
	root.add_child(self)


func _run() -> String:
	var err := _check_playtest_memory()
	if err == "":
		err = await _check_title_picker()
	if err == "":
		err = await _check_hud_label()
	if err == "":
		err = await _check_pause()
	if err == "":
		err = await _check_boon_still_works()
	if err == "":
		err = await _check_death_still_works()
	if err == "":
		err = await _check_restart_and_ashwick()
	return err


func _check_playtest_memory() -> String:
	GameState.set_playtest(false)
	var chars: Array[String] = ["severin"]
	GameState.unlocked_characters = chars
	var alts: Array[String] = []
	GameState.unlocked_alts = alts
	GameState.set_party_solo("severin", "")
	GameState.selected_sector = "dust_meridian"
	GameState.save_game()
	var canonical := FileAccess.get_file_as_bytes(GameState.SAVE_PATH)
	var err := ""
	if not GameState.playtest_arg(PackedStringArray(["--playtest"])):
		err = "--playtest was not recognized"
	elif GameState.playtest_arg(PackedStringArray(["seed=1"])):
		err = "an unrelated arg was treated as playtest"
	if err != "":
		return err
	GameState.set_playtest(true)
	for id: String in SIBLINGS:
		if err == "" and not CharacterDB.is_unlocked(id):
			err = "playtest left %s locked" % id
	for alt_id: String in ALTS:
		if err == "" and not CharacterDB.is_alt_unlocked(alt_id):
			err = "playtest left alt %s locked" % alt_id
	if err == "" and CharacterDB.is_alt_unlocked("not_a_real_alt"):
		err = "playtest unlocked an unknown alt"
	if err == "" and SectorDB.all_raidable_sectors().size() != SECTORS.size():
		err = "expected 8 sectors"
	GameState.set_party_solo("vesper", "vesper_anchor_spike")
	GameState.selected_sector = "pale_spire"
	GameState.save_game()
	var after := FileAccess.get_file_as_bytes(GameState.SAVE_PATH)
	if err == "" and after != canonical:
		err = "save bytes changed under playtest (%d vs %d)" % [canonical.size(), after.size()]
	if (
		err == ""
		and (
			GameState.unlocked_characters.size() != 1
			or GameState.unlocked_characters[0] != "severin"
		)
	):
		err = "playtest wrote unlocked_characters"
	if err == "" and not GameState.unlocked_alts.is_empty():
		err = "playtest wrote unlocked_alts"
	GameState.set_playtest(false)
	if err == "" and (CharacterDB.is_unlocked("vesper") or CharacterDB.is_unlocked("mira")):
		err = "leaving playtest kept siblings unlocked"
	if err == "" and CharacterDB.is_alt_unlocked("vesper_anchor_spike"):
		err = "leaving playtest kept the alt unlocked"
	if err == "" and GameState.party.is_empty():
		err = "party was empty after leaving playtest"
	elif err == "" and str(GameState.party[0].get("character_id", "")) != "severin":
		err = "leaving playtest did not restore the party"
	elif err == "" and str(GameState.party[0].get("alt_id", "x")) != "":
		err = "leaving playtest kept the alt equipped"
	if err == "" and GameState.selected_sector != "dust_meridian":
		err = "leaving playtest did not restore the sector"
	return err


func _check_title_picker() -> String:
	var main: Node = MAIN.instantiate()
	add_child(main)
	await get_tree().process_frame
	var picker: Control = main.get_node("Center/VBox/Picker")
	var err := ""
	if picker.visible:
		err = "picker visible while playtest is off"
	var toggle: Button = main.get_node("Center/VBox/Playtest")
	if err == "":
		toggle.pressed.emit()
		await get_tree().process_frame
		if not GameState.playtest_mode or not picker.visible:
			err = "title toggle did not turn playtest on"
	if err == "":
		var sibling: OptionButton = picker.get_node("Sibling")
		var alt: OptionButton = picker.get_node("Alt")
		var sector: OptionButton = picker.get_node("Sector")
		if sibling.item_count != SIBLINGS.size():
			err = "sibling picker has %d items" % sibling.item_count
		elif alt.item_count < 2:
			err = "alt picker missing the base kit and the alt"
		elif sector.item_count != SECTORS.size():
			err = "sector picker has %d items" % sector.item_count
		else:
			for i: int in SECTORS.size():
				if str(sector.get_item_metadata(i)) != SECTORS[i]:
					err = "sector picker missing %s" % SECTORS[i]
					break
		var start: Button = main.get_node("Center/VBox/Start")
		if err == "" and not start.text.contains("Dust Meridian"):
			err = "play raid label did not follow the sector"
		if err == "":
			toggle.pressed.emit()
			await get_tree().process_frame
			if GameState.playtest_mode or picker.visible:
				err = "title toggle did not turn playtest off"
	main.queue_free()
	await get_tree().process_frame
	return err


func _check_hud_label() -> String:
	RunState.phase = RunState.Phase.DUNGEON
	GameState.set_playtest(true)
	var hud: Node = HUD.instantiate()
	add_child(hud)
	await get_tree().process_frame
	var label: Label = hud.get_node("Root/PlaytestLabel")
	var bad := ""
	if not hud.visible or not label.visible or label.text != "PLAYTEST":
		bad = "PLAYTEST label missing from the HUD"
	GameState.set_playtest(false)
	await get_tree().process_frame
	if bad == "" and label.visible:
		bad = "PLAYTEST label stayed up after leaving playtest"
	hud.queue_free()
	RunState.phase = RunState.Phase.HUB
	await get_tree().process_frame
	return bad


func _check_pause() -> String:
	_menu = PAUSE_MENU.instantiate()
	add_child(_menu)
	await get_tree().process_frame
	var key := InputEventKey.new()
	key.physical_keycode = KEY_ESCAPE
	key.pressed = true
	var joy := InputEventJoypadButton.new()
	joy.button_index = JOY_BUTTON_START
	joy.pressed = true
	var err := ""
	if not key.is_action_pressed("pause_menu"):
		err = "Esc is not bound to pause_menu"
	elif not joy.is_action_pressed("pause_menu"):
		err = "pad Start is not bound to pause_menu"
	elif get_tree().paused or _menu.visible:
		err = "pause menu started open"
	if err != "":
		return err
	_menu._unhandled_input(key)
	var resume: Button = _menu.get_node("Root/Center/Panel/VBox/Resume")
	if not get_tree().paused or not _menu.visible:
		err = "Esc did not pause"
	elif not resume.can_process():
		err = "Resume is frozen while paused"
	if err != "":
		return err
	_menu._unhandled_input(joy)
	if get_tree().paused or _menu.visible:
		err = "Start did not resume"
	else:
		_menu._unhandled_input(key)
		resume.pressed.emit()
		if get_tree().paused or _menu.visible:
			err = "Resume did not unpause"
	return err


func _check_boon_still_works() -> String:
	var boon: CanvasLayer = BOON.instantiate()
	add_child(boon)
	boon.open_choices()
	await get_tree().process_frame
	if not get_tree().paused or not boon.visible or not boon.can_process():
		boon.queue_free()
		get_tree().paused = false
		return "boon select did not pause in a running state"
	var key := InputEventKey.new()
	key.physical_keycode = KEY_ESCAPE
	key.pressed = true
	_menu._unhandled_input(key)
	if _menu.visible or not boon.visible:
		boon.queue_free()
		get_tree().paused = false
		return "pause menu covered an open boon select"
	var buttons: HBoxContainer = boon.get_node("Center/VBox/Cards")
	if buttons.get_child_count() < 1:
		boon.queue_free()
		get_tree().paused = false
		return "boon select offered no choice"
	var choice: Node = buttons.get_child(0)
	if not choice is Button or not (choice as Button).can_process():
		boon.queue_free()
		get_tree().paused = false
		return "boon choice frozen while paused"
	(choice as Button).pressed.emit()
	await get_tree().process_frame
	var bad := ""
	if boon.visible or get_tree().paused:
		bad = "boon pick did not resume combat"
	boon.queue_free()
	get_tree().paused = false
	_menu.visible = false
	return bad


func _check_death_still_works() -> String:
	get_tree().paused = true
	var death: Control = DEATH.instantiate()
	add_child(death)
	await get_tree().process_frame
	var cont: Button = death.get_node("Center/VBox/Continue")
	var bad := ""
	if not death.can_process() or not cont.can_process():
		bad = "death screen frozen while the tree is paused"
	death.queue_free()
	get_tree().paused = false
	await get_tree().process_frame
	return bad


func _check_restart_and_ashwick() -> String:
	var err := ""
	_menu._unhandled_input(_esc())
	if not get_tree().paused:
		err = "raid pause did not open before restart"
	else:
		var restart: Button = _menu.get_node("Root/Center/Panel/VBox/Restart")
		restart.pressed.emit()
		await get_tree().process_frame
		await get_tree().process_frame
		var raid := get_tree().current_scene
		if raid == null or raid.scene_file_path != "res://scenes/sector/sector_run.tscn":
			err = "Restart raid did not open the sector"
		elif get_tree().paused:
			err = "Restart raid left the tree paused"
	if err == "":
		_menu._unhandled_input(_esc())
		if not get_tree().paused:
			err = "pause did not open in the raid"
		else:
			var ashwick: Button = _menu.get_node("Root/Center/Panel/VBox/Ashwick")
			ashwick.pressed.emit()
			await get_tree().process_frame
			await get_tree().process_frame
			var hub := get_tree().current_scene
			if hub == null or hub.scene_file_path != "res://scenes/hub/ashwick.tscn":
				err = "Return to Ashwick did not open the hub"
			elif get_tree().paused:
				err = "Return to Ashwick left the tree paused"
	return err


func _esc() -> InputEventKey:
	var key := InputEventKey.new()
	key.physical_keycode = KEY_ESCAPE
	key.pressed = true
	return key


func _snapshot_save() -> void:
	_save_existed = FileAccess.file_exists(GameState.SAVE_PATH)
	if _save_existed:
		_save_backup = FileAccess.get_file_as_bytes(GameState.SAVE_PATH)


func _restore_save() -> String:
	if not _save_existed:
		if FileAccess.file_exists(GameState.SAVE_PATH):
			var abs_path := ProjectSettings.globalize_path(GameState.SAVE_PATH)
			var err := DirAccess.remove_absolute(abs_path)
			if err != OK:
				return "could not remove the smoke save (%s)" % error_string(err)
		return ""
	var file := FileAccess.open(GameState.SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return "could not restore the save file"
	file.store_buffer(_save_backup)
	file.close()
	if FileAccess.get_file_as_bytes(GameState.SAVE_PATH) != _save_backup:
		return "restored save does not match the backup"
	return ""


func _fail(detail: String) -> void:
	var msg := SmokeSeed.fail_line("PAUSE_PLAYTEST_FAIL", _seed, detail)
	push_error(msg)
	print(msg)
	get_tree().quit(1)
