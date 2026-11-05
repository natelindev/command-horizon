# gdlint: disable=duplicated-load,max-public-methods
# Runtime loading avoids autoload-dependent preload cycles.
extends "res://source/match/objectives/CaptureRelay.gd"

signal recruitment_changed
signal hp_changed

const Sites = preload("res://source/match/world/PointOfInterestCatalog.gd")
const Factions = preload("res://source/match/FactionCatalog.gd")
const CAPTURE_RADIUS = 5.0
const INCOME_INTERVAL = 4.0
const ECONOMIC_CAPTURE_SECONDS = 12.0
const QUEUE_LIMIT = 3
const REFINERY = preload("res://assets/models/environment/neutral/OilRefinery.glb")
const OWNERSHIP_MATERIAL = "Ownership band"
const Rules = preload("res://source/match/combat/CombatRules.gd")
var site_id = ""
var kind = "refinery"
var radius = 2.2
var movement_domain = 1
var movement_speed = 0.0
var attack_range = null
var jobs = []
var stock_a = 600
var stock_b = 300
var income_left = INCOME_INTERVAL
var machinery = null
var radar_left = 0.0
var radar_points = []
var last_enemy_damage_time = -INF
var hp_max = 300.0
var signature = null
var type:
	get:
		return "RepairDepot" if kind == "repair" else "PointOfInterest"
var global_position_yless:
	get:
		return global_position * Vector3(1, 0, 1)

var _payer = null
var _capturer = null
var _capture_indicator


func _ready():
	hp = hp_max
	sight_range = 9.0
	add_to_group("vision_sources")
	_invalidate_registry()
	add_to_group("points_of_interest")
	_build_model()
	var obstacle = load("res://source/match/units/traits/MovementObstacle.tscn").instantiate()
	obstacle.radius = radius
	obstacle.path_height_offset = .6
	obstacle.affect_navigation_mesh = true
	if kind == "repair":
		obstacle.affect_navigation_mesh = false
		obstacle.avoidance_enabled = false
		add_to_group("repair_platforms")
	add_child(obstacle)
	captured.connect(_ownership_changed)
	collision_layer = 2
	var collider = CollisionShape3D.new()
	var shape = CylinderShape3D.new()
	shape.radius = radius
	shape.height = 4.0
	collider.shape = shape
	collider.position.y = 2.0
	add_child(collider)
	var targetability = load("res://source/match/units/traits/Targetability.tscn").instantiate()
	targetability.radius = radius
	add_child(targetability)
	input_event.connect(_recruitment_input)
	_capture_indicator = load("res://source/match/objectives/CaptureIndicator.gd").new()
	_capture_indicator.position.y = _label.position.y + 1.4
	add_child(_capture_indicator)


func _build_model():
	if kind == "refinery":
		_build_refinery()
	elif kind == "data_relay":
		_build_data_relay()
	else:
		_build_faction_building()
	_label = Label3D.new()
	_label.position = Vector3(0, 5.5 if kind == "refinery" else 3.4, 0)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font = load("res://assets/fonts/NotoSansSC.ttf")
	_label.font_size = 28
	_label.pixel_size = .012
	add_child(_label)
	_update_presentation()


# A neutral field refinery: painted bands take the owner's colour and the
# nodding pump on the pad's open corner shows active extraction.
func _build_refinery():
	var geometry = REFINERY.instantiate()
	geometry.name = "Geometry"
	add_child(geometry)
	_lamp = StandardMaterial3D.new()
	_lamp.albedo_color = Color("d0baa0")
	_lamp.roughness = 0.5
	for mesh in geometry.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count():
			var material = mesh.mesh.surface_get_material(surface)
			if material != null and material.resource_name.begins_with(OWNERSHIP_MATERIAL):
				mesh.set_surface_override_material(surface, _lamp)
	machinery = load("res://source/match/world/RefineryMachinery.gd").new()
	machinery.name = "ExtractionPump"
	machinery.position = Vector3(-1.45, 0.12, 1.55)
	machinery.rotation.y = PI / 2
	machinery.scale = Vector3.ONE * .5
	add_child(machinery)


func _build_faction_building():
	var role = {"mercenary": "Barracks", "repair": "RepairDepot"}[kind]
	var prototype = load(Factions.Bastion.scene_path(role)).instantiate()
	Factions.prepare_model(prototype, "bastion")
	var geometry = prototype.get_node("Geometry")
	_clear_owners(geometry)
	prototype.remove_child(geometry)
	geometry.rotation.y = PI
	add_child(geometry)
	_lamp = StandardMaterial3D.new()
	_lamp.albedo_color = Color("aaa18d")
	Utils.Match.traverse_node_tree_and_replace_materials_matching_albedo(
		geometry,
		prototype.MATERIAL_ALBEDO_TO_REPLACE,
		prototype.MATERIAL_ALBEDO_TO_REPLACE_EPSILON,
		_lamp,
		true
	)
	prototype.free()


