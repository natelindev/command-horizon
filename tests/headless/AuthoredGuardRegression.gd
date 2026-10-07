extends "res://tests/headless/SaveRestoreEdges.gd"

const Visual = preload("res://source/match/programs/VisualRules.gd")
const Records = preload("res://source/match/programs/ProgramRecord.gd")
const Application = preload("res://source/match/programs/ProgramApplication.gd")
var guard
var raider
var observer
var anchor = Vector3(40, 0, 10)
var active_mode = ""
var active_role = "Tank"


func _run():
	var manager = root.get_node("SaveManager")
	var autosaves = manager.autosaves_enabled
	manager.autosaves_enabled = false
	var runtime = load("res://source/match/programs/LuaRuntime.gd")
	_check(runtime.validate_intent({"kind": "guard"}) == "", "Guard intent rejected")
	for extra in [{"target": 1}, {"assignment": "safe"}, {"radius": 100}]:
		var invalid = {"kind": "guard"}
		invalid.merge(extra)
		_check(not runtime.validate_intent(invalid).is_empty(), "Guard accepted extra authority")
	for faction in ["bastion", "helix"]:
		for mode in ["lua", "visual"]:
			active_mode = mode
			await _setup(faction)
			await _firing_position()
			await _sector_exit()
			await _approach_archive()
			await _observation_bounds()
			await _authority_and_recovery()
			print("AUTHORED GUARD ", faction, " ", mode, " checked")
			paused = false
			game.queue_free()
			await _frames(5)
	manager.autosaves_enabled = autosaves
	for error in errors:
		push_error(error)
	print("Authored guard: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _setup(faction):
	await _skirmish(faction, "res://source/match/maps/DesertFrontier.tscn")
	var human = game._get_human_player()
	var enemy = get_nodes_in_group("players").filter(func(player): return player != human)[0]
	enemy.set_process(false)
	for unit in get_nodes_in_group("units"):
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	guard = _actor(active_role, human, anchor + Vector3(0, 0, 3))
	raider = _actor("Tank", enemy, anchor + Vector3(4, 0, 0))
	observer = _actor("Worker", human, anchor + Vector3(5, 0, 3))
	raider.process_mode = Node.PROCESS_MODE_DISABLED
	observer.process_mode = Node.PROCESS_MODE_DISABLED
	guard.program.installed = true
	guard.program.anchor = anchor
	guard.program.safe_point = anchor - Vector3(8, 0, 0)
	await _frames(20)
	game.battlefield.invalidate()


func _start_guard():
	var record = Records.visual("Authored guard", 1, Visual.starter(1), [active_role])
	if active_mode == "lua":
		record = Records.lua(
			"Authored guard",
			1,
			FileAccess.get_file_as_string("res://assets/programs/guard.lua"),
			[active_role],
			["movement", "attack"]
		)
	var result = Application.apply(record, [guard], guard.player)
	_check(result.ok, "Authored guard application failed")


func _firing_position():
	_check(game.battlefield.can_fire(guard, raider), "Firing-position fixture cannot fire")
	var point = guard.position
	var hp = raider.hp
	_start_guard()
	await _frames(120)
	_check(raider.hp < hp, "Assigned guard did not fire at legal in-area target")
	_check(
		guard.position.distance_to(point) < 0.25,
		"Guard abandoned a legal firing position to crowd its anchor"
	)
	await _review("engaging")


func _sector_exit():
	raider.position = anchor + Vector3(30, 0, 0)
	game.battlefield.invalidate()
	guard.issue_manual_order(null)
	await _frames(90)
	guard.position = anchor + Vector3(3, 0, 0)
	raider.position = anchor + Vector3(7, 0, 0)
	observer.position = raider.position + Vector3(0, 0, 3)
	raider.hp = raider.hp_max
	game.battlefield.invalidate()
	_check(
		game.battlefield.can_fire(guard, raider),
		"Outside-sector fixture is not within weapon range"
	)
	var hp = raider.hp
	_start_guard()
	await _frames(120)
	print(
		"SECTOR ",
		guard.player.faction,
		" ",
		active_mode,
		" ",
		guard.position,
		" anchor=",
		guard.program.anchor,
		" target=",
		raider.position,
		" hp=",
		hp,
		"->",
		raider.hp,
		" ",
		guard.program.reason
	)
	_check(raider.hp == hp, "Guard attacked outside its assigned six-metre sector")
	_check(
		guard.position.distance_to(anchor) < 1.2,
		"Guard did not return to its anchor after the target left"
	)


func _actor(role, player, point):
	var unit = load("res://source/match/units/%s.tscn" % role).instantiate()
	game._setup_and_spawn_unit(unit, Transform3D(Basis(), point), player, false)
	return unit


func _review(_label):
	pass


func _reset_at(point, target_point):
	raider.position = anchor + Vector3(30, 0, 0)
	observer.position = raider.position + Vector3(0, 0, 3)
	game.battlefield.invalidate()
	guard.issue_manual_order(null)
	await _frames(90)
	guard.position = point
	guard.hp = guard.hp_max
	raider.position = target_point
	raider.hp = raider.hp_max
	observer.position = target_point + Vector3(0, 0, 3)
	game.battlefield.invalidate()
	_start_guard()


func _approach_archive():
	await _reset_at(anchor - Vector3(5, 0, 0), anchor + Vector3(5, 0, 0))
	_check(game.battlefield.is_observed(guard.player, raider), "Outer target is not observed")
	_check(not game.battlefield.can_fire(guard, raider), "Approach fixture is already in range")
	await _frames(20)
	_check(guard.get_node("Movement")._has_destination, "Authored guard never approached")
	await _review("approaching")
	game.hud._toggle_pause()
	var point = guard.position
	var clock = game.simulation_time
	var hp = raider.hp
	var record = guard.program.saved_record.duplicate(true)
	var memory = guard.program.lua_runtime.state_snapshot()
	await _frames(30)
	_check(guard.position == point and raider.hp == hp, "Paused guard moved or fired")
	var builder = Snapshot.new()
	var snapshot = builder.capture(game)
	_check(snapshot != null, "Authored guard snapshot failed")
	if snapshot == null:
		return
	var ids = [builder._reference(guard), builder._reference(raider), builder._reference(observer)]
	var store = FileStore.new()
	var archive = "user://authored-guard-%d.json" % OS.get_process_id()
	_check(store.write_file(archive, snapshot), "Authored guard disk write failed")
	var restore = Restore.new()
	var loaded = await restore.restore(self, store.read_file(archive))
	DirAccess.remove_absolute(archive)
	_check(loaded.ok, "Authored guard disk restore failed: " + loaded.get("error", ""))
	if not loaded.ok:
		game.hud._toggle_pause()
		return
	game = loaded.game
	guard = restore.entities[ids[0]]
	raider = restore.entities[ids[1]]
	observer = restore.entities[ids[2]]
	for player in get_nodes_in_group("players"):
		if player != game._get_human_player():
			player.set_process(false)
	for unit in get_nodes_in_group("units"):
		if unit != guard:
			unit.process_mode = Node.PROCESS_MODE_DISABLED
	_check(paused and game.simulation_time == clock, "Guard disk load lost paused clock")
	_check(
		guard.position == point and guard.program.anchor == anchor,
		"Guard disk load changed assignment/position"
	)
	_check(
		(
			guard.program.saved_record == record
			and guard.program.lua_runtime.state_snapshot() == memory
		),
		"Guard disk load changed source or memory"
	)
	game.hud._toggle_pause()
	await _frames(360)
	_check(raider.hp < hp, "Restored guard never reached firing range")
	_check(
		guard.position.distance_to(anchor - Vector3(5, 0, 0)) > 2,
		"Guard did not physically approach"
	)
	print(
		"PASS: ",
		guard.player.faction,
		" ",
		active_mode,
		" actual approach/fire and exact paused disk restore"
	)


func _observation_bounds():
	await _reset_at(anchor - Vector3(7, 0, 0), anchor + Vector3(5, 0, 0))
	await _frames(3)
	observer.position = anchor - Vector3(20, 0, 0)
	game.battlefield.invalidate()
	_check(
		not game.battlefield.is_observed(guard.player, raider), "Hidden target fixture is visible"
	)
	_check(guard.action._pick_target(anchor, 6, true) == null, "Guard acquired hidden contact")
	guard.program.anchor = null
	await _frames(45)
	_check(
		guard.program.mode == "Waiting" and not guard.get_node("Movement")._has_destination,
		"Missing guard assignment did not wait"
	)
	guard.program.anchor = anchor
	observer.position = raider.position + Vector3(0, 0, 3)
	var blocker = _actor("Barracks", guard.player, anchor)
	blocker.process_mode = Node.PROCESS_MODE_DISABLED
	game.battlefield.invalidate()
	_check(not game.battlefield.has_line_of_fire(guard, raider), "Obstruction fixture is clear")
	_check(guard.action._pick_target(anchor, 6, true) == null, "Guard acquired through obstruction")
	blocker.queue_free()
	await _frames(5)
	await _reset_at(anchor - Vector3(5, 0, 0), anchor + Vector3(30, 0, 0))
	var aircraft = _actor("Helicopter", raider.player, anchor + Vector3(5, 0, 0))
	aircraft.process_mode = Node.PROCESS_MODE_DISABLED
	observer.position = aircraft.position + Vector3(0, 0, 3)
	game.battlefield.invalidate()
	_check(game.battlefield.is_observed(guard.player, aircraft), "Air target fixture is hidden")
	await _frames(20)
	_check(guard.action._pick_target(anchor, 6, true) == null, "Ground guard pursued aircraft")
	aircraft.queue_free()
	await _frames(5)
	print("PASS: hidden/obstructed/unsupported target and absent-area bounds")


func _authority_and_recovery():
	await _reset_at(anchor, anchor + Vector3(4, 0, 0))
	await _frames(30)
	guard.issue_manual_order(
		load("res://source/match/units/actions/Moving.gd").new(guard.program.safe_point)
	)
	await _frames(240)
	_check(guard.program.mode == "Manual", "Guard overrode direct movement")
	_check(
		guard.position.distance_to(guard.program.safe_point) < 1.2,
		"Direct safe-point movement failed"
	)
	guard.hp = guard.hp_max * .2
	_check(guard.program.run(), "Guard did not resume")
	await _frames(60)
	guard.hp = guard.hp_max * .5
	await _frames(90)
	_check(
		guard.program.lua_runtime.state_snapshot().get("retreating", false),
		"Guard lost retreat hysteresis"
	)
	_check(
		guard.position.distance_to(guard.program.safe_point) < 1.2,
		"Partial recovery left safe point"
	)
	var hp = raider.hp
	guard.hp = guard.hp_max
	await _frames(480)
	_check(
		not guard.program.lua_runtime.state_snapshot().get("retreating", true),
		"Guard did not release recovery"
	)
	_check(raider.hp < hp, "Recovered guard did not re-engage")
	print("PASS: direct movement, explicit resume, hysteresis and renewed combat")
