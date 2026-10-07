extends "res://tests/rendered/ProgramPreview.gd"


func _run():
	root.mode = Window.MODE_WINDOWED
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.size = Vector2i(1440, 900)
	root.content_scale_size = root.size
	var settings = load("res://source/data-model/MatchSettings.gd").new()
	settings.skirmish = true
	settings.advanced_start = true
	settings.map_path = "res://source/match/maps/BastionDesert.tscn"
	for side in range(2):
		var player = load("res://source/data-model/PlayerSettings.gd").new()
		player.controller = (
			root.get_node("Constants").PlayerType.HUMAN
			if side == 0
			else root.get_node("Constants").PlayerType.SIMPLE_CLAIRVOYANT_AI
		)
		player.faction = "bastion" if side == 0 else "helix"
		player.color = Color("e3ad48") if side == 0 else Color("38c8ce")
		settings.players.append(player)
	_game = load("res://source/match/Skirmish.tscn").instantiate()
	_game.settings = settings
	_game.map = load(settings.map_path).instantiate()
	root.add_child(_game)
	current_scene = _game
	get_nodes_in_group("players")[1].set_process(false)
	var camera = _game.get_node("IsometricCamera3D")
	camera.set_physics_process(false)
	camera.set_size_safely(9)
	camera.set_position_safely(Vector3(11, 0, 26))
	await _frames(50)
	var human = _game._get_human_player()
	var bar = _game.find_child("ResourcesBar")
	_check(bar.player == human, "Power meter bound to the wrong player")
	_check("available" in bar._power_status.text, "Healthy power has no available amount")
	_check(bar._power_meter.max_value == human.power_totals().x, "Wrong power capacity")
	for resource in get_nodes_in_group("resource_units"):
		_check(is_equal_approx(resource.radius, 0.6), "Salvage changed navigation footprint")
		_check(resource.get_node("Geometry").get_child_count() == 1, "Duplicate salvage meshes")
	await _capture("resource-salvage")
	camera.set_size_safely(16)
	camera.set_position_safely(Vector3(16, 0, 22))
	await _capture("resource-power-gameplay")
	var drains = []
	var aircraft_factory = load("res://source/match/units/AircraftFactory.tscn")
	for index in range(3):
		var unit = aircraft_factory.instantiate()
		_game._setup_and_spawn_unit(
			unit, Transform3D(Basis(), Vector3(45 + index * 2, 0, 15)), human, false
		)
		drains.append(unit)
	await _frames(40)
	_check("build power soon" in bar._power_status.text, "No near-capacity advisory")
	_check(human.production_factor() == 1.0, "Near capacity should not slow production")
	for index in range(2):
		var unit = load("res://source/match/units/AntiGroundTurret.tscn").instantiate()
		_game._setup_and_spawn_unit(
			unit, Transform3D(Basis(), Vector3(45 + index * 2, 0, 19)), human, false
		)
		drains.append(unit)
	await _frames(40)
	_check("At capacity" in bar._power_status.text, "No exact-capacity advisory")
	_check(human.production_factor() == 1.0, "Exact capacity should not slow production")
	await _capture("resource-power-capacity")
	var extra = aircraft_factory.instantiate()
	_game._setup_and_spawn_unit(extra, Transform3D(Basis(), Vector3(51, 0, 15)), human, false)
	drains.append(extra)
	await _frames(40)
	_check("LOW POWER" in bar._power_status.text, "No shortage warning")
	_check("35%" in bar._power_status.text, "Missing slowdown consequence")
	_check(bar._power_meter.value == bar._power_meter.max_value, "Deficit meter not full")
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	_game.hud._toggle_pause()
	await _frames(8)
	await _capture("resource-power-shortage-720p")
	_check(bar.get_global_rect().end.x < 1000, "Header collides with right-side controls")
	_check(bar.get_global_rect().end.y <= 62, "Header overlaps objectives")
	_game.hud._toggle_pause()
	for unit in drains:
		unit.queue_free()
	await _frames(40)
	_check("available" in bar._power_status.text, "Power warning did not recover")
	# No producer/no consumer and no producer/with demand are both bounded states.
	for unit in human.get_children():
		if "type" in unit and unit.has_method("is_constructed"):
			unit.queue_free()
	await _frames(3)
	bar._refresh()
	_check(bar._power_meter.max_value >= 1, "Zero power capacity invalidated meter")
	_check("No generation" in bar._power_status.text, "Zero power state unclear")
	var factory = load("res://source/match/units/VehicleFactory.tscn").instantiate()
	_game._setup_and_spawn_unit(factory, Transform3D(Basis(), Vector3(15, 0, 15)), human, false)
	await _frames(3)
	bar._refresh()
	_check("LOW POWER" in bar._power_status.text, "Zero-supply deficit invisible")
	_check(bar._power_meter.value == 1, "Zero-supply warning meter invisible")
	# Rebinding follows the second faction and does not leave the first player's signal attached.
	var enemy = get_nodes_in_group("players")[1]
	bar.setup(enemy)
	_check(not human.changed.is_connected(bar._refresh), "Old power HUD binding survived")
	_check(bar._power_meter.max_value == enemy.power_totals().x, "Helix power supply mismatch")
	bar.setup(human)
	await _asset_gallery(camera)
	_game.queue_free()
	await _frames(8)
	for message in _errors:
		push_error(message)
	if _errors.is_empty():
		print(
			(
				"PASS: six salvage assets; both-faction power, near/exact capacity; "
				+ "deficit/recovery/zero supply; 720p HUD"
			)
		)
	quit(0 if _errors.is_empty() else 1)


