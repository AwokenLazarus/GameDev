extends CanvasLayer

@onready var hp_bar: ProgressBar = $Root/HpBar
@onready var hp_label: Label = $Root/HpLabel
@onready var timer_label: Label = $Root/TimerLabel
@onready var diff_label: Label = $Root/DiffLabel
@onready var kills_label: Label = $Root/KillsLabel
@onready var phase_label: Label = $Root/PhaseLabel
@onready var boon_label: Label = $Root/BoonLabel
@onready var rep_label: Label = $Root/RepLabel
@onready var feed_label: Label = $Root/FeedLabel
@onready var hint_label: Label = $Root/HintLabel
var kit_label: Label
var boss_panel: VBoxContainer
var boss_name: Label
var boss_bar: ProgressBar
var boss_phase: Label
var title_card: Label
var _boss: Node
var _boss_phase_seen: int = -1


func _ready() -> void:
	RunState.timer_changed.connect(_on_timer)
	RunState.kills_changed.connect(_on_kills)
	RunState.phase_changed.connect(_on_phase)
	RunState.boons_changed.connect(_on_boons)
	RunState.reputation_changed.connect(_on_rep)
	RunState.feed_buff_changed.connect(_on_feed)
	kit_label = Label.new()
	kit_label.name = "KitLabel"
	kit_label.position = Vector2(24.0, 192.0)
	$Root.add_child(kit_label)
	_build_boss_ui()
	_refresh()


func _build_boss_ui() -> void:
	boss_panel = VBoxContainer.new()
	boss_panel.name = "BossPanel"
	boss_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	boss_panel.offset_left = -260.0
	boss_panel.offset_right = 260.0
	boss_panel.offset_top = 14.0
	boss_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_panel.visible = false
	$Root.add_child(boss_panel)
	boss_name = Label.new()
	boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_name.add_theme_font_size_override("font_size", 18)
	boss_name.add_theme_color_override("font_color", Color(0.92, 0.82, 0.7))
	boss_panel.add_child(boss_name)
	boss_bar = ProgressBar.new()
	boss_bar.show_percentage = false
	boss_bar.custom_minimum_size = Vector2(520.0, 14.0)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.62, 0.1, 0.12)
	boss_bar.add_theme_stylebox_override("fill", fill)
	boss_panel.add_child(boss_bar)
	boss_phase = Label.new()
	boss_phase.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_phase.add_theme_font_size_override("font_size", 12)
	boss_phase.add_theme_color_override("font_color", Color(0.75, 0.6, 0.55))
	boss_panel.add_child(boss_phase)
	title_card = Label.new()
	title_card.name = "TitleCard"
	title_card.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	title_card.offset_left = -400.0
	title_card.offset_right = 400.0
	title_card.offset_top = -120.0
	title_card.offset_bottom = -40.0
	title_card.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_card.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_card.add_theme_font_size_override("font_size", 30)
	title_card.add_theme_color_override("font_color", Color(0.95, 0.85, 0.72))
	title_card.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.03))
	title_card.add_theme_constant_override("outline_size", 6)
	title_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_card.modulate.a = 0.0
	$Root.add_child(title_card)


func _tick_boss() -> void:
	if _boss == null or not is_instance_valid(_boss):
		_boss = get_tree().get_first_node_in_group("boss")
		_boss_phase_seen = -1
		if _boss == null:
			boss_panel.visible = false
			return
		boss_name.text = str(_boss.get("display_name"))
		_show_card("%s\n%s" % [_boss.get("display_name"), _boss.get("title")])
	var h: Health = _boss.get_node_or_null("Health")
	if h == null:
		return
	boss_panel.visible = true
	boss_bar.max_value = h.max_hp
	boss_bar.value = h.hp
	var idx := int(_boss.get("phase_index"))
	if idx != _boss_phase_seen:
		var n := int(_boss.call("phase_count")) if _boss.has_method("phase_count") else 1
		boss_phase.text = "%s · %d/%d" % [_boss.get("phase_title"), idx + 1, n]
		if _boss_phase_seen >= 0:
			_show_card(str(_boss.get("phase_title")))
		_boss_phase_seen = idx


func _show_card(text: String) -> void:
	title_card.text = text
	var tw := create_tween()
	tw.tween_property(title_card, "modulate:a", 1.0, 0.25)
	tw.tween_interval(1.8)
	tw.tween_property(title_card, "modulate:a", 0.0, 0.6)


func _process(_delta: float) -> void:
	if RunState.phase == RunState.Phase.HUB:
		visible = false
		return
	visible = true
	hp_bar.max_value = RunState.player_max_hp
	hp_bar.value = RunState.player_hp
	hp_label.text = "%d / %d" % [int(RunState.player_hp), int(RunState.player_max_hp)]
	var p := get_tree().get_first_node_in_group("player")
	kit_label.text = p.slot_status() if p and p.has_method("slot_status") else ""
	_tick_boss()


func _refresh() -> void:
	_on_timer(RunState.run_time, RunState.get_difficulty_label())
	_on_kills(RunState.kills, RunState.kill_gate)
	_on_boons()
	_on_rep(RunState.reputation)
	_on_feed(RunState.feed_buff_stacks)


func _on_timer(seconds: float, difficulty: String) -> void:
	var m := int(seconds) / 60
	var s := int(seconds) % 60
	timer_label.text = "%02d:%02d" % [m, s]
	diff_label.text = difficulty


func _on_kills(current: int, needed: int) -> void:
	kills_label.text = "Kills %d / %d" % [current, needed]


func _on_phase(phase: String) -> void:
	phase_label.text = phase.capitalize()
	match phase:
		"dungeon":
			hint_label.text = "Clear the room · walk a door for Pact or Cache · J/LMB attack · K/RMB special · L/Q cast · Space dodge · F feed"
		"wild":
			hint_label.text = "Wild expanse — roam landmarks, keep killing until the general · camera follows you"
		"boss":
			hint_label.text = "GENERAL — red fill lands when full · step out · new phase at each HP notch"
		_:
			hint_label.text = ""


func _on_boons() -> void:
	var pact := ""
	if RunState.has_pact(RunState.aligned_patron):
		pact = " · PACT"
	boon_label.text = "Boons %d/%d · %s%s" % [
		RunState.boon_picks_done,
		RunState.boon_picks_target,
		RunState.patron_display(RunState.aligned_patron) if RunState.aligned_patron != "" else "Unaligned",
		pact,
	]


func _on_rep(value: int) -> void:
	rep_label.text = "Ashwick: %s (%d)" % [RunState.reputation_label(), value]


func _on_feed(stacks: int) -> void:
	feed_label.text = "Feed x%d" % stacks if stacks > 0 else ""
