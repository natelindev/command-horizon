extends "res://tests/headless/CampaignRegression.gd"

const Snapshot = preload("res://source/match/saves/MatchSnapshot.gd")
const Restore = preload("res://source/match/saves/MatchRestore.gd")
const Record = preload("res://source/match/programs/ProgramRecord.gd")
const FileStore = preload("res://source/match/saves/SaveFile.gd")
const HOLD = """return function(s,m)
 m.ticks=(m.ticks or 0)+1
 return {intent={kind='hold'},state=m}
end"""
var save_path


func _run():
	save_path = "user://restore-regression-%d.json" % OS.get_process_id()
	path = "user://restore-campaign-%d.json" % OS.get_process_id()
	if DisplayServer.get_name() != "headless":
		root.mode = Window.MODE_WINDOWED
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
		root.size = Vector2i(1280, 720)
		root.content_scale_size = root.size
	await _make_match()
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
	var params = [
		{"name": "threshold", "label": "Threshold", "value": 30, "min": 1, "max": 90, "step": 1}
	]
	var prefix = load("res://source/match/programs/llm/DraftResponse.gd").parameter_prefix(params)
	var record = Record.lua("Restored counter", 2, prefix + HOLD, ["Tank"], ["movement"])
	record.parameter_schema = load("res://source/match/programs/LuaParameters.gd").schema(params)
	Record.seal(record)
	tanks[0].program.installed = true
	# Apply through the real transaction so the live config matches the sealed record.
	var applied = load("res://source/match/programs/ProgramApplication.gd").apply(
		record, [tanks[0]], human
	)
	_check(applied.ok, "Could not apply restore fixture")
	tanks[0].program.run()
	tanks[1].manual_orders.submit({"kind": "move", "point": Vector3(65, 0, 23)})
	tanks[1].manual_orders.submit({"kind": "move", "point": Vector3(30, 0, 22)}, true)
	tanks[2].program.installed = true
	tanks[2].program.configure(
		load("res://source/match/programs/ProgramLibrary.gd").defaults("guard")
	)
	tanks[2].program.anchor = Vector3(25, 0, 28)
	tanks[2].program.safe_point = Vector3(15, 0, 20)
	tanks[2].hp = 18
	tanks[2].program.run()
	var squad = human.squad_roster.create("Restored armor", [tanks[0], tanks[2]])
	await _frames(300)
	var factory = _units(human, "VehicleFactory")[0]
	factory.production_queue.fit_chips = true
	var job = factory.production_queue.produce(load("res://source/match/units/Tank.tscn"))
	job.program_snapshot = {
		"record": record.duplicate(true),
		"title": "Restored counter · v2",
		"config": record.config.duplicate(true),
		"notice": ""
	}
	job.time_left = 2.5
	tanks[0].set_meta("next_attack_availability_time", int(game.simulation_time * 1000) + 1750)
	tanks[0].last_enemy_damage_time = game.simulation_time - 0.75
	var victim = game._spawn("Tank", game._enemy, Vector3(24, 0, 23))
	victim.issue_manual_order(
		load("res://source/match/units/actions/Moving.gd").new(Vector3(60, 0, 23))
	)
	var shot = load("res://source/match/units/projectiles/CannonShell.tscn").instantiate()
	shot.target_unit = victim
	tanks[0].add_child(shot)
	shot._flight_left = 0.25
	squad.write_state(tanks[0], "phase", "hold")
	squad.claim(tanks[0], victim)
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
		"lua": builder._reference(tanks[0]),
		"manual": builder._reference(tanks[1]),
		"retreat": builder._reference(tanks[2]),
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
	var lua = restorer.entities[ids.lua]
	var manual = restorer.entities[ids.manual]
	var retreat = restorer.entities[ids.retreat]
	var worker = restorer.entities[ids.worker]
	building = restorer.entities[ids.building]
	factory = restorer.entities[ids.factory]
	victim = restorer.entities[ids.victim]
	var saved_lua = snapshot.units.filter(func(unit): return unit.id == ids.lua)[0]
	_check(paused and game.simulation_time == snapshot.simulation_time, "Load advanced battle time")
	_check(
		game._get_human_player().resource_a == snapshot.players[0].resource_a,
		"Loading charged/refunded resources"
	)
	_check(
		(
			absf(
				(
					float(lua.get_meta("next_attack_availability_time")) / 1000.0
					- game.simulation_time
					- saved_lua.weapon_left
				)
			)
			< 0.002
		),
		"Weapon cooldown changed"
	)
	_check(
		is_equal_approx(game.simulation_time - lua.last_enemy_damage_time, saved_lua.damage_age),
		"Damage suppression duration changed"
	)
	var shell_script = load("res://source/match/units/projectiles/CannonShell.gd")
	var shells = lua.get_children().filter(func(child): return child.get_script() == shell_script)
	_check(shells.size() == 1, "Reload replayed the pending shot")
	_check(factory.production_queue._queue[0].time_left == 2.5, "Queued duration changed")
	_check(
		(
			lua.program.saved_record == record
			and lua.program.lua_runtime.state_snapshot() == saved_lua.program.runtime.state
		),
		"Exact program/state lost"
	)
	_check(
		manual.manual_orders.pending.size() == 1 and manual.program.mode == "Manual",
		"Manual queue authority changed"
	)
	_check(retreat.action._retreating, "Retreat hysteresis lost")
	_check(worker.resource_a > 0, "Cargo lost")
	_check(
		game.hold_seconds == 11.5 and game.waves_warned == 1 and game.waves_sent == 0,
		"Mission durations changed"
	)
	_check(
		lua.program_squad.title == "Restored armor" and lua.program_squad._state.phase == "hold",
		"Squad state lost"
	)
	_check(lua.program_squad._claims.size() == 1, "Claim duration lost")
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
	var health = victim.hp
	var time = game.simulation_time
	var position = manual.position
	await _frames(40)
	_check(
		victim.hp == health and game.simulation_time == time and manual.position == position,
		"Paused restore caused damage/movement"
	)
	var ticks = lua.program.lua_runtime.state_snapshot().ticks
	var construction = building._construction_progress
	await _resume_from_hud()
	_check(not paused, "Loaded battle could not resume through its HUD")
	await _frames(35)
	_check(victim.hp < health, "Saved in-flight shot did not resolve")
	_check(
		lua.program.lua_runtime.state_snapshot().ticks > ticks,
		"Lua failed to continue explicit state"
	)
	_check(manual.position.distance_to(position) > 0.2, "Manual movement did not resume")
	_check(building._construction_progress > construction, "Construction did not resume")
	await _frames(150)
	_check(factory.production_queue.size() == 0, "Paid production did not complete")
	var produced = _units(game._get_human_player(), "Tank").filter(
		func(unit): return unit != lua and unit != manual and unit != retreat
	)
	_check(
		produced.size() == 1 and produced[0].program.saved_record == record,
		"Production lost embedded version"
	)
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
				"PASS: actual reload preserves jobs, actions, programs, cargo, cooldowns and mission; "
				+ "resume works"
			)
		)
	quit(0 if errors.is_empty() else 1)


func _validate_corruption(snapshot, ids):
	var corruptions = [
		func(data): data.units[0].rally = {"position": Vector3.ZERO, "target": "player-0"},
		func(data): _saved(data, ids.manual).action.state._target_position = null,
		func(data): _saved(data, ids.retreat).action.state._waypoint = 2,
		func(data): _saved(data, ids.factory).production.pin = {"oops": 7},
		func(data): _saved(data, ids.lua).projectiles[0].target = "player-1",
		func(data): _saved(data, ids.lua).action.state._next_handle = 1.5,
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
	var actual = game.fog_of_war._fog_viewport.get_texture().get_image()
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
