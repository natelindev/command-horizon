extends Node

## The Scrapper's defensive gun keeps working while it loads or drives. It
## never replaces a harvest order or pursues a raider away from the field.
const SCAN_INTERVAL = 0.2
var _scan_left = 0.0
var _target = null
@onready var _unit = get_parent()


func _init():
	name = "HarvesterDefense"


func _physics_process(delta):
	if (
		_unit.hp == null
		or _unit.hp <= 0
		or _unit.stance == _unit.Stance.HOLD_FIRE
		or _unit._match == null
		or not _unit._match.is_node_ready()
	):
		return
	if (
		is_instance_valid(_unit.action)
		and (
			_unit.action.get_script().resource_path.get_file()
			in ["AutoAttacking.gd", "AttackMoving.gd", "AttackingWhileInRange.gd"]
		)
	):
		return
	_scan_left -= delta
	if _scan_left > 0:
		return
	_scan_left = SCAN_INTERVAL
	var rules = load("res://source/match/combat/CombatRules.gd")
	var field = _unit._match.battlefield
	if rules.commander_disabled(_unit):
		return
	if not _valid_target(_target, rules, field):
		if _unit.aim_target == _target:
			_unit.aim_target = null
		_target = null
		for target in field.nearby_units(_unit.global_position, _unit.attack_range):
			if _valid_target(target, rules, field):
				_target = target
				break
	if _target == null:
		return
	_unit.aim_target = _target
	var now = int(_unit._match.simulation_time * 1000.0)
	if _unit.get_meta("next_attack_availability_time", now) > now:
		return
	_unit.set_meta("next_attack_availability_time", now + int(_unit.attack_interval * 1000.0))
	_unit._match.projectile_system.fire(_unit, _target)


func _valid_target(target, rules, field) -> bool:
	return (
		is_instance_valid(target)
		and target != _unit
		and (
			rules.armor_for(target.type) < 2
			or (target.type in ["Tank", "AntiAirVehicle"] and target.player.faction == "frontier")
		)
		and field.is_observed(_unit.player, target)
		and rules.can_target(_unit, target)
		and field.can_fire(_unit, target)
	)
