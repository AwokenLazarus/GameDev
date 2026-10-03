class_name ActorVisual
extends Node2D
## 2.5D actor with real anim states: idle / walk / run / attack / dodge / talk.
## Stands upright on the iso floor: the sprite hangs from an upright rig with its feet on
## this node's origin, and the ground ring, contact shadow and moon shadow are drawn flat.

const ACTOR_SHADER := preload("res://assets/shaders/actor.gdshader")
const SHADOW_SHADER := preload("res://assets/shaders/cast_shadow.gdshader")
const BLOB := preload("res://assets/visuals/soft_blob.tres")
## Screen direction the moon shadow falls in (toward the viewer), per unit of height.
const SHADOW_FALL := Vector2(-0.42, 0.36)
const TARGET_HEIGHT := {"characters": 128.0, "generals": 168.0, "enemies": 96.0, "npcs": 110.0}
## Outline colour and ground-ring colour and radius by role.
const ROLE_OUTLINE := {
	"characters": Color(1.0, 0.86, 0.72, 0.9),
	"enemies": Color(0.72, 0.12, 0.18, 0.85),
	"generals": Color(1.0, 0.76, 0.3, 0.95),
	"npcs": Color(0.6, 0.72, 0.88, 0.6),
}
const ROLE_RING := {
	"characters": Color(0.96, 0.9, 0.82, 0.8),
	"enemies": Color(0.8, 0.14, 0.2, 0.42),
	"generals": Color(1.0, 0.76, 0.3, 0.8),
	"npcs": Color(0.6, 0.72, 0.88, 0.3),
}
const ROLE_RADIUS := {"characters": 22.0, "enemies": 17.0, "generals": 34.0, "npcs": 18.0}

static var _materials: Dictionary[String, ShaderMaterial] = {}
static var _shadow_material: ShaderMaterial

@export var sprite_folder: String = "characters"
@export var sprite_name: String = "severin"
@export var bob_amount: float = 1.2
@export var shadow_scale: Vector2 = Vector2(1.0, 0.45)
@export var show_marker: bool = true

var _rig: Node2D
var _sprite: Sprite2D
var _shadow: Sprite2D
var _anims: Dictionary = {}  ## String -> Array[Texture2D]
var _anim: String = "idle"
var _frames: Array[Texture2D] = []
var _frame_i: int = 0
var _frame_t: float = 0.0
var _loop: bool = true
var _locked: bool = false
var _moving: bool = false
var _running: bool = false
var _facing_right: bool = true
var _flash_t: float = 0.0
var _fps: float = 8.0
var _scale: float = 0.5
var _base_modulate: Color = Color(1.12, 1.08, 1.06, 1.0)


func _ready() -> void:
	z_as_relative = true
	_rig = Node2D.new()
	IsoView.stand(_rig)
	add_child(_rig)
	_shadow = Sprite2D.new()
	_shadow.centered = false
	_shadow.z_index = -1
	_shadow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_shadow.material = _shared_shadow_material()
	_rig.add_child(_shadow)
	_sprite = Sprite2D.new()
	_sprite.centered = false
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_sprite.modulate = _base_modulate
	_rig.add_child(_sprite)
	load_sprite(sprite_folder, sprite_name)


static func _shared_shadow_material() -> ShaderMaterial:
	if _shadow_material == null:
		_shadow_material = ShaderMaterial.new()
		_shadow_material.shader = SHADOW_SHADER
	return _shadow_material


static func _role_material(folder: String) -> ShaderMaterial:
	if not _materials.has(folder):
		var m := ShaderMaterial.new()
		m.shader = ACTOR_SHADER
		m.set_shader_parameter("outline_color", ROLE_OUTLINE.get(folder, Color(0.9, 0.9, 0.9, 0.6)))
		_materials[folder] = m
	return _materials[folder]


func load_sprite(folder: String, name: String) -> void:
	sprite_folder = folder
	sprite_name = name
	_anims.clear()
	for anim: String in ["idle", "walk", "run", "attack", "dodge", "talk"]:
		var frames: Array[Texture2D] = []
		for i: int in 8:
			var path := "res://assets/textures/%s/%s_%s_f%d.png" % [folder, name, anim, i]
			if ResourceLoader.exists(path):
				frames.append(load(path))
			else:
				break
		if not frames.is_empty():
			_anims[anim] = frames
	## Legacy fallback: name_f0..f3 as walk/idle
	if not _anims.has("walk"):
		var legacy: Array[Texture2D] = []
		for i: int in 4:
			var path := "res://assets/textures/%s/%s_f%d.png" % [folder, name, i]
			if ResourceLoader.exists(path):
				legacy.append(load(path))
		if not legacy.is_empty():
			_anims["walk"] = legacy
			_anims["idle"] = [legacy[0]]
	var base := "res://assets/textures/%s/%s.png" % [folder, name]
	if _anims.is_empty() and ResourceLoader.exists(base):
		var t: Texture2D = load(base)
		_anims["idle"] = [t]
		_anims["walk"] = [t]
	_sprite.material = _role_material(folder)
	_locked = false
	_frames = []
	_play_internal(_default_locomotion(), true)
	queue_redraw()


