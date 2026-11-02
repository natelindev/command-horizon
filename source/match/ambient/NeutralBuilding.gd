extends "res://source/match/ambient/NeutralTarget.gd"

const InfantryRoster = preload("res://source/match/BastionCatalog.gd")

const CAPACITY = InfantryRoster.GARRISON_CAPACITY
const Catalog = preload("res://source/match/ambient/AmbientCatalog.gd")
const NeutralDetails = preload("res://source/match/ambient/NeutralDetails.gd")
const CaptureIndicator = preload("res://source/match/objectives/CaptureIndicator.gd")
var occupants = []
var pending_evacuations = []
var habitable = true
var _evacuation_retry = 0.0
var _body
var _obstacle
var _label
var _height = 6.9
var _fans = []
var _debris = []
var _asset = ""
var _capturer = null
var _capture_indicator
var _owner_flag


func setup(body, identity):
	_body = body
	_asset = body.get_meta("neutral_asset", "")
	habitable = _asset in Catalog.HABITABLE
	_model = body.get_child(0)
	_model_origin = _model.position
	_model_scale = _model.scale
	_obstacle = body.get_node("MovementObstacle")
	_height = _obstacle.sight_height
	neutral_id = identity
	name = "NeutralBuilding"
	_match = body.find_parent("Match")
	configure_target("building", _obstacle.radius, Catalog.BUILDING_HEALTH)
	type = "NeutralBuilding"
	var collider = get_child(0)
	collider.shape.height = _height
	collider.position.y = _height / 2
	_health.position.y = _height + .6
	_label = load("res://source/match/debug/UnitInfoLabel.gd").new()
	_label.position.y = _height + 1
	_label.font = load("res://assets/fonts/NotoSansSC.ttf")
	_label.font_size = 32
	_label.pixel_size = .018
	_label.outline_size = 8
	_label.outline_modulate = Color("15232c")
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.refresh_requested.connect(update_label)
	add_child(_label)
	NeutralDetails.dress_building(_model, radius / _model_scale.x, _asset)
	for mesh in _model.find_children("*", "MeshInstance3D", true, false):
		if "Fanblade" in str(mesh.name).replace("_", "").replace(" ", ""):
			_fans.append([mesh, mesh.rotation])
	_create_debris()
	selected.connect(select_occupants)
	add_to_group("neutral_buildings")
	_capture_indicator = CaptureIndicator.new()
	_capture_indicator.position.y = _height + 1.8
	add_child(_capture_indicator)
	_owner_flag = CaptureIndicator.new()
	_owner_flag.position.y = _height + 0.8
	add_child(_owner_flag)
	update_label()


func is_constructed():
	return hp > 0


func can_garrison(unit):
	return (
		hp > 0
		and habitable
		and InfantryRoster.is_infantry(unit.type)
		and unit.hp > 0
		and unit.regarrison_lock_left <= 0.0
		and not unit.has_meta("breach_pending")
		and occupants.size() < CAPACITY
		and (occupants.is_empty() or player == unit.player)
		and (not is_instance_valid(_capturer) or _capturer.player.is_allied_with(unit.player))
	)


func capture_busy(unit):
	return is_instance_valid(_capturer) and _capturer != unit


func force_attack_only():
	return occupants.is_empty()


func show_capture(unit, elapsed):
	_capturer = unit
	_capture_indicator.display(elapsed, 15.0, unit.player.color)


func clear_capture(unit):
	if _capturer == unit:
		_capturer = null
		_capture_indicator.hide()


func enter(unit, saved_slot = -1):
	if not can_garrison(unit):
		return false
	var slots = occupants.map(func(other): return other.get_meta("garrison_slot", 0))
	for slot in CAPACITY:
		if slot not in slots and (saved_slot < 0 or saved_slot == slot):
			unit.set_meta("garrison_slot", slot)
			break
	unit.set_meta("garrison_entry", unit.global_position)
	occupants.append(unit)
	player = unit.player
	unit.set_meta("garrison_host", self)
	var movement = unit.get_node("Movement")
	movement.stop()
	movement.set_physics_process(false)
	movement.avoidance_enabled = false
	unit.get_node("Geometry").hide()
	unit.collision_layer = 0
	unit.global_position = global_position + Vector3(0, 1.8, 0)
	movement._ground_motion_budget(0.0, 0.0, true)
	unit.get_node("Selection").deselect()
	_match.battlefield.invalidate()
	update_label()
	return true


