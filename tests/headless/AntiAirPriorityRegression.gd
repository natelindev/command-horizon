extends "res://tests/headless/SaveRestoreEdges.gd"

var turret
var ground
var aircraft
var owner


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	for faction in ["bastion", "helix", "frontier"]:
		await _skirmish(faction)
		_freeze()
		owner = game._get_human_player()
		var enemy = get_nodes_in_group("players").filter(func(side): return side != owner)[0]
		turret = _place("AntiAirTurret", owner, Vector3(31, 0, 20))
		ground = _place("Tank", enemy, Vector3(37, 0, 20))
		aircraft = _place("Helicopter", enemy, Vector3(60, 3, 20))
		# An empty helicopter is less threatening than the nearby armed tank;
		# air priority must override the ordinary threat and distance scores.
		aircraft.rockets = 0
		await _frames(10)
		turret.process_mode = Node.PROCESS_MODE_PAUSABLE
		_check(await _aims_at(ground), "AA turret did not acquire a ground fallback")
		game.projectile_system.clear()
		var reload_at = int(game.simulation_time * 1000) + 2000
		turret.set_meta("next_attack_availability_time", reload_at)
		aircraft.global_position = Vector3(39, 3, 24)
		game.battlefield.invalidate()
		_check(
			game.battlefield.automatic_target(turret) == aircraft,
			"AA turret preferred a closer armed ground unit over an aircraft"
		)
		var attack = turret.action._sub_action
		var shot = attack._shot if "_shot" in attack else attack
		var fired = game.projectile_system.rounds_fired
		shot._hit_target()
		_check(
			game.projectile_system.rounds_fired == fired,
			"A ground shot slipped through before the next air-priority scan"
		)
		var ground_hp = ground.hp
		var air_hp = aircraft.hp
		_check(await _aims_at(aircraft), "AA turret did not preempt its ground attack")
		_check(
			turret.get_meta("next_attack_availability_time") == reload_at,
			"Switching to air reset the turret reload"
		)
		for _tick in 180:
			await _frames(1)
			if aircraft.hp < air_hp:
				break
		_check(aircraft.hp < air_hp, "Retargeted turret did not hit the aircraft")
		_check(ground.hp == ground_hp, "Retargeted turret kept firing on the ground unit")
		owner.technology.completed = ["weapons_1", "dual_purpose_aa"]
		_check(
			game.battlefield.automatic_target(turret) == aircraft,
			"Full ground damage removed turret air priority"
		)
		aircraft.global_position = Vector3(60, 3, 20)
		game.battlefield.invalidate()
		_check(await _aims_at(ground), "Out-of-range aircraft prevented ground fallback")
		game.projectile_system.clear()
		await _archive_and_retarget()
		paused = false
		game.queue_free()
		await _frames(5)
	for message in errors:
		push_error(message)
	print("AA turret air priority, ground fallback and restore: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _freeze():
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	for unit in get_nodes_in_group("units"):
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	game.repair_service.set_physics_process(false)


func _place(role, player, point):
	var unit = load("res://source/match/units/%s.tscn" % role).instantiate()
	game._setup_and_spawn_unit(unit, Transform3D(Basis(), point), player, false)
	unit.process_mode = Node.PROCESS_MODE_DISABLED
	return unit


func _aims_at(target):
	for _tick in 60:
		await _frames(1)
		if turret.aim_target == target:
			return true
	return false


func _archive_and_retarget():
	paused = true
	turret.set_meta("next_attack_availability_time", int(game.simulation_time * 1000) + 4000)
	var builder = Snapshot.new()
	var saved = builder.capture(game)
	_check(saved != null, "Turret ground-attack snapshot failed: " + builder.error)
	if saved == null:
		return
	var ids = [builder._reference(turret), builder._reference(ground), builder._reference(aircraft)]
	var archive = "user://aa-priority-%d.json" % OS.get_process_id()
	_check(FileStore.new().write_file(archive, saved), "AA turret archive write failed")
	var restorer = Restore.new()
	var loaded = await restorer.restore(self, FileStore.new().read_file(archive))
	DirAccess.remove_absolute(archive)
	_check(loaded.ok, "AA turret archive failed: " + loaded.get("error", ""))
	if not loaded.ok:
		return
	game = loaded.game
	_freeze()
	turret = restorer.entities[ids[0]]
	ground = restorer.entities[ids[1]]
	aircraft = restorer.entities[ids[2]]
	_check(turret.aim_target == ground, "Restored turret lost its ground attack")
	_check(
		turret.action._timer.timeout.is_connected(turret.action._on_timer_timeout),
		"Restored turret stopped watching for aircraft"
	)
	var rules = load("res://source/match/combat/CombatRules.gd")
	_check(
		is_equal_approx(rules.damage(turret, ground), turret.attack_damage),
		"Restored turret lost full ground damage research"
	)
	var reload_at = turret.get_meta("next_attack_availability_time")
	aircraft.global_position = Vector3(39, 3, 24)
	game.battlefield.invalidate()
	turret.process_mode = Node.PROCESS_MODE_PAUSABLE
	paused = false
	_check(await _aims_at(aircraft), "Restored turret did not prioritize arriving aircraft")
	_check(
		turret.get_meta("next_attack_availability_time") == reload_at,
		"Restored turret bypassed reload when retargeting"
	)
	aircraft.queue_free()
	_check(await _aims_at(ground), "Destroyed aircraft prevented ground fallback")
