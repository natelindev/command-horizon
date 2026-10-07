extends "res://tests/headless/SaveRestoreEdges.gd"

var recovery_deadline = 0
var preset_library


func _initialize():
	recovery_deadline = Time.get_ticks_msec() + 240000
	_run.call_deferred()


func _process(_delta):
	if Time.get_ticks_msec() > recovery_deadline:
		push_error("Preset recovery wall-clock timeout")
		quit(1)
	return false


func _run():
	preset_library = load("res://source/match/programs/ProgramLibrary.gd")
	root.get_node("SaveManager").autosaves_enabled = false
	for faction in ["bastion", "helix"]:
		await _skirmish(faction)
		for player in get_nodes_in_group("players"):
			player.set_process(false)
		for unit in get_nodes_in_group("units"):
			if unit.movement_speed > 0:
				unit.queue_free()
		await _frames(5)
		for role in ["Tank", "AdvancedTank", "CombatRobot", "RepairRobot", "Drone", "Helicopter"]:
			await _preset_service(role)
		await _service_boundary()
		await _point_and_manual_authority()
		await _unavailable_service()
		game.queue_free()
		await _frames(5)
	for error in errors:
		push_error(error)
	print("Preset facility recovery: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _preset_service(role):
	var human = game._get_human_player()
	var repairs = load("res://source/match/combat/RepairService.gd")
	var service = _preset_actor(repairs.facility_for_role(role), Vector3(32, 0, 25))
	var unit = _preset_actor(role, Vector3(43, 0, 25))
	await _frames(120)
	unit.hp = unit.hp_max * .35
	unit.program.installed = true
	var config = preset_library.defaults("guard")
	config.retreat = 40
	config["return"] = 85
	unit.program.configure(config, "Facility recovery check")
	unit.program.anchor = Vector3(43, 0, 25)
	unit.program.safe_point = service.global_position_yless
	_check(unit.program.run(), "Preset recovery fixture refused to run")
	var healed = false
	var resumed = false
	var blocked = false
	for frame in 2400:
		await physics_frame
		if role == "Tank" and frame == 299:
			await _review_service(unit, service, "healing")
			var restored = await _recovery_archive(unit, service)
			unit = restored[0]
			service = restored[1]
			human = game._get_human_player()
		blocked = blocked or unit.program.mode == "Blocked"
		healed = healed or unit.hp >= unit.hp_max * .85
		resumed = resumed or (healed and unit.position.distance_to(Vector3(43, 0, 25)) < 3)
	_check(healed, "%s %s failed actual facility healing" % [human.faction, role])
	_check(not blocked, "%s %s falsely blocked at reachable service" % [human.faction, role])
	_check(resumed, "%s %s did not resume its assignment after healing" % [human.faction, role])
	if role == "Tank":
		await _review_service(unit, service, "resumed")
	print(
		"PRESET RECOVERY ",
		human.faction,
		" ",
		role,
		" healed=",
		healed,
		" resumed=",
		resumed,
		" blocked=",
		blocked,
		" health=",
		unit.hp / unit.hp_max,
		" reason=",
		unit.program.reason
	)
	unit.queue_free()
	service.queue_free()
	await _frames(90)


func _recovery_archive(unit, service):
	_check(unit.program.reason.begins_with("Recovering:"), "Archive missed facility recovery")
	_check(unit.hp < unit.hp_max * .85, "Archive missed partial healing")
	paused = true
	var position = unit.position
	var health = unit.hp
	var point = unit.program.safe_point
	var snapshotter = Snapshot.new()
	var snapshot = snapshotter.capture(game)
	var ids = [snapshotter._reference(unit), snapshotter._reference(service)]
	var disk = "user://preset-recovery-%d.json" % OS.get_process_id()
	_check(FileStore.new().write_file(disk, snapshot), "Recovery disk write failed")
	var restore = Restore.new()
	var loaded = await restore.restore(self, FileStore.new().read_file(disk))
	DirAccess.remove_absolute(disk)
	_check(loaded.ok, "Recovery disk restore failed")
	if not loaded.ok:
		paused = false
		return [unit, service]
	game = loaded.game
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	unit = restore.entities[ids[0]]
	service = restore.entities[ids[1]]
	await _frames(30)
	_check(unit.position == position and unit.hp == health, "Paused recovery archive advanced")
	_check(
		unit.program.safe_point == point and unit.action._retreating,
		"Recovery archive lost assignment or hysteresis"
	)
	paused = false
	return [unit, service]


func _service_boundary():
	var service = _preset_actor("RepairDepot", Vector3(55, 0, 25))
	var unit = _preset_actor("Tank", Vector3(59.75, 0, 25))
	await _frames(120)
	var start = unit.position
	_check(
		start.distance_to(service.position) > 4.6 and start.distance_to(service.position) <= 5.0,
		"Service boundary fixture was displaced"
	)
	unit.hp = unit.hp_max * .35
	unit.program.installed = true
	var config = preset_library.defaults("guard")
	config.retreat = 40
	config["return"] = 85
	unit.program.configure(config)
	unit.program.anchor = Vector3(65, 0, 25)
	unit.program.safe_point = service.global_position_yless
	_check(unit.program.run(), "Boundary fixture refused to run")
	var excursion = 0.0
	for frame in 180:
		await physics_frame
		excursion = maxf(excursion, unit.position.distance_to(start))
	_check(unit.hp > unit.hp_max * .4, "Unit inside service range did not heal")
	_check(excursion < .05, "Unit already inside service range chased the inaccessible center")
	print(
		"SERVICE BOUNDARY ",
		unit.player.faction,
		" excursion=",
		excursion,
		" health=",
		unit.hp / unit.hp_max
	)
	unit.queue_free()
	service.queue_free()
	await _frames(90)


func _point_and_manual_authority():
	var service = _preset_actor("RepairDepot", Vector3(55, 0, 25))
	var unit = _preset_actor("Tank", Vector3(51, 0, 25))
	await _frames(120)
	unit.hp = unit.hp_max * .35
	unit.program.installed = true
	var config = preset_library.defaults("guard")
	config.retreat = 40
	config["return"] = 85
	unit.program.configure(config)
	unit.program.anchor = Vector3(43, 0, 25)
	# A nearby ground point outside the structure stays an exact player assignment.
	unit.program.safe_point = service.position + Vector3(4, 0, 0)
	_check(unit.program.run(), "Ground-point fixture refused to run")
	var saw_recovery = false
	var closest = INF
	for frame in 480:
		await physics_frame
		saw_recovery = saw_recovery or unit.program.reason.begins_with("Recovering:")
		closest = minf(closest, unit.global_position_yless.distance_to(unit.program.safe_point))
	_check(not saw_recovery and closest < 1.0, "Nearby service replaced the chosen ground point")
	unit.issue_manual_order(null)
	unit.hp = unit.hp_max * .35
	unit.program.safe_point = service.global_position_yless
	_check(unit.program.run(), "Manual authority fixture refused to resume")
	await _frames(180)
	_check(unit.program.reason.begins_with("Recovering:"), "Manual fixture did not reach service")
	unit.issue_manual_order(null)
	var stopped = unit.position
	await _frames(1200)
	_check(unit.hp >= unit.hp_max * .99, "Manual stop prevented passive service")
	_check(
		unit.program.mode == "Manual" and unit.position.distance_to(stopped) < .05,
		"Healing overrode manual Stop"
	)
	unit.manual_orders.submit({"kind": "move", "point": Vector3(65, 0, 25)})
	await _frames(180)
	_check(
		unit.position.distance_to(stopped) > 2 and unit.program.mode == "Manual",
		"Recovery retained control after a manual move"
	)
	print(
		"PASS: ",
		game._get_human_player().faction,
		" exact ground point, passive service after Stop and manual replacement"
	)
	unit.queue_free()
	service.queue_free()
	await _frames(90)


func _review_service(_unit, _service, _label):
	return true


func _unavailable_service():
	var human = game._get_human_player()
	var enemy = get_nodes_in_group("players").filter(func(player): return player != human)[0]
	for kind in ["wrong", "unfinished", "enemy", "removed"]:
		var service = _preset_actor(
			"Barracks" if kind == "wrong" else "RepairDepot",
			Vector3(55, 0, 25),
			enemy if kind == "enemy" else human
		)
		if kind == "unfinished":
			service.mark_as_under_construction()
		var unit = _preset_actor("Tank", Vector3(59.4, 0, 25))
		await _frames(120)
		unit.hp = unit.hp_max * .35
		unit.program.installed = true
		var config = preset_library.defaults("guard")
		config.retreat = 40
		config["return"] = 85
		unit.program.configure(config)
		unit.program.anchor = Vector3(43, 0, 25)
		unit.program.safe_point = service.global_position_yless
		_check(unit.program.run(), "Unavailable-service fixture refused to run")
		if kind == "removed":
			await _frames(90)
			_check(
				unit.program.reason.begins_with("Recovering:"),
				"Removal fixture never used real service"
			)
			service.queue_free()
			await _frames(1)
		var health = unit.hp
		var reported_recovery = false
		for frame in 480:
			await physics_frame
			if frame >= 30:
				reported_recovery = (
					reported_recovery or unit.program.reason.begins_with("Recovering:")
				)
		_check(unit.hp == health, "Unavailable service granted healing: " + kind)
		_check(not reported_recovery, "Unavailable service reported recovery: " + kind)
		_check(
			unit.program.safe_point == Vector3(55, 0, 25),
			"Unavailable service changed the assigned safe point"
		)
		unit.queue_free()
		if is_instance_valid(service):
			service.queue_free()
		await _frames(90)
	print(
		"PASS: ",
		human.faction,
		" wrong-role, unfinished, enemy and removed service preserve assignment"
	)


func _preset_actor(role, point, owner = null):
	var unit = load("res://source/match/units/%s.tscn" % role).instantiate()
	game._setup_and_spawn_unit(
		unit,
		Transform3D(Basis(), point),
		owner if owner != null else game._get_human_player(),
		false
	)
	return unit
