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


func _ready() -> void:
	RunState.timer_changed.connect(_on_timer)
	RunState.kills_changed.connect(_on_kills)
	RunState.phase_changed.connect(_on_phase)
	RunState.boons_changed.connect(_on_boons)
	RunState.reputation_changed.connect(_on_rep)
	RunState.feed_buff_changed.connect(_on_feed)
	_refresh()


func _process(_delta: float) -> void:
	if RunState.phase == RunState.Phase.HUB:
		visible = false
		return
	visible = true
	hp_bar.max_value = RunState.player_max_hp
	hp_bar.value = RunState.player_hp
	hp_label.text = "%d / %d" % [int(RunState.player_hp), int(RunState.player_max_hp)]


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
			hint_label.text = "Clear the burst · WASD move · J/Click attack · Space dodge · F feed"
		"wild":
			hint_label.text = "Wild stage — push kills for the Marshal · greed vs the timer"
		"boss":
			hint_label.text = "Marshal Corvin Hale — watch the charge telegraph"
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