func _capture_presence():
	var infantry = []
	var combatants = []
	if _match == null or _match.battlefield == null:
		return {"infantry": infantry, "combatants": combatants}
	for unit in _match.battlefield.nearby_units(global_position, CAPTURE_RADIUS):
		if (
			unit.hp <= 0
			or unit.is_queued_for_deletion()
			or unit.movement_domain != 1
			or unit.has_meta("garrison_host")
		):
			continue
		if unit.movement_speed <= 0 or unit.attack_range == null:
			continue
		if unit.player not in combatants:
			combatants.append(unit.player)
		if InfantryRoster.is_infantry(unit.type) and unit.player not in infantry:
			infantry.append(unit.player)
	return {"infantry": infantry, "combatants": combatants}


func _clear_owners(node):
	node.owner = null
	for child in node.get_children():
		_clear_owners(child)


func capture_help(_viewer):
	return (
		tr(
			(
				"Right-click with infantry to capture at the building for %d seconds. "
				+ "Any damage to the infantry interrupts capture. "
				+ "Use Force Attack to destroy the building."
			)
		)
		% int(capture_duration())
	)


func capture_duration() -> float:
	return ECONOMIC_CAPTURE_SECONDS if kind in ["refinery", "data_relay"] else 15.0


func capture_blocked(unit) -> bool:
	return _capture_presence().infantry.any(func(side): return not unit.player.is_allied_with(side))


func can_garrison(unit):
	return (
		hp > 0
		and unit.hp > 0
		and InfantryRoster.is_infantry(unit.type)
		and not unit.player.is_allied_with(captured_by)
		and (not is_instance_valid(_capturer) or _capturer.player.is_allied_with(unit.player))
	)


func capture_busy(unit):
	return is_instance_valid(_capturer) and _capturer != unit


func show_capture(unit, elapsed):
	_capturer = unit
	candidate = unit.player
	progress = elapsed
	_capture_indicator.display(elapsed, capture_duration(), unit.player.color)
	_update_presentation()


func clear_capture(unit):
	if _capturer == unit:
		_capturer = null
		candidate = null
		progress = 0.0
		_capture_indicator.hide()
		_update_presentation()


func enter(unit):
	if not can_garrison(unit):
		return false
	captured_by = unit.player
	clear_capture(unit)
	_match.battlefield.invalidate()
	captured.emit(captured_by)
	_update_presentation()
	return true


func leave(_unit):
	pass


func capture_side():
	return candidate


func capture_status(viewer):
	if hp <= 0:
		return tr("Destroyed")
	if candidate != null:
		return tr("Capturing · %d / %d s") % [floori(progress), int(capture_duration())]
	if captured_by != null and viewer != null and viewer.is_allied_with(captured_by):
		return tr("Secured")
	return tr("Enemy owned") if captured_by != null else tr("Unclaimed")


func force_attack_only():
	return true


func combat_domain():
	return movement_domain


func receive_weapon_hit(source):
	_take_damage(Rules.damage(source, self))


func receive_shot(shot, _point = null, share = 1.0, _weapon = {}):
	_take_damage(Rules.damage_from(shot, self) * share)


func _take_damage(amount):
	if amount <= 0 or hp <= 0:
		return
	last_enemy_damage_time = _match.simulation_time
	hp = maxf(0, hp - amount)
	hp_changed.emit()
	if hp <= 0:
		if is_instance_valid(_capturer):
			clear_capture(_capturer)
		captured_by = null
		candidate = null
		progress = 0.0
		_ownership_changed(null)
		get_node("Geometry").scale.y = 0.15
		collision_layer = 2
		_match.battlefield.invalidate()
		_update_presentation()


func is_constructed():
	return captured_by != null


func service_active():
	return operational()


func service_point(_unit):
	return to_global(Vector3(0, 0, -0.25))


func service_reach():
	return 0.55


func services(unit):
	return (
		unit.global_position_yless.distance_to(service_point(unit) * Vector3(1, 0, 1))
		<= service_reach()
	)


func deck_height(point):
	var local = to_local(point)
	return 0.28 * clampf((1.0 - maxf(absf(local.x) / 1.15, absf(local.z) / 1.25)) / 0.35, 0.0, 1.0)


func operational():
	return hp > 0 and captured_by != null and not contested and capture_side() == null


func income_interval() -> float:
	return 5.0 if kind == "data_relay" else INCOME_INTERVAL


func income_payment():
	return {"refinery": Vector2i(3, 1), "data_relay": Vector2i(0, 2)}.get(kind, Vector2i.ZERO)


