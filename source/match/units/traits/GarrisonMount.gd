extends Node

## Open infantry mounts share the existing garrison action and combat rules.
## Passengers remain independent shooters; only their movement belongs to the rig.
const CAPACITY = 4
const WRECK_DAMAGE_FRACTION = 0.35
const Catalog = preload("res://source/match/BastionCatalog.gd")
const Placement = preload("res://source/match/utils/UnitPlacementUtils.gd")
var capacity: int = CAPACITY
var occupants: Array = []
var pending_evacuations: Array = []
var _retry_left = 0.0
@onready var _host = get_parent()


static func eligible(unit) -> bool:
	return unit.player != null and unit.player.faction == "frontier" and unit.type == "AdvancedTank"


func _ready():
	MatchSignals.unit_destroying.connect(_on_unit_destroying)
	_host.tree_exiting.connect(_on_host_removed)


func can_garrison(unit) -> bool:
	return (
		is_instance_valid(unit)
		and unit != _host
		and _host.hp > 0
		and not _host.is_queued_for_deletion()
		and unit.hp > 0
		and unit.player == _host.player
		and Catalog.is_infantry(unit.type)
		and unit.regarrison_lock_left <= 0.0
		and not unit.has_meta("breach_pending")
		and not unit.has_meta("garrison_host")
		and occupants.size() < capacity
	)


func enter(unit, saved_slot = -1) -> bool:
	if not can_garrison(unit):
		return false
	if (
		saved_slot < 0
		and (
			unit.global_position_yless.distance_to(_host.global_position_yless)
			> _host.radius + unit.radius + 1.0
		)
	):
		return false
	var slots = occupants.map(func(other): return other.get_meta("garrison_slot", 0))
	var available = -1
	for slot in capacity:
		if slot not in slots and (saved_slot < 0 or saved_slot == slot):
			available = slot
			break
	if available < 0:
		return false
	unit.set_meta("garrison_slot", available)
	unit.set_meta("garrison_host", _host)
	occupants.append(unit)
	var movement = unit.get_node("Movement")
	movement.stop()
	movement.set_physics_process(false)
	movement.avoidance_enabled = false
	movement.ghosted = true
	unit.collision_layer = 0
	unit.get_node("Selection").deselect()
	unit.hide()
	_position_passenger(unit)
	movement._ground_motion_budget(0.0, 0.0, true)
	_host._match.battlefield.invalidate()
	_host.action_updated.emit()
	return true


func leave(unit):
	if unit not in occupants:
		return
	if (
		not _host.is_inside_tree()
		or not unit.is_inside_tree()
		or not _host._match.is_inside_tree()
		or _host._match.is_queued_for_deletion()
	):
		occupants.erase(unit)
		pending_evacuations.erase(unit)
		unit.remove_meta("garrison_host")
		unit.remove_meta("garrison_slot")
		return
	var point = _exit_position(unit)
	if not point.is_finite():
		if unit not in pending_evacuations:
			pending_evacuations.append(unit)
		unit.set_meta("breach_pending", true)
		return
	_release(unit, point)


func _release(unit, point: Vector3):
	var movement = unit.get_node("Movement")
	var resume_destination = (
		movement.target_position
		if unit in pending_evacuations and movement._has_destination
		else Vector3.INF
	)
	occupants.erase(unit)
	pending_evacuations.erase(unit)
	unit.remove_meta("garrison_host")
	unit.remove_meta("garrison_slot")
	if unit.has_meta("breach_pending"):
		unit.remove_meta("breach_pending")
	unit.global_position = point
	unit.reset_physics_interpolation()
	movement.stop()
	movement._ground_motion_budget(0.0, 0.0, true)
	movement.set_velocity_forced(Vector3.ZERO)
	movement.set_physics_process(true)
	movement.avoidance_enabled = true
	movement.ghosted = false
	unit.collision_layer = 2
	var visibility = _host._match.get_node_or_null("Handlers/UnitVisibilityHandler")
	if visibility != null:
		visibility._recalculate_unit_visibility(unit)
	else:
		unit.show()
	if is_instance_valid(unit.action):
		unit.action.process_mode = Node.PROCESS_MODE_INHERIT
	if resume_destination.is_finite():
		movement.move(resume_destination)
	unit.action_updated.emit()
	_host._match.battlefield.invalidate()
	_host.action_updated.emit()


