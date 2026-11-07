extends "res://tests/rendered/ImpactEffectsPreview.gd"

var _actors = []
var _props = []
var _human
var _helix
var _camera_node


func _run():
	if DisplayServer.get_name() == "headless":
		push_error("WorldFeedbackPreview requires a graphical renderer")
		quit(1)
		return
	_output = "res://art/world-feedback/" + RenderingServer.get_current_rendering_method() + "/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_output))
	Engine.max_fps = 60
	var options = root.get_node("Globals").options
	var original = options.capture()
	options.restore(
		{
			"screen": 1,
			"edge_scrolling": false,
			"day_cycle": false,
			"weather": 1,
			"time_of_day": 0,
			"graphics_dof": false,
			"graphics_clouds": false,
			"graphics_dust": false,
			"graphics_fog": false,
			"living_world": false,
			"battlefield_wear": true,
			"graphics_ground_detail": true,
			"reduced_flashes": false
		}
	)
	root.get_node("SaveManager").autosaves_enabled = false
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1440, 900)
	root.content_scale_size = root.size
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	var logger = RenderErrorLog.new()
	OS.add_logger(logger)
	_setup_match()
	_human = game._get_human_player()
	_helix = get_nodes_in_group("players").filter(func(side): return side != _human)[0]
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	for unit in game.get_units():
		unit.process_mode = Node.PROCESS_MODE_DISABLED
		unit.hide()
	for layer in game.find_children("*", "CanvasLayer", true, false):
		layer.hide()
	game.settings.visibility = game.settings.Visibility.FULL
	game.fog_of_war.reveal()
	game.fog_of_war._screen_overlay.hide()
	var terrain = game.map.get_node("Geometry/Terrain")
	# Isolate VFX on a neutral floor, including on Mac GL's limited sampler budget.
	var floor_material = StandardMaterial3D.new()
	floor_material.albedo_color = Color("49575d")
	floor_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	floor_material.roughness = .9
	terrain.material_override = floor_material
	for mesh in game.map.find_children("*", "GeometryInstance3D", true, false):
		if mesh != terrain:
			mesh.hide()
	_camera_node = game.get_node("IsometricCamera3D")
	_camera_node.set_physics_process(false)
	_camera_node.set_size_safely(24)
	_camera_node.set_position_safely(ORIGIN + Vector3(0, .8, 1))
	await _frames(12)
	# Keep grading and deferred map decorations out of the renderer comparison.
	var environment = game.get_node("WorldEnvironment").environment
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.tonemap_exposure = 1.0
	environment.adjustment_enabled = false
	environment.fog_enabled = false
	environment.volumetric_fog_enabled = false
	for mesh in game.map.find_children("*", "GeometryInstance3D", true, false):
		if mesh != terrain:
			mesh.hide()
	await _abilities_gallery()
	await _clear_gallery()
	await _ground_gallery()
	await _clear_gallery()
	for faction in ["bastion", "helix", "frontier"]:
		await _building_gallery(faction)
		await _clear_gallery()
	game.queue_free()
	await _frames(5)
	options.restore(original)
	OS.remove_logger(logger)
	errors.append_array(logger.messages)
	for message in errors:
		push_error(message)
	print(
		(
			"World feedback preview (%s): %d failures"
			% [RenderingServer.get_current_rendering_method(), errors.size()]
		)
	)
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)


func _actor(role, side, offset, foundation = false):
	var catalog = load("res://source/match/FactionCatalog.gd")
	var unit = load(catalog.scene_path(side.faction, role)).instantiate()
	game._setup_and_spawn_unit(unit, Transform3D(Basis(), ORIGIN + offset), side, foundation)
	unit.process_mode = Node.PROCESS_MODE_DISABLED
	_actors.append(unit)
	for path in ["Highlight", "Selection", "TeamFootprint", "HealthBar"]:
		var decoration = unit.get_node_or_null(path)
		if decoration != null:
			decoration.hide()
	return unit


