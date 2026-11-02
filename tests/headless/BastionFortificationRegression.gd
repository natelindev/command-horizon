extends "res://tests/headless/Skirmish.gd"

var game
var human
var physical
var energy
var rules


func _run():
	Engine.physics_ticks_per_second = 60
	factions = load("res://source/match/FactionCatalog.gd")
	constants = root.get_node("Constants")
	rules = load("res://source/match/combat/CombatRules.gd")
	root.get_node("SaveManager").autosaves_enabled = false
	_descriptions()
	var settings = _settings("bastion", "frontier", true)
	settings.map_path = "res://source/match/maps/PlainAndSimple.tscn"
	settings.visibility = settings.Visibility.FULL
	var third = settings.players[1].duplicate()
	third.faction = "helix"
	settings.players.append(third)
	settings.players.append(settings.players[1].duplicate())
	game = await _start(settings)
	game.set_physics_process(false)
	human = game._get_human_player()
	physical = get_nodes_in_group("players").filter(func(side): return side.faction == "frontier")[0]
	energy = get_nodes_in_group("players").filter(func(side): return side.faction == "helix")[0]
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	for unit in get_nodes_in_group("units"):
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	if "--native-unit-state" in OS.get_cmdline_user_args():
		_check(
			_unit(human, "CommandCenter")._native_state != null,
			"Fortification fixture disabled native state"
		)
	game.repair_service.set_physics_process(false)
	var target = _spawn("PowerPlant", human, Vector3(25, 0, 25))
	var shell_source = null
	for role in ["Infantry", "Tank", "RocketInfantry", "SniperInfantry", "AssaultInfantry"]:
		var shooter = _spawn(role, physical, Vector3(25, 0, 22))
		await _frames(4)
		var expected = (
			shooter.attack_damage * rules.MULTIPLIERS[rules.profile_for(shooter)][3] * .85
		)
		var before = target.hp
		target.receive_weapon_hit(shooter)
		_check(
			is_equal_approx(before - target.hp, expected),
			"Bastion physical resistance failed for " + role
		)
		if role == "Tank":
			shell_source = shooter
		if role == "Infantry":
			_check(
				expected < 1.0 and not is_zero_approx(expected),
				"Fractional structural damage fixture lost precision"
			)
			var shot = load("res://source/match/combat/Shot.gd").from(
				shooter, shooter.global_position
			)
			shooter.queue_free()
			await _frames(2)
			_check(
				is_equal_approx(rules._damage(shot, target), expected),
				"Frozen ballistic facts changed after shooter death"
			)
	for role in ["Infantry", "Tank", "AdvancedTank", "RocketInfantry", "Hero", "CombatRobot"]:
		var shooter = _spawn(role, energy, Vector3(25, 0, 22))
		await _frames(4)
		var facts = rules.damage_facts(shooter)
		var profile = "Anti-armor lance" if role == "CombatRobot" else rules.profile_for(shooter)
		var expected = shooter.attack_damage * rules.MULTIPLIERS[profile][3]
		_check(not facts.ballistic, "Energy flight solver classified as ballistic: " + role)
		_check(
			is_equal_approx(rules.damage_with_facts(facts, target), expected),
			"Bastion incorrectly resists energy: " + role
		)
	var truck = _spawn("Tank", human, Vector3(30, 0, 25))
	await _frames(4)
	_check(
		is_equal_approx(
			rules._damage(shell_source, truck),
			(
				shell_source.attack_damage
				* rules.MULTIPLIERS[rules.profile_for(shell_source)][rules.armor_for(truck.type)]
			)
		),
		"Mobile armor incorrectly gained building resistance"
	)
	await _maintenance()
	await _archive(target, shell_source)
	paused = false
	game.queue_free()
	await _frames(6)
	for error in _errors:
		push_error(error)
	print("Bastion fortification and free maintenance: %d failures" % _errors.size())
	await root.get_node("Globals").quit_game(0 if _errors.is_empty() else 1)


