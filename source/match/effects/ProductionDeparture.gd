extends Node3D

const Factions = preload("res://source/match/FactionCatalog.gd")
const InfantryMotion = preload("res://source/match/units/traits/InfantryMotion.gd")
const WheelMotion = preload("res://source/match/units/traits/WheelMotion.gd")
const WalkerGait = preload("res://source/match/units/traits/WalkerGait.gd")
var movement_speed = 3.0
var endpoint = Vector3.ZERO
var duration = 1.8
var job
var producer
var airborne = false
var radius = .5
var _origin = Vector3.ZERO
var _control = Vector3.ZERO
var _navigation_map = RID()
var _motion
var _wheels
var _rotors = []
var _walker = null
var _clock = 0.0
var _previous = Vector3.ZERO
var _route_ready = false
var _exit_blockers = []
var _clearance_retry = 0.0
var _geometry


static func seconds(element):
	var role = element.unit_prototype.resource_path.get_file().get_basename()
	var length = 1.1 if Factions.Bastion.is_infantry(role) else 1.8
	if Factions.Bastion.is_aircraft(role):
		length = 2.4
	return minf(length, element.time_total * .35)


func prepare(building, element):
	producer = building
	job = element
	duration = seconds(job)
	var prototype = job.unit_prototype.instantiate()
	radius = prototype.radius
	movement_speed = prototype.movement_speed
	airborne = prototype.movement_domain == Constants.Match.Navigation.Domain.AIR
	_navigation_map = producer._match.navigation.get_navigation_map_rid_by_domain(
		prototype.movement_domain
	)
	Factions.prepare_model(prototype, producer.player.faction)
	_geometry = prototype.get_node("Geometry")
	_clear_owners(_geometry)
	prototype.remove_child(_geometry)
	add_child(_geometry)
	Utils.Match.traverse_node_tree_and_replace_materials_matching_albedo(
		_geometry,
		prototype.MATERIAL_ALBEDO_TO_REPLACE,
		prototype.MATERIAL_ALBEDO_TO_REPLACE_EPSILON,
		producer.player.get_color_material(),
		true
	)
	var infantry = Factions.Bastion.is_infantry(prototype.type)
	prototype.free()
	var activity = producer.get_node("StructureActivity")
	_origin = producer.to_global(
		activity.portal + (Vector3.ZERO if airborne else Vector3.BACK * .55)
	)
	_control = producer.to_global(activity.portal + Vector3.FORWARD * .7)
	global_position = _origin
	global_rotation.y = producer.global_rotation.y
	_previous = global_position
	if infantry:
		_motion = InfantryMotion.new()
		_motion.setup(self, float(producer.get_meta("visual_seed", 0) % 17) * .37)
	_wheels = WheelMotion.new()
	_wheels.setup(self)
	for pattern in ["*RotorLeft", "*RotorRight", "*Rotor?"]:
		_rotors += find_children(pattern, "Node3D", true, false)
	var legs = []
	for pattern in ["*LegLeft*", "*LegRight*"]:
		for leg in find_children(pattern, "Node3D", true, false):
			if not leg is MeshInstance3D:
				legs.append(leg)
	if not legs.is_empty():
		_walker = WalkerGait.new()
		_walker.setup(self, legs, 0.0)
	if job.departure_endpoint != null:
		endpoint = job.departure_endpoint
		_route_ready = true
	visible = false


func _clear_owners(node):
	node.owner = null
	for child in node.get_children():
		_clear_owners(child)


func find_route():
	if _route_ready:
		if clear_route():
			return true
		# A selected exit can become occupied during assembly or a paused
		# archive. Before departure starts, try another legal route. Preserve
		# the path once the unit has started emerging from the building.
		if job.time_left < duration:
			if clear_route(true):
				_clear_friendly_exit()
			return false
		_route_ready = false
	var yield_endpoint = Vector3.INF
	var activity = producer.get_node("StructureActivity")
	var reach = producer.radius + radius + .35
	var base = Vector3(activity.portal.x, 0, 0)
	if airborne and activity.portal_direction != Vector3.FORWARD:
		# Leave from the helipad itself, not from the structure's center.
		reach = radius + 2.5
		base = activity.portal * Vector3(1, 0, 1)
	for ring in range(3):
		for angle in [0.0, -.35, .35, -.7, .7]:
			var offset = (
				base
				+ (
					activity.portal_direction.rotated(Vector3.UP, angle)
					* (reach + ring * radius * 1.5)
				)
			)
			var requested = producer.to_global(offset)
			var navigable = NavigationServer3D.map_get_closest_point(_navigation_map, requested)
			if ((navigable - requested) * Vector3(1, 0, 1)).length() > .1:
				continue
			navigable.y -= .8 if airborne else .6
			if airborne and producer._match.map.has_method("flight_height_at"):
				navigable.y = producer._match.map.flight_height_at(navigable, navigable.y)
			endpoint = navigable
			if clear_route():
				job.departure_endpoint = endpoint
				_route_ready = true
				return true
			if not yield_endpoint.is_finite() and clear_route(true):
				yield_endpoint = endpoint
	if yield_endpoint.is_finite():
		endpoint = yield_endpoint
		job.departure_endpoint = endpoint
		_route_ready = true
		clear_route(true)
		_clear_friendly_exit()
	return false


