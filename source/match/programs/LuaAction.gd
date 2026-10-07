# gdlint: disable=max-returns
extends "res://source/match/programs/PresetAction.gd"

const MAX_CONTACTS = 32
var _faulted = false
var _known = {}
var _handles = {}
var _next_handle = 1
var _guarding_area = false


func guards_assigned_area():
	return _guarding_area


func _decision_interval():
	return 0.2


func _physics_process(delta):
	if _faulted or controller.mode in ["Manual", "Error"] or _unit.action != self:
		return
	super(delta)


func _tick():
	var snapshot = _snapshot()
	var result = controller.lua_runtime.step(snapshot)
	if not result.ok:
		_faulted = true
		_hold("Error", result.error, true)
		controller.report_lua_error(result.error)
		controller.evaluated.emit(snapshot, result)
		return
	_apply_intent(result.intent)
	controller.evaluated.emit(snapshot, result)


func _point(point):
	return {"x": point.x, "z": point.z}


func _record(unit, handle):
	var distance = _unit.global_position_yless.distance_to(unit.global_position_yless)
	# _snapshot already verified current visibility synchronously. Recheck legality
	# again when applying an attack, not once more for every copied contact.
	var can_attack = (
		Rules.can_target(_unit, unit)
		and distance <= Rules.range_for(_unit, unit)
		and _unit.weapon_delay() <= 0
		and _unit._match.battlefield.has_line_of_fire(_unit, unit)
	)
	return {
		"id": handle,
		"type": unit.type,
		"hp": unit.hp,
		"hp_max": unit.hp_max,
		"position": _point(unit.global_position_yless),
		"distance": distance,
		"can_attack": can_attack,
		"can_repair": _unit.type == "RepairRobot" and Repairs.mobile_eligible(_unit, unit),
	}


func _snapshot():
	var field = _unit._match.battlefield
	var position = _unit.global_position_yless
	var nearby = field.nearby_units(position, maxf(_unit.sight_range, controller.config.radius))
	var ranked = []
	for other in nearby:
		if other != _unit:
			ranked.append(
				{
					"unit": other,
					"distance": position.distance_squared_to(other.global_position_yless),
					"id": other.get_instance_id()
				}
			)
	ranked.sort_custom(
		func(a, b): return a.distance < b.distance if a.distance != b.distance else a.id < b.id
	)
	var candidates = []
	var truncated = false
	for entry in ranked:
		if not field.is_observed(_unit.player, entry.unit):
			continue
		if candidates.size() == MAX_CONTACTS:
			truncated = true
			break
		candidates.append(entry.unit)
	var next_known = {}
	_handles.clear()
	var enemies = []
	var allies = []
	for other in candidates:
		var instance = other.get_instance_id()
		var handle = _known.get(instance, 0)
		if handle == 0:
			handle = _next_handle
			_next_handle += 1
		next_known[instance] = handle
		_handles[handle] = weakref(other)
		var record = _record(other, handle)
		if other.player == _unit.player:
			allies.append(record)
		else:
			enemies.append(record)
	_known = next_known
	var assignments = {}
	for name in ["anchor", "safe", "route_a", "route_b"]:
		var assigned = _assigned_point(name)
		if assigned != null:
			assignments[name] = _point(assigned)
	return {
		"api_version": 1,
		"time": _unit._match.simulation_time,
		"self":
		{
			"type": _unit.type,
			"hp": _unit.hp,
			"hp_max": _unit.hp_max,
			"position": _point(position),
			"attack_range": _unit.attack_range if _unit.attack_range != null else 0,
		},
		"assignments": assignments,
		"enemies": enemies,
		"allies": allies,
		"contacts_truncated": truncated,
	}


func _assigned_point(name):
	match name:
		"anchor":
			return controller.anchor
		"safe":
			return controller.safe_point
		"route_a":
			return controller.route[0] if controller.route.size() == 2 else null
		"route_b":
			return controller.route[1] if controller.route.size() == 2 else null
	return null


func _contact(handle):
	var reference = _handles.get(handle)
	var target = reference.get_ref() if reference != null else null
	if not is_instance_valid(target) or target.is_queued_for_deletion():
		return null
	return target


func _apply_intent(intent):
	var explanation = intent.get("status", "")
	_guarding_area = intent.kind == "guard" and _unit.attack_range != null
	match intent.kind:
		"guard":
			if _unit.attack_range == null:
				_hold("Waiting", "This unit cannot defend an area; choose an armed unit.")
			else:
				_guard_area(controller.anchor, controller.config.radius)
		"hold":
			_hold("Running", explanation if explanation else "Lua: holding position.", true)
		"move":
			var point = _assigned_point(intent.assignment)
			if point == null:
				_hold("Waiting", "Lua: assign %s before moving." % intent.assignment)
			elif (
				intent.assignment == "safe"
				and _unit.hp < _unit.hp_max
				and _unit.global_position_yless.distance_to(point) < 0.9
				and not RecoveryAdvice.support_near(_unit)
			):
				_hold(
					"Running",
					(explanation + " " if explanation else "") + RecoveryAdvice.waiting(_unit)
				)
			elif intent.assignment == "safe" and _at_assigned_service():
				_hold("Running", explanation if explanation else "Lua: at assigned service.")
			else:
				_move(point, explanation if explanation else "Lua: moving to " + intent.assignment)
		"attack":
			var target = _contact(intent.target)
			if target == null or not _unit._match.battlefield.can_fire(_unit, target):
				_hold("Waiting", "Lua: target is unavailable or outside legal weapon range.")
			else:
				_fire(target)
				controller.set_status(
					"Running", explanation if explanation else "Lua: engaging visible target."
				)
		"repair":
			_repair_intent(_contact(intent.target), explanation)
		"escort":
			var ally = controller.escort
			if (
				not is_instance_valid(ally)
				or ally.is_queued_for_deletion()
				or ally == _unit
				or ally.player != _unit.player
			):
				_hold("Waiting", "Lua: assign a friendly unit to escort.")
			elif _unit.global_position_yless.distance_to(ally.global_position_yless) <= 3.0:
				_hold(
					"Running",
					explanation if explanation else "Lua: covering assigned escort.",
					true
				)
			else:
				_move(
					ally.global_position_yless,
					explanation if explanation else "Lua: following assigned escort."
				)


func _repair_intent(target, explanation):
	if _unit.type != "RepairRobot":
		_hold("Waiting", "Lua: this unit cannot repair allies.")
		return
	if controller.anchor == null:
		_hold("Waiting", "Lua: assign a repair area.")
		return
	if target == null or not Repairs.mobile_eligible(_unit, target):
		_hold("Waiting", "Lua: target is unavailable or incompatible with repair.")
		return
	if target.global_position_yless.distance_to(controller.anchor) > controller.config.radius:
		_hold("Waiting", "Lua: damaged ally is outside the assigned repair area.")
		return
	if Repairs.mobile_distance(_unit, target) > 2.8:
		_move(target.global_position_yless, "Lua: approaching ally within repair assignment.")
	else:
		_hold("Running", explanation if explanation else "Lua: repairing assigned ally.")
		_repair = target
		_claim(target, "repair")
