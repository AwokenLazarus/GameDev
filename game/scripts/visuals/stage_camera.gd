class_name StageCamera
extends Node
## Party camera for the iso stage. Writes IsoView.BASIS (with zoom and follow) to the
## viewport's canvas transform each frame, and depth-sorts the children of `sort_roots`.
## The owner calls down: `targets`, `sort_roots`, `set_stage()`.

## Screen-pixel room kept around the stage so wall tops and the slab edge stay in view.
const MARGIN_TOP := 170.0
const MARGIN_SIDE := 90.0
const MARGIN_BOTTOM := 110.0
const FOLLOW_SPEED := 7.0

@export var zoom: float = 1.0

## Followed nodes; the camera centres on the living ones (co-op: the party's midpoint).
var targets: Array[Node2D] = []
## Parents whose Node2D children are ordered by depth every frame.
var sort_roots: Array[Node] = []

var _stage_half := Vector2(480.0, 320.0)
## Camera centre in projected (un-zoomed) screen units.
var _center := Vector2.ZERO
var _snap := true
var _shake := 0.0


func _exit_tree() -> void:
	var vp := get_viewport()
	if vp:
		vp.canvas_transform = Transform2D.IDENTITY


func set_stage(half: Vector2, stage_zoom: float) -> void:
	_stage_half = half
	zoom = stage_zoom
	_snap = true


## Short positional kick in screen pixels, decaying over ~0.2 s.
func shake(pixels: float) -> void:
	_shake = maxf(_shake, pixels)


## World point at the centre of the view.
func focus_world() -> Vector2:
	return IsoView.to_world(_center)


func _process(delta: float) -> void:
	var vp := get_viewport()
	if vp == null:
		return
	var view := vp.get_visible_rect().size
	var want := _clamp_to_stage(IsoView.to_screen(_focus()), view)
	if _snap:
		_center = want
		_snap = false
	else:
		_center = _center.lerp(want, 1.0 - exp(-FOLLOW_SPEED * delta))
	var kick := Vector2.ZERO
	if _shake > 0.05:
		kick = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake
		_shake = lerpf(_shake, 0.0, 1.0 - exp(-18.0 * delta))
	vp.canvas_transform = Transform2D(
		IsoView.BASIS.x * zoom, IsoView.BASIS.y * zoom, view * 0.5 - _center * zoom + kick
	)
	_sort(IsoView.depth(focus_world()))


func _focus() -> Vector2:
	var sum := Vector2.ZERO
	var n := 0
	for t: Node2D in targets:
		if not is_instance_valid(t) or t.get("dead") == true:
			continue
		sum += t.global_position
		n += 1
	if n == 0:
		return IsoView.to_world(_center)
	return sum / float(n)


func _clamp_to_stage(at: Vector2, view: Vector2) -> Vector2:
	var reach := (_stage_half.x + _stage_half.y) * IsoView.C
	var half_view := view * 0.5 / zoom
	var left := -reach - MARGIN_SIDE + half_view.x
	var right := reach + MARGIN_SIDE - half_view.x
	var top := -reach * IsoView.SQUASH - MARGIN_TOP + half_view.y
	var bottom := reach * IsoView.SQUASH + MARGIN_BOTTOM - half_view.y
	var out := at
	out.x = (left + right) * 0.5 if left > right else clampf(at.x, left, right)
	out.y = (top + bottom) * 0.5 if top > bottom else clampf(at.y, top, bottom)
	return out


func _sort(focus_depth: float) -> void:
	for root: Node in sort_roots:
		if not is_instance_valid(root):
			continue
		for child: Node in root.get_children():
			var item := child as Node2D
			## Laid / lifted items (z_as_relative off) keep their band.
			if item == null or not item.z_as_relative:
				continue
			var z := roundi(
				(IsoView.depth(item.global_position) - focus_depth) * IsoView.Z_PER_DEPTH
			)
			item.z_index = clampi(z, -IsoView.Z_SORT_RANGE, IsoView.Z_SORT_RANGE)
