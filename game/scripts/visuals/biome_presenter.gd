extends Node2D
class_name BiomePresenter
## Builds 2.5D biome ground, props, particles, lighting for a sector/hub.

var _ground: Sprite2D
var _tiles: Node2D
var _props: Node2D
var _fx: Node2D
var _modulate: CanvasModulate
var _light: PointLight2D
var _particles: GPUParticles2D


func clear() -> void:
	for c in get_children():
		c.queue_free()


func present_sector(sector: Dictionary, half_size: Vector2) -> void:
	clear()
	var sid := str(sector.get("id", "dust_meridian"))
	_build_ground(sid, half_size)
	_build_props(sid, half_size)
	_build_atmosphere(sid, sector)
	_build_particles(sid)


func present_ashwick() -> void:
	clear()
	_build_ground("ashwick", Vector2(700, 420))
	_spawn_prop("chapel", Vector2(0, -180), 1.2)
	_spawn_prop("ruin", Vector2(-260, -40), 1.0)
	_spawn_prop("ruin", Vector2(240, -20), 0.9)
	_spawn_prop("rail", Vector2(0, 80), 2.5)
	_spawn_prop("crate", Vector2(-120, 40), 1.0)
	_spawn_prop("crate", Vector2(140, 60), 1.0)
	_build_atmosphere("ashwick", {"accent": Color(0.5, 0.35, 0.3)})
	_build_particles("ashwick")


func _build_ground(sid: String, half_size: Vector2) -> void:
	var path := "res://assets/textures/tiles/%s_ground.png" % sid
	if not ResourceLoader.exists(path):
		path = "res://assets/textures/tiles/dust_meridian_ground.png"
	_ground = Sprite2D.new()
	var tex: Texture2D = load(path) as Texture2D
	if tex == null:
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img:
			tex = ImageTexture.create_from_image(img)
	if tex == null:
		return
	_ground.texture = tex
	_ground.z_index = -20
	_ground.centered = true
	## Stretch to arena
	var tex_size := _ground.texture.get_size()
	_ground.scale = Vector2(half_size.x * 2.0 / tex_size.x, half_size.y * 2.0 / tex_size.y) * 1.05
	add_child(_ground)
	## Iso diamond overlays
	_tiles = Node2D.new()
	_tiles.z_index = -19
	add_child(_tiles)
	var tile_path := "res://assets/textures/tiles/%s.png" % sid
	if not ResourceLoader.exists(tile_path):
		return
	var tile_tex: Texture2D = load(tile_path)
	for iy in range(-3, 4):
		for ix in range(-4, 5):
			var s := Sprite2D.new()
			s.texture = tile_tex
			s.modulate = Color(1, 1, 1, 0.18)
			s.position = Vector2(ix * 90 + (iy % 2) * 45, iy * 50)
			s.scale = Vector2(0.7, 0.45) ## flatten into faux-iso
			s.z_index = -19
			_tiles.add_child(s)


func _build_props(sid: String, half_size: Vector2) -> void:
	_props = Node2D.new()
	_props.z_index = -5
	_props.y_sort_enabled = true
	add_child(_props)
	match sid:
		"dust_meridian":
			_spawn_prop("rail", Vector2(-200, 120), 2.0)
			_spawn_prop("rail", Vector2(180, -80), 1.6)
			_spawn_prop("ruin", Vector2(-320, -100), 1.0)
			_spawn_prop("crate", Vector2(260, 140), 1.0)
			_spawn_prop("crate", Vector2(-80, -160), 0.9)
		"cinder_barrens":
			_spawn_prop("ruin", Vector2(-280, 0), 1.1)
			_spawn_prop("ruin", Vector2(300, -120), 0.95)
			_spawn_prop("crate", Vector2(40, 160), 1.2)
		"gloampine":
			for i in 6:
				_spawn_prop("ruin", Vector2(-300 + i * 110, -150 + (i % 2) * 80), 0.7 + (i % 3) * 0.15)
		"salt_choir":
			_spawn_prop("chapel", Vector2(0, -200), 1.0)
			_spawn_prop("ruin", Vector2(-260, 40), 0.9)
		"iron_orchard":
			_spawn_prop("crate", Vector2(-200, -40), 1.3)
			_spawn_prop("crate", Vector2(220, 80), 1.1)
			_spawn_prop("rail", Vector2(0, 160), 2.2)
		"noir_cathedral":
			_spawn_prop("chapel", Vector2(-40, -220), 1.4)
			_spawn_prop("ruin", Vector2(280, 20), 1.1)
		"umbral_marches":
			_spawn_prop("rail", Vector2(-100, -40), 2.0)
			_spawn_prop("crate", Vector2(200, -120), 1.0)
		"pale_spire":
			_spawn_prop("chapel", Vector2(0, -240), 1.6)
			_spawn_prop("ruin", Vector2(-320, 60), 1.2)
			_spawn_prop("ruin", Vector2(320, 40), 1.2)
		_:
			_spawn_prop("ruin", Vector2(-200, -80), 1.0)


