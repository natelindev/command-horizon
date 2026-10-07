extends SceneTree
## Observational probe, not a balance benchmark. Run at normal time scale.

const Catalog = preload("res://source/match/BastionCatalog.gd")
var _game = null
var _human = null
var _report = {"scenario": "Bastion default harvest; enemy processing disabled", "samples": []}


func _initialize():
	call_deferred("_run")


func _run():
	seed(20261001)
	root.get_node("FeatureFlags").handle_match_end = false
	_game = load("res://source/match/BastionDemo.tscn").instantiate()
	root.add_child(_game)
	current_scene = _game
	_human = _game._get_human_player()
	_game.get_node("IsometricCamera3D").set_physics_process(false)
	for player in get_nodes_in_group("players"):
		if player != _human:
			player.process_mode = Node.PROCESS_MODE_DISABLED
	_sample(0)
	for second in [30, 60]:
		await create_timer(30.0, false).timeout
		_sample(second)
		print("Economy sample: ", _report.samples.back())
	for unit in _human.get_children():
		if "action" in unit:
			unit.action = null
			var movement = unit.find_child("Movement")
			if movement != null:
				movement.stop()
	var tank = _unit("Tank")
	var robot = _unit("RepairRobot")
	var depot = _unit("RepairDepot")
	# Isolate the target from every other healer, then compare one and two robots.
	tank.global_position = Vector3(40, 0, 10)
	robot.global_position = Vector3(41.5, 0, 10)
	depot.global_position = Vector3(5, 0, 5)
	robot.set_process(false)
	tank.hp = 20
	robot._process(0.51)
	_report.single_robot_hp_per_tick = tank.hp - 20
	var second_robot = load(Catalog.scene_path("RepairRobot")).instantiate()
	_game._setup_and_spawn_unit(
		second_robot, Transform3D(Basis(), Vector3(40, 0, 11.5)), _human, false
	)
	second_robot.set_process(false)
	tank.hp = 20
	robot._process(0.51)
	second_robot._process(0.51)
	_report.two_robots_hp_per_tick = tank.hp - 20
	depot.global_position = Vector3(40, 0, 6)
	depot.set_process(false)
	tank.hp = 20
	robot._process(0.51)
	depot._process(0.51)
	_report.robot_and_depot_hp_per_tick = tank.hp - 20
	_report.repair_method = "Explicit 0.51s update per healer; no combat, no resource spending"
	_report.tank_nominal_dps = float(tank.attack_damage) / tank.attack_interval
	_report.power_supply_demand = str(_human.power_totals())
	_report.unit_cap = Catalog.POPULATION_LIMIT
	_report.godot = Engine.get_version_info().string
	var directory = "res://docs/playtests/2026-10-01"
	DirAccess.make_dir_recursive_absolute(directory)
	var output = FileAccess.open(directory + "/design-probe.json", FileAccess.WRITE)
	assert(output != null)
	output.store_string(JSON.stringify(_report, "\t") + "\n")
	output.close()
	print("REPORT: ", JSON.stringify(_report))
	_game.queue_free()
	await process_frame
	await process_frame
	quit()


func _sample(second):
	var workers = []
	for unit in _human.get_children():
		if "type" in unit and unit.type == "Worker":
			(
				workers
				. append(
					{
						"cargo_materials": unit.resource_a,
						"cargo_electronics": unit.resource_b,
						"action": str(unit.action),
					}
				)
			)
	(
		_report
		. samples
		. append(
			{
				"simulation_seconds": second,
				"materials": _human.resource_a,
				"electronics": _human.resource_b,
				"workers": workers,
			}
		)
	)


func _unit(unit_type):
	for unit in _human.get_children():
		if "type" in unit and unit.type == unit_type:
			return unit
	return null
