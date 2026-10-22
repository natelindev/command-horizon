extends "res://source/match/units/actions/Action.gd"

const AttackingWhileInRange = preload("res://source/match/units/actions/AttackingWhileInRange.gd")

const REFRESH_INTERVAL = 1.0 / 60.0 * 10.0

var _timer = null
var _sub_action = null

@onready var _unit = Utils.NodeEx.find_parent_with_group(self, "units")


func _ready():
	if restoring:
		return
	_timer = Timer.new()
	_timer.timeout.connect(_on_timer_timeout)
	add_child(_timer)
	_timer.start(REFRESH_INTERVAL)


func _to_string():
	return "{0}({1})".format([super(), str(_sub_action) if _sub_action != null else ""])


func is_idle():
	return _sub_action == null


func _get_units_to_attack():
	if "stance" in _unit and _unit.stance == _unit.Stance.HOLD_FIRE:
		return []
	var targets = _unit._match.battlefield.fireable_targets(_unit)
	if "stance" in _unit and _unit.stance == _unit.Stance.HOLD_POSITION:
		return targets.filter(
			func(target):
				if not is_instance_valid(target) or _unit.attack_range == null:
					return false
				var dist = _unit.global_position_yless.distance_to(target.global_position_yless)
				return dist <= (_unit.attack_range + target.radius + _unit.radius)
		)
	return targets


func _attack_unit(unit):
	if _unit.type != "AntiAirTurret":
		_timer.timeout.disconnect(_on_timer_timeout)
	if "stance" in _unit and _unit.stance == _unit.Stance.DEFENSIVE:
		var auto = preload("res://source/match/units/actions/AutoAttacking.gd").new(unit)
		auto._defense_origin = _unit.global_position_yless
		auto._defense_radius = maxf(
			_unit.sight_range * 1.25 if _unit.sight_range != null else 15.0,
			_unit.attack_range * 1.5 if _unit.attack_range != null else 10.0
		)
		_sub_action = auto
	else:
		_sub_action = AttackingWhileInRange.new(unit)
	_sub_action.tree_exited.connect(_on_attack_finished)
	add_child(_sub_action)
	_unit.action_updated.emit()


func _on_timer_timeout():
	var attacking = is_instance_valid(_sub_action)
	if (
		attacking
		and (
			_unit.type != "AntiAirTurret"
			or (
				is_instance_valid(_unit.aim_target)
				and _unit.aim_target.combat_domain() == Constants.Match.Navigation.Domain.AIR
			)
		)
	):
		return
	var target = _unit._match.battlefield.automatic_target(_unit, _get_units_to_attack())
	if attacking:
		if target == null or target.combat_domain() != Constants.Match.Navigation.Domain.AIR:
			return
		# Replace the whole attack subtree so save/restore and target-loss handling
		# agree about the new target. The unit's shared reload remains in effect.
		_sub_action.tree_exited.disconnect(_on_attack_finished)
		_sub_action.free()
		_sub_action = null
	if target != null:
		_attack_unit(target)


func _on_attack_finished():
	if not is_inside_tree():
		return
	_sub_action = null
	_unit.action_updated.emit()
	if not _timer.timeout.is_connected(_on_timer_timeout):
		_timer.timeout.connect(_on_timer_timeout)


static func _pick_closest_unit(units, unit):
	assert(not units.is_empty())
	var distance_to_closest_unit = unit.global_position_yless.distance_to(
		units[0].global_position_yless
	)
	var closest_unit = units[0]
	for unit_to_check in units:
		var distance = unit.global_position_yless.distance_to(unit_to_check.global_position_yless)
		if distance < distance_to_closest_unit:
			distance_to_closest_unit = distance
			closest_unit = unit_to_check
	return closest_unit
