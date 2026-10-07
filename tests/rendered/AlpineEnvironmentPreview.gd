extends "res://tests/headless/AlpineRegression.gd"

var deadline = 0
var options
var initial_options


func _initialize():
	Engine.max_fps = 60
	deadline = Time.get_ticks_msec() + 210000
	_run.call_deferred()


func _process(_delta):
	if Time.get_ticks_msec() > deadline:
		push_error("Alpine environment preview timed out")
		quit(1)
	return false


func _run():
	options = root.get_node("Globals").options
	initial_options = options.capture()
	options.restore({"screen": 1, "interface_scale": 1.5, "edge_scrolling": false})
	await create_timer(2.0).timeout
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(1920, 1080)
	var saves = root.get_node("SaveManager")
	var autosaves = saves.autosaves_enabled
	saves.autosaves_enabled = false
	for faction in ["bastion", "helix"]:
		await _skirmish(faction, ALPINE)
		_enemy().set_process(false)
		_set_colors(faction)
		game.hud._toggle_pause()
		var camera = game.get_node("IsometricCamera3D")
		camera.size_max = 200
		camera.set_size_safely(34)
		camera.set_position_safely(Vector3(21, 0, 24))
		await _shot("alpine-home-fog-" + faction)
		_check(
			not game.battlefield.is_observed(
				game._get_human_player(), _units(_enemy(), "CommandCenter")[0]
			),
			"Backdrop revealed enemy base"
		)
		camera.set_position_safely(_units(_enemy(), "CommandCenter")[0].position)
		await _shot("alpine-hidden-base-" + faction)
		var hidden_frame = root.get_texture().get_image()
		var middle = hidden_frame.get_size() / 2
		_check(
			hidden_frame.get_pixel(middle.x, middle.y).get_luminance() < 0.01,
			"Exterior scenery exposed pixels inside the hidden enemy base"
		)
		await _combat(faction)
		await _relay_review(faction)
		game.fog_of_war.reveal()
		camera.set_size_safely(142)
		camera.set_position_safely(Vector3(64, 0, 52))
		await _shot("alpine-overview-" + faction)
		camera.set_size_safely(30)
		camera.set_position_safely(Vector3(64, 0, 51))
		await _shot("alpine-shelves-" + faction)
		camera.set_size_safely(28)
		camera.set_position_safely(Vector3(1, 0, 26))
		await _shot("alpine-boundary-" + faction)
		game.hud.hide()
		game.subtitles.hide()
		var bounds = camera.bounding_planes.duplicate()
		camera.bounding_planes.clear()
		camera.set_position_safely(Vector3(89, 0, -12))
		await _shot("alpine-weather-station-" + faction)
		camera.bounding_planes = bounds
		game.hud.show()
		game.subtitles.show()
		camera.set_size_safely(30)
		camera.set_position_safely(Vector3(62, 0, 36))
		await _shot("alpine-north-relay-" + faction)
		if faction == "helix":
			root.size = Vector2i(1440, 900)
			camera.set_size_safely(72)
			camera.set_position_safely(Vector3(59, 0, 50))
			await _shot("alpine-wide-900p")
			root.size = Vector2i(1280, 720)
		paused = false
		game.queue_free()
		await _frames(5)
	await _skirmish("bastion", "res://source/match/maps/PlainAndSimple.tscn")
	var overlay = game.get_node("FogOfWar/ScreenOverlay").material_override
	_check(
		is_zero_approx(overlay.get_shader_parameter("exterior_visibility")),
		"Alpine exterior visibility leaked into another rendered map"
	)
	game.queue_free()
	await _frames(5)
	saves.autosaves_enabled = autosaves
	options.restore(initial_options)
	print("Alpine environment preview: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _shot(title):
	await _frames(10)
	await RenderingServer.frame_post_draw
	var frame = root.get_texture().get_image()
	_check(frame.get_size() == root.size, "Alpine output resolution changed")
	frame.save_png("res://art/skirmish/environment/%s.png" % title)


func _set_colors(faction):
	var sides = [game._get_human_player(), _enemy()]
	sides[0].color = Color("e3ad48") if faction == "bastion" else Color("38c8ce")
	sides[1].color = Color("38c8ce") if faction == "bastion" else Color("e3ad48")
	for side in sides:
		side.get_color_material().albedo_color = side.color


func _combat(faction):
	var sides = [game._get_human_player(), _enemy()]
	var armies = [[], []]
	var roles = ["Tank", "Tank", "Tank", "Infantry", "Infantry", "Infantry", "Infantry"]
	for side in 2:
		for index in roles.size():
			var point = Vector3(57 if side == 0 else 76, 0, 32 + index * 1.35)
			armies[side].append(_spawn_alpine(roles[index], sides[side], point))
	game.hud._toggle_pause()
	await _frames(20)
	for side in 2:
		for unit in armies[side]:
			unit.manual_orders.submit(
				{
					"kind": "attack_move",
					"point": Vector3(75 if side == 0 else 57, 0, unit.position.z)
				}
			)
	var camera = game.get_node("IsometricCamera3D")
	camera.set_size_safely(27)
	camera.set_position_safely(Vector3(65, 0, 36))
	await _frames(240)
	await _shot("alpine-combat-" + faction)
	await _frames(240)
	var effects = game.combat_effects
	_check(
		effects.shots_emitted > 20 and effects.impacts_emitted > 10,
		"Alpine combat did not exercise weapon effects"
	)
	game.hud._toggle_pause()
	var before = game.simulation_time
	var shots = effects.shots_emitted
	await _shot("alpine-combat-paused-" + faction)
	_check(
		game.simulation_time == before and effects.shots_emitted == shots,
		"Alpine combat advanced during tactical pause"
	)
	print(
		"PASS: ",
		faction,
		" visible alpine combat, shots=",
		shots,
		" impacts=",
		effects.impacts_emitted,
		"; pause freezes combat"
	)
	for army in armies:
		for unit in army:
			if is_instance_valid(unit):
				unit.queue_free()
	await _frames(5)


func _relay_review(faction):
	var relay = game.map.relays[0]
	var human = game._get_human_player()
	var enemy = _enemy()
	relay.captured_by = null
	relay.candidate = null
	relay.progress = 0.0
	relay.contested = false
	relay._update_presentation()
	var camera = game.get_node("IsometricCamera3D")
	camera.set_size_safely(27)
	camera.set_position_safely(relay.position + Vector3(-3, 0, 0))
	# Use real registered units, with their own weapons disabled for isolated capture review.
	var infantry = _spawn_alpine("Infantry", human, relay.position + Vector3(-2, 0, 0))
	infantry.process_mode = Node.PROCESS_MODE_DISABLED
	game.battlefield.invalidate()
	game.hud._toggle_pause()
	await _frames(310)
	game.hud._toggle_pause()
	var capture_progress = relay.progress
	await _shot("alpine-relay-capturing-" + faction)
	_check(
		relay.candidate == human and capture_progress > 4 and capture_progress < 7,
		"Relay capture did not advance with real infantry"
	)
	_check(relay.progress == capture_progress, "Relay capture advanced during pause")
	game.hud._toggle_pause()
	await _frames(320)
	game.hud._toggle_pause()
	_check(relay.captured_by == human, "Rendered relay did not become secured")
	await _shot("alpine-relay-secured-" + faction)
	var contester = _spawn_alpine("Tank", enemy, relay.position + Vector3(2, 0, 0))
	contester.process_mode = Node.PROCESS_MODE_DISABLED
	game.battlefield.invalidate()
	game.hud._toggle_pause()
	await _frames(120)
	game.hud._toggle_pause()
	_check(relay.contested and relay.captured_by == human, "Enemy tank did not contest relay")
	await _shot("alpine-relay-contested-" + faction)
	infantry.queue_free()
	contester.queue_free()
	await _frames(5)
	var attacker = _spawn_alpine("Infantry", enemy, relay.position + Vector3(2, 0, 0))
	attacker.process_mode = Node.PROCESS_MODE_DISABLED
	# A scout outside capture radius keeps the hostile state legitimately visible.
	var scout = _spawn_alpine("Drone", human, relay.position + Vector3(-5, 1.5, 0))
	scout.process_mode = Node.PROCESS_MODE_DISABLED
	game.battlefield.invalidate()
	game.hud._toggle_pause()
	await _frames(630)
	game.hud._toggle_pause()
	_check(relay.captured_by == enemy, "Rendered relay did not become hostile")
	await _shot("alpine-relay-hostile-" + faction)
	attacker.queue_free()
	scout.queue_free()
	await _frames(5)
	print("PASS: ", faction, " rendered capture/secured/contested/hostile relay states and pause")


func _enemy():
	return get_nodes_in_group("players").filter(func(p): return p != game._get_human_player())[0]