func _descriptions():
	var language = TranslationServer.get_locale()
	for locale in ["en", "zh_CN"]:
		TranslationServer.set_locale(locale)
		_check(
			factions.description("bastion", "PowerPlant").contains("15%"),
			"Structure tooltip omits innate resistance"
		)
		var depot = factions.description("bastion", "RepairDepot")
		_check(
			depot.contains("5 米" if locale == "zh_CN" else "5 m"),
			"Depot tooltip omits translated perimeter range"
		)
		if locale == "zh_CN":
			_check(
				depot.contains("免费") and not depot.contains("Automatically repairs"),
				"New maintenance tooltip is not localized"
			)
	TranslationServer.set_locale(language)


func _spawn(role, side, point):
	var unit = load(factions.Bastion.scene_path(role)).instantiate()
	game._setup_and_spawn_unit(unit, Transform3D(Basis(), point), side, false)
	unit.process_mode = Node.PROCESS_MODE_DISABLED
	return unit


func _maintenance():
	var depot = _spawn("RepairDepot", human, Vector3(25, 0, 31))
	var tank = _spawn("Tank", human, Vector3(29.5, 0, 31))
	var rover = _spawn("RepairRobot", human, Vector3(25, 0, 19))
	var mobile = _spawn("Tank", human, Vector3(27, 0, 19))
	var outside = _spawn("Tank", human, Vector3(33, 0, 31))
	await _frames(45)
	for unit in [depot, tank, rover, mobile, outside]:
		unit.process_mode = Node.PROCESS_MODE_INHERIT
		unit.set_physics_process(false)
		unit.set_process(false)
		if unit.has_node("Movement"):
			unit.get_node("Movement").stop()
			unit.get_node("Movement").velocity = Vector3.ZERO
	for unit in [tank, mobile, outside]:
		unit.hp = unit.hp_max * .5
		unit.last_enemy_damage_time = game.simulation_time - 5.0
	game.battlefield.invalidate()
	var resources = Vector2i(human.resource_a, human.resource_b)
	var before = Vector3(tank.hp, mobile.hp, outside.hp)
	game.repair_service.set_physics_process(true)
	await _frames(120)
	_check(
		tank.hp > before.x, "Bastion depot failed to repair adjacent armor outside its service bay"
	)
	print(
		"Maintenance rover=",
		rover.global_position,
		" target=",
		mobile.global_position,
		" action=",
		rover.action,
		" stationary=",
		load("res://source/match/combat/RepairService.gd").stationary(rover),
		" processing=",
		rover.can_process(),
		" slots=",
		rover.get_meta("service_used", 0),
		" health=",
		before.y,
		"->",
		mobile.hp
	)
	_check(mobile.hp > before.y, "Mobile support failed to repair adjacent armor")
	_check(outside.hp == before.z, "Depot aura reached beyond its perimeter")
	_check(
		Vector2i(human.resource_a, human.resource_b) == resources,
		"Perimeter/mobile maintenance consumed resources"
	)
	paused = true
	before = Vector3(tank.hp, mobile.hp, outside.hp)
	await _frames(30)
	_check(Vector3(tank.hp, mobile.hp, outside.hp) == before, "Paused maintenance advanced")
	paused = false
	game.repair_service.set_physics_process(false)
	for unit in [depot, tank, rover, mobile, outside]:
		unit.process_mode = Node.PROCESS_MODE_DISABLED


func _archive(target, shooter):
	paused = true
	var capture = load("res://source/match/saves/MatchSnapshot.gd").new()
	var saved = capture.capture(game)
	_check(saved != null, "Fortification capture failed: " + capture.error)
	if saved == null:
		return
	var target_id = capture._reference(target)
	var shooter_id = capture._reference(shooter)
	var hp = target.hp
	var damage = rules._damage(shooter, target)
	var restore = load("res://source/match/saves/MatchRestore.gd").new()
	var loaded = await restore.restore(self, saved)
	_check(loaded.ok, "Fortification restore failed: " + loaded.get("error", ""))
	if not loaded.ok:
		return
	game = loaded.game
	target = restore.entities[target_id]
	shooter = restore.entities[shooter_id]
	_check(target.hp == hp, "Fractional structural health changed across restore")
	_check(
		is_equal_approx(rules._damage(shooter, target), damage),
		"Restored Bastion structure lost innate resistance"
	)
	var before = target.hp
	await _frames(20)
	_check(target.hp == before, "Paused restored structure advanced combat")