func income_status():
	var payment = income_payment()
	if payment == Vector2i.ZERO:
		return tr("Depleted")
	if not operational():
		return tr("Income paused")
	return (
		tr("+%d M / +%d E every %d s · next in %ds")
		% [payment.x, payment.y, int(income_interval()), ceili(income_left)]
	)


func _update_presentation():
	super()
	if candidate != null:
		_label.text = tr(label_title)
	if kind in ["refinery", "data_relay"] and captured_by != null:
		_label.text += "\n" + income_status()


func _physics_process(delta):
	if (
		not _match.is_node_ready()
		or _match.restoring
		or ("finished" in _match and _match.finished)
		or get_tree().paused
	):
		return
	radar_left = maxf(0.0, radar_left - delta)
	if radar_left == 0.0:
		radar_points.clear()
	var previous_owner = captured_by
	if hp <= 0:
		return
	var presence = _capture_presence()
	var defending = captured_by if captured_by != null else candidate
	contested = (
		defending != null
		and presence.infantry.any(func(side): return not defending.is_allied_with(side))
	)
	_update_presentation()
	if machinery != null:
		machinery.advance(delta, operational() and income_payment() != Vector2i.ZERO)
	if previous_owner != captured_by or not operational():
		return
	if kind in ["refinery", "data_relay"]:
		income_left -= delta
		if income_left <= 0.000001:
			var interval = income_interval()
			var deliveries = floori(maxf(0.0, -income_left) / interval) + 1
			income_left += deliveries * interval
			var payment = income_payment() * deliveries
			captured_by.add_resources({"resource_a": payment.x, "resource_b": payment.y})
			if kind == "refinery" and captured_by.has_method("add_logistics"):
				captured_by.add_logistics(2.0 * deliveries)
			if kind == "data_relay":
				_radar_sweep()
			MatchSignals.resources_mined.emit(self, "materials", payment.x)
			MatchSignals.resources_mined.emit(self, "electronics", payment.y)
		_update_presentation()
	elif kind == "mercenary" and not jobs.is_empty():
		jobs[0].left = maxf(0, jobs[0].left - delta)
		if jobs[0].left == 0 and captured_by.population(true) <= Factions.Bastion.POPULATION_LIMIT:
			var unit = load(Factions.Bastion.scene_path(jobs[0].role)).instantiate()
			var point = _spawn_point(unit.radius)
			if not point.is_finite():
				unit.free()
				return
			jobs.pop_front()
			recruitment_changed.emit()
			_match._setup_and_spawn_unit(
				unit, Transform3D(Basis(Vector3.UP, PI), point), captured_by, false
			)
			MatchSignals.unit_production_finished.emit(unit, self)
			if jobs.is_empty():
				_payer = null


func hire(requester, role):
	var gate = load("res://source/match/network/NetworkGate.gd")
	if gate.intercept(
		requester, {"kind": "hire_mercenary", "target": gate.id_for(self), "role": role}
	):
		return true
	if (
		kind != "mercenary"
		or requester != captured_by
		or not operational()
		or role not in Sites.ROLES
	):
		return false
	if (
		jobs.size() >= QUEUE_LIMIT
		or requester.population(true) >= Factions.Bastion.POPULATION_LIMIT
	):
		return false
	var cost = Sites.price(role)
	if not requester.has_resources(cost):
		return false
	requester.subtract_resources(cost)
	_payer = requester
	jobs.append({"role": role, "left": Factions.duration(requester, role), "paid_cost": cost})
	recruitment_changed.emit()
	MatchSignals.unit_production_started.emit(load(Factions.Bastion.scene_path(role)), self)
	return true


func cancel_hire(requester, index = 0):
	var gate = load("res://source/match/network/NetworkGate.gd")
	if gate.intercept(
		requester, {"kind": "cancel_mercenary", "target": gate.id_for(self), "index": index}
	):
		return true
	if index < 0 or index >= jobs.size() or requester != _payer:
		return false
	requester.add_resources(jobs[index].paid_cost)
	jobs.remove_at(index)
	recruitment_changed.emit()
	if jobs.is_empty():
		_payer = null
	return true


func _ownership_changed(side):
	radar_left = 0.0
	radar_points.clear()
	if side != null and kind == "refinery":
		side.add_resources({"resource_a": 50, "resource_b": 25})
	while not jobs.is_empty():
		if is_instance_valid(_payer):
			_payer.add_resources(jobs[0].paid_cost)
		jobs.pop_front()
	_payer = null
	income_left = income_interval()
	recruitment_changed.emit()


