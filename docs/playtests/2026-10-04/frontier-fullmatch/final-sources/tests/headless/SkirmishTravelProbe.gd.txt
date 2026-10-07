extends "res://tests/headless/SkirmishMatrix.gd"

var reported = {}
var archive_path = ""
var archive_written = false
var avoidance_frames = {}
var avoidance_velocities = {}


func _track_unit(unit):
	super(unit)
	var movement = unit.get_node_or_null("Movement")
	if movement == null:
		return
	var callback = _record_avoidance.bind(unit.get_instance_id())
	if not movement.velocity_computed.is_connected(callback):
		movement.velocity_computed.connect(callback)


func _record_avoidance(safe_velocity, unit_id):
	avoidance_frames[unit_id] = Engine.get_physics_frames()
	avoidance_velocities[unit_id] = safe_velocity


func _initialize():
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--archive="):
			archive_path = argument.trim_prefix("--archive=")
	super()


func _capture_stationary_state(unit):
	if archive_path.is_empty() or archive_written:
		return
	archive_written = true
	var was_paused = paused
	paused = true
	var snapshot = load("res://source/match/saves/MatchSnapshot.gd").new()
	var record = snapshot.capture(game)
	var file = load("res://source/match/saves/SaveFile.gd").new()
	var saved = record != null and file.write_file(archive_path, record)
	paused = was_paused
	_check(saved, "Stationary-travel archive failed: " + snapshot.error)
	print("STATIONARY ARCHIVE ", archive_path, " saved=", saved)
	if saved:
		var id = snapshot._reference(unit)
		print("STATIONARY ARCHIVE UNIT ", id)
		return id


func _measure():
	super()
	for unit in get_nodes_in_group("units"):
		var id = unit.get_instance_id()
		if not travel_samples.has(id) or travel_samples[id].still < 15:
			continue
		var movement = unit.get_node_or_null("Movement")
		if movement == null or unit.is_queued_for_deletion():
			continue
		var interval = int(travel_samples[id].still / 15)
		if reported.get(id, 0) >= interval:
			continue
		reported[id] = interval
		_capture_stationary_state(unit)
		print(
			"STATIONARY TRAVEL ",
			JSON.stringify(
				{
					"case": active_case,
					"repetition": repetition,
					"time": game.simulation_time,
					"side": "human" if unit.player == human else "AI",
					"role": unit.type,
					"seconds": travel_samples[id].still,
					"position": str(unit.position),
					"destination": str(movement.target_position),
					"action": str(unit.action),
					"path": str(movement.get_current_navigation_path()),
					"path_index": movement.get_current_navigation_path_index(),
					"path_query":
					str(
						NavigationServer3D.map_get_path(
							movement.get_navigation_map(),
							unit.global_position,
							movement.target_position,
							true,
							movement.navigation_layers
						)
					),
					"nearest_navigable":
					str(
						NavigationServer3D.map_get_closest_point(
							movement.get_navigation_map(), unit.global_position
						)
					),
					"movement_processing": movement.is_physics_processing(),
					"synchronized": movement._synchronized,
					"has_destination": movement._has_destination,
					"physics_delta": movement._physics_delta,
					"avoidance_enabled": movement.avoidance_enabled,
					"frames_since_avoidance":
					(
						Engine.get_physics_frames() - avoidance_frames[id]
						if avoidance_frames.has(id)
						else -1
					),
					"navigation_layers": movement.navigation_layers,
					"map_iteration":
					NavigationServer3D.map_get_iteration_id(movement.get_navigation_map()),
					"nearby_obstacles": _nearby_obstacles(unit),
					"nearby_agents": _nearby_agents(unit),
					"velocity": str(movement.velocity),
					"safe_velocity": str(avoidance_velocities.get(id, Vector3.ZERO)),
					"recovery_left": movement._recovery_left,
					"recovery_direction": str(movement._recovery_direction),
					"hp": unit.hp,
					"target":
					str(unit.aim_target.position) if is_instance_valid(unit.aim_target) else "none"
				}
			)
		)


func _nearby_obstacles(unit):
	var result = []
	for other in get_nodes_in_group("units") + get_nodes_in_group("resource_units"):
		var obstacle = other.get_node_or_null("MovementObstacle")
		if obstacle == null or other.position.distance_to(unit.position) > 10:
			continue
		result.append(
			{
				"role": other.type if "type" in other else other.name,
				"position": str(other.position),
				"radius": obstacle.radius
			}
		)
	return result


func _nearby_agents(unit):
	var result = []
	for other in get_nodes_in_group("units"):
		var movement = other.get_node_or_null("Movement")
		if (
			other == unit
			or other.is_queued_for_deletion()
			or movement == null
			or other.movement_domain != unit.movement_domain
			or other.position.distance_to(unit.position) > movement.neighbor_distance
		):
			continue
		result.append(
			{
				"role": other.type,
				"position": str(other.position),
				"radius": movement.radius,
				"action": str(other.action),
				"destination": str(movement.target_position),
				"velocity": str(movement.velocity),
				"safe_velocity":
				str(avoidance_velocities.get(other.get_instance_id(), Vector3.ZERO)),
				"has_destination": movement._has_destination
			}
		)
	return result
