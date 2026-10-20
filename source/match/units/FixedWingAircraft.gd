extends "res://source/match/units/Unit.gd"

# Fixed-wing aircraft (fighter, bomber). Orders from every source are
# translated into air actions; weapons are limited stores that are released by
# fire control when the flight geometry gives a firing solution, and refilled
# on the aircraft's airfield stand.

const AirStation = preload("res://source/match/units/actions/AirStation.gd")
const AirStrike = preload("res://source/match/units/actions/AirStrike.gd")
const AirReturn = preload("res://source/match/units/actions/AirReturn.gd")
const AirIdle = preload("res://source/match/units/actions/AirIdle.gd")
const AIR_ACTIONS = ["AirStation", "AirStrike", "AirReturn", "AirIdle"]
const REARM_INTERVAL = 0.6
const ACQUISITION_MARGIN = 4.0

# Stores remaining by name; capacities and weapons come from loadout().
var stores = {}
# Where an auto-returning aircraft goes back to after rearming.
var resume_station = Vector3.INF
# Scenario aircraft without an airfield never run dry.
var unlimited_stores = false
var _cooldowns = {}
var _rearm_left = REARM_INTERVAL
var _flight = null


# name -> {weapon, capacity, interval, range, cone}
func loadout():
	return {}


func _ready():
	await super()
	_flight = get_node("Movement")
	_fill_stores()
	action_changed.connect(_on_action_changed)
	if action == null:
		action = AirIdle.new()


func _fill_stores():
	if not stores.is_empty():
		return
	for store in loadout():
		stores[store] = loadout()[store].capacity
		_cooldowns[store] = 0.0


func _on_action_changed(new_action):
	if new_action == null and is_inside_tree() and not is_queued_for_deletion():
		action = AirIdle.new()


func _exit_tree():
	if _flight == null:
		return
	var field = _flight.airfield
	if is_instance_valid(field) and not field.is_queued_for_deletion():
		field.release_stand(self)
		field.release_runway(self)


func combat_domain():
	if _flight != null and _flight.on_ground():
		return Constants.Match.Navigation.Domain.TERRAIN
	return Constants.Match.Navigation.Domain.AIR


# --- Orders ---------------------------------------------------------------------


func _adapt_action(action_node):
	if action_node == null:
		return null
	var kind = action_node.get_script().resource_path.get_file().get_basename()
	if kind in AIR_ACTIONS:
		return action_node
	var replacement = null
	match kind:
		"Moving":
			replacement = AirStation.new(action_node._target_position)
		"AttackMoving":
			replacement = AirStation.new(action_node.destination, true)
		"AutoAttacking", "AttackingWhileInRange":
			if can_strike(action_node._target_unit):
				replacement = AirStrike.new(action_node._target_unit)
		"Following":
			replacement = AirStation.new(Vector3.ZERO, true, action_node._target_unit)
		"RecoveringAtService":
			replacement = AirReturn.new()
		"WaitingForTargets":
			replacement = AirIdle.new()
	action_node.free()
	return replacement


func can_strike(target):
	return (
		is_instance_valid(target)
		and not target.is_queued_for_deletion()
		and _rules().can_target(self, target)
	)


# --- Stores and rearming ----------------------------------------------------------


func has_stores():
	return stores.values().any(func(count): return count > 0)


func stores_full():
	for store in stores:
		if stores[store] < loadout()[store].capacity:
			return false
	return true


# Ordered sorties leave with whatever is loaded; automatic ones wait for a full
# load and most of the airframe's health.
func sortie_ready(by_order):
	if by_order:
		return has_stores()
	return stores_full() and hp >= hp_max * 0.75


func landed():
	_rearm_left = REARM_INTERVAL


func became_airborne():
	pass


func _physics_process(delta):
	if _flight == null:
		return
	for store in _cooldowns:
		_cooldowns[store] = maxf(0.0, _cooldowns[store] - delta)
	if _flight.is_parked():
		_rearm(delta)
	elif _flight.is_airborne():
		_fire_control()


func _rearm(delta):
	if stores_full():
		return
	_rearm_left -= delta
	if _rearm_left > 0.0:
		return
	_rearm_left = REARM_INTERVAL
	for store in stores:
		var capacity = loadout()[store].capacity
		if stores[store] < capacity:
			# Bulk stores (cannon rounds) refill in clips, guided stores one by one.
			stores[store] = mini(capacity, stores[store] + maxi(1, capacity / 6))
			return


# --- Fire control -------------------------------------------------------------


func weapons_free():
	if stance == Stance.HOLD_FIRE:
		return action is AirStrike
	return action != null and action.has_method("weapons_free") and action.weapons_free()


func _fire_control():
	if not weapons_free():
		return
	var target = aim_target if can_strike(aim_target) else null
	for store in stores:
		if stores[store] <= 0 or _cooldowns[store] > 0.0:
			continue
		var spec = loadout()[store]
		var candidate = target if target != null else _opportunity_target(spec)
		if candidate != null and _solution(spec, candidate):
			_release(store, spec, candidate)


# Targets of opportunity in the firing envelope while flying a mission.
func _opportunity_target(spec):
	if stance == Stance.HOLD_FIRE:
		return null
	var best = null
	var best_distance = INF
	var reach = spec.get("range", 4.0) + 2.0
	for unit in _match.battlefield.nearby_units(global_position * Vector3(1, 0, 1), reach):
		if unit.player == player or not can_strike(unit):
			continue
		if not _match.battlefield.is_observed(player, unit):
			continue
		var distance = global_position.distance_to(unit.global_position)
		if distance < best_distance:
			best = unit
			best_distance = distance
	return best


func _solution(_spec, _target):
	return false


func _release(store, spec, target):
	if not unlimited_stores:
		stores[store] -= 1
	_cooldowns[store] = spec.interval
	_match.projectile_system.launch(self, target, spec.weapon, _flight.flight_velocity())


# A visible enemy this aircraft can attack near its patrol.
func acquire_target():
	var best = null
	var best_distance = INF
	var reach = sight_range + ACQUISITION_MARGIN
	var center = _flight.station if _flight.station.is_finite() else global_position
	for unit in _match.battlefield.nearby_units(center * Vector3(1, 0, 1), reach):
		if unit.player == player or not can_strike(unit):
			continue
		if not _match.battlefield.is_observed(player, unit):
			continue
		var distance = global_position.distance_to(unit.global_position)
		if distance < best_distance:
			best = unit
			best_distance = distance
	return best


# Where to steer while attacking `target`.
func strike_point(target):
	return target.global_position


# --- Saves ------------------------------------------------------------------------


func capture_air(reference):
	return {
		"flight": _flight.capture_flight(reference),
		"stores": stores.duplicate(),
		"cooldowns": _cooldowns.duplicate(),
		"rearm_left": _rearm_left,
		"resume_station": resume_station if resume_station.is_finite() else null,
		"unlimited": unlimited_stores,
	}


# Restore can run before _ready completes; resolve nodes and stores here.
func restore_air(saved, entities):
	_flight = get_node("Movement")
	_fill_stores()
	for store in saved.stores:
		if stores.has(store):
			stores[store] = mini(saved.stores[store], loadout()[store].capacity)
	_cooldowns = saved.cooldowns.duplicate()
	_rearm_left = saved.rearm_left
	resume_station = saved.resume_station if saved.resume_station != null else Vector3.INF
	unlimited_stores = saved.unlimited
	_flight.restore_flight(saved.flight, entities)