func _spawn_point(unit_radius):
	var nav = _match.navigation.get_navigation_map_rid_by_domain(1)
	if NavigationServer3D.map_get_iteration_id(nav) == 0:
		return Vector3.INF
	for ring in [4.5, 5.5, 6.5]:
		for index in 12:
			var angle = index * TAU / 12
			var requested = global_position + Vector3(sin(angle), 0, cos(angle)) * ring
			# Compare on the ground plane: camps on raised tiers stand above y = 0.
			var surface = NavigationServer3D.map_get_closest_point(nav, requested)
			var point = surface * Vector3(1, 0, 1)
			if point.distance_to(requested * Vector3(1, 0, 1)) > .2:
				continue
			var occupied = false
			for unit in (
				get_tree().get_nodes_in_group("units")
				+ get_tree().get_nodes_in_group("resource_units")
			):
				if (
					not unit.is_queued_for_deletion()
					and (
						point.distance_to(unit.global_position_yless)
						< unit.radius + unit_radius + .3
					)
				):
					occupied = true
					break
			if not occupied:
				return surface
	return Vector3.INF


func capture_state(reference):
	return {
		"id": site_id,
		"hp": hp,
		"owner": reference.call(captured_by),
		"candidate": reference.call(candidate),
		"progress": progress,
		"contested": contested,
		"income_left": income_left,
		"stock_a": stock_a,
		"stock_b": stock_b,
		"radar_left": radar_left,
		"radar_points": radar_points.duplicate(),
		"jobs": jobs.duplicate(true)
	}


func restore_state(saved, entities):
	hp = saved.hp
	captured_by = entities.get(saved.owner)
	candidate = entities.get(saved.candidate)
	progress = saved.progress
	contested = saved.contested
	income_left = saved.income_left
	stock_a = saved.stock_a
	stock_b = saved.stock_b
	radar_left = saved.radar_left
	radar_points = saved.radar_points.duplicate()
	jobs = saved.jobs.duplicate(true)
	_payer = captured_by if not jobs.is_empty() else null
	if hp <= 0:
		get_node("Geometry").scale.y = 0.15
		collision_layer = 2
	_update_presentation()


func _recruitment_input(_camera, event, _point, _normal, _shape):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if open_recruitment():
			get_viewport().set_input_as_handled()


func open_recruitment():
	if captured_by != _match._get_human_player():
		return false
	_match.hud.open_camp(self)
	return true


func _radar_sweep():
	radar_points.clear()
	for unit in _match.get_units():
		if (
			unit.hp != null
			and unit.hp > 0
			and unit.movement_speed > 0
			and not unit.has_meta("garrison_host")
			and not captured_by.is_allied_with(unit.player)
		):
			radar_points.append(unit.global_position)
	radar_left = 3.0


func radar_blips(viewer) -> Array:
	return (
		radar_points
		if (
			radar_left > 0
			and operational()
			and viewer != null
			and viewer.is_allied_with(captured_by)
		)
		else []
	)


func can_field_repair(unit) -> bool:
	return (
		kind in ["refinery", "data_relay"]
		and hp < hp_max
		and is_instance_valid(unit)
		and unit.type in ["Worker", "RepairRobot"]
		and (captured_by == null or unit.player.is_allied_with(captured_by))
	)


func repair_ruin(unit) -> bool:
	if not can_field_repair(unit) or unit.player.resource_a < 1:
		return false
	unit.player.resource_a -= 1
	hp = minf(hp_max, hp + 10.0)
	get_node("Geometry").scale.y = 1.0
	collision_layer = 2
	hp_changed.emit()
	_update_presentation()
	return true


func _build_data_relay():
	var geometry = Node3D.new()
	geometry.name = "Geometry"
	add_child(geometry)
	var steel = StandardMaterial3D.new()
	steel.albedo_color = Color("566369")
	steel.metallic = .6
	_lamp = StandardMaterial3D.new()
	_lamp.albedo_color = Color("d0baa0")
	_lamp.emission_enabled = true
	for part in [
		[Vector3(2.7, .25, 2.7), Vector3(0, .13, 0)],
		[Vector3(1.2, 1.6, 1.2), Vector3(0, .95, 0)],
		[Vector3(.22, 2.6, .22), Vector3(0, 2.8, 0)],
		[Vector3(2.0, .2, .65), Vector3(0, 3.7, 0)],
		[Vector3(.12, 1.2, .12), Vector3(-.75, 4.1, 0)],
		[Vector3(.12, 1.2, .12), Vector3(.75, 4.1, 0)],
	]:
		var mesh = MeshInstance3D.new()
		var box = BoxMesh.new()
		box.size = part[0]
		mesh.mesh = box
		mesh.position = part[1]
		mesh.material_override = steel
		geometry.add_child(mesh)
	var panel = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(.9, .32, .1)
	panel.mesh = box
	panel.position = Vector3(0, 1.3, -.66)
	panel.material_override = _lamp
	geometry.add_child(panel)
