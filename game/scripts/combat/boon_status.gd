extends Node
class_name MWBoonStatus
## Boon statuses on one foe (MW-006 verb glossary): Bleed, Blind, Root, Slow, Condemn,
## Warrant, Collateral. Created on demand by `of()`; foes read it for movement and AI.
## Bleed ticks route through the player who applied it, so kills and hooks credit them.

const BLEED_MAX := 5
const BLEED_DPS := 3.0 ## per stack
const BLEED_TIME := 4.0
const ROOT_IMMUNE := 4.0

var bleed: int = 0
var bleed_t: float = 0.0
var bleed_src: Node = null
var blind_t: float = 0.0
var root_t: float = 0.0
var root_immune_t: float = 0.0
var slow_t: float = 0.0
var slow_mult: float = 1.0
var condemn_t: float = 0.0
var warrant_t: float = 0.0
var collateral: bool = false
var fused: bool = false

var _tick_acc: float = 0.0
var _label: Label


static func of(foe: Node) -> MWBoonStatus:
	if foe == null or not is_instance_valid(foe):
		return null
	var s := foe.get_node_or_null("BoonStatus") as MWBoonStatus
	if s == null:
		s = MWBoonStatus.new()
		s.name = "BoonStatus"
		foe.add_child(s)
	return s


## Read-only lookup: null when the foe has never had a status.
static func peek(foe: Node) -> MWBoonStatus:
	if foe == null or not is_instance_valid(foe):
		return null
	return foe.get_node_or_null("BoonStatus") as MWBoonStatus


static func is_general(foe: Node) -> bool:
	return foe != null and foe.is_in_group("boss")


static func is_elite(foe: Node) -> bool:
	return foe != null and foe.get("is_elite") == true


func _ready() -> void:
	var host := get_parent()
	if host is Node2D:
		_label = Label.new()
		_label.position = Vector2(-50, -66)
		_label.size = Vector2(100, 14)
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.add_theme_font_size_override("font_size", 10)
		_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		_label.add_theme_constant_override("outline_size", 4)
		_label.z_index = 40
		host.add_child.call_deferred(_label)


## Adds Bleed stacks (cap 5, refreshes the timer). Returns the new stack count.
func add_bleed(stacks: int, src: Node) -> int:
	var before := bleed
	bleed = mini(BLEED_MAX, bleed + stacks)
	bleed_t = BLEED_TIME
	bleed_src = src
	if bleed == BLEED_MAX and before < BLEED_MAX and is_instance_valid(src):
		## src is the player; its BoonKit owns the Dead Man's Tally hook.
		var kit = src.get("boons") if "boons" in src else src
		if kit != null and kit.has_method("on_bleed_capped"):
			kit.on_bleed_capped(get_parent())
	_refresh_label()
	return bleed


## Bleed damage still to come if left alone.
func bleed_remaining() -> float:
	return float(bleed) * BLEED_DPS * maxf(bleed_t, 0.0)


func clear_bleed() -> void:
	bleed = 0
	bleed_t = 0.0
	_refresh_label()


## Blind: loses its target and wanders. Generals immune; elites half duration.
func blind(seconds: float) -> void:
	var foe := get_parent()
	if is_general(foe):
		return
	if is_elite(foe):
		seconds *= 0.5
	if seconds > blind_t:
		blind_t = seconds
		if foe.has_method("on_blinded"):
			foe.on_blinded()
	_refresh_label()


## Root: can't move, can still attack. 2 s then 4 s immunity.
func root(seconds: float = 2.0) -> bool:
	if root_immune_t > 0.0 or root_t > 0.0:
		return false
	root_t = seconds
	root_immune_t = seconds + ROOT_IMMUNE
	_refresh_label()
	return true


func slow(seconds: float, mult: float = 0.5) -> void:
	if slow_t <= 0.0:
		slow_mult = 1.0
	slow_t = maxf(slow_t, seconds)
	slow_mult = minf(slow_mult, mult)


func condemn(seconds: float = 5.0) -> void:
	condemn_t = maxf(condemn_t, seconds)
	_refresh_label()


func warrant(seconds: float = 8.0) -> void:
	warrant_t = maxf(warrant_t, seconds)
	_refresh_label()


func blinded() -> bool:
	return blind_t > 0.0


func rooted() -> bool:
	return root_t > 0.0


func condemned() -> bool:
	return condemn_t > 0.0


func warranted() -> bool:
	return warrant_t > 0.0


func move_mult() -> float:
	if root_t > 0.0:
		return 0.0
	if slow_t > 0.0:
		return slow_mult
	return 1.0


func _process(delta: float) -> void:
	var changed := false
	for key in ["blind_t", "root_t", "condemn_t", "warrant_t"]:
		var v: float = get(key)
		if v > 0.0:
			v -= delta
			set(key, v)
			if v <= 0.0:
				changed = true
	if root_immune_t > 0.0:
		root_immune_t -= delta
	if slow_t > 0.0:
		slow_t -= delta
		if slow_t <= 0.0:
			slow_mult = 1.0
	if bleed > 0:
		bleed_t -= delta
		_tick_acc += delta
		if _tick_acc >= 0.5:
			var dmg := float(bleed) * BLEED_DPS * _tick_acc
			_tick_acc = 0.0
			_bleed_tick(dmg)
		if bleed_t <= 0.0:
			clear_bleed()
	if changed:
		_refresh_label()


func _bleed_tick(dmg: float) -> void:
	var foe := get_parent()
	if is_instance_valid(bleed_src) and bleed_src.has_method("land_slot_hit"):
		bleed_src.land_slot_hit(foe, dmg, "bleed", false, 0.0)
		return
	var h: Health = foe.get_node_or_null("Health")
	if h:
		h.take_damage(dmg, true)


func _refresh_label() -> void:
	if _label == null or not is_instance_valid(_label):
		return
	var tags: Array[String] = []
	if bleed > 0:
		tags.append("BLEED %d" % bleed)
	if blind_t > 0.0:
		tags.append("BLIND")
	if root_t > 0.0:
		tags.append("ROOT")
	if condemn_t > 0.0:
		tags.append("CONDEMN")
	if warrant_t > 0.0:
		tags.append("WARRANT")
	_label.text = " · ".join(tags)
	_label.modulate = Color(1.0, 0.55, 0.45) if bleed > 0 else Color(1.0, 0.95, 0.8)