func _physics_process(delta):
	for unit in occupants.duplicate():
		if not is_instance_valid(unit) or unit.hp <= 0:
			occupants.erase(unit)
			pending_evacuations.erase(unit)
			continue
		_position_passenger(unit)
	_retry_left = maxf(0.0, _retry_left - delta)
	if _retry_left <= 0.0 and not pending_evacuations.is_empty():
		for unit in pending_evacuations.duplicate():
			leave(unit)
		_retry_left = 0.2


func _position_passenger(unit):
	var slot = unit.get_meta("garrison_slot", 0)
	var lateral = -0.42 if slot % 2 == 0 else 0.42
	var longitudinal = -0.42 if slot < 2 else 0.42
	unit.global_position = _host.to_global(
		Vector3(lateral * _host.radius, 1.0, longitudinal * _host.radius)
	)


func firing_origin(target_point: Vector3) -> Vector3:
	var direction = (target_point - _host.global_position) * Vector3(1, 0, 1)
	return _host.global_position + direction.normalized() * (_host.radius + 0.15) + Vector3.UP * 1.5


func _exit_position(unit) -> Vector3:
	var movement = unit.get_node("Movement")
	var navigation_map = movement.get_navigation_map()
	var game = _host._match
	var anchor = NavigationServer3D.map_get_closest_point(
		navigation_map, _host.global_position + Vector3.UP * movement.path_height_offset
	)
	var angle = unit.get_meta("garrison_slot", 0) * TAU / capacity
	for ring in 5:
		for step in 24:
			var direction = Vector3(
				cos(angle + step * TAU / 24.0), 0, sin(angle + step * TAU / 24.0)
			)
			var desired = (
				_host.global_position + direction * (_host.radius + unit.radius + 0.5 + ring)
			)
			desired.y = game.map.height_at(Vector2(desired.x, desired.z))
			var point = (
				NavigationServer3D.map_get_closest_point(
					navigation_map, desired + Vector3.UP * movement.path_height_offset
				)
				- Vector3.UP * movement.path_height_offset
			)
			if Vector2(point.x - desired.x, point.z - desired.z).length() > 0.3:
				continue
			var nearby = game.battlefield.nearby_units(point, unit.radius + 4.0).filter(
				func(other):
					return (
						other != unit
						and not other.has_meta("garrison_host")
						and other.movement_domain == unit.movement_domain
					)
			)
			nearby.append_array(game.battlefield.nearby_obstacles(point, unit.radius + 4.0))
			if (
				Placement.validate_agent_placement_position(
					point, unit.radius + 0.05, nearby, navigation_map, game.map
				)
				== Placement.VALID
			):
				var endpoint = point + Vector3.UP * movement.path_height_offset
				var path = NavigationServer3D.map_get_path(navigation_map, anchor, endpoint, true)
				if path.is_empty() or path[-1].distance_to(endpoint) > 0.4:
					continue
				var distance = 0.0
				for index in range(1, path.size()):
					distance += path[index - 1].distance_to(path[index])
				# A nearby position across a wall or cliff needs an ordinary approach.
				if distance <= (_host.radius + 6.0) * TAU:
					return point
	return Vector3.INF


func _on_unit_destroying(unit):
	if unit == _host:
		_evacuate(true)


func _on_host_removed():
	if is_instance_valid(_host._match) and not _host._match.is_queued_for_deletion():
		_evacuate(false)


func _evacuate(wrecked: bool):
	for unit in occupants.duplicate():
		if not is_instance_valid(unit) or not unit.is_inside_tree():
			continue
		var point = _exit_position(unit)
		if not point.is_finite():
			var movement = unit.get_node("Movement")
			point = (
				NavigationServer3D.map_get_closest_point(
					movement.get_navigation_map(), _host.global_position
				)
				- Vector3.UP * movement.path_height_offset
			)
		_release(unit, point)
		unit.manual_orders.cancel()
		unit.action = null
		if wrecked:
			unit.regarrison_lock_left = 3.0
			unit.hp -= unit.hp_max * WRECK_DAMAGE_FRACTION


func capture(reference) -> Dictionary:
	return {
		"occupants": occupants.map(reference),
		"slots": occupants.map(func(unit): return unit.get_meta("garrison_slot", 0)),
		"evacuating": pending_evacuations.map(reference),
	}


func restore(saved: Dictionary, entities: Dictionary):
	for index in saved.occupants.size():
		enter(entities[saved.occupants[index]], saved.slots[index])
	for id in saved.evacuating:
		var unit = entities[id]
		pending_evacuations.append(unit)
		unit.set_meta("breach_pending", true)
