extends "res://tests/headless/SaveRestoreEdges.gd"

var plan
var factions
var watched
var human
var worker
var service
var harvest


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	harvest = load("res://source/match/units/actions/CollectingResourcesSequentially.gd")
	plan = load("res://source/match/SkirmishPlan.gd")
	factions = load("res://source/match/FactionCatalog.gd")
	for faction in ["bastion", "helix"]:
		await _fixture(faction)
		await _missing_and_paid_service(faction)
		await _other_roles(faction)
		paused = false
		game.queue_free()
		await _frames(5)
	for error in errors:
		push_error(error)
	print("Recovery guidance: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _fixture(faction):
	await _skirmish(faction, "res://source/match/maps/CoastalFoundry.tscn")
	human = game._get_human_player()
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	for unit in plan.owned_units(human):
		if unit.type in ["RepairDepot", "RepairRobot"]:
			unit.queue_free()
	await _frames(30)
	worker = _units(human, "Worker")[0]
	var deposits = get_nodes_in_group("resource_units").filter(
		func(unit): return "resource_a" in unit
	)
	deposits.sort_custom(
		func(a, b):
			return a.position.distance_to(worker.position) < b.position.distance_to(worker.position)
	)
	worker.issue_manual_order(harvest.new(deposits[0]))
	watched = _units(human, "Tank")[0]
	watched.program.configure(
		load("res://source/match/programs/ProgramLibrary.gd").defaults("guard")
	)
	watched.program.anchor = watched.position
	watched.program.safe_point = watched.position
	_check(watched.program.run(), "Fixture cannot run guard")
	watched.issue_manual_order(null)
	watched.hp = watched.hp_max * .25
	human.resource_a = 100
	human.resource_b = 100
	game.hud._toggle_pause()
	_check(paused, "Recovery fixture is not paused")


func _missing_and_paid_service(faction):
	var advice = plan.next_step(human)
	_check(
		advice.id == "RepairDepot",
		"Missing ground service has no construction guidance: " + faction
	)
	_check(
		advice.units.size() == 1 and advice.units[0].type == "Worker",
		"Missing service did not select an engineer"
	)
	var before = Vector2i(human.resource_a, human.resource_b)
	var clock = game.simulation_time
	var action = watched.action
	await _review(faction + "-missing")
	game.hud.battle_plan._action.pressed.emit()
	_check(get_nodes_in_group("selected_units").size() == 1, "Advice selection is ambiguous")
	_check(
		watched.action == action and game.simulation_time == clock, "Advice changed orders or time"
	)
	_check(Vector2i(human.resource_a, human.resource_b) == before, "Advice spent funds")
	human.resource_a = 0
	human.resource_b = 0
	_check(plan.next_step(human).id == "supply_electronics", "Missing income lost priority")
	var electronics = get_nodes_in_group("resource_units").filter(
		func(unit): return "resource_b" in unit
	)
	var gatherer = _units(human, "Worker")[1]
	electronics.sort_custom(
		func(a, b):
			return (
				a.position.distance_to(gatherer.position)
				< b.position.distance_to(gatherer.position)
			)
	)
	gatherer.issue_manual_order(harvest.new(electronics[0]))
	advice = plan.next_step(human)
	_check(advice.id == "fund_RepairDepot", "Missing service ignored its actual cost")
	await _review(faction + "-funds")
	human.resource_a = before.x
	human.resource_b = before.y
	service = _place_service()
	_check(service != null, "Could not place paid repair facility")
	if service == null:
		return
	var price = factions.cost(human, "RepairDepot", true)
	_check(
		(
			Vector2i(human.resource_a, human.resource_b)
			== before - Vector2i(price.resource_a, price.resource_b)
		),
		"Facility charged the wrong price"
	)
	advice = plan.next_step(human)
	_check(
		advice.id == "RepairDepot" and "already paid" in advice.description,
		"Recovery ignored an unfinished paid facility"
	)
	await _review(faction + "-foundation")
	var builder = Snapshot.new()
	var data = builder.capture(game)
	var id = builder._reference(watched)
	var site_id = builder._reference(service)
	var file = "user://recovery-guidance-%d.json" % OS.get_process_id()
	_check(FileStore.new().write_file(file, data), "Guidance disk write failed")
	var restore = Restore.new()
	var loaded = await restore.restore(self, FileStore.new().read_file(file))
	DirAccess.remove_absolute(file)
	_check(loaded.ok, "Guidance disk restore failed")
	game = loaded.game
	human = game._get_human_player()
	watched = restore.entities[id]
	service = restore.entities[site_id]
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	await _frames(30)
	_check(paused and game.simulation_time == clock, "Guidance restore advanced time")
	_check(plan.next_step(human).id == "RepairDepot", "Paid-facility guidance lost after loading")
	game.hud._toggle_pause()
	for frame in 2100:
		await physics_frame
		if service.is_constructed():
			break
	_check(service.is_constructed(), "Paid recovery facility never completed")
	watched.issue_manual_order(
		load("res://source/match/units/actions/Moving.gd").new(
			service.position + Vector3(3.2, 0, 0)
		)
	)
	var health = watched.hp
	await _frames(1200)
	_check(watched.hp > health, "Suggested facility did not provide ordinary healing")
	_check(watched.program.mode == "Manual", "Recovery advice resumed automation")
	game.hud._toggle_pause()
	print(
		"RECOVERY SERVICE ",
		faction,
		" health=",
		health,
		" -> ",
		watched.hp,
		" complete=",
		service.is_constructed()
	)
	await _review(faction + "-recovering")


func _other_roles(faction):
	watched.hp = watched.hp_max
	var scout = _actor("Drone", human, Vector3(14, 3, 44))
	scout.hp = scout.hp_max * .25
	await _frames(5)
	_check(
		plan.next_step(human).id == "AircraftFactory",
		"Damaged scout lacks flight-service construction guidance"
	)
	await _review(faction + "-air-service")
	scout.hp = scout.hp_max
	service.queue_free()
	await _frames(5)
	var robot = _actor("RepairRobot", human, Vector3(16, 0, 43))
	robot.hp = robot.hp_max * .25
	await _frames(5)
	_check(
		plan.next_step(human).id == "RepairDepot", "Repair robot was treated as its own provider"
	)
	robot.hp = robot.hp_max
	watched.hp = watched.hp_max * .25
	_check(plan.next_step(human).id == "repair_army", "Valid mobile repair support was ignored")
	_check(watched in plan.next_step(human).units, "Supported damaged tank was not selectable")
	await _review(faction + "-supported")
	robot.queue_free()
	await _frames(5)
	var enemy = get_nodes_in_group("players").filter(func(side): return side != human)[0]
	var enemy_service = _actor("RepairDepot", enemy, Vector3(70, 0, 15))
	await _frames(5)
	_check(plan.next_step(human).id == "RepairDepot", "Enemy service satisfied friendly recovery")
	enemy_service.queue_free()
	watched.hp = watched.hp_max
	var infantry = _units(human, "Infantry")[0]
	infantry.hp = infantry.hp_max * .25
	_check(plan.next_step(human).id == "repair_army", "Completed barracks did not support infantry")
	print("RECOVERY PROVIDERS ", faction, " aircraft/self/mobile/enemy/infantry checked")


func _place_service():
	var chosen = plan.next_step(human).units
	var engineer = (
		chosen[0]
		if not chosen.is_empty() and chosen[0].type == "Worker"
		else _units(human, "Worker")[1]
	)
	var handler = human.get_node("StructurePlacementHandler")
	handler._start_structure_placement(load("res://source/match/units/RepairDepot.tscn"))
	var origin = _units(human, "CommandCenter")[0].position
	for distance in [7.0, 10.0, 13.0]:
		for angle in 16:
			handler._active_blueprint_node.position = (
				origin + Vector3(cos(angle * TAU / 16), 0, sin(angle * TAU / 16)) * distance
			)
			if (
				handler._calculate_blueprint_position_validity()
				!= handler.BlueprintPositionValidity.VALID
			):
				continue
			root.get_node("MatchSignals").deselect_all_units.emit()
			engineer.get_node("Selection").select()
			handler._finish_structure_placement()
			return _units(human, "RepairDepot")[0]
	handler._cancel_structure_placement()
	return null


func _actor(role, player, point):
	var unit = load("res://source/match/units/%s.tscn" % role).instantiate()
	game._setup_and_spawn_unit(unit, Transform3D(Basis(), point), player, false)
	return unit


func _review(_label):
	return true
