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
var canister_left = 60.0
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
var _site_rotor: Node3D = null
var _site_halo: MeshInstance3D = null
var _site_halo_mat: StandardMaterial3D = null
var _site_anim_phase = 0.0
var _payout_flash = 0.0


func _ready():
	hp = hp_max
	sight_range = 22.0 if kind == "data_relay" else 9.0
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
	var circle_scene = load("res://source/generic-scenes-and-nodes/3d/Circle3D.tscn")
	_capture_ring = circle_scene.instantiate()
	_capture_ring.radius = CAPTURE_RADIUS
	_capture_ring.width = 0.08
	_capture_ring.position = Vector3(0, 0.06, 0)
	add_child(_capture_ring)
	if kind == "data_relay":
		_vision_ring = circle_scene.instantiate()
		_vision_ring.radius = sight_range
		_vision_ring.width = 0.05
		_vision_ring.position = Vector3(0, 0.05, 0)
		_vision_ring.visible = false
		add_child(_vision_ring)
	_label = Label3D.new()
	_label.position = Vector3(
		0, 6.4 if kind == "refinery" else 6.1 if kind == "data_relay" else 4.4, 0
	)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.render_priority = 12
	_label.outline_render_priority = 11
	_label.font = load("res://assets/fonts/NotoSansSC.ttf")
	_label.font_size = 26
	_label.outline_size = 10
	_label.outline_modulate = Color("0b1318")
	_label.modulate = Color("f2ecd8")
	_label.pixel_size = .011
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
	_site_halo_mat = StandardMaterial3D.new()
	_site_halo_mat.emission_enabled = true
	_site_halo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_site_halo = MeshInstance3D.new()
	var torus = TorusMesh.new()
	torus.inner_radius = 2.25
	torus.outer_radius = 2.38
	_site_halo.mesh = torus
	_site_halo.position = Vector3(0, 0.10, 0)
	_site_halo.material_override = _site_halo_mat
	add_child(_site_halo)


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
	_site_rotor = Node3D.new()
	_site_rotor.name = "FacilityAntenna"
	_site_rotor.position = Vector3(0.55, 2.35 if kind == "mercenary" else 2.55, 0)
	add_child(_site_rotor)
	var steel = StandardMaterial3D.new()
	steel.albedo_color = Color("46525a")
	steel.metallic = 0.65
	_box_into(_site_rotor, Vector3(0.10, 0.55, 0.10), Vector3(0, 0.25, 0), steel)
	_box_into(_site_rotor, Vector3(0.85, 0.18, 0.18), Vector3(0, 0.52, 0), steel)
	_box_into(_site_rotor, Vector3(0.24, 0.10, 0.24), Vector3(0, 0.64, 0), _lamp)
	_site_halo_mat = StandardMaterial3D.new()
	_site_halo_mat.emission_enabled = true
	_site_halo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_site_halo = MeshInstance3D.new()
	var torus = TorusMesh.new()
	torus.inner_radius = 2.05
	torus.outer_radius = 2.18
	_site_halo.mesh = torus
	_site_halo.position = Vector3(0, 0.10, 0)
	_site_halo.material_override = _site_halo_mat
	add_child(_site_halo)


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
	return {"refinery": Vector2i(2, 1), "data_relay": Vector2i(0, 0)}.get(kind, Vector2i.ZERO)


func income_status():
	if kind == "data_relay":
		if not operational():
			return tr("Relay paused")
		return tr("Core drop in %ds · Radar sweep") % ceili(canister_left)
	var payment = income_payment()
	if payment == Vector2i.ZERO:
		return tr("Depleted")
	if not operational():
		return tr("Income paused")
	return (
		tr("+%d M / +%d R every %d s · Catalyst +20%%")
		% [payment.x, payment.y, int(income_interval())]
	)


func _update_presentation():
	super()
	if candidate != null:
		_label.text = tr(label_title)
	if kind in ["refinery", "data_relay"] and captured_by != null:
		_label.text += "\n" + income_status()
	if _site_halo_mat != null:
		var base = captured_by.color if captured_by != null else Color("d0baa0")
		_site_halo_mat.albedo_color = Color(
			base.r, base.g, base.b, 0.55 if captured_by != null else 0.25
		)
		_site_halo_mat.emission = base * (0.95 if operational() else 0.25)


func _animate_facility(delta: float):
	if hp <= 0:
		return
	var active = operational()
	var speed = 2.1 if active else 0.55
	if kind == "mercenary" and not jobs.is_empty():
		speed = 3.6
	_site_anim_phase = fmod(_site_anim_phase + delta * speed, TAU)
	_payout_flash = maxf(0.0, _payout_flash - delta * 2.2)
	if is_instance_valid(_site_rotor):
		_site_rotor.rotation.y = _site_anim_phase
	if is_instance_valid(_site_halo):
		var pulse = 1.0 + 0.045 * sin(_site_anim_phase * 2.0) + _payout_flash * 0.12
		_site_halo.scale = Vector3(pulse, 1.0, pulse)
		if _site_halo_mat != null:
			var base = captured_by.color if captured_by != null else Color("d0baa0")
			_site_halo_mat.emission = base * ((0.95 if active else 0.25) + _payout_flash * 1.4)


