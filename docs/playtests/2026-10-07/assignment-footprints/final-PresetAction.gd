# gdlint: disable=max-returns
extends "res://source/match/units/actions/Action.gd"

const Library = preload("res://source/match/programs/ProgramLibrary.gd")
const Shooting = preload("res://source/match/units/actions/AttackingWhileInRange.gd")
const Rules = preload("res://source/match/combat/CombatRules.gd")
const RecoveryAdvice = preload("res://source/match/programs/RecoveryAdvice.gd")
const Repairs = preload("res://source/match/combat/RepairService.gd")
var controller
var _shot = null
var _target = null
var _repair = null
var _retreating = false
var _returning = false
var _defense = null
var _elapsed = 0.0
var _waypoint = 0
var _last_progress = Vector3.ZERO
var _stalled = 0.0
var _destination = null
var _guard_settled_at = null
@onready var _unit = get_parent()
@onready var _movement = _unit.get_node("Movement")


func _init(program):
	controller = program


func _ready():
	if restoring:
		return
	# Spread evaluations across physics frames when a large group is activated together.
	_elapsed = -float(_unit.get_meta("visual_seed", 0) % 10) * 0.025
	_last_progress = _unit.global_position_yless
	controller.set_status("Running", "Evaluating assignment.")


func is_idle():
	return not _movement._has_destination and not is_instance_valid(_shot)


func is_settled_guard():
	return (
		_guard_settled_at != null
		and controller.anchor != null
		and _guard_settled_at.distance_to(controller.anchor) < 0.1
	)


func repair_target():
	return _repair if is_instance_valid(_repair) else null


func _physics_process(delta):
	_elapsed += delta
	if _elapsed < _decision_interval() or controller.mode == "Blocked":
		return
	var elapsed = _elapsed
	_elapsed = 0.0
	if _destination != null:
		_stalled += elapsed
		if _last_progress.distance_to(_unit.global_position_yless) > 0.2:
			_last_progress = _unit.global_position_yless
			_stalled = 0.0
	_tick()
	# Arrival, a valid formation neighbor, combat or a changed assignment may
	# complete the old trip on this decision. Resolve that before reporting a
	# timeout; an unchanged trip still uses the same saved no-progress clock.
	if _destination != null and _stalled >= 5.0:
		_hold("Blocked", _blocked_reason())


func _blocked_reason():
	if _unit.movement_domain == Constants.Match.Navigation.Domain.TERRAIN:
		var points = [controller.anchor, controller.safe_point] + controller.route
		var assigned = points.any(
			func(point): return point != null and point.distance_to(_destination) < 0.1
		)
		# Only our own known footprints explain assignment failures. Never use
		# hidden enemy geometry, or reinterpret a combat approach as an assignment.
		if assigned and _owned_structure_at(_destination) != null:
			return "Assigned point is inside a friendly structure. Choose a clear point."
	return "No progress for 5 seconds. Reassign or Resume to retry."


func _owned_structure_at(point):
	return Utils.Match.Unit.Placement.owned_structure_at(_unit.player, point)