func leave(unit, reserved_exit = Vector3.INF):
	if unit in pending_evacuations and not reserved_exit.is_finite():
		return
	if unit not in occupants:
		return
	if not is_inside_tree() or not unit.is_inside_tree() or _match.is_queued_for_deletion():
		occupants.erase(unit)
		unit.remove_meta("garrison_host")
		return
	var index = unit.get_meta("garrison_slot", occupants.find(unit))
	unit.remove_meta("garrison_slot")
	unit.remove_meta("garrison_entry")
	occupants.erase(unit)
	unit.remove_meta("garrison_host")
	var movement = unit.get_node("Movement")
	var radial = Vector3(cos(index * TAU / CAPACITY), 0, sin(index * TAU / CAPACITY))
	var exit = global_position + radial * (radius + 1.4)
	# Navigation points sit above the feet, just as on ordinary unit spawns.
	unit.global_position = (
		reserved_exit
		if reserved_exit.is_finite()
		else (
			NavigationServer3D.map_get_closest_point(movement.get_navigation_map(), exit)
			- Vector3.UP * movement.path_height_offset
		)
	)
	unit.reset_physics_interpolation()
	movement.stop()
	movement._ground_motion_budget(0.0, 0.0, true)
	movement.set_velocity_forced(Vector3.ZERO)
	movement.set_physics_process(true)
	movement.avoidance_enabled = true
	unit.get_node("Geometry").show()
	unit.collision_layer = 2
	# Leaving a garrison does not relinquish the captured building.
	_match.battlefield.invalidate()
	update_label()


func select_occupants():
	for unit in occupants:
		if is_instance_valid(unit) and unit.is_in_group("controlled_units"):
			unit.get_node("Selection").select()


func update_label():
	if is_instance_valid(_owner_flag):
		_owner_flag.visible = hp > 0 and player != null
		if player != null:
			_owner_flag.text = (
				(tr("Player %d") % (player.get_index() + 1))
				+ " · "
				+ (tr("Garrison %d / %d") % [occupants.size(), CAPACITY])
			)
			_owner_flag.modulate = player.color.lightened(0.5)
	if not _label.diagnostics_enabled():
		return
	_label.text = (
		tr("Garrison %d / %d") % [occupants.size(), CAPACITY]
		if player != null
		else (
			tr("Infantry shelter · %d slots") % CAPACITY if habitable else tr("Neutral structure")
		)
	)
	_label.modulate = player.color.lightened(.65) if player != null else Color("e1dccb")
	_label.content_visible = hp > 0


func begin_death():
	super()
	for unit in occupants.duplicate():
		pending_evacuations.erase(unit)
		if unit.has_meta("breach_pending"):
			unit.remove_meta("breach_pending")
		leave(unit)
		unit.action = null
		unit.hp -= unit.hp_max * .35
	player = null
	_obstacle.sight_height = .65
	_label.content_visible = false
	_owner_flag.hide()
	_capture_indicator.hide()
	_match.battlefield.invalidate()


func _physics_process(delta):
	if not _match.is_node_ready():
		return
	_evacuation_retry = maxf(0.0, _evacuation_retry - delta)
	if not pending_evacuations.is_empty() and _evacuation_retry <= 0.0:
		_retry_evacuations()
		_evacuation_retry = 0.2
	var previous_count = occupants.size()
	occupants = occupants.filter(func(unit): return is_instance_valid(unit) and unit.hp > 0)
	if occupants.size() != previous_count:
		update_label()
	advance_damage(delta)
	if hp > 0:
		for fan in _fans:
			fan[0].rotation = fan[1] + Vector3(0, _match.simulation_time * 1.8, 0)
	_update_debris()
	refresh_visibility(_match)
	_model.visible = visible


func capture(reference):
	return {
		"id": neutral_id,
		"owner": reference.call(player),
		"combat": capture_combat(),
		"occupants": occupants.map(reference),
		"slots": occupants.map(func(unit): return unit.get_meta("garrison_slot", 0)),
		"entry_points":
		occupants.map(func(unit): return unit.get_meta("garrison_entry", unit.global_position)),
		"evacuating":
		(
			pending_evacuations
			. filter(func(unit): return is_instance_valid(unit) and unit.hp > 0)
			. map(reference)
		)
	}


func restore(saved, entities):
	restore_combat(saved.combat)
	# Pre-v13 saves derive ownership from their garrison, as before.
	player = entities.get(saved.get("owner", ""))
	for index in saved.occupants.size():
		var unit = entities[saved.occupants[index]]
		enter(unit, saved.slots[index])
		if index < saved.get("entry_points", []).size():
			unit.set_meta("garrison_entry", saved.entry_points[index])
	for id in saved.get("evacuating", []):
		var unit = entities.get(id)
		if unit in occupants:
			pending_evacuations.append(unit)
			unit.set_meta("breach_pending", true)
			unit.action = null
	if hp == 0:
		_obstacle.sight_height = .65
	_update_debris()
	update_label()


func firing_origin(target_point):
	var direction = (target_point - global_position) * Vector3(1, 0, 1)
	return global_position + direction.normalized() * (radius + .15) + Vector3.UP * 2.0


