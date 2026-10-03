extends Node
class_name MWVFX
## Static helpers to spawn combat / moon VFX.

static var _hitstopping: bool = false

## How a spawned sprite sits on the iso stage.
enum Pose { SWEEP, PUFF, MARK }


## Arc in the ground plane at the attacker's feet, drawn over actors.
static func slash(parent: Node, pos: Vector2, angle: float) -> void:
	_spawn_sprite(
		parent,
		"res://assets/textures/vfx/slash.png",
		pos,
		angle,
		0.18,
		Vector2(1.2, 1.2),
		Pose.SWEEP
	)


static func blood(parent: Node, pos: Vector2) -> void:
	_spawn_sprite(
		parent,
		"res://assets/textures/vfx/blood.png",
		pos + IsoView.up(44.0),
		0.0,
		0.35,
		Vector2(0.6, 0.6),
		Pose.PUFF
	)


static func dust_puff(parent: Node, pos: Vector2) -> void:
	_spawn_sprite(
		parent,
		"res://assets/textures/vfx/dust.png",
		pos + IsoView.up(14.0),
		0.0,
		0.4,
		Vector2(1.0, 0.8),
		Pose.PUFF
	)


static func telegraph_mark(
	parent: Node, pos: Vector2, life: float = 0.45, scl: Vector2 = Vector2(1.15, 1.15)
) -> void:
	_spawn_sprite(parent, "res://assets/textures/vfx/telegraph.png", pos, 0.0, life, scl, Pose.MARK)


## Flat ground ring that pops out and fades (boon verbs, pact bursts).
static func ring(
	parent: Node, pos: Vector2, r: float, tint: Color, width: float = 3.0, life: float = 0.3
) -> void:
	if parent == null:
		return
	var line := Line2D.new()
	line.points = ellipse(r, 24, true)
	line.width = width
	line.default_color = Color(tint, 0.9)
	IsoView.lay(line)
	parent.add_child(line)
	line.global_position = pos
	line.scale = Vector2(0.4, 0.4)
	var tw := line.create_tween()
	tw.tween_property(line, "scale", Vector2.ONE, life * 0.6)
	tw.parallel().tween_property(line, "modulate:a", 0.0, life)
	tw.tween_callback(line.queue_free)


## Deep pact formed: a patron-coloured double ring and a column of light on the sibling.
static func pact_burst(parent: Node, pos: Vector2, tint: Color) -> void:
	ring(parent, pos, 70.0, tint, 5.0, 0.9)
	ring(parent, pos, 130.0, tint, 3.0, 1.2)
	if parent == null:
		return
	var column := Polygon2D.new()
	column.polygon = PackedVector2Array(
		[Vector2(-16, 0), Vector2(16, 0), Vector2(6, -220), Vector2(-6, -220)]
	)
	column.color = Color(tint, 0.55)
	parent.add_child(column)
	column.global_position = pos
	IsoView.stand(column)
	IsoView.lift(column)
	var tw := column.create_tween()
	tw.tween_property(column, "modulate:a", 0.0, 0.9)
	tw.tween_callback(column.queue_free)


## Ground circle of radius `r`; the iso canvas projection turns it into the on-screen
## ellipse (it was pre-squashed before MW-029). `closed` repeats the first point for Line2D.
static func ellipse(r: float, n: int = 24, closed: bool = false) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i: int in n + 1 if closed else n:
		var a := TAU * float(i) / float(n)
		pts.append(Vector2(cos(a), sin(a)) * r)
	return pts


static func hitstop(tree: SceneTree, seconds: float = 0.045) -> void:
	if _hitstopping or tree == null:
		return
	_hitstopping = true
	Engine.time_scale = 0.18
	await tree.create_timer(seconds, true, false, true).timeout
	Engine.time_scale = 1.0
	_hitstopping = false


static func _spawn_sprite(
	parent: Node, path: String, pos: Vector2, angle: float, life: float, scl: Vector2, pose: Pose
) -> void:
	if parent == null or not ResourceLoader.exists(path):
		return
	var s := Sprite2D.new()
	s.texture = load(path)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	parent.add_child(s)
	s.global_position = pos
	match pose:
		Pose.PUFF:
			IsoView.stand(s, scl)
			IsoView.lift(s)
		Pose.MARK:
			s.scale = scl
			IsoView.lay(s)
		_:
			s.rotation = angle
			s.scale = scl
			IsoView.lift(s)
	var tw := parent.get_tree().create_tween()
	tw.tween_property(s, "modulate:a", 0.0, life)
	tw.parallel().tween_property(s, "scale", s.scale * 1.35, life)
	tw.tween_callback(s.queue_free)
