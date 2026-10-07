extends "res://tests/headless/BattlePlanRegression.gd"

var human
var feedback_library
var feedback_factions
var feedback_repairs


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	feedback_library = load("res://source/match/programs/ProgramLibrary.gd")
	feedback_factions = load("res://source/match/FactionCatalog.gd")
	feedback_repairs = load("res://source/match/combat/RepairService.gd")
	for faction in feedback_factions.IDS:
		await _feedback_fixture(faction)
		for role in ["Tank", "AdvancedTank", "CombatRobot", "RepairRobot", "Drone", "Helicopter"]:
			await _missing_support(role)
		if not "--original-only" in OS.get_cmdline_user_args():
			await _authored_and_mobile()
			await _setup_advice()
		print("PROGRAM RECOVERY VERIFIED ", faction)
		paused = false
		game.queue_free()
		await _frames(5)
	for error in errors:
		push_error(error)
	print("Program recovery feedback: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _feedback_fixture(faction):
	await _skirmish(faction, "res://source/match/maps/DesertFrontier.tscn", true)
	human = game._get_human_player()
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	for unit in get_nodes_in_group("units"):
		if unit.movement_speed > 0 or unit.type == "RepairDepot":
			unit.queue_free()
	await _frames(5)


func _missing_support(role):
	var unit = _spawn_for_plan(role, human, Vector3(40, 0, 25))
	unit.program.installed = true
	unit.hp = unit.hp_max * .25
	unit.program.configure(feedback_library.defaults("guard"))
	unit.program.anchor = Vector3(49, 0, 25)
	unit.program.safe_point = unit.global_position_yless
	var hp = unit.hp
	_check(unit.program.run(), "Feedback fixture could not run " + role)
	await _frames(90)
	_check(
		"No recovery support" in unit.program.reason,
		role + ": unserviced retreat hides missing support"
	)
	_check(unit.hp == hp, "Unserviced safe point granted healing")
	if not "--original-only" in OS.get_cmdline_user_args():
		if role == "Tank":
			unit = await _archive_feedback(unit)
		var service = _spawn_for_plan(
			feedback_repairs.facility_for_role(role), human, Vector3(40, 0, 29.5)
		)
		var healed = false
		for frame in 1800:
			await _frames(1)
			healed = healed or unit.hp >= unit.hp_max * .8
			if healed and unit.position.distance_to(Vector3(49, 0, 25)) < 2:
				break
		_check(healed, role + ": new support did not provide actual healing")
		_check(
			unit.position.distance_to(Vector3(49, 0, 25)) < 2,
			role + ": recovery did not return to assignment"
		)
		service.queue_free()
	unit.queue_free()
	await _frames(5)


func _authored_and_mobile():
	var helper = load("res://source/match/programs/RecoveryAdvice.gd")
	var visual = load("res://source/match/programs/VisualRules.gd")
	var sources = [
		(
			"return function(ctx,m) return {intent={kind='move', "
			+ "assignment=ctx.self.hp / ctx.self.hp_max < 0.8 and 'safe' or 'anchor', "
			+ "status='Authored withdrawal.'},state=m} end"
		),
		visual.compile(visual.starter(1)).source
	]
	for source in sources:
		var unit = _spawn_for_plan("Tank", human, Vector3(40, 0, 25))
		unit.program.installed = true
		unit.hp = unit.hp_max * .25
		_check(unit.program.configure_lua(source).ok, "Authored recovery fixture failed to compile")
		unit.program.anchor = Vector3(49, 0, 25)
		unit.program.safe_point = unit.global_position_yless
		unit.program.run()
		await _frames(90)
		_check(
			"No recovery support" in unit.program.reason,
			"Authored safe-point arrival hid missing service"
		)
		game.hud._toggle_pause()
		var hp = unit.hp
		var action = unit.action
		var funds = Vector2i(human.resource_a, human.resource_b)
		var point = unit.program.safe_point
		for sample in 5:
			helper.waiting(unit)
		await _frames(15)
		_check(
			(
				unit.action == action
				and unit.hp == hp
				and unit.program.safe_point == point
				and Vector2i(human.resource_a, human.resource_b) == funds
			),
			"Paused recovery hint changed gameplay"
		)
		game.hud._toggle_pause()
		var robot = _spawn_for_plan("RepairRobot", human, Vector3(42, 0, 25))
		await _frames(120)
		_check(unit.hp > hp, "Stationary mobile support failed to heal")
		_check(
			not "No recovery support" in unit.program.reason,
			"Mobile support did not clear missing-service warning"
		)
		robot.issue_manual_order(
			load("res://source/match/units/actions/Moving.gd").new(Vector3(53, 0, 25))
		)
		await _frames(120)
		_check(
			"No recovery support" in unit.program.reason,
			"Departed mobile support remained advertised"
		)
		unit.issue_manual_order(null)
		await _frames(45)
		_check(
			unit.program.mode == "Manual" and not "No recovery support" in unit.program.reason,
			"Recovery hint overrode manual control"
		)
		unit.queue_free()
		robot.queue_free()
		await _frames(10)


func _setup_advice():
	var opening = load("res://source/match/SkirmishOpening.gd")
	for role in ["Tank", "Drone", "RepairRobot"]:
		var unit = _spawn_for_plan(role, human, Vector3(40, 0, 25))
		unit.program.installed = true
		var advice = opening.programs(human, [unit], unit)
		var preset = {"Tank": "Guard area", "Drone": "Scout route", "RepairRobot": "Service area"}[role]
		_check(preset in advice.description, "First-program advice ignored the selected role")
		_check("alone does not heal" in advice.description, "First program omitted missing support")
		var facility = _spawn_for_plan(
			feedback_repairs.facility_for_role(role), human, Vector3(40, 0, 29.5)
		)
		advice = opening.programs(human, [unit, facility], unit)
		_check(
			"Set the safe point on your" in advice.description,
			"Existing service omitted from setup advice"
		)
		facility.mark_as_under_construction()
		advice = opening.programs(human, [unit, facility], unit)
		_check(
			"alone does not heal" in advice.description, "Unfinished service advertised as ready"
		)
		facility.queue_free()
		unit.queue_free()
		await _frames(10)


func _archive_feedback(unit):
	game.hud._toggle_pause()
	var capture = Snapshot.new()
	var snapshot = capture.capture(game)
	var id = capture._reference(unit)
	var reason = unit.program.reason
	var hp = unit.hp
	var clock = game.simulation_time
	var file = "user://program-recovery-feedback-%d.json" % OS.get_process_id()
	_check(FileStore.new().write_file(file, snapshot), "Recovery feedback archive write failed")
	var restore = Restore.new()
	var loaded = await restore.restore(self, FileStore.new().read_file(file))
	DirAccess.remove_absolute(file)
	_check(loaded.ok, "Recovery feedback archive restore failed")
	game = loaded.game
	human = game._get_human_player()
	unit = restore.entities[id]
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	await _frames(15)
	_check(
		(
			paused
			and unit.hp == hp
			and is_equal_approx(game.simulation_time, clock)
			and unit.program.reason == reason
		),
		"Paused restore changed recovery feedback or state"
	)
	game.hud._toggle_pause()
	return unit
