class_name SlotGlyph
extends Control
## One kit slot on the HUD: a lozenge that fills as its cooldown returns.

## 0 = just used, 1 = ready.
@export var ready_frac: float = 1.0:
	set(v):
		ready_frac = clampf(v, 0.0, 1.0)
		queue_redraw()
@export var color: Color = MWPalette.BONE:
	set(v):
		color = v
		queue_redraw()
## Drawn in the middle: "special" (cleave mark) or "cast" (stake).
@export var mark: String = "special"


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5 - 1.0
	var pts := PackedVector2Array(
		[c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)]
	)
	draw_colored_polygon(pts, Color(MWPalette.INK, 0.7))
	## Fill rises from the bottom point.
	var level := c.y + r - 2.0 * r * ready_frac
	var fill := PackedVector2Array()
	for i: int in 4:
		var a := pts[i]
		var b := pts[(i + 1) % 4]
		if a.y >= level:
			fill.append(a)
		if (a.y - level) * (b.y - level) < 0.0:
			fill.append(a.lerp(b, (level - a.y) / (b.y - a.y)))
	var ready := ready_frac >= 1.0
	if fill.size() >= 3:
		draw_colored_polygon(fill, Color(color, 0.3 if ready else 0.16))
	pts.append(pts[0])
	draw_polyline(pts, Color(color, 0.95 if ready else 0.4), 1.5, true)
	var ink := Color(color, 1.0 if ready else 0.45)
	if mark == "cast":
		draw_line(c + Vector2(0, -r * 0.5), c + Vector2(0, r * 0.5), ink, 1.6, true)
		draw_line(
			c + Vector2(-r * 0.24, -r * 0.14), c + Vector2(r * 0.24, -r * 0.14), ink, 1.6, true
		)
	else:
		draw_arc(c + Vector2(r * 0.12, 0), r * 0.42, PI * 0.55, PI * 1.45, 14, ink, 1.8, true)
