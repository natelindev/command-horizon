extends "res://tests/headless/CampaignRegression.gd"

const Snapshot = preload("res://source/match/saves/MatchSnapshot.gd")
const Restore = preload("res://source/match/saves/MatchRestore.gd")
const FileStore = preload("res://source/match/saves/SaveFile.gd")
var save_path


func _run():
	save_path = "user://restore-regression-%d.json" % OS.get_process_id()
	path = "user://restore-campaign-%d.json" % OS.get_process_id()
	if DisplayServer.get_name() != "headless":
		root.mode = Window.MODE_WINDOWED
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
		root.size = Vector2i(1280, 720)
		root.content_scale_size = root.size
	var behavior = load("res://source/match/orders/UnitBehavior.gd")
	var guard_point = Vector3(25, 0, 28)
	await _make_match()
	# A graphical campaign starts in its modal briefing. Exercise gameplay before
	# capturing; a pending briefing would otherwise keep this whole fixture paused.
	if is_instance_valid(game.campaign_story) and game.campaign_story.cinematic:
		game.campaign_story.skip_briefing()
	var human = game._get_human_player()
	human.resource_a = 500
	human.resource_b = 500
	game._spawn("CommandLab", human, Vector3(28, 0, 8))
	await _frames(5)
	human.coordination_unlocked = true
	var tanks = _units(human, "Tank")
	var workers = _units(human, "Worker")
	var resource = get_nodes_in_group("resource_units")[0]
	workers[0].issue_manual_order(
		load("res://source/match/units/actions/CollectingResourcesSequentially.gd").new(resource)
	)
	var building = load("res://source/match/units/PowerPlant.tscn").instantiate()
	game._setup_and_spawn_unit(building, Transform3D(Basis(), Vector3(15, 0, 32)), human, true)
	workers[1].issue_manual_order(
		load("res://source/match/units/actions/Constructing.gd").new(building)
	)
	_check(behavior.guard(tanks[0], guard_point), "Could not post the guard fixture")
	tanks[1].manual_orders.submit({"kind": "move", "point": Vector3(65, 0, 23)})
	tanks[1].manual_orders.submit({"kind": "move", "point": Vector3(30, 0, 22)}, true)
	_check(behavior.follow(tanks[2], tanks[1]), "Could not start the follow fixture")
	await _frames(300)
	var factory = _units(human, "VehicleFactory")[0]
	var job = factory.production_queue.produce(load("res://source/match/units/Tank.tscn"))
	_check(job != null, "Could not queue the production fixture")
	job.time_left = 2.5
	tanks[0].set_meta("next_attack_availability_time", int(game.simulation_time * 1000) + 1750)
	tanks[0].last_enemy_damage_time = game.simulation_time - 0.75
	var victim = game._spawn("Tank", game._enemy, Vector3(24, 0, 23))
	victim.issue_manual_order(
		load("res://source/match/units/actions/Moving.gd").new(Vector3(60, 0, 23))
	)
	var shot = game.projectile_system.launch(tanks[0], victim)
	shot.life = 0.25
	game.phase = 2
	game.relay.captured_by = human
	game.hold_seconds = 11.5
	game.defence_started = true
	game.defence_time = 8.5
	game.waves_warned = 1
	game.waves_sent = 0
	paused = true
	game.relay._update_presentation()
	game.fog_of_war._physics_process(0.0)
	if DisplayServer.get_name() != "headless":
		await _frames(3)
		await RenderingServer.frame_post_draw
	var builder = Snapshot.new()
	var snapshot = builder.capture(game)
	_check(snapshot != null, "Fixture capture failed: " + builder.error)
	if snapshot == null:
		await _finish()
		return
	var ids = {
		"guard": builder._reference(tanks[0]),
		"manual": builder._reference(tanks[1]),
		"follow": builder._reference(tanks[2]),
		"worker": builder._reference(workers[0]),
		"building": builder._reference(building),
		"factory": builder._reference(factory),
		"victim": builder._reference(victim)
	}
	var relay_position = game.relay.global_position
	var restorer = Restore.new()
	var invalid = snapshot.duplicate(true)
	invalid.units[0].role = "../../bad"
	var rejected = await restorer.restore(self, invalid)
	_check(
		not rejected.ok and is_instance_valid(game) and current_scene == game and paused,
		"Bad load changed the live match"
	)
	_validate_corruption(snapshot, ids)
	var file = FileStore.new()
	_check(file.write_file(save_path, snapshot), "Could not write reload fixture")
	var loaded = await restorer.restore(self, file.read_file(save_path))
	_check(loaded.ok, "Restore failed: " + loaded.get("error", ""))
	if not loaded.ok:
		if loaded.has("game"):
			game = loaded.game
		await _finish()
		return
	game = loaded.game
	_check(game.relay.global_position == relay_position, "Navigation shifted the saved relay")
	await _verify_fog(snapshot)
	game.progress_path = path
	game.get_node("IsometricCamera3D").set_physics_process(false)
	var guard = restorer.entities[ids.guard]
	var manual = restorer.entities[ids.manual]
	var follower = restorer.entities[ids.follow]
	var worker = restorer.entities[ids.worker]
	building = restorer.entities[ids.building]
	factory = restorer.entities[ids.factory]
	victim = restorer.entities[ids.victim]
	var saved_guard = snapshot.units.filter(func(unit): return unit.id == ids.guard)[0]
	_check(paused and game.simulation_time == snapshot.simulation_time, "Load advanced battle time")
	_check(
		game._get_human_player().resource_a == snapshot.players[0].resource_a,
		"Loading charged/refunded resources"
	)
	_check(
		(
			absf(
				(
					float(guard.get_meta("next_attack_availability_time")) / 1000.0
					- game.simulation_time
					- saved_guard.weapon_left
				)
			)
			< 0.002
		),
		"Weapon cooldown changed"
	)
	_check(
		is_equal_approx(
			game.simulation_time - guard.last_enemy_damage_time, saved_guard.damage_age
		),
		"Damage suppression duration changed"
	)
	var shells = game.projectile_system._rounds.filter(
		func(round): return round.shot.shooter() == guard
	)
	_check(
		shells.size() == 1 and is_equal_approx(shells[0].life - shells[0].age, 0.25),
		"Reload replayed or retimed the pending shot"
	)
	_check(factory.production_queue._queue[0].time_left == 2.5, "Queued duration changed")
	_check(
		(
			behavior.current(guard) == "guard"
			and guard.global_position_yless.distance_to(guard_point) < 2.5
		),
		"Guard post lost"
	)
	_check(manual.manual_orders.pending.size() == 1, "Manual queue authority changed")
	_check(
		(
			behavior.current(follower) == "follow"
			and follower.manual_orders.current.target.get_ref() == manual
		),
		"Follow target lost"
	)
	_check(worker.resource_a > 0, "Cargo lost")
	_check(
		game.hold_seconds == 11.5 and game.waves_warned == 1 and game.waves_sent == 0,
		"Mission durations changed"
	)
	var bar = game.find_child("ResourcesBar")
	var human_loaded = game._get_human_player()
	var power = human_loaded.power_totals()
	_check(
		bar._population.text == "%d / 100" % human_loaded.population(),
		"Paused population HUD is stale"
	)
	_check(
		bar._power_title.text == "POWER   %d used / %d supply" % [power.y, power.x],
		"Paused power HUD is stale"
	)
	var health = victim.hp + victim.shields
	var time = game.simulation_time
	var position = manual.position
	await _frames(40)
	_check(
		(
			victim.hp + victim.shields == health
			and game.simulation_time == time
			and manual.position == position
		),
		"Paused restore caused damage/movement"
	)
	var construction = building._construction_progress
	await _resume_from_hud()
	_check(not paused, "Loaded battle could not resume through its HUD")
	await _frames(35)
	_check(victim.hp + victim.shields < health, "Saved in-flight shot did not resolve")
	_check(manual.position.distance_to(position) > 0.2, "Manual movement did not resume")
	_check(building._construction_progress > construction, "Construction did not resume")
	await _frames(150)
	_check(factory.production_queue.size() == 0, "Paid production did not complete")
	var produced = _units(game._get_human_player(), "Tank").filter(
		func(unit): return unit not in [guard, manual, follower]
	)
	_check(produced.size() == 1, "Paid production did not deliver its tank")
	await _finish()


