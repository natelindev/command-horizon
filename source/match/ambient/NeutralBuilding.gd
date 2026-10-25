extends "res://source/match/ambient/NeutralTarget.gd"

const InfantryRoster = preload("res://source/match/BastionCatalog.gd")

const CAPACITY = InfantryRoster.GARRISON_CAPACITY
const Catalog = preload("res://source/match/ambient/AmbientCatalog.gd")
const NeutralDetails = preload("res://source/match/ambient/NeutralDetails.gd")
const CaptureIndicator = preload("res://source/match/objectives/CaptureIndicator.gd")
var occupants = []
var habitable = true
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
	unit.get_node("Selection").deselect()
	_match.battlefield.invalidate()
	update_label()
	return true


func leave(unit):
	if unit not in occupants:
		return
	if not is_inside_tree() or not unit.is_inside_tree() or _match.is_queued_for_deletion():
		occupants.erase(unit)
		unit.remove_meta("garrison_host")
		return
	var index = unit.get_meta("garrison_slot", occupants.find(unit))
	unit.remove_meta("garrison_slot")
	occupants.erase(unit)
	unit.remove_meta("garrison_host")
	var movement = unit.get_node("Movement")
	var radial = Vector3(cos(index * TAU / CAPACITY), 0, sin(index * TAU / CAPACITY))
	var exit = global_position + radial * (radius + 1.4)
	# Navigation points sit above the feet, just as on ordinary unit spawns.
	unit.global_position = (
		NavigationServer3D.map_get_closest_point(movement.get_navigation_map(), exit)
		- Vector3.UP * movement.path_height_offset
	)
	unit.reset_physics_interpolation()
	movement.stop()
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
		"slots": occupants.map(func(unit): return unit.get_meta("garrison_slot", 0))
	}


func restore(saved, entities):
	restore_combat(saved.combat)
	# Pre-v13 saves derive ownership from their garrison, as before.
	player = entities.get(saved.get("owner", ""))
	for index in saved.occupants.size():
		enter(entities[saved.occupants[index]], saved.slots[index])
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
