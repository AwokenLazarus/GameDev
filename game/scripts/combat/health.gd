class_name Health
extends Node

signal died
signal damaged(amount: float, remaining: float)
signal healed(amount: float, remaining: float)

@export var max_hp: float = 50.0
var hp: float = 50.0
var invuln_timer: float = 0.0


func _ready() -> void:
	hp = max_hp


func _process(delta: float) -> void:
	if invuln_timer > 0.0:
		invuln_timer -= delta


func is_alive() -> bool:
	return hp > 0.0


func take_damage(amount: float, ignore_invuln: bool = false) -> void:
	if not is_alive():
		return
	if invuln_timer > 0.0 and not ignore_invuln:
		return
	hp = maxf(0.0, hp - amount)
	damaged.emit(amount, hp)
	if hp <= 0.0:
		died.emit()


func heal(amount: float) -> void:
	if not is_alive():
		return
	var before := hp
	hp = minf(max_hp, hp + amount)
	healed.emit(hp - before, hp)


func set_invuln(seconds: float) -> void:
	invuln_timer = maxf(invuln_timer, seconds)