## Flat on the iso floor (this node is not upright): contact shadow, then the role ring.
func _draw() -> void:
	var r: float = ROLE_RADIUS.get(sprite_folder, 18.0)
	var blob := r * 1.9 * shadow_scale.x
	draw_texture_rect(
		BLOB, Rect2(-blob, -blob, blob * 2.0, blob * 2.0), false, Color(0.02, 0.01, 0.03, 0.88)
	)
	if not show_marker:
		return
	var col: Color = ROLE_RING.get(sprite_folder, Color(0.9, 0.9, 0.9, 0.3))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, col, 1.6, true)
	if sprite_folder == "generals":
		draw_arc(Vector2.ZERO, r + 7.0, 0.0, TAU, 48, Color(col, col.a * 0.5), 1.2, true)
	elif sprite_folder == "characters":
		## Four crescent ticks: reads as "you" without a label.
		for i: int in 4:
			var a := TAU * float(i) / 4.0 + PI * 0.25
			draw_arc(Vector2.ZERO, r + 5.0, a - 0.22, a + 0.22, 8, Color(0.78, 0.16, 0.2, 0.9), 2.2)


func _show_frame(tex: Texture2D) -> void:
	if tex == null:
		return
	var target_h: float = TARGET_HEIGHT.get(sprite_folder, 110.0)
	_scale = target_h / maxf(float(tex.get_height()), 1.0)
	var feet := Vector2(-tex.get_width() * 0.5, -float(tex.get_height()))
	_sprite.texture = tex
	_sprite.offset = feet
	_shadow.texture = tex
	_shadow.offset = feet
	_apply_facing()


func _apply_facing() -> void:
	var sx := _scale if _facing_right else -_scale
	_sprite.scale = Vector2(sx, _scale)
	## Same silhouette, sheared onto the ground: head lands down-screen from the feet.
	_shadow.transform = Transform2D(
		Vector2(sx, 0.0), -SHADOW_FALL * _scale * shadow_scale.x, Vector2.ZERO
	)


func _default_locomotion() -> String:
	if _moving:
		return "run" if _running and _anims.has("run") else "walk"
	return "idle" if _anims.has("idle") else "walk"


func play(anim: String, loop: bool = true, fps: float = -1.0) -> void:
	if _locked and anim != _anim:
		return
	_play_internal(anim, loop, fps)


func play_oneshot(anim: String, fps: float = 12.0) -> void:
	if not _anims.has(anim):
		return
	_locked = true
	_play_internal(anim, false, fps)


func _play_internal(anim: String, loop: bool = true, fps: float = -1.0) -> void:
	if not _anims.has(anim):
		if _anims.has("idle"):
			anim = "idle"
		elif _anims.has("walk"):
			anim = "walk"
		else:
			return
	if anim == _anim and loop == _loop and not _frames.is_empty():
		return
	_anim = anim
	_frames = _anims[anim]
	_frame_i = 0
	_frame_t = 0.0
	_loop = loop
	if fps > 0.0:
		_fps = fps
	else:
		match anim:
			"idle":
				_fps = 3.0
			"walk":
				_fps = 8.0
			"run":
				_fps = 12.0
			"attack":
				_fps = 14.0
			"dodge":
				_fps = 14.0
			"talk":
				_fps = 5.0
			_:
				_fps = 8.0
	if not _frames.is_empty():
		_show_frame(_frames[0])


func set_moving(moving: bool) -> void:
	_moving = moving
	if _locked:
		return
	_play_internal(_default_locomotion(), true)


func set_running(running: bool) -> void:
	_running = running
	if _locked:
		return
	if _moving:
		_play_internal(_default_locomotion(), true)


## Turn toward a world-space direction; the flip follows its on-screen x.
func face(world_dir: Vector2) -> void:
	var sx := IsoView.to_screen(world_dir).x
	if absf(sx) < 0.05:
		return
	_facing_right = sx >= 0.0
	_apply_facing()


func flash(color: Color = Color(1.0, 0.4, 0.4), seconds: float = 0.1) -> void:
	_flash_t = seconds
	_sprite.modulate = color


func set_ghost(on: bool) -> void:
	_sprite.modulate = Color(0.75, 0.85, 1.0, 0.65) if on else _base_modulate


## Corpse pose: darkened and pressed toward the ground, ring and shadows gone.
func lay_dead() -> void:
	show_marker = false
	_shadow.visible = false
	_base_modulate = Color(0.45, 0.15, 0.15, 0.85)
	_sprite.modulate = _base_modulate
	IsoView.stand(_rig, Vector2(1.0, 0.55))
	queue_redraw()


func current_anim() -> String:
	return _anim


func _process(delta: float) -> void:
	if _flash_t > 0.0:
		_flash_t -= delta
		if _flash_t <= 0.0:
			_sprite.modulate = _base_modulate
	if _frames.is_empty():
		return
	_frame_t += delta * _fps
	if _frame_t >= 1.0:
		_frame_t = 0.0
		if _frame_i + 1 >= _frames.size():
			if _loop:
				_frame_i = 0
			else:
				_locked = false
				_play_internal(_default_locomotion(), true)
				return
		else:
			_frame_i += 1
		_show_frame(_frames[_frame_i])
	var bob := sin(Time.get_ticks_msec() * 0.01 * (1.6 if _moving else 1.0)) * bob_amount
	if _anim == "attack" or _anim == "dodge":
		bob *= 0.25
	_sprite.position.y = bob