func _setup_match():
	var settings = load("res://source/data-model/MatchSettings.gd").new()
	settings.skirmish = true
	settings.visibility = settings.Visibility.FULL
	settings.map_path = "res://source/match/maps/IndustrialCrossroads.tscn"
	for index in 2:
		var side = load("res://source/data-model/PlayerSettings.gd").new()
		side.controller = index + 1
		side.faction = "bastion" if index == 0 else "helix"
		settings.players.append(side)
	game = load("res://source/match/Skirmish.tscn").instantiate()
	game.settings = settings
	game.map = load(settings.map_path).instantiate()
	var map_size = game.map.size
	game.map.set_script(load("res://tests/rendered/WorldFeedbackMap.gd"))
	game.map.size = map_size
	root.add_child(game)
	current_scene = game


func _label(text, at):
	var label = Label3D.new()
	label.text = text
	label.font_size = 34
	label.pixel_size = .01
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color("edf7f6")
	label.no_depth_test = true
	game.add_child(label)
	label.position = ORIGIN + at
	_props.append(label)


func _abilities_gallery():
	var blink = _actor("CombatRobot", _helix, Vector3(-6, 0, -4))
	var shield = _actor("Tank", _helix, Vector3(3, 0, -4))
	var sniper = _actor("SniperInfantry", _helix, Vector3(7, 0, -4))
	var drone = _actor("Drone", _helix, Vector3(-5, 1.8, 4))
	var factory = _actor("VehicleFactory", _helix, Vector3(3, 0, 4))
	_label("PHASE SHIFT", Vector3(-4, .1, -1.5))
	_label("SHIELD", Vector3(3, .1, -1.5))
	_label("CLOAK", Vector3(7, .1, -1.5))
	_label("GUIDANCE CHAFF", Vector3(-5, .1, 6.5))
	_label("FLUX RESONANCE", Vector3(3, .1, 7))
	await _frames(8)
	drone.global_position = ORIGIN + Vector3(-5, 1.8, 4)
	drone.get_node("Geometry").global_transform = drone.global_transform
	drone.reset_physics_interpolation()
	var baseline = await _impact_capture("abilities-baseline")
	var origin = blink.global_position
	blink.get_node("Movement").relocate(origin + Vector3(4, 0, 0))
	game.combat_effects.phase_shift(origin, blink.global_position, _helix, blink)
	blink.get_node("Geometry").global_transform = blink.global_transform
	shield.shield_component.absorb(shield.shields_max, game.simulation_time)
	sniper.optical_cloak.concealed = true
	sniper.get_node("OpticalCloakVisual").refresh(.35)
	_helix.production_boosts.append({"target": weakref(factory), "left": 25.0})
	drone.abilities.restore(
		{"drone_chaff": {"is_active": true, "active_left": 8.0, "cooldown_left": 30.0}}
	)
	for frame in 48:
		await _frames(1)
		if frame in [5, 17, 35]:
			var capture = await _impact_capture("abilities-%02d" % frame)
			_check(_changed_pixels(baseline, capture) > 300, "Ability gallery is visually empty")
			var before = baseline.get_pixel(10, 10)
			var after = capture.get_pixel(10, 10)
			_check(
				(
					Vector3(before.r, before.g, before.b).distance_to(
						Vector3(after.r, after.g, after.b)
					)
					< .03
				),
				"Ability/ground feedback changed the untouched background"
			)
	shield.shield_component.tick(.1, game.simulation_time + 6)
	await _frames(25)
	await _impact_capture("shield-recharging")
	shield.shield_component.tick(10, game.simulation_time + 20)
	await _frames(8)
	await _impact_capture("shield-restored")
	root.get_node("Globals").options.reduced_flashes = true
	game.combat_effects.phase_shift(origin, blink.global_position, _helix)
	sniper.get_node("OpticalCloakVisual").refresh(.1)
	await _frames(10)
	await _impact_capture("abilities-reduced-flashes")
	_check(game.combat_effects._phase_remnants.is_empty(), "Reduced flashes retained blink shells")
	root.get_node("Globals").options.reduced_flashes = false
	_helix.production_boosts.clear()