func _tick():
	var hp_percent = 100.0 * _unit.hp / _unit.hp_max
	if hp_percent < controller.config.retreat:
		_retreating = true
	if _retreating:
		if hp_percent >= controller.config["return"]:
			_retreating = false
			_on_recovery()
		elif controller.safe_point == null:
			_hold("Waiting", "Low health: assign a safe point for retreat.")
			return
		elif _at_assigned_service():
			_hold(
				"Running",
				"Recovering: %d%% HP; return at %d%%." % [hp_percent, controller.config["return"]]
			)
			return
		else:
			_move(
				controller.safe_point,
				"Retreating: %d%% HP; return at %d%%." % [hp_percent, controller.config["return"]]
			)
			return
	var center = controller.anchor
	if Library.behavior(controller.config.preset) == "escort":
		if not is_instance_valid(controller.escort) or controller.escort.is_queued_for_deletion():
			_hold("Waiting", "Choose a friendly unit to escort.")
			return
		if controller.escort.player != _unit.player or controller.escort == _unit:
			_hold("Waiting", "Escort assignment must be another friendly unit.")
			return
		center = controller.escort.global_position_yless
	if Library.behavior(controller.config.preset) == "patrol":
		if controller.route.size() != 2:
			_hold("Waiting", "Choose two patrol waypoints.")
			return
		center = controller.route[_waypoint]
		if _unit.global_position_yless.distance_to(center) < 1.0:
			_waypoint = 1 - _waypoint
			center = controller.route[_waypoint]
	if center == null:
		_hold("Waiting", "Choose an area to guard.")
		return
	if _returning:
		var reached = (
			_unit.global_position_yless.distance_to(center)
			<= (3.0 if Library.behavior(controller.config.preset) == "escort" else 1.0)
		)
		if controller.config.preset == "guard" and _unit.attack_range != null:
			reached = _guard_point_reached(center, controller.config.radius)
		if not reached:
			_move(center, "Returning to assignment after recovery.")
			return
		_returning = false
	var radius = controller.config.radius
	if _specialist_tick(center, radius):
		return
	if _unit.global_position_yless.distance_to(center) > radius + 2.0:
		_move(center, "Returning to assigned area.")
		return
	if _unit.type == "RepairRobot":
		_service(center, radius)
		return
	if Library.behavior(controller.config.preset) == "guard":
		_guard_area(center, radius)
		return
	var target = _pick_target(center, radius)
	if target != null and _unit._match.battlefield.can_fire(_unit, target):
		_fire(target)
	elif Library.behavior(controller.config.preset) == "hold":
		_hold("Running", "Holding position; firing only at legal targets in range.")
	elif Library.behavior(controller.config.preset) == "patrol":
		_move(center, "Patrolling waypoint %d / 2." % (_waypoint + 1))
	elif (
		_unit.global_position_yless.distance_to(center)
		> (3.0 if Library.behavior(controller.config.preset) == "escort" else 1.0)
	):
		_move(
			center,
			(
				"Following escort."
				if Library.behavior(controller.config.preset) == "escort"
				else "Returning to guard point."
			)
		)
	else:
		_hold("Running", "Watching assigned area.")


func _guard_area(center, radius):
	if center == null:
		_hold("Waiting", "Choose an area to guard.")
		return
	if _unit.global_position_yless.distance_to(center) > radius + 2.0:
		_move(center, "Returning to assigned area.")
		return
	var target = _pick_target(center, radius, true)
	if target != null and _unit._match.battlefield.can_fire(_unit, target):
		_fire(target)
	elif target != null:
		_move(target.global_position_yless, "Engaging inside assigned area.")
	elif not _guard_point_reached(center, radius):
		_move(center, "Returning to guard point.")
	else:
		_hold("Running", "Watching assigned area.")
		_guard_settled_at = center


func _guard_point_reached(center, radius):
	var point = _unit.global_position_yless
	if point.distance_to(center) <= 1.0:
		return true
	if (
		_unit.movement_domain != Constants.Match.Navigation.Domain.TERRAIN
		or point.distance_to(center) > radius
		or _owned_structure_at(center) != null
	):
		return false
	# Guards can form up beside settled allies instead of all pushing into one
	# center. A settled guard of this same area can extend that group, bounded
	# by the original circle. Keep the center outside structures and require a
	# clear connection to the neighbor, so a formation can bend around a corner.
	var field = _unit._match.battlefield
	if not field.line_clear(center + Vector3.UP * 0.1, center + Vector3.UP * 0.11, _unit):
		return false
	if (
		_guard_endpoint_reached(center)
		and field.line_clear(point + Vector3.UP * 0.1, center + Vector3.UP * 0.1, _unit)
	):
		return true
	var reach = _unit.radius + Constants.Match.Terrain.Navmesh.MAX_AGENT_RADIUS + 0.25
	for other in field.nearby_units(point, reach, _unit.player):
		if (
			other == _unit
			or other.hp <= 0
			or other.movement_domain != _unit.movement_domain
			or point.distance_to(other.global_position_yless) > _unit.radius + other.radius + 0.25
		):
			continue
		var movement = other.get_node_or_null("Movement")
		if (
			movement == null
			or movement._has_destination
			or movement.velocity.length_squared() >= 0.01
		):
			continue
		if not field.line_clear(
			point + Vector3.UP * 0.1, other.global_position_yless + Vector3.UP * 0.1, _unit
		):
			continue
		if other.global_position_yless.distance_to(center) <= 1.0:
			return true
		if _settled_guard(other, center, radius):
			return true
	return false


