class_name IsoView
extends RefCounted
## Dimetric ground projection (MW-029). Gameplay stays on a flat, axis-aligned plane; the
## stage camera puts BASIS on the viewport's canvas transform, so the floor and everything
## drawn flat on it (telegraphs, zones, rings) is projected for free. Things that stand up
## (actor sprites, props, labels) take UPRIGHT to cancel it and are depth-sorted by IsoSorter.

## Vertical squash of the ground plane: 0.5 is true 2:1 iso, 1.0 is top-down.
const SQUASH := 0.6
const C := 0.70710678
## World → screen. World +x runs down-right, world +y runs down-left.
const BASIS := Transform2D(Vector2(C, C * SQUASH), Vector2(-C, C * SQUASH), Vector2.ZERO)
## Screen → world (inverse of BASIS).
const UPRIGHT := Transform2D(
	Vector2(0.5 / C, -0.5 / C), Vector2(0.5 / (C * SQUASH), 0.5 / (C * SQUASH)), Vector2.ZERO
)

## Absolute z bands. Sorted things sit between FLOOR and OVER, ordered by depth.
const Z_GROUND := -4000
const Z_FLOOR := -3500
const Z_SORT_RANGE := 3000
const Z_OVER := 3500
## z steps per world unit of depth; the sorter measures depth from the camera focus.
const Z_PER_DEPTH := 2.0


static func to_screen(world: Vector2) -> Vector2:
	return BASIS.basis_xform(world)


static func to_world(screen: Vector2) -> Vector2:
	return UPRIGHT.basis_xform(screen)


## Larger = nearer the viewer (drawn later).
static func depth(world: Vector2) -> float:
	return world.x + world.y


## Stick / WASD vector to a world move vector. A pure turn, so the keyboard diagonals run
## along the room's walls and analog magnitude is kept.
static func move_to_world(input: Vector2) -> Vector2:
	return input.rotated(-PI * 0.25)


## Screen-accurate direction (right stick aim).
static func aim_to_world(screen_dir: Vector2) -> Vector2:
	return to_world(screen_dir).normalized()


## Height `h` screen pixels straight up, as a world offset.
static func up(h: float) -> Vector2:
	return to_world(Vector2(0.0, -h))


## Stand a node up: cancels the projection, keeping `scl` as its on-screen scale.
static func stand(node: Node2D, scl: Vector2 = Vector2.ONE) -> void:
	node.transform = Transform2D(UPRIGHT.x * scl.x, UPRIGHT.y * scl.y, node.position)


## Flat ground decoration: under every sorted thing, above the floor.
static func lay(item: CanvasItem) -> void:
	item.z_as_relative = false
	item.z_index = Z_FLOOR


## Overlay that must never be hidden by an actor (labels, hit sparks).
static func lift(item: CanvasItem) -> void:
	item.z_as_relative = false
	item.z_index = Z_OVER
