extends Node2D
## Ground effect spawned by a kit slot (flare, sigil, shockwave step). Shows a telegraph
## ring for `delay`, then hits enemies inside `radius` `ticks` times, `interval` apart.
## Damage routes through the owning player so slot hooks and blood marks apply.

var owner_player: Node
var slot: String = "cast"
var radius: float = 50.0
var damage: float = 10.0
var delay: float = 0.0
var ticks: int = 1
var interval: float = 0.25
var knock: float = 0.0
var color: Color = Color(0.85, 0.25, 0.3)

var _t: float = 0.0
var _ring: Line2D
var _fill: Polygon2D


func setup(from: Node, slot_name: String, pos: Vector2, r: float, dmg: float, fuse: float = 0.0,
		tick_count: int = 1, tick_interval: float = 0.25, knock_force: float = 0.0,
		tint: Color = Color(0.85, 0.25, 0.3)) -> void:
	owner_player = from
	slot = slot_name
	global_position = pos
	radius = r
	damage = dmg
	delay = fuse
	ticks = maxi(1, tick_count)
	interval = tick_interval
	knock = knock_force
	color = tint


func _ready() -> void:
	z_index = 5
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * float(i) / 24.0
		pts.append(Vector2(cos(a), sin(a) * 0.6) * radius)
	_fill = Polygon2D.new()
	_fill.polygon = pts
	_fill.color = Color(color, 0.12)
	add_child(_fill)
	_ring = Line2D.new()
	pts.append(pts[0])
	_ring.points = pts
	_ring.width = 2.0
	_ring.default_color = Color(color, 0.8)
	add_child(_ring)


func _physics_process(delta: float) -> void:
	if delay > 0.0:
		delay -= delta
		return
	_t -= delta
	if _t > 0.0:
		return
	_t = interval
	_tick()
	ticks -= 1
	if ticks <= 0:
		set_physics_process(false)
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.18)
		tw.tween_callback(queue_free)


func _tick() -> void:
	_fill.color = Color(color, 0.45)
	var tw := create_tween()
	tw.tween_property(_fill, "color:a", 0.15, 0.12)
	if owner_player == null or not is_instance_valid(owner_player):
		return
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e):
			continue
		var off: Vector2 = e.global_position - global_position
		off.y /= 0.6
		if off.length() <= radius + 10.0:
			owner_player.land_slot_hit(e, damage, slot, false, knock)
