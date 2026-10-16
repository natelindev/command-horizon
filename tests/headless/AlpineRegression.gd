extends "res://tests/headless/SaveRestoreEdges.gd"

const ALPINE = "res://source/match/maps/AlpineRelay.tscn"
var moving


func _run():
	moving = load("res://source/match/units/actions/Moving.gd")
	if DisplayServer.get_name() != "headless":
		root.mode = Window.MODE_WINDOWED
		root.size = Vector2i(1280, 720)
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
		root.content_scale_size = root.size
		_check(await _menu_review() == true, "Map menu review did not finish")
	for faction in ["bastion", "helix"]:
		await _skirmish(faction, ALPINE)
		var human = game._get_human_player()
		var enemy = get_nodes_in_group("players").filter(func(side): return side != human)[0]
		enemy.set_process(false)
		await _frames(100)
		_check(await _routes_and_army(human) == true, "Route suite did not finish")
		_check(await _relay_and_restore(human, enemy) == true, "Relay suite did not finish")
		paused = false
		game.queue_free()
		await _frames(5)
		await _standard_economy(faction)
	print("Alpine regression: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _route(domain, from, to):
	var nav = game.navigation.get_navigation_map_rid_by_domain(domain)
	var start = NavigationServer3D.map_get_closest_point(nav, from)
	var end = NavigationServer3D.map_get_closest_point(nav, to)
	return NavigationServer3D.map_get_path(nav, start, end, true)


func _length(route):
	var total = 0.0
	for index in range(1, route.size()):
		total += route[index - 1].distance_to(route[index])
	return total


func _routes_and_army(human):
	var ground = root.get_node("Constants").Match.Navigation.Domain.TERRAIN
	var air = root.get_node("Constants").Match.Navigation.Domain.AIR
	for z in [36.0, 73.0, 2.5]:
		var route = _route(ground, Vector3(40, 0, z), Vector3(88, 0, z))
		_check(route.size() >= 2 and _length(route) < 55, "A pass or rear bypass is blocked")
	var ridge = _route(ground, Vector3(52, 0, 55), Vector3(76, 0, 55))
	var flight = _route(air, Vector3(52, 1.5, 55), Vector3(76, 1.5, 55))
	_check(_length(ridge) > _length(flight) + 8, "Air has no shortcut across the ridge")
	var crossing = _route(ground, Vector3(25, 0, 18), Vector3(103, 0, 86))
	var seconds = _length(crossing) / 2.6
	_check(seconds >= 35 and seconds <= 55, "Tank traversal outside pacing target")
	print(
		(
			"Alpine paths: ground=%.1f air=%.1f base traversal=%.1fs at 2.6 m/s"
			% [_length(ridge), _length(flight), seconds]
		)
	)
	var materials = 0
	var electronics = 0
	for deposit in get_nodes_in_group("resource_units"):
		if "resource_a" in deposit:
			materials += deposit.resource_a
		else:
			electronics += deposit.resource_b
	# Authored fields plus two salvage caches of 600 materials / 300 electronics.
	_check(materials == 11200 and electronics == 8280, "Authored paired stockpiles changed")
	var army = []
	for index in 16:
		var unit = _spawn_alpine(
			"Tank", human, Vector3(39 - (index / 4) * 2.5, 0, 33 + (index % 4) * 2)
		)
		army.append(unit)
	await _frames(10)
	for index in army.size():
		army[index].issue_manual_order(
			moving.new(Vector3(81 + (index / 4) * 2.5, 0, 33 + (index % 4) * 2))
		)
	var drone = _spawn_alpine("Drone", human, Vector3(40, 0, 55))
	await _frames(5)
	drone.issue_manual_order(moving.new(Vector3(88, 1.5, 55)))
	await _frames(2400)
	for unit in army:
		if unit.global_position.x <= 76:
			var movement = unit.get_node("Movement")
			print(
				"TRANSIT FAILURE pos=",
				unit.global_position,
				" target=",
				movement.target_position,
				" active=",
				movement._has_destination,
				" next=",
				movement.get_next_path_position(),
				" path=",
				movement.get_current_navigation_path()
			)
	_check(
		army.all(func(unit): return unit.global_position.x > 76), "Tank group stuck at north pass"
	)
	_check(drone.global_position.x > 86, "Drone failed to cross the ridge")
	if DisplayServer.get_name() != "headless":
		game.settings.visibility = 2
		game.fog_of_war.reveal()
		var camera = game.get_node("IsometricCamera3D")
		camera.size_max = 150
		camera.set_size_safely(106)
		camera.set_position_safely(Vector3(64, 0, 52))
		await _frames(5)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(
			"res://art/skirmish/alpine-overview-%s.png" % human.faction
		)
		camera.size_max = 45
		camera.set_size_safely(40)
	for unit in army:
		unit.queue_free()
	drone.queue_free()
	await _frames(5)
	return true


func _relay_and_restore(human, enemy):
	var relay = game.map.relays[0]
	var infantry = _spawn_alpine("Infantry", human, relay.global_position + Vector3(-2, 0, 0))
	await _frames(5)
	infantry.issue_manual_order(null)
	await _frames(610)
	_check(relay.captured_by == human, "Infantry failed to capture Alpine relay")
	var hidden = _spawn_alpine("Tank", enemy, relay.global_position + Vector3(-7, 0, 0))
	await _frames(5)
	infantry.global_position = Vector3(20, 0.6, 20)
	game.battlefield.invalidate()
	_check(game.battlefield.is_observed(human, hidden), "Owned relay does not provide local vision")
	var attacker = _spawn_alpine("Infantry", enemy, relay.global_position + Vector3(2, 0, 0))
	await _frames(250)
	_check(
		relay.candidate == enemy and relay.progress > 2 and relay.progress < 10,
		"Recapture did not begin"
	)
	attacker.process_mode = Node.PROCESS_MODE_DISABLED
	hidden.process_mode = Node.PROCESS_MODE_DISABLED
	var builder = Snapshot.new()
	paused = true
	var snapshot = builder.capture(game)
	_check(snapshot != null, "Alpine capture failed: " + builder.error)
	if snapshot == null:
		return
	var owned = snapshot.mission.relays[0]
	var broken = snapshot.duplicate(true)
	broken.mission.relays[0].owner = "unit-1"
	_check(not Restore.new().prepare(broken), "Invalid relay ownership accepted")
	var restore = Restore.new()
	var file = FileStore.new()
	var archive = "user://alpine-%d.json" % OS.get_process_id()
	_check(file.write_file(archive, snapshot), "Alpine archive write failed")
	var loaded = await restore.restore(self, file.read_file(archive))
	DirAccess.remove_absolute(archive)
	_check(loaded.ok, "Alpine restore failed: " + loaded.get("error", ""))
	if not loaded.ok:
		return
	game = loaded.game
	human = game._get_human_player()
	enemy = get_nodes_in_group("players").filter(func(side): return side != human)[0]
	enemy.set_process(false)
	relay = game.map.relays[0]
	_check(
		(
			relay.captured_by == human
			and relay.candidate == enemy
			and relay.progress == owned.progress
		),
		"Restore lost relay owner or recapture duration"
	)
	_check(game.map.relays[1].captured_by == null, "Restore duplicated relay ownership")
	game.hud._toggle_pause()
	await _frames(450)
	_check(relay.captured_by == enemy, "Loaded recapture could not finish")
	enemy._command_army(enemy._units())
	var captures = enemy._army_groups.filter(func(group): return group.kind == "capture")
	_check(captures.size() == 1, "AI did not assign a team to the other neutral relay")
	if captures.size() == 1:
		_check(
			captures[0].point.distance_to(game.map.relays[1].position) < 1,
			"Capture team chose an owned relay"
		)
	print(
		(
			"PASS: %s pass transit, stockpiles, relay sight/recapture, save/restore and AI objective"
			% human.faction
		)
	)

	return true


func _spawn_alpine(role, player, point):
	var unit = load("res://source/match/units/%s.tscn" % role).instantiate()
	game._setup_and_spawn_unit(unit, Transform3D(Basis(), point), player, true)
	return unit


func _standard_economy(faction):
	await _skirmish(faction, ALPINE, false)
	var human = game._get_human_player()
	var enemy = get_nodes_in_group("players").filter(func(side): return side != human)[0]
	enemy.set_process(false)
	_check(
		_units(human, "Tank").is_empty() and _units(human, "Worker").size() == 4,
		"Standard start inherited advanced units"
	)
	var workers = _units(human, "Worker")
	var harvest = load("res://source/match/units/actions/CollectingResourcesSequentially.gd")
	for index in 2:
		var kind = "resource_a" if index == 0 else "resource_b"
		var deposits = get_nodes_in_group("resource_units").filter(func(unit): return kind in unit)
		deposits.sort_custom(
			func(a, b):
				return (
					a.global_position.distance_squared_to(workers[index].global_position)
					< b.global_position.distance_squared_to(workers[index].global_position)
				)
		)
		workers[index].issue_manual_order(harvest.new(deposits[0]))
	var material_before = human.resource_a
	var electronics_before = human.resource_b
	await _frames(3000)
	_check(
		human.resource_a > material_before and human.resource_b > electronics_before,
		"Standard home harvest failed to return both resources"
	)
	var placement = load("res://source/match/utils/UnitPlacementUtils.gd")
	var nav = game.navigation.get_navigation_map_rid_by_domain(
		root.get_node("Constants").Match.Navigation.Domain.TERRAIN
	)
	_check(
		(
			placement.validate_agent_placement_position(Vector3(64, 0, 55), 2.0, [], nav)
			== placement.NOT_NAVIGABLE
		),
		"Building placement accepted the ridge"
	)
	print("PASS: %s Standard home economy and blocked ridge placement" % faction)
	game.queue_free()
	await _frames(5)


func _menu_review():
	var menu = load("res://source/main-menu/Play.tscn").instantiate()
	root.add_child(menu)
	await _frames(5)
	var position = menu._map_list.get_global_rect().get_center()
	for pressed in [true, false]:
		var event = InputEventMouseButton.new()
		event.position = position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
		await _frames(2)
	for code in [KEY_DOWN, KEY_DOWN, KEY_DOWN, KEY_DOWN, KEY_ENTER]:
		for pressed in [true, false]:
			var event = InputEventKey.new()
			event.keycode = code
			event.window_id = menu._map_list.get_popup().get_window_id()
			event.pressed = pressed
			Input.parse_input_event(event)
			await _frames(2)
	_check(menu._get_selected_map_path() == ALPINE, "Map selection did not reach Alpine")
	_check(
		menu._preview.relays.size() == 2 and menu._preview.rocks.size() == 6,
		"Map preview omitted passes or relays"
	)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://art/skirmish/alpine-menu-720p.png")
	menu.queue_free()
	await _frames(3)
	return true


func _check(value, message):
	if not value:
		errors.append(message)
		push_error(message)
