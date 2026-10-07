extends "res://tests/headless/AuthoredGuardRegression.gd"

var response
var air


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	for faction in ["bastion", "helix", "frontier"]:
		await _setup(faction)
		game.hud.pause_after_load()
		response = load("res://tests/playtest/reference/HomeDefensePolicy.gd").new()
		guard.program.installed = false
		raider.position = anchor + Vector3(10, 0, 0)
		observer.position = anchor + Vector3(9, 0, 3)
		air = _actor("Helicopter", raider.player, anchor + Vector3(3, 1.5, 0))
		air.process_mode = Node.PROCESS_MODE_DISABLED
		await _frames(5)
		game.battlefield.invalidate()
		_check(
			game.battlefield.is_observed(guard.player, raider),
			"Response fixture ground target is hidden"
		)
		_check(
			not response.command(guard, [air], game.simulation_time),
			"Conventional tank followed aircraft"
		)
		_check(
			response.command(guard, [air, raider], game.simulation_time),
			"Conventional tank refused visible raid"
		)
		_check(
			(
				is_instance_of(guard.action, response.Advance)
				and guard.action.destination == raider.global_position_yless
			),
			"Response chose an incompatible destination"
		)
		var action = guard.action
		var point = raider.position
		raider.position += Vector3(3, 0, 0)
		response.command(guard, [raider], game.simulation_time + .5)
		_check(guard.action == action, "Response bypassed its reorder interval")
		raider.position = point
		if not await _disk_approach():
			paused = false
			game.queue_free()
			await _frames(5)
			continue
		var hp = raider.hp
		game.hud._toggle_pause()
		await _frames(360)
		game.hud.pause_after_load()
		_check(raider.hp < hp, "Restored conventional response never fired")
		action = guard.action
		_check(
			not game.battlefield.fireable_targets(guard).is_empty(),
			"Firing preservation fixture has no legal shot"
		)
		response.command(guard, [raider], game.simulation_time)
		_check(guard.action == action, "Response replaced an available firing action")
		guard.issue_manual_order(null)
		raider.position = anchor + Vector3(60, 0, 0)
		observer.position = anchor
		game.battlefield.invalidate()
		_check(
			not response.command(guard, [raider], game.simulation_time),
			"Response chased a hidden contact"
		)
		raider.position = point
		game.battlefield.invalidate()
		var depot = _actor("RepairDepot", guard.player, anchor - Vector3(8, 0, 0))
		guard.hp = guard.hp_max * .3
		guard.issue_manual_order(response.Recover.new(depot))
		action = guard.action
		_check(
			not response.command(guard, [raider], game.simulation_time) and guard.action == action,
			"Response overrode protected recovery"
		)
		guard.issue_manual_order(null)
		guard.program.installed = true
		active_mode = "visual"
		_start_guard()
		game.hud._toggle_pause()
		await _frames(2)
		game.hud.pause_after_load()
		_check(
			guard.program.mode == "Running", "Response authority fixture failed to start program"
		)
		action = guard.action
		_check(
			not response.command(guard, [raider], game.simulation_time) and guard.action == action,
			"Response overrode active program"
		)
		print("HOME RESPONSE ", faction, " firing/archive/authority checked")
		paused = false
		game.queue_free()
		await _frames(5)
	for error in errors:
		push_error(error)
	print("Home response: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _disk_approach():
	var builder = Snapshot.new()
	var data = builder.capture(game)
	var ids = [guard, raider, observer, air].map(func(unit): return builder._reference(unit))
	var expected = [guard.position, guard.action.destination, raider.hp]
	var file = "user://home-response-%d.json" % OS.get_process_id()
	_check(FileStore.new().write_file(file, data), "Response archive write failed")
	var restore = Restore.new()
	var loaded = await restore.restore(self, FileStore.new().read_file(file))
	DirAccess.remove_absolute(file)
	_check(loaded.ok, "Response archive restore failed: " + loaded.get("error", ""))
	if not loaded.ok:
		return false
	game = loaded.game
	guard = restore.entities[ids[0]]
	raider = restore.entities[ids[1]]
	observer = restore.entities[ids[2]]
	air = restore.entities[ids[3]]
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	for unit in get_nodes_in_group("units"):
		if unit != guard:
			unit.process_mode = Node.PROCESS_MODE_DISABLED
	await _frames(10)
	_check(
		paused and game.simulation_time == data.simulation_time,
		"Paused response archive advanced clock"
	)
	_check(
		(
			is_instance_of(guard.action, response.Advance)
			and [guard.position, guard.action.destination, raider.hp] == expected
		),
		"Response archive changed approach or health"
	)
	return true
