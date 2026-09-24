extends Area2D
class_name GreedShrine
## Wild-stage greed interactable (MW-025): stand in it to channel, then SectorController pays out.
## Kinds: chest (Blood/Ash/Tech haul or gear), moon_altar (boon, moon hurries the director),
## blood_well (boon, paid in feed stacks or blood). The timer keeps running while you channel.

signal activated(shrine: GreedShrine, player: Node)

const CHANNEL_S := {"chest": 1.5, "moon_altar": 1.0, "blood_well": 1.0}
const TITLES := {
	"chest": "Strongbox",
	"moon_altar": "Moon Altar",
	"blood_well": "Blood Well",
}
const HINTS := {
	"chest": "stand to pry open",
	"moon_altar": "a boon · the moon hurries",
	"blood_well": "a boon · pay in hunger or blood",
}

var kind: String = "chest"
var used: bool = false
var _channel: float = 0.0
var _inside: Array[Node] = []
var _base: Polygon2D
var _glow: Polygon2D
var _bar: Polygon2D
var _label: Label


func _ready() -> void:
	add_to_group("greed_hook")
	add_to_group("greed_shrine")
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_build_visual()


func setup(kind_id: String, pos: Vector2) -> void:
	kind = kind_id
	position = pos
	set_meta("kind", kind)
	if is_inside_tree():
		_build_visual()


func channel_seconds() -> float:
	return float(CHANNEL_S.get(kind, 1.2))


func _physics_process(delta: float) -> void:
	if used:
		return
	var who: Node = null
	for b in _inside:
		if is_instance_valid(b) and not bool(b.get("dead")):
			who = b
			break
	if who == null:
		_channel = maxf(0.0, _channel - delta * 2.0)
	else:
		_channel += delta
		if _channel >= channel_seconds():
			_activate(who)
	_update_bar()


func _activate(who: Node) -> void:
	used = true
	_channel = 0.0
	if _base:
		_base.modulate = Color(0.45, 0.45, 0.45, 0.7)
	if _glow:
		_glow.visible = false
	if _label:
		_label.text = "%s (spent)" % str(TITLES.get(kind, kind))
		_label.modulate = Color(0.6, 0.55, 0.5, 0.6)
	activated.emit(self, who)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") and not _inside.has(body):
		_inside.append(body)


func _on_body_exited(body: Node) -> void:
	_inside.erase(body)


func _update_bar() -> void:
	if _bar == null:
		return
	var f := clampf(_channel / maxf(channel_seconds(), 0.01), 0.0, 1.0)
	_bar.visible = f > 0.0 and not used
	_bar.scale = Vector2(f, 1.0)


func _build_visual() -> void:
	for c in get_children():
		c.queue_free()
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 46.0
	shape.shape = circle
	add_child(shape)

	var col := Color(0.62, 0.48, 0.24, 0.95)
	var glow := Color(0.95, 0.75, 0.35, 0.35)
	var poly := PackedVector2Array([Vector2(-18, 12), Vector2(18, 12), Vector2(18, -8), Vector2(-18, -8)])
	match kind:
		"moon_altar":
			col = Color(0.55, 0.58, 0.66, 0.95)
			glow = Color(0.75, 0.82, 1.0, 0.35)
			poly = PackedVector2Array([Vector2(-16, 14), Vector2(16, 14), Vector2(10, -22), Vector2(0, -30), Vector2(-10, -22)])
		"blood_well":
			col = Color(0.36, 0.1, 0.12, 0.95)
			glow = Color(0.85, 0.12, 0.16, 0.4)
			poly = PackedVector2Array([Vector2(-22, 6), Vector2(-14, -10), Vector2(14, -10), Vector2(22, 6), Vector2(14, 16), Vector2(-14, 16)])
	_glow = Polygon2D.new()
	_glow.color = glow
	var ring := PackedVector2Array()
	for i in 20:
		var a := TAU * float(i) / 20.0
		ring.append(Vector2(cos(a) * 44.0, sin(a) * 26.0))
	_glow.polygon = ring
	add_child(_glow)
	_base = Polygon2D.new()
	_base.color = col
	_base.polygon = poly
	add_child(_base)

	_bar = Polygon2D.new()
	_bar.color = Color(0.95, 0.85, 0.6, 0.9)
	_bar.polygon = PackedVector2Array([Vector2(0, 0), Vector2(60, 0), Vector2(60, 5), Vector2(0, 5)])
	_bar.position = Vector2(-30, 22)
	_bar.visible = false
	add_child(_bar)

	_label = Label.new()
	_label.text = "%s\n%s" % [str(TITLES.get(kind, kind)), str(HINTS.get(kind, ""))]
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.position = Vector2(-80, -66)
	_label.size = Vector2(160, 34)
	_label.add_theme_font_size_override("font_size", 11)
	_label.modulate = Color(0.92, 0.85, 0.72, 0.9)
	add_child(_label)
