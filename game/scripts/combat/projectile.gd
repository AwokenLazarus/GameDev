extends Area2D
## Seeking / straight projectile for Mira and similar kits.

var damage: float = 10.0
var speed: float = 420.0
var lifetime: float = 2.2
var seek: bool = true
var pierce: int = 0
var velocity: Vector2 = Vector2.RIGHT
var owner_player: Node = null

@onready var visual: Polygon2D = $Visual


func _ready() -> void:
	body_entered.connect(_on_body)
	area_entered.connect(_on_area)
	collision_layer = 8
	collision_mask = 4


func setup(origin: Vector2, dir: Vector2, dmg: float, from: Node, seeking: bool = true, spd: float = 420.0) -> void:
	global_position = origin
	velocity = dir.normalized() * spd
	damage = dmg
	owner_player = from
	seek = seeking
	speed = spd
	rotation = dir.angle()


func make_hostile() -> void:
	set_meta("hostile", true)
	collision_mask = 2 ## player layer
	seek = false


func _physics_process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return
	if seek:
		var target := _nearest_enemy()
		if target:
			var desired := (target.global_position - global_position).normalized() * speed
			velocity = velocity.lerp(desired, 0.12)
	global_position += velocity * delta
	rotation = velocity.angle()


func _nearest_enemy() -> Node2D:
	var best: Node2D = null
	var best_d := 280.0
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e):
			continue
		var d := global_position.distance_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best


func _on_body(body: Node) -> void:
	_hit(body)


func _on_area(area: Area2D) -> void:
	_hit(area.get_parent())


func _hit(node: Node) -> void:
	if node == null or node == owner_player:
		return
	var hostile: bool = bool(get_meta("hostile", false))
	if hostile:
		if node.is_in_group("player") and node.has_method("apply_hit"):
			node.apply_hit(damage)
			queue_free()
		return
	if not node.is_in_group("enemy"):
		return
	var h: Health = node.get_node_or_null("Health")
	if h:
		h.take_damage(damage)
		if owner_player and owner_player.has_method("on_deal_damage"):
			owner_player.on_deal_damage(damage)
	if pierce > 0:
		pierce -= 1
	else:
		queue_free()
