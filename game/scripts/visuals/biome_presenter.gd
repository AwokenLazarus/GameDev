class_name BiomePresenter
extends Node2D
## Dresses the iso stage for a sector or the hub: painted vista behind, shaded floor slab,
## masonry on the far edges, set pieces, votive lights, motes and the screen grade.
## The tree lives in scenes/visuals/biome.tscn; this script only configures it.

const BLOCK_SCENE := preload("res://scenes/visuals/wall_block.tscn")
const PROP_SCENE := preload("res://scenes/visuals/stage_prop.tscn")
const LIGHT_SCENE := preload("res://scenes/visuals/votive_light.tscn")
const WALL_SHADER := preload("res://assets/shaders/wall.gdshader")
const GRAIN := preload("res://assets/visuals/grain_noise.tres")
## Niche spacing along the far walls; every second niche carries a real light.
const BAY := 150.0
const BLOCK_HEIGHT := 60.0
const BLOCK_SPAN := 44.0
const SLAB_DROP := 150.0
const ASHWICK_HALF := Vector2(620.0, 420.0)
## Footprint centre as a fraction of image height, per painted prop.
const PROP_FOOT := {"chapel": 0.78, "ruin": 0.8, "crate": 0.72, "rail": 0.5}
const FLAT_PROPS: PackedStringArray = ["rail"]

var _look: BiomeLook
var _block_material: ShaderMaterial

@onready var vista: ColorRect = $Backdrop/Vista
@onready var ambient: CanvasModulate = $Ambient
@onready var floor_poly: Polygon2D = $Floor
@onready var slab: StageWalls = $Slab
@onready var behind: Node2D = $Behind
@onready var walls: StageWalls = $Walls
@onready var decals: Node2D = $Decals
@onready var moon_wash: PointLight2D = $MoonWash
@onready var sorted: Node2D = $Sorted
@onready var motes: GPUParticles2D = $Finish/Motes
@onready var grade: ColorRect = $Finish/Grade


func _ready() -> void:
	get_viewport().size_changed.connect(_fit_motes)
	_fit_motes()


## Parent whose children the stage camera depth-sorts (blocks, props).
func sorted_root() -> Node2D:
	return sorted


func present_sector(
	sector: Dictionary, half_size: Vector2, mode: String = "room", inner_walls: Array = []
) -> void:
	var sid := str(sector.get("id", "dust_meridian"))
	_apply_look(sid)
	_clear()
	_lay_floor(half_size)
	var walled := mode != "wild"
	(floor_poly.material as ShaderMaterial).set_shader_parameter("walled", 1.0 if walled else 0.0)
	walls.build(half_size, _look.wall_height, walled)
	slab.build(half_size, SLAB_DROP)
	if walled:
		_light_niches(half_size)
		_raise_blocks(inner_walls)
		_dress_room(half_size)
	else:
		place_landmarks(StageLayout.wild_landmarks(sid, half_size))


func present_ashwick() -> void:
	var half := ASHWICK_HALF
	_apply_look("ashwick")
	_clear()
	_lay_floor(half)
	(floor_poly.material as ShaderMaterial).set_shader_parameter("walled", 0.0)
	walls.build(half, _look.wall_height, false)
	slab.build(half, SLAB_DROP)
	_prop("chapel", Vector2(-420.0, -320.0), 1.3, sorted)
	_prop("ruin", Vector2(-540.0, 60.0), 1.1, sorted)
	_prop("ruin", Vector2(120.0, -360.0), 1.0, sorted)
	_prop("rail", Vector2(160.0, 200.0), 1.4, decals)
	_prop("crate", Vector2(-250.0, -160.0), 0.5, sorted)
	_prop("crate", Vector2(380.0, -240.0), 0.5, sorted)
	for at: Vector2 in [Vector2(-300.0, -200.0), Vector2(200.0, -260.0), Vector2(-60.0, 120.0)]:
		_votive(at, 1.0, 420.0)


## Set pieces at fixed world points (wild-stage landmarks).
func place_landmarks(landmarks: Array) -> void:
	for spec: Variant in landmarks:
		if typeof(spec) != TYPE_DICTIONARY:
			continue
		var kind := str(spec.get("kind", "ruin"))
		var at: Vector2 = spec.get("pos", Vector2.ZERO)
		var flat := FLAT_PROPS.has(kind)
		_prop(kind, at, float(spec.get("scale", 1.0)) * 1.15, decals if flat else sorted)
		if not flat:
			_votive(at + Vector2(46.0, 46.0), 0.9, 380.0)


func _apply_look(sid: String) -> void:
	_look = BiomeLook.for_sector(sid)
	var path := "res://assets/textures/tiles/%s_vista.png" % sid
	var vm := vista.material as ShaderMaterial
	if ResourceLoader.exists(path):
		var tex: Texture2D = load(path)
		vm.set_shader_parameter("vista", tex)
		vm.set_shader_parameter("vista_aspect", float(tex.get_width()) / float(tex.get_height()))
	vm.set_shader_parameter("haze", _look.haze)
	vm.set_shader_parameter("dim", _look.vista_dim)
	var fm := floor_poly.material as ShaderMaterial
	fm.set_shader_parameter("paving", _look.paving)
	fm.set_shader_parameter("tile", _look.tile)
	fm.set_shader_parameter("stone_a", _look.stone_a)
	fm.set_shader_parameter("stone_b", _look.stone_b)
	fm.set_shader_parameter("earth_a", _look.earth_a)
	fm.set_shader_parameter("earth_b", _look.earth_b)
	fm.set_shader_parameter("stain_amount", _look.stain)
	var sm := slab.material as ShaderMaterial
	sm.set_shader_parameter("rock", _look.stone_b)
	sm.set_shader_parameter("mist", _look.haze)
	var wm := walls.material as ShaderMaterial
	wm.set_shader_parameter("stone", _look.wall_stone)
	wm.set_shader_parameter("glow", _look.flame)
	wm.set_shader_parameter("height", _look.wall_height)
	wm.set_shader_parameter("bay", BAY)
	_block_material = ShaderMaterial.new()
	_block_material.shader = WALL_SHADER
	_block_material.set_shader_parameter("grain", GRAIN)
	_block_material.set_shader_parameter("stone", _look.wall_stone.lightened(0.06))
	_block_material.set_shader_parameter("height", BLOCK_HEIGHT)
	_block_material.set_shader_parameter("bay", 0.0)
	moon_wash.color = _look.moon
	moon_wash.energy = 0.6
	motes.modulate = _look.mote
	var gm := grade.material as ShaderMaterial
	gm.set_shader_parameter("shadow_tint", _look.shadow_tint)
	gm.set_shader_parameter("light_tint", _look.light_tint)