func _ground_gallery():
	_camera_node.set_size_safely(23)
	_human.faction = "frontier"
	var truck = _actor("SupplyTruck", _human, Vector3(4, 0, -4))
	var hover = _actor("AdvancedTank", _helix, Vector3(4, 0, 4))
	_label("WATER GEYSER", Vector3(-4, .1, -1))
	_label("TIRES / EXHAUST", Vector3(4, .1, -1))
	_label("REPULSOR WASH", Vector3(4, .1, 7))
	_label("INDUSTRIAL OVERHAUL", Vector3(-5, .1, 7))
	var water = MeshInstance3D.new()
	water.mesh = PlaneMesh.new()
	water.mesh.size = Vector2(6, 6)
	var finish = StandardMaterial3D.new()
	finish.albedo_color = Color("32788a")
	finish.metallic = .3
	finish.roughness = .2
	water.material_override = finish
	game.add_child(water)
	water.position = ORIGIN + Vector3(-4, .03, -4)
	_props.append(water)
	var field = load("res://source/match/maps/terrain/WaterFlowField.gd").new()
	var center = Vector2(water.position.x, water.position.z)
	field.waters = [
		{
			"polygon":
			PackedVector2Array(
				[
					center + Vector2(-3, -3),
					center + Vector2(3, -3),
					center + Vector2(3, 3),
					center + Vector2(-3, 3)
				]
			),
			"level": .33
		}
	]
	var old_field = game.map.water_flow
	game.map.water_flow = field
	await _frames(6)
	game.combat_effects._explosion(water.position, 2.2, true, true)
	var aura = load("res://source/match/effects/AbilityAura.gd").new()
	game.add_child(aura)
	aura.setup("overhaul", 3.1, null, game.map)
	aura.position = ORIGIN + Vector3(-5, 0, 4)
	_props.append(aura)
	truck.hp = truck.hp_max * .24
	for frame in 95:
		truck.position.z += .035
		truck.get_node("Geometry").global_transform = truck.global_transform
		truck.get_node("BastionVisuals")._advance_pose(1.0 / 60.0)
		aura.advance(float(frame) / 60.0, false)
		game.battlefield_wear.sample_vehicle(truck)
		if frame % 14 == 0:
			game.combat_effects.movement_dust(hover)
			game.combat_effects.movement_dust(truck)
		if frame == 10:
			game.combat_effects.vehicle_backfire(
				truck, truck.get_node("BastionVisuals").damage_emission_point()
			)
		await _frames(1)
		if frame in [12, 28, 55, 90]:
			await _impact_capture("ground-%02d" % frame)
	game.map.water_flow = old_field


func _building_gallery(faction):
	_human.faction = faction
	_human.resource_a = 10000
	_human.resource_b = 10000
	_camera_node.set_size_safely(14)
	_camera_node.set_position_safely(ORIGIN + Vector3(0, .8, .5))
	var building = _actor("PowerPlant", _human, Vector3(-3.5, 0, 0), true)
	_label(faction.to_upper() + " / COMPLETE", Vector3(-3.5, .1, 3))
	_label("PLACEMENT HOLOGRAM", Vector3(3.5, .1, 3))
	await _frames(5)
	var handler = _human.get_node("StructurePlacementHandler")
	handler._start_structure_placement(load("res://source/match/units/PowerPlant.tscn"))
	handler._active_blueprint_node.global_position = ORIGIN + Vector3(3.5, 0, 0)
	handler._update_blueprint_color(true)
	handler._feedback.hide()
	await _impact_capture(faction + "-blueprint")
	building.construct(1.0)
	for frame in 42:
		await _frames(1)
		if frame in [7, 22, 40]:
			await _impact_capture(faction + "-completion-%02d" % frame)
	handler._update_blueprint_color(false)
	await _impact_capture(faction + "-invalid-blueprint")
	handler._cancel_structure_placement()


func _clear_gallery():
	for actor in _actors:
		if is_instance_valid(actor):
			actor.queue_free()
	for prop in _props:
		if is_instance_valid(prop):
			prop.queue_free()
	_actors.clear()
	_props.clear()
	game.combat_effects.world_abilities.clear()
	await _frames(135)