func _finish():
	paused = false
	if is_instance_valid(game):
		game.queue_free()
	await _frames(5)
	DirAccess.remove_absolute(save_path)
	DirAccess.remove_absolute(path)
	for message in errors:
		push_error(message)
	if errors.is_empty():
		print(
			(
				"PASS: actual reload preserves jobs, actions, guard/follow orders, cargo, cooldowns "
				+ "and mission; resume works"
			)
		)
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)


func _validate_corruption(snapshot, ids):
	var corruptions = [
		func(data): data.snapshot_version = Snapshot.VERSION - 1,
		func(data): data.players[0].erase("_lab_research"),
		func(data): data.units[0].rally = {"position": Vector3.ZERO, "target": "player-0"},
		func(data): _saved(data, ids.manual).action.state._target_position = null,
		func(data): _saved(data, ids.follow).stance = 7,
		func(data): _saved(data, ids.factory).production.jobs[0].role = "Barracks",
		func(data): data.rounds.flying[0].target = "player-1",
		func(data): _saved(data, ids.worker).action.references._cc_unit = "player-0",
		func(data):
			_saved(data, ids.manual).orders.pending = [
				{"kind": "attack", "point": Vector3.ZERO, "target": "player-1"}
			],
	]
	for index in range(corruptions.size()):
		var data = snapshot.duplicate(true)
		corruptions[index].call(data)
		var restorer = Restore.new()
		_check(
			not restorer.prepare(data) and not restorer.error.is_empty(),
			"Unsafe snapshot accepted: %d" % index
		)


func _saved(snapshot, id):
	return snapshot.units.filter(func(unit): return unit.id == id)[0]


func _verify_fog(snapshot):
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var expected = Image.new()
	expected.load_png_from_buffer(Marshalls.base64_to_raw(snapshot.fog.png))
	var actual = game.fog_of_war.exploration_image()
	_check(actual.get_size() == expected.get_size(), "Restored exploration dimensions changed")
	var changed = 0
	for y in range(actual.get_height()):
		for x in range(actual.get_width()):
			if absf(actual.get_pixel(x, y).r - expected.get_pixel(x, y).r) > 0.01:
				changed += 1
	_check(changed == 0, "Exploration changed across paused reload: %d pixels" % changed)
	_check(not game.fog_of_war._unit_to_circles_mapping.is_empty(), "Loaded current vision missing")


func _resume_from_hud():
	if DisplayServer.get_name() == "headless":
		game.hud._pause_button.pressed.emit()
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://art/skirmish/save-restored-paused-720p.png")
	var point = game.hud._pause_button.get_global_rect().get_center()
	var motion = InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	await _frames(2)
	for pressed in [true, false]:
		var event = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.pressed = pressed
		root.push_input(event, true)
		await _frames(2)