func _clear() -> void:
	for group: Node in [behind, decals, sorted]:
		for c: Node in group.get_children():
			c.queue_free()


func _lay_floor(half: Vector2) -> void:
	floor_poly.polygon = PackedVector2Array(
		[
			Vector2(-half.x, -half.y),
			Vector2(half.x, -half.y),
			Vector2(half.x, half.y),
			Vector2(-half.x, half.y)
		]
	)
	(floor_poly.material as ShaderMaterial).set_shader_parameter("half_size", half)
	moon_wash.texture_scale = maxf(half.x, half.y) * 2.6 / 128.0
	## One pool of moonlight suits a room; the open wild is lit evenly instead.
	var open := half.x >= 1000.0
	moon_wash.visible = not open
	ambient.color = _look.ambient.lerp(Color.WHITE, 0.28) if open else _look.ambient


## A real light at the foot of every second niche on both far walls.
func _light_niches(half: Vector2) -> void:
	var step := BAY * 2.0
	var x := -floorf((half.x - 60.0) / step) * step
	while x <= half.x - 60.0:
		_votive(Vector2(x, -half.y + 26.0), 1.15, 400.0)
		x += step
	var y := -floorf((half.y - 60.0) / step) * step
	while y <= half.y - 60.0:
		_votive(Vector2(-half.x + 26.0, y), 1.15, 400.0)
		y += step


func _votive(at: Vector2, strength: float, reach: float) -> void:
	var light: VotiveLight = LIGHT_SCENE.instantiate()
	light.position = at
	## Lights are not depth-sorted; they live with the decals so `_clear` takes them.
	decals.add_child(light)
	light.setup(_look.flame, strength, reach)


## Inner walls become runs of short blocks so each sorts against actors by itself.
func _raise_blocks(inner_walls: Array) -> void:
	for w: Variant in inner_walls:
		if typeof(w) != TYPE_DICTIONARY:
			continue
		var at: Vector2 = w.get("pos", Vector2.ZERO)
		var size: Vector2 = w.get("size", Vector2(40.0, 40.0))
		var nx := maxi(1, ceili(size.x / BLOCK_SPAN))
		var ny := maxi(1, ceili(size.y / BLOCK_SPAN))
		var piece := Vector2(size.x / float(nx), size.y / float(ny))
		for iy: int in ny:
			for ix: int in nx:
				var block: WallBlock = BLOCK_SCENE.instantiate()
				block.position = (
					at - size * 0.5 + Vector2((ix + 0.5) * piece.x, (iy + 0.5) * piece.y)
				)
				sorted.add_child(block)
				block.setup(piece, BLOCK_HEIGHT, _block_material)


## Skyline pieces stand outside the far walls; clutter hugs the far corners of the floor.
func _dress_room(half: Vector2) -> void:
	var n := _look.skyline.size()
	for i: int in n:
		var t := (float(i) + 0.5) / float(n)
		var along := lerpf(-0.8, 0.8, t)
		var kind := _look.skyline[i]
		if i % 2 == 0:
			_prop(kind, Vector2(along * half.x, -half.y - 120.0), 1.25, behind)
		else:
			_prop(kind, Vector2(-half.x - 120.0, along * half.y), 1.25, behind)
	var spots: Array[Vector2] = [
		Vector2(-half.x + 74.0, -half.y + 70.0),
		Vector2(half.x * 0.42, -half.y + 64.0),
		Vector2(-half.x + 66.0, half.y * 0.46),
	]
	for i: int in mini(_look.clutter.size(), spots.size()):
		var kind := _look.clutter[i]
		if FLAT_PROPS.has(kind):
			_prop(kind, Vector2(half.x * 0.2, half.y * 0.25), 1.3, decals)
		else:
			_prop(kind, spots[i], 0.5, sorted)


func _prop(kind: String, at: Vector2, scl: float, into: Node2D) -> void:
	var path := "res://assets/textures/props/%s.png" % kind
	if not ResourceLoader.exists(path):
		push_warning("BiomePresenter: no prop art for '%s'" % kind)
		return
	var prop: StageProp = PROP_SCENE.instantiate()
	prop.position = at
	into.add_child(prop)
	var tex: Texture2D = load(path)
	prop.setup(tex, scl, PROP_FOOT.get(kind, 0.8), into != sorted)


func _fit_motes() -> void:
	var view := get_viewport().get_visible_rect().size
	motes.position = view * 0.5
	var proc := motes.process_material as ParticleProcessMaterial
	proc.emission_box_extents = Vector3(view.x * 0.55, view.y * 0.55, 1.0)