func _physics_process(delta):
	if (
		_match == null
		or not _match.is_node_ready()
		or _match.restoring
		or ("finished" in _match and _match.finished)
		or get_tree().paused
	):
		return
	_animate_facility(delta)
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
			_payout_flash = 1.0
			if payment.x > 0:
				MatchSignals.resources_mined.emit(self, "materials", payment.x)
			if payment.y > 0:
				MatchSignals.resources_mined.emit(self, "electronics", payment.y)
		if kind == "data_relay":
			canister_left = maxf(0.0, canister_left - delta)
			if canister_left <= 0.000001:
				var profile = load("res://source/match/economy/RefiningProfile.gd")
				canister_left = profile.RELAY_CANISTER_INTERVAL
				if _match != null and _match.refining_manager != null:
					var drop = global_position + Vector3(0.0, 0.0, radius + 1.5)
					_match.refining_manager.spawn_canisters(
						drop, profile.RELAY_CANISTER_REFINED, captured_by, false
					)
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
	_payout_flash = 1.0 if side != null else 0.0
	if side != null and kind == "refinery":
		side.add_resources({"resource_a": 25, "resource_b": 15})
	canister_left = 60.0
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
		"canister_left": canister_left,
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
	canister_left = float(saved.get("canister_left", 60.0))
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
	var concrete = StandardMaterial3D.new()
	concrete.albedo_color = Color("646862")
	concrete.roughness = 0.85
	var steel = StandardMaterial3D.new()
	steel.albedo_color = Color("4c5960")
	steel.metallic = 0.65
	steel.roughness = 0.42
	var dish_mat = StandardMaterial3D.new()
	dish_mat.albedo_color = Color("d8dde0")
	dish_mat.metallic = 0.35
	dish_mat.roughness = 0.3
	_lamp = StandardMaterial3D.new()
	_lamp.albedo_color = Color("d0baa0")
	_lamp.emission_enabled = true
	_site_halo_mat = StandardMaterial3D.new()
	_site_halo_mat.emission_enabled = true
	_site_halo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# Stepped octagonal foundation, armored transceiver core, and braced spire.
	_cyl_into(geometry, 1.85, 0.22, Vector3(0, 0.11, 0), concrete, 8)
	_cyl_into(geometry, 1.35, 0.24, Vector3(0, 0.34, 0), steel, 8)
	_box_into(geometry, Vector3(1.45, 1.35, 1.45), Vector3(0, 1.12, 0), steel)
	_cyl_into(geometry, 0.32, 2.3, Vector3(0, 2.75, 0), steel, 8)
	_cyl_into(geometry, 0.78, 0.18, Vector3(0, 1.95, 0), _lamp, 12)
	for angle in [0.0, PI * 0.5, PI, PI * 1.5]:
		var strut = _box_into(
			geometry,
			Vector3(0.14, 1.65, 0.14),
			Vector3(cos(angle) * 0.72, 1.75, sin(angle) * 0.72),
			steel
		)
		strut.rotation.z = cos(angle) * 0.38
		strut.rotation.x = -sin(angle) * 0.38
	for z_side in [-0.74, 0.74]:
		_box_into(geometry, Vector3(1.05, 0.34, 0.08), Vector3(0, 1.25, z_side), _lamp)
	# Rotating phased-array radar dish assembly on top.
	_site_rotor = Node3D.new()
	_site_rotor.name = "RelayDishPivot"
	_site_rotor.position = Vector3(0, 3.85, 0)
	geometry.add_child(_site_rotor)
	_box_into(_site_rotor, Vector3(2.2, 0.26, 0.55), Vector3(0, 0, 0), dish_mat)
	_box_into(_site_rotor, Vector3(2.28, 0.10, 0.62), Vector3(0, 0, 0), _lamp)
	_box_into(_site_rotor, Vector3(1.55, 0.85, 0.16), Vector3(0, 0.42, -0.22), dish_mat)
	_box_into(_site_rotor, Vector3(0.20, 0.95, 0.20), Vector3(0, 0.45, 0.12), steel)
	for x in [-0.88, 0.88]:
		_box_into(_site_rotor, Vector3(0.10, 1.05, 0.10), Vector3(x, 0.52, 0), steel)
	_site_halo = MeshInstance3D.new()
	var torus = TorusMesh.new()
	torus.inner_radius = 0.62
	torus.outer_radius = 0.74
	_site_halo.mesh = torus
	_site_halo.position = Vector3(0, 4.55, 0)
	_site_halo.material_override = _site_halo_mat
	geometry.add_child(_site_halo)


func _cyl_into(parent, radius_val, height_val, point, material, sides = 12):
	var node = MeshInstance3D.new()
	var mesh = CylinderMesh.new()
	mesh.top_radius = radius_val
	mesh.bottom_radius = radius_val
	mesh.height = height_val
	mesh.radial_segments = sides
	node.mesh = mesh
	node.position = point
	node.material_override = material
	parent.add_child(node)
	return node