func _guard_endpoint_reached(center):
	# An off-mesh assignment can finish at the last reachable path point.
	# Account for that endpoint's arrival tolerance, bounded to half a metre;
	# never accept a distant projection or another command's completed path.
	var tolerance = minf(_movement.path_desired_distance, 0.5)
	var point = _unit.global_position_yless
	if point.distance_to(center) > 1.0 + tolerance:
		return false
	# Holding stops navigation, so preserve a verified arrival on later ticks
	# and archive reloads while the unit remains beside this same clear point.
	if (
		_guard_settled_at != null
		and _guard_settled_at.distance_to(center) < 0.1
		and point.distance_to(_last_progress) < 0.05
	):
		return true
	if (
		_destination == null
		or _destination.distance_to(center) > 0.1
		or _movement.target_position.distance_to(center) > 0.1
		or not _movement.is_navigation_finished()
	):
		return false
	var path = _movement.get_current_navigation_path()
	if path.is_empty():
		return false
	var endpoint = path[-1] * Vector3(1, 0, 1)
	return endpoint.distance_to(center) <= 1.0 and point.distance_to(endpoint) <= tolerance


func _settled_guard(other, center, radius):
	if (
		other.program == null
		or other.program.mode != "Running"
		or other.program.anchor == null
		or other.program.anchor.distance_to(center) > 0.1
		or other.global_position_yless.distance_to(center) > radius
		or other.action == null
		or not other.action.has_method("is_settled_guard")
	):
		return false
	return other.action.is_settled_guard()


func _pick_target(center, radius, assigned_guard = false):
	var best = null
	var score = INF
	if _unit.attack_range == null:
		return null
	var claims = {}
	if is_instance_valid(_unit.program_squad):
		claims = _unit.program_squad.claim_snapshot(_unit)
	var reach = _target_reach()
	if assigned_guard:
		reach = _unit.global_position_yless.distance_to(center) + radius
	for target in _unit._match.battlefield.observed_enemies_near(_unit, reach):
		if (
			(assigned_guard or Library.behavior(controller.config.preset) != "hold")
			and target.global_position_yless.distance_to(center) > radius
		):
			continue
		var distance = _unit.global_position_yless.distance_to(target.global_position_yless)
		if distance > reach:
			continue
		if not _unit._match.battlefield.has_line_of_fire(_unit, target):
			continue
		var value = distance
		if controller.config.priority == "weakest":
			value = 100.0 * target.hp / target.hp_max + distance * 0.01
		elif controller.config.priority == "armor":
			value = distance - (100.0 if Rules.armor_for(target.type) == 2 else 0.0)
		if is_instance_valid(_unit.program_squad):
			value += _unit.program_squad.target_bias(_unit, target, "fire", claims)
		if value < score:
			score = value
			best = target
	return best


