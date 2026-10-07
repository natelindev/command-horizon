extends "res://source/match/units/actions/Action.gd"

signal shot_fired

const RANGE_CHECK_INTERVAL = 1.0 / 60.0 * 10.0
const Rules = preload("res://source/match/combat/CombatRules.gd")

var _shot_limit = 0
var _shots = 0
var _target_unit = null
var _one_shot_timer = null
var _range_check_timer = null
var _charge_left = -1.0
var _charge_total = 0.0
var _charge_origin = Vector3.ZERO

@onready var _unit = Utils.NodeEx.find_parent_with_group(self, "units")
@onready var _unit_movement_trait = _unit.find_child("Movement")


func _init(target_unit, shot_limit = 0):
	_target_unit = target_unit
	_shot_limit = shot_limit


func _ready():
	if restoring:
		return
	if _teardown_if_out_of_range():
		return
	_target_unit.tree_exited.connect(_on_target_unit_removed)
	_unit.aim_target = _target_unit
	_rotate_unit_towards_target()
	if _unit_movement_trait != null:
		# non-stationary units must hold shooting as long as passive movement is active
		_unit_movement_trait.passive_movement_started.connect(_on_passive_movement_started)
		_unit_movement_trait.passive_movement_finished.connect(_on_passive_movement_finished)
	_setup_one_shot_timer()
	_setup_range_check_timer()
	_schedule_hit()


func _physics_process(delta):
	if _unit_movement_trait == null:
		_rotate_unit_towards_target()  # stationary units can rotate every frame
	if _charge_left < 0:
		return
	if _teardown_if_out_of_range():
		return
	if (
		_moving_during_preparation()
		or _unit.weapon_delay() > 0
		or Rules.preparation_for(_unit) == 0
	):
		_cancel_charge()
		_one_shot_timer.start(maxf(0.05, _unit.weapon_delay()))
		return
	_charge_left = maxf(0, _charge_left - delta)
	_update_charge_visual()
	if _charge_left == 0:
		_hit_target()


func _setup_one_shot_timer():
	_one_shot_timer = Timer.new()
	_one_shot_timer.one_shot = true
	_one_shot_timer.timeout.connect(_schedule_hit)
	add_child(_one_shot_timer)


func _setup_range_check_timer():
	_range_check_timer = Timer.new()
	_range_check_timer.timeout.connect(_teardown_if_out_of_range)
	add_child(_range_check_timer)
	_range_check_timer.start(RANGE_CHECK_INTERVAL)


func _rotate_unit_towards_target():
	if not is_instance_valid(_target_unit):
		return
	if _unit.global_position_yless.distance_squared_to(_target_unit.global_position_yless) < 0.0001:
		return
	if _unit.find_child("*TurretPivot", true, false) != null:
		return
	_unit.global_transform = _unit.global_transform.looking_at(
		Vector3(
			_target_unit.global_position.x, _unit.global_position.y, _target_unit.global_position.z
		),
		Vector3(0, 1, 0)
	)


func _schedule_hit():
	if not is_inside_tree() or is_queued_for_deletion():
		return
	if _shot_limit > 0 and _shots >= _shot_limit:
		return
	if get_tree().paused:
		_one_shot_timer.start(0.01)
		return
	if _unit.weapon_delay() > 0:
		_one_shot_timer.start(_unit.weapon_delay())
		return
	var now = int(_unit._match.simulation_time * 1000.0)
	var next_attack_availability_time = _unit.get_meta("next_attack_availability_time", now)
	if next_attack_availability_time > now:
		var delay_millis = next_attack_availability_time - now
		_one_shot_timer.start(delay_millis / 1000.0)
	else:
		if _teardown_if_out_of_range():
			return
		var preparation = Rules.preparation_for(_unit)
		if preparation == 0:
			_hit_target()
		elif _unit_movement_trait != null and _unit_movement_trait._has_destination:
			_one_shot_timer.start(0.05)
		elif _charge_left < 0:
			if _unit.signature != null:
				preparation = _unit.signature.preparation_time(preparation)
			_charge_left = preparation
			_charge_total = preparation
			_charge_origin = _unit.global_position
			_one_shot_timer.stop()
			_update_charge_visual()


func _moving_during_preparation():
	return (
		(_unit_movement_trait != null and _unit_movement_trait._has_destination)
		or _unit.global_position.distance_squared_to(_charge_origin) > 0.0004
	)


func _update_charge_visual():
	if _charge_left >= 0 and _charge_total > 0:
		_unit.weapon_charge_owner = self
		_unit.weapon_charge_progress = 1.0 - _charge_left / _charge_total
		_refresh_charge_display()


func _cancel_charge():
	_charge_left = -1.0
	_charge_total = 0.0
	if is_instance_valid(_unit) and _unit.weapon_charge_owner == self:
		_unit.weapon_charge_progress = -1.0
		_unit.weapon_charge_owner = null
		_refresh_charge_display()


func restart_preparation():
	_cancel_charge()
	_schedule_hit()


func apply_precision_window():
	if _charge_left < 0 or not _unit._match.battlefield.can_fire(_unit, _target_unit):
		return
	var total = _unit.signature.preparation_time(_charge_total)
	_charge_left = maxf(0, _charge_left - (_charge_total - total))
	_charge_total = total
	_update_charge_visual()


func _refresh_charge_display():
	var display = _unit.get_node_or_null("WeaponPreparationVisual")
	if display != null and display.is_node_ready():
		display.refresh()


func _hit_target():
	if _teardown_if_out_of_range():
		return
	_cancel_charge()
	_unit.set_meta(
		"next_attack_availability_time",
		int(_unit._match.simulation_time * 1000.0) + int(_unit.attack_interval * 1000.0)
	)
	var projectile = (
		load(
			Constants.Match.Units.PROJECTILES[_unit.get_script().resource_path.replace(
				".gd", ".tscn"
			)]
		)
		. instantiate()
	)
	projectile.target_unit = _target_unit
	_unit.add_child(projectile)
	_shots += 1
	shot_fired.emit()
	if _shot_limit > 0 and _shots >= _shot_limit:
		queue_free()
	else:
		_schedule_hit()


func _teardown_if_out_of_range():
	if not is_instance_valid(_target_unit) or _target_unit.is_queued_for_deletion():
		queue_free()
		return true
	if not _unit._match.battlefield.can_fire(_unit, _target_unit):
		queue_free()
		return true
	return false


func _on_target_unit_removed():
	queue_free()


func _exit_tree():
	_cancel_charge()
	if is_instance_valid(_unit) and _unit.aim_target == _target_unit:
		_unit.aim_target = null


func _on_passive_movement_started():
	_cancel_charge()
	_one_shot_timer.stop()


func _on_passive_movement_finished():
	_rotate_unit_towards_target()
	_schedule_hit()
