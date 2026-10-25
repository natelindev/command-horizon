# gdlint: disable=max-returns
extends "res://source/match/units/actions/Action.gd"

const Shooting = preload("res://source/match/units/actions/AttackingWhileInRange.gd")
const CAPTURE_DURATION = 15.0
var _target_unit
var _shot = null
var _elapsed = 0.0
var _capture_elapsed = 0.0
@onready var _unit = Utils.NodeEx.find_parent_with_group(self, "units")


func _init(target):
	_target_unit = target


func _ready():
	MatchSignals.unit_damaged.connect(_on_damage)


func _on_damage(unit):
	if unit == _unit and _capture_elapsed > 0 and not _unit.has_meta("garrison_host"):
		_capture_elapsed = 0.0
		if is_instance_valid(_target_unit):
			_target_unit.clear_capture(_unit)
		queue_free()


func _physics_process(delta):
	_elapsed += delta
	if _elapsed < .2:
		return
	var elapsed = _elapsed
	_elapsed = 0
	if not is_instance_valid(_target_unit) or _target_unit.hp <= 0:
		queue_free()
		return
	if _unit.has_meta("garrison_host") and _unit.get_meta("garrison_host") == _target_unit:
		# Explicit attacks may finish their shot action, but Hold Fire must never
		# acquire a new target merely because the infantry entered a building.
		if _unit.stance == _unit.Stance.HOLD_FIRE:
			return
		if not is_instance_valid(_shot) or _shot.is_queued_for_deletion():
			var target = _unit._match.battlefield.automatic_target(_unit)
			if target != null:
				_shot = Shooting.new(target)
				add_child(_shot)
		return
	if not _target_unit.can_garrison(_unit):
		queue_free()
		return
	var direction = (_unit.global_position_yless - _target_unit.global_position_yless).normalized()
	if direction.is_zero_approx():
		direction = Vector3.FORWARD
	var distance = _unit.global_position_yless.distance_to(_target_unit.global_position_yless)
	if distance <= _target_unit.radius + _unit.radius + 1.0:
		_unit.get_node("Movement").stop()
		if _target_unit.capture_busy(_unit):
			return
		if not load("res://source/match/Players.gd").allied(_unit.player, _target_unit.player):
			_capture_elapsed += elapsed
			_target_unit.show_capture(_unit, _capture_elapsed)
			if _capture_elapsed < CAPTURE_DURATION:
				return
		_target_unit.clear_capture(_unit)
		_target_unit.enter(_unit)
		if not _unit.has_meta("garrison_host"):
			queue_free()
	else:
		_capture_elapsed = 0.0
		_target_unit.clear_capture(_unit)
		_unit.get_node("Movement").move(
			_target_unit.global_position + direction * (_target_unit.radius + .7)
		)


func _exit_tree():
	if is_instance_valid(_target_unit) and is_instance_valid(_unit):
		_target_unit.clear_capture(_unit)
		_target_unit.leave(_unit)
		_unit.get_node("Movement").stop()


func attack_from_building(target):
	if not _unit._match.battlefield.can_fire(_unit, target):
		return false
	if is_instance_valid(_shot):
		remove_child(_shot)
		_shot.queue_free()
	_shot = Shooting.new(target)
	add_child(_shot)
	return true


func _to_string():
	if not _unit.has_meta("garrison_host"):
		return (
			tr("Capturing · %d / %d s") % [floori(_capture_elapsed), 15]
			if _capture_elapsed > 0
			else tr("Moving to capture")
		)
	return tr("Garrisoned · Move to leave")
