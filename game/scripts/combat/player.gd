extends CharacterBody2D
## Severin — moon-edge longblade. Manual melee + dodge.

signal died
signal fed

const MOVE_SPEED := 220.0
const DODGE_SPEED := 520.0
const DODGE_TIME := 0.18
const DODGE_COOLDOWN := 0.55
const ATTACK_COOLDOWN := 0.38
const ATTACK_DAMAGE := 22.0
const ATTACK_RANGE := 56.0

@onready var body_visual: Polygon2D = $BodyVisual
@onready var blade_visual: Polygon2D = $BladeVisual
@onready var hitbox: Area2D = $AttackHitbox
@onready var feed_area: Area2D = $FeedArea
@onready var health: Health = $Health
@onready var anim_timer: Timer = $AnimTimer

var facing: Vector2 = Vector2.RIGHT
var dodge_timer: float = 0.0
var dodge_cd: float = 0.0
var attack_cd: float = 0.0
var attacking: bool = false
var dead: bool = false
var _hit_ids: Dictionary = {}


func _ready() -> void:
	add_to_group("player")
	health.max_hp = RunState.player_max_hp
	health.hp = RunState.player_hp
	health.died.connect(_on_died)
	health.damaged.connect(_on_damaged)
	hitbox.monitoring = false
	hitbox.body_entered.connect(_on_hitbox_body)
	hitbox.area_entered.connect(_on_hitbox_area)


func _physics_process(delta: float) -> void:
	if dead:
		return
	## Sync run HP mirror.
	RunState.player_hp = health.hp
	RunState.player_max_hp = health.max_hp

	if dodge_cd > 0.0:
		dodge_cd -= delta
	if attack_cd > 0.0:
		attack_cd -= delta

	if dodge_timer > 0.0:
		dodge_timer -= delta
		move_and_slide()
		return

	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_dir.length() > 0.1:
		facing = input_dir.normalized()
		_update_facing_visual()

	var speed := MOVE_SPEED * RunState.move_mult
	velocity = input_dir * speed

	if Input.is_action_just_pressed("dodge") and dodge_cd <= 0.0 and input_dir.length() > 0.1:
		_start_dodge(input_dir.normalized())
	elif Input.is_action_just_pressed("attack") and attack_cd <= 0.0 and not attacking:
		_start_attack()
	elif Input.is_action_just_pressed("feed"):
		_try_feed()

	move_and_slide()
	## Soft contact damage handled by enemies.


func _start_dodge(dir: Vector2) -> void:
	dodge_timer = DODGE_TIME
	dodge_cd = DODGE_COOLDOWN / maxf(0.5, RunState.dash_mult)
	velocity = dir * DODGE_SPEED * RunState.dash_mult
	health.set_invuln(DODGE_TIME + 0.05)
	body_visual.modulate = Color(0.85, 0.85, 1.0, 0.55)
	await get_tree().create_timer(DODGE_TIME).timeout
	if is_instance_valid(body_visual):
		body_visual.modulate = Color.WHITE


func _start_attack() -> void:
	attacking = true
	attack_cd = ATTACK_COOLDOWN / maxf(0.25, RunState.attack_speed_mult)
	_hit_ids.clear()
	hitbox.monitoring = true
	blade_visual.visible = true
	blade_visual.rotation = facing.angle()
	hitbox.rotation = facing.angle()
	## Pact FX tint
	if RunState.has_pact("dust_compact"):
		blade_visual.color = Color(0.75, 0.65, 0.45)
	elif RunState.has_pact("red_petition"):
		blade_visual.color = Color(0.75, 0.2, 0.25)
	else:
		blade_visual.color = Color(0.85, 0.85, 0.9)

	await get_tree().create_timer(0.12).timeout
	if is_instance_valid(hitbox):
		hitbox.monitoring = false
	if is_instance_valid(blade_visual):
		blade_visual.visible = false
	attacking = false


func _damage_amount() -> float:
	var dmg := ATTACK_DAMAGE * RunState.damage_mult * (1.0 + RunState.get_feed_damage_bonus())
	if RunState.has_pact("dust_compact"):
		dmg *= 1.15 ## scrap teeth rewrite
	if RunState.has_pact("red_petition"):
		dmg *= 1.2
	return dmg


func _on_hitbox_body(body: Node) -> void:
	_try_damage_target(body)


func _on_hitbox_area(area: Area2D) -> void:
	_try_damage_target(area.get_parent())


func _try_damage_target(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	if node == self:
		return
	var id := node.get_instance_id()
	if _hit_ids.has(id):
		return
	if not node.is_in_group("enemy"):
		return
	_hit_ids[id] = true
	var h: Health = node.get_node_or_null("Health")
	if h:
		h.take_damage(_damage_amount())
		var ls := RunState.lifesteal + RunState.get_feed_lifesteal_bonus()
		if ls > 0.0:
			health.heal(_damage_amount() * ls)


func _try_feed() -> void:
	for body in feed_area.get_overlapping_bodies():
		if body.is_in_group("feedable_corpse"):
			_feed(body)
			return
	for area in feed_area.get_overlapping_areas():
		var p := area.get_parent()
		if p and p.is_in_group("feedable_corpse"):
			_feed(p)
			return


func _feed(corpse: Node) -> void:
	RunState.feed_on_human()
	fed.emit()
	if corpse.has_method("consume"):
		corpse.consume()
	else:
		corpse.queue_free()
	body_visual.modulate = Color(0.9, 0.3, 0.35)
	await get_tree().create_timer(0.2).timeout
	if is_instance_valid(body_visual):
		body_visual.modulate = Color.WHITE


func apply_hit(amount: float) -> void:
	health.take_damage(amount)


func _on_damaged(_amount: float, remaining: float) -> void:
	RunState.player_hp = remaining
	body_visual.modulate = Color(1.0, 0.4, 0.4)
	await get_tree().create_timer(0.08).timeout
	if is_instance_valid(body_visual) and not dead:
		body_visual.modulate = Color.WHITE


func _on_died() -> void:
	dead = true
	died.emit()


func _update_facing_visual() -> void:
	blade_visual.rotation = facing.angle()
