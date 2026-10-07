extends "res://tests/headless/AuthoredGuardRegression.gd"

var response
var air
var original = false


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	response = load("res://tests/playtest/reference/GuardResponsePolicy.gd")
	original = "--original-policy" in OS.get_cmdline_user_args()
	for faction in ["bastion", "helix", "frontier"]:
		for mode in ["lua", "visual"]:
			active_mode = mode
			await _setup(faction)
			await _response_case(faction)
			paused = false
			game.queue_free()
			await _frames(5)
	for error in errors:
		push_error(error)
	print("Guard response: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _respond(threats, fallback, protected = false):
	if original:
		if protected or guard.program.mode != "Running":
			return false
		var point = fallback if threats.is_empty() else threats[0].global_position_yless
		if guard.program.anchor != null and guard.program.anchor.distance_to(point) < 2:
			return false
		guard.program.anchor = point
		return true
	return response.update(guard, threats, fallback, protected)


func _response_case(faction):
	game.hud.pause_after_load()
	var enemy = raider.player
	raider.position = anchor + Vector3(8, 0, 0)
	observer.position = anchor + Vector3(8, 0, 3)
	air = _actor("Helicopter", enemy, anchor + Vector3(-5, 1.5, 0))
	air.process_mode = Node.PROCESS_MODE_DISABLED
	await _frames(5)
	game.battlefield.invalidate()
	_check(game.battlefield.is_observed(guard.player, air), "Air-priority fixture not observed")
	_start_guard()
	game.hud._toggle_pause()
	await _frames(2)
	game.hud.pause_after_load()
	_check(guard.program.mode == "Running", "Response fixture program did not start")
	var source = guard.program.lua_source
	var safe = guard.program.safe_point
	var fallback = anchor + Vector3(0, 0, -3)
	_respond([air, raider], fallback)
	_check(
		guard.program.anchor == raider.global_position_yless,
		"Ground guard followed incompatible air threat"
	)
	var hp = raider.hp
	game.hud._toggle_pause()
	await _frames(180)
	game.hud.pause_after_load()
	_check(raider.hp < hp, "Mixed-raid ground guard did not fire at ground attacker")
	_check(
		guard.program.lua_source == source and guard.program.safe_point == safe,
		"Response changed authored program or recovery"
	)
	await _disk_response()
	_check(guard.program.mode == "Running", "Loaded defense guard lost running state")
	var previous = guard.program.anchor
	_respond([air], fallback, true)
	_check(guard.program.anchor == previous, "Response overrode protected recovery")
	guard.issue_manual_order(null)
	_respond([air, raider], fallback)
	_check(
		guard.program.anchor == previous and guard.program.mode == "Manual",
		"Response resumed manual guard"
	)
	_check(guard.program.run(), "Manual guard could not explicitly resume")
	game.hud._toggle_pause()
	await _frames(2)
	game.hud.pause_after_load()
	_respond([air], fallback)
	_check(guard.program.anchor == fallback, "Air-only raid pulled ground guard off fallback")
	raider.position = anchor + Vector3(50, 0, 0)
	observer.position = anchor
	game.battlefield.invalidate()
	_check(
		not game.battlefield.is_observed(guard.player, raider),
		"Hidden ground fixture still observed"
	)
	_respond([raider], fallback)
	_check(guard.program.anchor == fallback, "Hidden threat moved defense sector")
	print("GUARD RESPONSE ", faction, " ", active_mode, " checked")


func _disk_response():
	var builder = Snapshot.new()
	var data = builder.capture(game)
	var ids = [guard, raider, air, observer].map(func(unit): return builder._reference(unit))
	var expected = [
		guard.position,
		guard.program.anchor,
		guard.program.safe_point,
		guard.program.lua_source,
		raider.hp
	]
	var path = "user://guard-response-%d.json" % OS.get_process_id()
	_check(FileStore.new().write_file(path, data), "Guard response save failed")
	var restore = Restore.new()
	var loaded = await restore.restore(self, FileStore.new().read_file(path))
	DirAccess.remove_absolute(path)
	_check(loaded.ok, "Guard response restore failed")
	game = loaded.game
	guard = restore.entities[ids[0]]
	raider = restore.entities[ids[1]]
	air = restore.entities[ids[2]]
	observer = restore.entities[ids[3]]
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	for unit in get_nodes_in_group("units"):
		if unit != guard:
			unit.process_mode = Node.PROCESS_MODE_DISABLED
	await _frames(10)
	_check(
		paused and game.simulation_time == data.simulation_time,
		"Paused guard response advanced time"
	)
	_check(
		(
			[
				guard.position,
				guard.program.anchor,
				guard.program.safe_point,
				guard.program.lua_source,
				raider.hp
			]
			== expected
		),
		"Paused guard response changed saved state"
	)