func _create_debris():
	var details = NeutralDetails
	var concrete = details.material(Color("777267"))
	for index in 14:
		var angle = index * 2.39996
		var distance = radius * (.25 + .38 * float(index % 4) / 3.0)
		var point = Vector3(cos(angle) * distance, .16, sin(angle) * distance)
		var chunk = details.box(
			self,
			"Rubble",
			point,
			Vector3(.65 + (index % 3) * .35, .28 + (index % 2) * .22, .55),
			concrete
		)
		chunk.rotation = Vector3(.17 * (index % 3), angle, .13 * (index % 2))
		chunk.hide()
		_debris.append([chunk, point])
	var metal = details.material(Color("424a47"), .25)
	for index in 7:
		var angle = index * 2.4
		var point = Vector3(
			cos(angle) * radius * .42, .35 + (index % 3) * .12, sin(angle) * radius * .42
		)
		var panel = details.box(self, "FallenRoof", point, Vector3(2.5, .14, 1.9), metal)
		panel.rotation = Vector3(.15 + (index % 3) * .12, angle, -.15)
		panel.hide()
		_debris.append([panel, point])
	for index in 8:
		var angle = index * TAU / 8
		var point = Vector3(cos(angle) * radius * .58, .4, sin(angle) * radius * .58)
		var wall = details.box(
			self, "BrokenWall", point, Vector3(1.6, .65 + (index % 3) * .3, .38), concrete
		)
		wall.rotation = Vector3(.15 * (index % 2), -angle, .2)
		wall.hide()
		_debris.append([wall, point])


func _update_debris():
	for entry in _debris:
		entry[0].visible = hp <= 0
		if hp <= 0:
			var t = clampf(death_age / 1.1, 0, 1)
			entry[0].position = entry[1] * smoothstep(0, 1, t)
			entry[0].position.y = entry[1].y + sin(t * PI) * 1.3


func apply_death_pose():
	super()
	# The intact shell settles into dust, leaving fractured walls and roof slabs.
	# Keep the authored apron as the footprint beneath the rubble.
	for mesh in _meshes:
		if "apron" not in str(mesh.name).to_lower():
			mesh.transparency = smoothstep(.4, 1.1, death_age)


func evacuate_breached(units: Array):
	for unit in units:
		if unit not in occupants or unit in pending_evacuations or unit.hp <= 0.0:
			continue
		pending_evacuations.append(unit)
		unit.set_meta("breach_pending", true)
		# Teardown may request leave; leave waits for a reserved legal position.
		unit.action = null
	_retry_evacuations()
	_evacuation_retry = 0.2


func _retry_evacuations():
	pending_evacuations = pending_evacuations.filter(
		func(unit): return is_instance_valid(unit) and unit.hp > 0.0 and unit in occupants
	)
	var reserved = []
	# Reserve the whole batch before moving anyone; slots never overlap.
	for unit in pending_evacuations:
		var point = _evacuation_position(unit, reserved)
		if point.is_finite():
			reserved.append({"unit": unit, "point": point})
	for exit in reserved:
		var unit = exit.unit
		leave(unit, exit.point)
		pending_evacuations.erase(unit)
		unit.remove_meta("breach_pending")
		unit.regarrison_lock_left = 3.0
		if is_instance_valid(unit.action):
			unit.action.process_mode = Node.PROCESS_MODE_INHERIT
		unit.action_updated.emit()


func _evacuation_position(unit, reserved: Array) -> Vector3:
	var movement = unit.get_node("Movement")
	var nav = movement.get_navigation_map()
	var origin = unit.get_meta("garrison_entry", global_position + Vector3.RIGHT * (radius + 1.4))
	var anchor = NavigationServer3D.map_get_closest_point(nav, origin)
	var placement = load("res://source/match/utils/UnitPlacementUtils.gd")
	var base_angle = unit.get_meta("garrison_slot", 0) * TAU / CAPACITY
	for ring in 4:
		for step in 32:
			var angle = base_angle + step * TAU / 32.0
			var desired = (
				global_position + Vector3(cos(angle), 0, sin(angle)) * (radius + 0.8 + ring * 0.8)
			)
			desired.y = _match.map.height_at(Vector2(desired.x, desired.z))
			var point = (
				NavigationServer3D.map_get_closest_point(
					nav, desired + Vector3.UP * movement.path_height_offset
				)
				- Vector3.UP * movement.path_height_offset
			)
			if Vector2(point.x - desired.x, point.z - desired.z).length() > 0.3:
				continue
			var nearby = _match.battlefield.nearby_units(point, unit.radius + 4.0).filter(
				func(other):
					return (
						other != unit
						and not other.has_meta("garrison_host")
						and other.movement_domain == unit.movement_domain
					)
			)
			nearby.append_array(_match.battlefield.nearby_obstacles(point, unit.radius + 4.0))
			if (
				placement.validate_agent_placement_position(
					point, unit.radius + 0.05, nearby, nav, _match.map
				)
				!= placement.VALID
			):
				continue
			var overlaps = false
			for exit in reserved:
				if point.distance_to(exit.point) < unit.radius + exit.unit.radius + 0.1:
					overlaps = true
			if overlaps:
				continue
			var path = _match.navigation.path_query.path(
				nav, anchor, point + Vector3.UP * movement.path_height_offset
			)
			if (
				path.is_empty()
				or path[-1].distance_to(point + Vector3.UP * movement.path_height_offset) > 0.4
			):
				continue
			var distance = 0.0
			for index in range(1, path.size()):
				distance += path[index - 1].distance_to(path[index])
			if distance > (radius + 4.0) * TAU:
				continue
			return point
	return Vector3.INF