func _spawn_prop(kind: String, pos: Vector2, scl: float) -> void:
	if _props == null:
		_props = Node2D.new()
		add_child(_props)
	var path := "res://assets/textures/props/%s.png" % kind
	if not ResourceLoader.exists(path):
		return
	var s := Sprite2D.new()
	s.texture = load(path)
	s.position = pos
	s.scale = Vector2(scl, scl)
	s.centered = true
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	## Fake depth: lower on screen = higher z
	s.z_index = int(pos.y / 10.0)
	_props.add_child(s)


func _build_atmosphere(sid: String, sector: Dictionary) -> void:
	_modulate = CanvasModulate.new()
	match sid:
		"dust_meridian", "ashwick":
			_modulate.color = Color(0.95, 0.88, 0.78)
		"cinder_barrens":
			_modulate.color = Color(1.0, 0.75, 0.65)
		"gloampine":
			_modulate.color = Color(0.7, 0.85, 0.7)
		"salt_choir":
			_modulate.color = Color(0.92, 0.92, 0.88)
		"iron_orchard":
			_modulate.color = Color(0.8, 0.9, 0.7)
		"noir_cathedral":
			_modulate.color = Color(0.65, 0.6, 0.85)
		"umbral_marches":
			_modulate.color = Color(0.7, 0.75, 0.9)
		"pale_spire":
			_modulate.color = Color(0.85, 0.55, 0.55)
		_:
			_modulate.color = Color(0.9, 0.85, 0.8)
	add_child(_modulate)

	_light = PointLight2D.new()
	_light.color = sector.get("accent", Color(1.0, 0.85, 0.7))
	_light.energy = 0.55
	_light.texture_scale = 2.5
	## Soft circular light via gradient texture
	var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	for y in 128:
		for x in 128:
			var d := Vector2(x - 64, y - 64).length() / 64.0
			var a := clampf(1.0 - d, 0.0, 1.0)
			a = a * a
			img.set_pixel(x, y, Color(1, 1, 1, a))
	var tex := ImageTexture.create_from_image(img)
	_light.texture = tex
	_light.position = Vector2(0, -40)
	add_child(_light)

	## Vignette overlay
	var vig := ColorRect.new()
	vig.z_index = 50
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	## Use a Sprite covering view instead — ColorRect needs canvas layer
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.color = Color(0.05, 0.03, 0.04, 0.0)
	layer.add_child(rect)
	## Gradient vignette via polygon corners
	var corners := ColorRect.new()
	corners.set_anchors_preset(Control.PRESET_FULL_RECT)
	corners.mouse_filter = Control.MOUSE_FILTER_IGNORE
	corners.color = Color(0, 0, 0, 0.25)
	## Use shader-less edge: four dark edge rects
	for data in [
		[0, 0, 1, 0.12],
		[0, 0.88, 1, 0.12],
		[0, 0, 0.08, 1],
		[0.92, 0, 0.08, 1],
	]:
		var e := ColorRect.new()
		e.anchor_left = data[0]
		e.anchor_top = data[1]
		e.anchor_right = data[0] + data[2]
		e.anchor_bottom = data[1] + data[3]
		e.offset_left = 0
		e.offset_top = 0
		e.offset_right = 0
		e.offset_bottom = 0
		e.mouse_filter = Control.MOUSE_FILTER_IGNORE
		e.color = Color(0.02, 0.01, 0.02, 0.55)
		layer.add_child(e)


func _build_particles(sid: String) -> void:
	_particles = GPUParticles2D.new()
	_particles.z_index = 8
	_particles.amount = 48
	_particles.lifetime = 3.5
	_particles.preprocess = 1.0
	_particles.emitting = true
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(600, 400, 1)
	mat.direction = Vector3(0.2, -0.1, 0)
	mat.spread = 40.0
	mat.initial_velocity_min = 8.0
	mat.initial_velocity_max = 28.0
	mat.gravity = Vector3(0, 4, 0)
	mat.scale_min = 0.3
	mat.scale_max = 1.1
	match sid:
		"cinder_barrens", "pale_spire":
			mat.color = Color(1.0, 0.45, 0.25, 0.7)
		"gloampine":
			mat.color = Color(0.6, 0.8, 0.5, 0.45)
		"noir_cathedral", "umbral_marches":
			mat.color = Color(0.6, 0.55, 0.8, 0.4)
		"salt_choir":
			mat.color = Color(0.95, 0.95, 0.9, 0.5)
		_:
			mat.color = Color(0.85, 0.75, 0.55, 0.45)
	_particles.process_material = mat
	var dust := "res://assets/textures/vfx/dust.png"
	if ResourceLoader.exists(dust):
		_particles.texture = load(dust)
	add_child(_particles)