func _service(center, radius):
	var best = null
	var health = INF
	var claims = {}
	if is_instance_valid(_unit.program_squad):
		claims = _unit.program_squad.claim_snapshot(_unit, "repair")
	for target in _unit._match.battlefield.nearby_units(center, radius, _unit.player):
		if not Repairs.mobile_eligible(_unit, target):
			continue
		if target.global_position_yless.distance_to(center) > radius:
			continue
		if target.hp >= target.hp_max:
			continue
		var ratio = float(target.hp) / target.hp_max
		if is_instance_valid(_unit.program_squad):
			ratio += _unit.program_squad.target_bias(_unit, target, "repair", claims)
		if ratio < health:
			health = ratio
			best = target
	if best == null:
		if _unit.global_position_yless.distance_to(center) > 2.5:
			_move(center, "Returning to service area.")
		else:
			_hold("Running", "Holding service area; no damaged allies.")
		return
	if Repairs.mobile_distance(_unit, best) > 2.8:
		_move(best.global_position_yless, "Approaching damaged ally inside assignment.")
	else:
		_hold("Running", "Repairing assigned ally.")
		_repair = best
		_claim(best, "repair")


func _at_assigned_service():
	# A safe point placed on a service building means its usable service area;
	# the structure's center is outside the ground navigation mesh.
	for service in _unit.player.get_children():
		if not service.is_in_group("units") or not Repairs.facility_eligible(service, _unit):
			continue
		if controller.safe_point.distance_to(service.global_position_yless) > service.radius:
			continue
		if (
			_unit.global_position_yless.distance_to(service.global_position_yless)
			<= Repairs.FACILITY_RANGE
		):
			return true
	return false


func _fire(target):
	_guard_settled_at = null
	_movement.stop()
	_destination = null
	_stalled = 0.0
	_repair = null
	if is_instance_valid(_shot) and not _shot.is_queued_for_deletion() and _target == target:
		_claim(target)
		return
	_clear_shot()
	_claim(target)
	_target = target
	_shot = Shooting.new(target)
	add_child(_shot)
	controller.set_status("Running", "Engaging: %s target priority." % controller.config.priority)


func _clear_shot():
	_release_claim()
	if is_instance_valid(_defense):
		remove_child(_defense)
		_defense.queue_free()
	_defense = null
	if is_instance_valid(_shot):
		remove_child(_shot)
		_shot.queue_free()
	_shot = null
	_target = null
	_repair = null


func _move(point, explanation):
	_guard_settled_at = null
	_clear_shot()
	if _unit.global_position_yless.distance_to(point) < 0.9:
		_hold("Running", RecoveryAdvice.waiting(_unit) if _retreating else explanation)
		return
	if _destination == null:
		_stalled = 0.0
		_last_progress = _unit.global_position_yless
	_destination = point
	_movement.move(point)
	controller.set_status("Running", explanation)


func _hold(state, explanation, idle_defense = false):
	_guard_settled_at = null
	var defend = idle_defense or state in ["Waiting", "Blocked"]
	if not defend or not is_instance_valid(_defense):
		_clear_shot()
	if defend and _unit.attack_range != null and not is_instance_valid(_defense):
		_defense = load("res://source/match/units/actions/WaitingForTargets.gd").new()
		add_child(_defense)
	_movement.stop()
	_destination = null
	_stalled = 0.0
	_last_progress = _unit.global_position_yless
	controller.set_status(state, explanation)


func _exit_tree():
	_release_claim()
	if is_instance_valid(_movement):
		_movement.stop()


func _claim(target, channel = "fire"):
	if is_instance_valid(_unit.program_squad):
		_unit.program_squad.claim(_unit, target, channel)


func _release_claim():
	if is_instance_valid(_unit) and is_instance_valid(_unit.program_squad):
		_unit.program_squad.release(_unit)


func _specialist_tick(_center, _radius):
	return false


func _on_recovery():
	_returning = true


func _target_reach():
	if controller.config.preset == "guard" and controller.anchor != null:
		# The assignment bounds pursuit. Weapon range only bounds firing:
		# allied observers may reveal a raider anywhere inside the guarded area.
		return _unit.global_position_yless.distance_to(controller.anchor) + controller.config.radius
	return (
		_unit.attack_range + (2.0 if Library.behavior(controller.config.preset) == "guard" else 0.0)
	)


func _decision_interval():
	return 0.25
