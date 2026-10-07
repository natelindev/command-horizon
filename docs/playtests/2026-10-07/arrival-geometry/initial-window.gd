extends "res://tests/headless/AttackArrivalProgressRegression.gd"

const FAILED_REPLAYS = [1, 7, 16, 17, 19]


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	await _directional_observation()
	await _held_window()
	for trial in FAILED_REPLAYS:
		current_case = {
			"path": "res://docs/playtests/2026-10-07/arrival-geometry/late-30579-%d.json" % trial,
			"unit": "unit-16"
		}
		for repetition in 3:
			await _captured_attack(repetition)
	await _queued_attack_archive()
	await _distant_attack()
	await _active_combat()
	for message in errors:
		push_error(message)
	print("Arrival window: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _held_window():
	current_case = LATE_CASES[4]
	var unit = await _open_attack()
	paused = false
	await _frames(2)
	game.hud.pause_after_load()
	var movement = unit.get_node("Movement")
	var action = unit.action
	var endpoint = movement.get_current_navigation_path()[-1] * Vector3(1, 0, 1)
	var best = endpoint + Vector3(0, 0, .64)
	unit.position = endpoint + Vector3(0, 0, .9)
	action._arrival_progress = best
	action._arrival_elapsed = 1.99
	var helper = load("res://source/match/units/actions/Moving.gd")
	_check(not movement.has_occupied_endpoint(), "Outward fixture is inside arrival bounds")
	_check(
		not helper.occupied_arrival(action, movement, unit, .02), "Settled beyond arrival bounds"
	)
	_check(action._arrival_elapsed == 2.0, "Stalled arrival restarted its observation wait")
	_check(action._arrival_progress == best, "Outward yielding replaced best approach position")
	var builder = Snapshot.new()
	var snapshot = builder.capture(game)
	var id = builder._reference(unit)
	var saved_point = unit.position
	var file = "user://arrival-window-%d.json" % OS.get_process_id()
	_check(FileStore.new().write_file(file, snapshot), "Ready arrival window could not save")
	var restore = Restore.new()
	var loaded = await restore.restore(self, FileStore.new().read_file(file))
	DirAccess.remove_absolute(file)
	_check(loaded.ok, "Ready arrival window failed to restore")
	if not loaded.ok:
		return
	game = loaded.game
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	unit = restore.entities[id]
	movement = unit.get_node("Movement")
	action = unit.action
	await _frames(20)
	_check(
		paused and game.simulation_time == snapshot.simulation_time,
		"Ready window load advanced time"
	)
	_check(unit.position == saved_point, "Ready window load moved infantry")
	_check(
		action._arrival_elapsed == 2.0 and action._arrival_progress == best,
		"Ready observation was not restored exactly"
	)
	# The legal geometry becomes available between the old two-second samples.
	# No new approach beyond the prior best is made during this small return.
	unit.position = endpoint + Vector3(0, 0, .7)
	game.hud._toggle_pause()
	var resumed = game.simulation_time
	for frame in 30:
		await _frames(1)
		if unit.action != action:
			break
	_check(
		unit.action != action and not movement._has_destination,
		"Ready arrival ignored newly legal geometry"
	)
	_check(
		game.simulation_time - resumed < .5, "Ready arrival waited for another two-second sample"
	)
	print("HELD ARRIVAL WINDOW settled=", game.simulation_time - resumed)
	paused = false
	game.queue_free()
	await _frames(5)
