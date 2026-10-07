# gdlint: disable=max-returns
extends "res://source/match/programs/PresetAction.gd"

var _backing_off = false
var _strike_returning = false


func _specialist_tick(center, radius):
	match controller.config.preset:
		"standoff":
			_standoff(center, radius)
		"strike_return":
			_strike(center, radius)
		"fire_support":
			_support(center, radius)
		_:
			return false
	return true


func _standoff(center, radius):
	if _unit.global_position_yless.distance_to(center) > radius + 2.0:
		_move(center, "Returning to assigned standoff area.")
		return
	var target = _pick_target(center, radius)
	if target == null:
		_backing_off = false
		_station(center, "Watching standoff area.")
		return
	var distance = _unit.global_position_yless.distance_to(target.global_position_yless)
	if distance < _unit.attack_range * 0.55:
		_backing_off = true
	elif distance >= _unit.attack_range * 0.8:
		_backing_off = false
	if _backing_off or not _unit._match.battlefield.can_fire(_unit, target):
		var away = (_unit.global_position_yless - target.global_position_yless).normalized()
		if away.is_zero_approx():
			away = Vector3.RIGHT
		var desired = target.global_position_yless + away * _unit.attack_range * 0.85
		var point = center + (desired - center).limit_length(radius)
		if _unit.global_position_yless.distance_to(point) > 0.9:
			_move(point, "Keeping standoff distance inside assigned area.")
			return
		# A sector edge must not cause endless retreat or cross-map kiting.
		_backing_off = false
	if _unit._match.battlefield.can_fire(_unit, target):
		_fire(target)
	else:
		_hold("Running", "No legal firing position inside standoff area.")


func _strike(center, radius):
	if controller.safe_point == null:
		_hold("Waiting", "Choose a regroup point before starting strike-and-return.")
		return
	if _strike_returning:
		if _unit.global_position_yless.distance_to(controller.safe_point) > 0.9:
			_move(controller.safe_point, "Strike complete; returning to regroup point.")
			return
		var now = int(_unit._match.simulation_time * 1000.0)
		if _unit.get_meta("next_attack_availability_time", now) > now:
			_hold("Running", "Regrouped; waiting for weapon cooldown.")
			return
		_strike_returning = false
	if _unit.global_position_yless.distance_to(center) > radius + 2.0:
		_move(center, "Approaching assigned strike area.")
		return
	var target = _pick_target(center, radius)
	if target == null:
		_station(center, "Watching assigned strike area; no visible target.")
	elif _unit._match.battlefield.can_fire(_unit, target):
		_launch(target)
	else:
		_move(target.global_position_yless, "Closing on visible target inside strike area.")


func _launch(target):
	_movement.stop()
	_destination = null
	_stalled = 0.0
	if is_instance_valid(_shot) and not _shot.is_queued_for_deletion() and _target == target:
		_claim(target)
		return
	_clear_shot()
	_claim(target)
	_target = target
	_shot = Shooting.new(target, 1)
	_shot.shot_fired.connect(func(): _strike_returning = true)
	add_child(_shot)
	controller.set_status("Running", "Firing one strike, then returning to regroup.")


func _support(center, radius):
	if _unit.global_position_yless.distance_to(center) > 1.0:
		_move(center, "Taking assigned fire-support position.")
		return
	var target = _pick_target(center, radius)
	if target != null and _unit._match.battlefield.can_fire(_unit, target):
		_fire(target)
	else:
		_hold("Running", "Holding fire-support position; no pursuit.")


func _station(center, explanation):
	if _unit.global_position_yless.distance_to(center) > 1.0:
		_move(center, "Returning to assigned area.")
	else:
		_hold("Running", explanation)


func _on_recovery():
	if controller.config.preset == "strike_return":
		_strike_returning = true
		_returning = false
	else:
		super()


func _target_reach():
	return _unit.attack_range if controller.config.preset == "fire_support" else super()