func clear_route(ignore_friendly = false):
	if ignore_friendly:
		_exit_blockers.clear()
	var game = producer._match
	var units = (
		get_tree().get_nodes_in_group("units") + get_tree().get_nodes_in_group("resource_units")
	)
	var previous = _origin
	for index in range(1, 13):
		var point = route_point(index / 12.0)
		for unit in units:
			if (
				unit == producer
				or unit.is_queued_for_deletion()
				or unit.is_in_group("salvage_wrecks")
			):
				continue
			var domain = (
				unit.movement_domain
				if "movement_domain" in unit
				else Constants.Match.Navigation.Domain.TERRAIN
			)
			if (
				domain
				!= (
					Constants.Match.Navigation.Domain.AIR
					if airborne
					else Constants.Match.Navigation.Domain.TERRAIN
				)
			):
				continue
			if point.distance_to(unit.global_position) < radius + unit.radius + .08:
				if ignore_friendly and _can_clear_exit(unit):
					if unit not in _exit_blockers:
						_exit_blockers.append(unit)
					continue
				return false
		if not airborne:
			for side in [-1, 0, 1]:
				var margin = producer.global_basis.x * radius * side
				if not game.battlefield.line_clear(
					previous + margin + Vector3.UP * .6, point + margin + Vector3.UP * .6, producer
				):
					return false
			# The building excludes the largest agent from its navmesh; small
			# infantry must cross that same exclusion before normal navigation.
			if (
				point.distance_to(producer.global_position)
				> producer.radius + Constants.Match.Terrain.Navmesh.MAX_AGENT_RADIUS + .3
			):
				var nav = NavigationServer3D.map_get_closest_point(_navigation_map, point)
				if ((nav - point) * Vector3(1, 0, 1)).length() > .12:
					return false
		previous = point
	return true


func _can_clear_exit(unit):
	return (
		unit.is_in_group("units")
		and unit.player == producer.player
		and unit.movement_speed > 0
		and unit.hp > 0
		and not unit.has_meta("garrison_host")
	)


func _clear_friendly_exit():
	var game = producer._match
	if game.simulation_time < _clearance_retry:
		return
	_clearance_retry = game.simulation_time + .3
	var units = (
		get_tree().get_nodes_in_group("units") + get_tree().get_nodes_in_group("resource_units")
	)
	# A packed row needs its adjacent allies to yield too; otherwise every
	# candidate sidestep can be occupied. Only expand one local neighbor layer.
	for blocker in _exit_blockers.duplicate():
		for neighbor in game.battlefield.nearby_bodies(
			blocker.global_position, blocker.radius + 1.0, producer.player
		):
			if (
				neighbor not in _exit_blockers
				and _can_clear_exit(neighbor)
				and neighbor.movement_domain == blocker.movement_domain
				and (
					neighbor.global_position.distance_to(blocker.global_position)
					< neighbor.radius + blocker.radius + 1.0
				)
			):
				_exit_blockers.append(neighbor)
	for unit in _exit_blockers:
		var movement = unit.get_node("Movement")
		var side = producer.global_basis.x.normalized()
		if (unit.global_position - endpoint).dot(side) < 0:
			side = -side
		for offset in [side, -side, -producer.global_basis.z.normalized()]:
			var requested = unit.global_position + offset * (radius + unit.radius + 1.0)
			var point = NavigationServer3D.map_get_closest_point(
				movement.get_navigation_map(), requested
			)
			point.y -= movement.path_height_offset
			if ((point - requested) * Vector3(1, 0, 1)).length() > .12:
				continue
			if units.any(
				func(other):
					return (
						other != unit
						and not other.is_queued_for_deletion()
						and not other.is_in_group("salvage_wrecks")
						and (
							not "movement_domain" in other
							or other.movement_domain == unit.movement_domain
						)
						and (
							point.distance_to(other.global_position)
							< unit.radius + other.radius + .15
						)
					)
			):
				continue
			if (
				not airborne
				and not game.battlefield.line_clear(
					unit.global_position + Vector3.UP * .6, point + Vector3.UP * .6, unit
				)
			):
				continue
			# The destination must clear the whole exit, not just its endpoint.
			var outside = true
			for index in range(1, 13):
				if point.distance_to(route_point(index / 12.0)) < radius + unit.radius + .3:
					outside = false
					break
			if outside:
				movement.request_exit_clearance(point)
				break


func route_point(progress):
	if airborne:
		# Rise vertically above the deck before translating into the flight lane.
		var lift = _origin
		lift.y = endpoint.y
		if progress < .55:
			return _origin.lerp(lift, smoothstep(0.0, .55, progress))
		return lift.lerp(endpoint, smoothstep(.55, 1.0, progress))
	var a = _origin.lerp(_control, progress)
	var b = _control.lerp(endpoint, progress)
	return a.lerp(b, progress)


func update_pose(delta):
	if not _route_ready:
		return
	visible = true
	var progress = clampf(1.0 - job.time_left / duration, 0.0, 1.0)
	global_position = route_point(progress)
	var direction = (route_point(minf(1.0, progress + .01)) - global_position) * Vector3(1, 0, 1)
	if direction.length_squared() > .00001:
		global_rotation.y = atan2(-direction.x, -direction.z)
	var distance = global_position.distance_to(_previous)
	_previous = global_position
	_clock += delta
	if _motion != null:
		_motion.advance(delta, distance, _clock, 0.0, 0.0, 0.0)
	_wheels.advance(delta)
	for rotor in _rotors:
		rotor.rotation.y += delta * 25.0
	if _walker != null:
		_walker.advance(delta, distance, 0.0)


func handoff(unit):
	# Continue the exit stride on the real unit instead of restarting its gait.
	var visual = unit.get_node("BastionVisuals")
	if _motion != null and visual._infantry_motion != null:
		visual._infantry_motion.copy_from(_motion)
	if _walker != null and visual._walker != null:
		visual._walker.copy_from(_walker)
