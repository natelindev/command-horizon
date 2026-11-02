extends Node

const Attack = preload("res://source/match/units/actions/AutoAttacking.gd")
const Waiting = preload("res://source/match/units/actions/WaitingForTargets.gd")
const Players = preload("res://source/match/Players.gd")
const RESPONSE_RADIUS = 10.0
const PURSUIT_RADIUS = 16.0
const SMALL_COHORT = 16
var _candidates := {}
@onready var game = get_parent()


func _ready():
	MatchSignals.unit_weapon_hit.connect(_on_hit)
	MatchSignals.unit_spawned.connect(_track_unit)
	for unit in game.get_units():
		_track_unit(unit)


func _track_unit(unit):
	if (
		not game.is_ancestor_of(unit)
		or not unit.has_signal("action_changed")
		or unit.get_node_or_null("Movement") == null
	):
		return
	# This is action topology only. Read stance, manual intent, weapons, speed,
	# ownership and visibility afresh for every hit, including within one tick.
	var changed := _action_changed.bind(unit)
	if not unit.action_changed.is_connected(changed):
		unit.action_changed.connect(changed)
		unit.tree_exiting.connect(_forget_unit.bind(unit), CONNECT_ONE_SHOT)
	_action_changed(unit.action, unit)


func _action_changed(_action, unit):
	# Earlier listeners may replace the action reentrantly. The signal argument
	# then describes an old transition; membership follows the final live head.
	var action = unit.action
	if action == null or action is Waiting:
		_candidates[unit] = true
	else:
		_candidates.erase(unit)


func _forget_unit(unit):
	_candidates.erase(unit)


func _exit_tree():
	_candidates.clear()


func _on_hit(victim, attacker):
	if game.restoring or ("finished" in game and game.finished):
		return
	if not is_instance_valid(victim) or not is_instance_valid(attacker):
		return
	# A round whose shooter was destroyed reports its frozen Shot record.
	if not attacker is Node3D:
		return
	if _candidates.is_empty():
		return
	if (
		Players.allied(victim.player, attacker.player)
		or not game.battlefield.is_observed(victim.player, attacker)
	):
		return
	var origin = victim.global_position_yless
	var radius = RESPONSE_RADIUS + victim.radius
	# A battle's busy army cannot assist. Avoid rebuilding its entire nearby
	# cohort for every bullet when only a few idle bodies remain.
	var small := _candidates.size() <= SMALL_COHORT
	var nearby: Array = (
		_candidates.keys() if small else game.battlefield.nearby_units(origin, radius)
	)
	for unit in nearby:
		if not _candidates.has(unit) or unit.is_queued_for_deletion():
			continue
		if small and unit.global_position_yless.distance_squared_to(origin) > radius * radius:
			continue
		if not Players.allied(unit.player, victim.player):
			continue
		if not _available(unit, attacker):
			continue
		var response = Attack.new(attacker)
		response._defense_origin = origin
		response._defense_radius = PURSUIT_RADIUS + victim.radius
		unit.action = response


func _available(unit, attacker):
	if unit.manual_orders != null and unit.manual_orders._engaged:
		return false
	if (
		unit.action != null
		and not (
			is_instance_valid(unit.action) and unit.action is Waiting and unit.action.is_idle()
		)
	):
		return false
	if unit.movement_speed <= 0:
		return false
	if "stance" in unit and unit.stance in [unit.Stance.HOLD_FIRE, unit.Stance.HOLD_POSITION]:
		return false
	if unit.has_meta("garrison_host"):
		return false
	return Attack.is_applicable(unit, attacker)
