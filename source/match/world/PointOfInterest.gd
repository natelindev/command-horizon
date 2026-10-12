extends "res://source/match/objectives/CaptureRelay.gd"

const Sites = preload("res://source/match/world/PointOfInterestCatalog.gd")
const Factions = preload("res://source/match/FactionCatalog.gd")
const CAPTURE_RADIUS = 5.0
const INCOME_INTERVAL = 10.0
const QUEUE_LIMIT = 3
var site_id = ""
var kind = "refinery"
var radius = 2.2
var movement_domain = 1
var movement_speed = 0.0
var attack_range = null
var type:
	get:
		return "RepairDepot" if kind == "repair" else "PointOfInterest"
var global_position_yless:
	get:
		return global_position * Vector3(1, 0, 1)
var jobs = []
var stock_a = 600
var stock_b = 300
var income_left = INCOME_INTERVAL
var _payer = null


func _ready():
	add_to_group("vision_sources")
	add_to_group("points_of_interest")
	_build_model()
	var obstacle = load("res://source/match/units/traits/MovementObstacle.tscn").instantiate()
	obstacle.radius = radius
	obstacle.path_height_offset = .6
	obstacle.affect_navigation_mesh = true
	add_child(obstacle)
	captured.connect(_ownership_changed)


func _build_model():
	var role = {"refinery": "PowerPlant", "mercenary": "Barracks", "repair": "RepairDepot"}[kind]
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
	_label = Label3D.new()
	_label.position = Vector3(0, 5.5, 0)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font = load("res://assets/fonts/NotoSansSC.ttf")
	_label.font_size = 28
	_label.pixel_size = .012
	add_child(_label)
	_update_presentation()


func _capture_presence():
	var infantry = []
	var combatants = []
	if _match == null or _match.battlefield == null:
		return {"infantry": infantry, "combatants": combatants}
	for unit in _match.battlefield.nearby_units(global_position, CAPTURE_RADIUS):
		if unit.hp <= 0 or unit.is_queued_for_deletion() or unit.movement_domain != 1:
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
	return tr(
		(
			"Infantry within 5 m capture in 10 seconds. "
			+ "Opposing ground combatants pause capture and services."
		)
	)


func is_constructed():
	return captured_by != null


func service_active():
	return operational()


func operational():
	return captured_by != null and not contested and capture_side() == null


func _physics_process(delta):
	if not _match.is_node_ready() or _match.restoring or _match.finished or get_tree().paused:
		return
	var previous_owner = captured_by
	super(delta)
	if previous_owner != captured_by or not operational():
		return
	if kind == "refinery":
		income_left -= delta
		if income_left <= 0:
			var deliveries = floori(-income_left / INCOME_INTERVAL) + 1
			income_left += deliveries * INCOME_INTERVAL
			var materials = mini(2 * deliveries, stock_a)
			var electronics = mini(deliveries, stock_b)
			stock_a -= materials
			stock_b -= electronics
			captured_by.add_resources({"resource_a": materials, "resource_b": electronics})
			MatchSignals.resources_mined.emit(self, "materials", materials)
			MatchSignals.resources_mined.emit(self, "electronics", electronics)
	elif kind == "mercenary" and not jobs.is_empty():
		jobs[0].left = maxf(0, jobs[0].left - delta)
		if jobs[0].left == 0 and captured_by.population(true) <= Factions.Bastion.POPULATION_LIMIT:
			var unit = load(Factions.Bastion.scene_path(jobs[0].role)).instantiate()
			var point = _spawn_point(unit.radius)
			if not point.is_finite():
				unit.free()
				return
			jobs.pop_front()
			_match._setup_and_spawn_unit(
				unit, Transform3D(Basis(Vector3.UP, PI), point), captured_by, false
			)
			MatchSignals.unit_production_finished.emit(unit, self)
			if jobs.is_empty():
				_payer = null


func hire(requester, role):
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
	var cost = Sites.price(requester.faction, role)
	if not requester.has_resources(cost):
		return false
	requester.subtract_resources(cost)
	_payer = requester
	jobs.append({"role": role, "left": Factions.duration(requester, role), "paid_cost": cost})
	MatchSignals.unit_production_started.emit(load(Factions.Bastion.scene_path(role)), self)
	return true


func cancel_hire(requester):
	if jobs.is_empty() or requester != _payer:
		return false
	requester.add_resources(jobs.pop_front().paid_cost)
	if jobs.is_empty():
		_payer = null
	return true


func _ownership_changed(_side):
	while not jobs.is_empty():
		if is_instance_valid(_payer):
			_payer.add_resources(jobs[0].paid_cost)
		jobs.pop_front()
	_payer = null
	income_left = INCOME_INTERVAL


func _spawn_point(unit_radius):
	var nav = _match.navigation.get_navigation_map_rid_by_domain(1)
	if NavigationServer3D.map_get_iteration_id(nav) == 0:
		return Vector3.INF
	for ring in [4.5, 5.5, 6.5]:
		for index in 12:
			var angle = index * TAU / 12
			var requested = global_position + Vector3(sin(angle), 0, cos(angle)) * ring
			var point = NavigationServer3D.map_get_closest_point(nav, requested) * Vector3(1, 0, 1)
			if point.distance_to(requested) > .2:
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
				return point
	return Vector3.INF


func capture_state(reference):
	return {
		"id": site_id,
		"owner": reference.call(captured_by),
		"candidate": reference.call(candidate),
		"progress": progress,
		"contested": contested,
		"income_left": income_left,
		"stock_a": stock_a,
		"stock_b": stock_b,
		"jobs": jobs.duplicate(true)
	}


func restore_state(saved, entities):
	captured_by = entities.get(saved.owner)
	candidate = entities.get(saved.candidate)
	progress = saved.progress
	contested = saved.contested
	income_left = saved.income_left
	stock_a = saved.stock_a
	stock_b = saved.stock_b
	jobs = saved.jobs.duplicate(true)
	_payer = captured_by if not jobs.is_empty() else null
	_update_presentation()
