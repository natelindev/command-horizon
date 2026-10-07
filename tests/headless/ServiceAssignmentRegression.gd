extends "res://tests/headless/AuthoredRecoveryRegression.gd"

var factions = ["bastion", "helix", "frontier"]
var modes = ["preset", "lua", "visual"]
var roles = ["Tank", "AdvancedTank", "CombatRobot", "RepairRobot", "Drone", "Helicopter"]
var eligibility_only = false
var case_label = ""
var repairs


func _initialize():
	recovery_deadline = Time.get_ticks_msec() + 480000
	_run.call_deferred()


func _run():
	_load_authoring()
	preset_library = load("res://source/match/programs/ProgramLibrary.gd")
	repairs = load("res://source/match/combat/RepairService.gd")
	eligibility_only = "--eligibility-only" in OS.get_cmdline_user_args()
	root.get_node("SaveManager").autosaves_enabled = false
	for faction in factions:
		await _skirmish(faction)
		for side in get_nodes_in_group("players"):
			side.set_process(false)
		for unit in get_nodes_in_group("units"):
			if unit.movement_speed > 0 or unit.type == "RepairDepot":
				unit.queue_free()
		await _frames(5)
		for mode in modes:
			for role in roles:
				case_label = "%s-%s-%s" % [faction, mode, role]
				await _service_assignment(mode, role)
		paused = false
		game.queue_free()
		await _frames(5)
	for message in errors:
		push_error(message)
	print("Service assignment: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _service_assignment(mode, role):
	var service = _preset_actor(repairs.facility_for_role(role), Vector3(32, 0, 25))
	var unit = _preset_actor(role, Vector3(43, 0, 25))
	await _frames(90)
	game.hud.pause_after_load()
	unit.hp = unit.hp_max * .35
	unit.program.installed = true
	if mode == "preset":
		var config = preset_library.defaults("guard")
		config.retreat = 40
		config["return"] = 85
		unit.program.configure(config)
	else:
		_check(
			application.apply(_recovery_entry(mode, role), [unit], unit.player).ok,
			"Recovery source could not apply"
		)
	unit.program.anchor = Vector3(43, 0, 25)
	unit.program.safe_point = Vector3(47, 0, 25)
	if (
		mode == "preset"
		and unit.movement_domain == root.get_node("Constants").Match.Navigation.Domain.TERRAIN
	):
		await _rejected_points(unit, service)
	var before = _authority(unit)
	var accepted = await _assign_point("safe", [unit], service.global_position_yless)
	_check(accepted, case_label + ": completed matching service safe point rejected")
	if not accepted:
		game.hud.cancel_map_assignment()
		await _close_service(unit, service)
		return
	_check(
		unit.program.safe_point.distance_to(service.global_position_yless) < .01,
		"Service click changed the assigned point"
	)
	_check(unit.program.mode == "Manual", "Service assignment implicitly resumed the program")
	_check(
		(
			[
				unit.hp,
				unit.position,
				unit.player.resource_a,
				unit.player.resource_b,
				game.simulation_time,
				paused,
				unit.program.anchor,
				unit.program.lua_source
			]
			== before.slice(0, 8)
		),
		"Service assignment changed health, location, funds, time or source"
	)
	if eligibility_only:
		await _close_service(unit, service)
		return
	_check(unit.program.run(), "Explicit recovery Resume failed")
	await _review_service_assignment(unit, service, "assigned")
	var start = game.simulation_time
	var healed = false
	var resumed = false
	var blocked = false
	var archived = false
	game.hud._toggle_pause()
	for frame in 2400:
		await _frames(1)
		blocked = blocked or unit.program.mode == "Blocked"
		healed = healed or unit.hp >= unit.hp_max * .85
		if role == "Tank" and not archived and unit.hp > unit.hp_max * .4 and not healed:
			game.hud.pause_after_load()
			await _review_service_assignment(unit, service, "healing")
			var restored = await _service_assignment_reload(unit, service)
			unit = restored[0]
			service = restored[1]
			archived = true
			game.hud._toggle_pause()
		resumed = healed and unit.global_position_yless.distance_to(unit.program.anchor) < 3
		if resumed:
			break
	_check(
		healed and resumed and not blocked, case_label + ": assigned service failed healing/return"
	)
	_check(role != "Tank" or archived, "Recovery missed the partial-healing archive")
	game.hud.pause_after_load()
	await _review_service_assignment(unit, service, "returned")
	print(
		"SERVICE ASSIGNMENT ",
		case_label,
		" healed=",
		healed,
		" returned=",
		resumed,
		" blocked=",
		blocked,
		" seconds=",
		game.simulation_time - start
	)
	await _close_service(unit, service)


func _authority(unit):
	return [
		unit.hp,
		unit.position,
		unit.player.resource_a,
		unit.player.resource_b,
		game.simulation_time,
		paused,
		unit.program.anchor,
		unit.program.lua_source,
		unit.program.safe_point,
		unit.program.mode,
		unit.action,
		unit.manual_orders.pending.duplicate(true)
	]


func _rejected_points(unit, service):
	for kind in ["anchor", "patrol"]:
		var before = _authority(unit)
		_check(
			not await _assign_point(kind, [unit], service.global_position_yless),
			"Service exception admitted a ground " + kind
		)
		_check(_authority(unit) == before, "Rejected service-center assignment changed authority")
	service._construction_progress = .5
	var before = _authority(unit)
	_check(
		not await _assign_point("safe", [unit], service.global_position_yless),
		"Unfinished service accepted"
	)
	_check(_authority(unit) == before, "Unfinished rejection changed authority")
	service._construction_progress = 1.0
	var hq = _units(unit.player, "CommandCenter")[0]
	before = _authority(unit)
	_check(
		not await _assign_point("safe", [unit], hq.global_position_yless),
		"Non-healing HQ accepted as ground safe point"
	)
	_check(_authority(unit) == before, "Unsuitable service rejection changed authority")
	game.hud.cancel_map_assignment()


func _assign_point(kind, units, point):
	game.hud.arm_program_assignment(kind, units)
	return game.hud.accept_program_assignment(point, null)


func _service_assignment_reload(unit, service):
	var before = _authority(unit)
	var builder = Snapshot.new()
	var data = builder.capture(game)
	var ids = [builder._reference(unit), builder._reference(service)]
	var file = "user://service-assignment-%d.json" % OS.get_process_id()
	_check(FileStore.new().write_file(file, data), "Service-assignment disk write failed")
	var restore = Restore.new()
	var loaded = await restore.restore(self, FileStore.new().read_file(file))
	DirAccess.remove_absolute(file)
	_check(loaded.ok, "Service-assignment disk restore failed")
	game = loaded.game
	unit = restore.entities[ids[0]]
	service = restore.entities[ids[1]]
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	await _frames(20)
	_check(
		_authority(unit).slice(0, 10) == before.slice(0, 10),
		"Paused recovery load changed health, assignment, source or status"
	)
	return [unit, service]


func _close_service(unit, service):
	paused = false
	unit.queue_free()
	service.queue_free()
	await _frames(90)


func _review_service_assignment(_unit, _service, _stage):
	return
