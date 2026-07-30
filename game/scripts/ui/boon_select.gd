extends CanvasLayer

signal chosen(boon: Dictionary)

@onready var panel: PanelContainer = $Center/Panel
@onready var title: Label = $Center/Panel/VBox/Title
@onready var buttons: VBoxContainer = $Center/Panel/VBox/Buttons

var _choices: Array[Dictionary] = []


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS


func open_choices() -> void:
	_choices = BoonDB.get_choices(3)
	for c in buttons.get_children():
		c.queue_free()
	title.text = "A pact answers in the dust"
	for boon in _choices:
		var btn := Button.new()
		btn.text = "%s — %s\n%s" % [
			RunState.patron_display(str(boon.get("patron", ""))),
			str(boon.get("name", "")),
			str(boon.get("desc", "")),
		]
		btn.custom_minimum_size = Vector2(520, 72)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var captured := boon
		btn.pressed.connect(func(): _pick(captured))
		buttons.add_child(btn)
	visible = true
	get_tree().paused = true


func _pick(boon: Dictionary) -> void:
	RunState.add_boon(boon)
	visible = false
	get_tree().paused = false
	RunState.awaiting_boon = false
	chosen.emit(boon)