func _asset_gallery(camera):
	_game.get_node("HUD").hide()
	_game.hud.hide()
	_game.fog_of_war.reveal()
	for unit in get_nodes_in_group("units"):
		unit.queue_free()
	for resource in get_nodes_in_group("resource_units"):
		resource.queue_free()
	await _frames(3)
	var salvage = load("res://source/match/units/non-player/ResourceUnit.gd")
	var gallery = Node3D.new()
	_game.add_child(gallery)
	for kind in ["materials", "electronics"]:
		for variant in range(3):
			var model = salvage.SALVAGE_MODELS[kind][variant].instantiate()
			gallery.add_child(model)
			model.position = Vector3(8 + variant * 3, 0, 27 if kind == "materials" else 30)
			model.rotation.y = -0.35
			_verify_mesh(model, model)
			var label = Label3D.new()
			label.text = (
				["BEAM STOCK", "ARMOR WRECK", "STEEL COIL"][variant]
				if kind == "materials"
				else ["SERVER CACHE", "RELAY WRECK", "CAPACITOR PACK"][variant]
			)
			label.font_size = 32
			label.pixel_size = 0.004
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			label.modulate = Color("d6ab64") if kind == "materials" else Color("65cdd8")
			gallery.add_child(label)
			label.position = model.position + Vector3(0, 0.05, 0.85)
	camera.set_size_safely(8)
	camera.set_position_safely(Vector3(11, 0, 28.5))
	# The gallery is review-only geometry, with the real map lighting and camera.
	root.size = Vector2i(1440, 900)
	root.content_scale_size = root.size
	await _capture("resource-six-designs")
	gallery.queue_free()


func _verify_mesh(node, model):
	if node is MeshInstance3D:
		var transform = model.global_transform.affine_inverse() * node.global_transform
		var mesh = node.mesh
		for surface in range(mesh.get_surface_count()):
			for vertex in mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				var point = transform * vertex
				_check(
					Vector2(point.x, point.z).length() < 0.6, "Salvage exceeds navigation radius"
				)
				_check(point.y >= -0.001 and point.y <= 0.8, "Salvage exceeds vertical bounds")
	for child in node.get_children():
		_verify_mesh(child, model)
