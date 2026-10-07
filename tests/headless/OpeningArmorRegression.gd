extends "res://tests/headless/SaveRestoreEdges.gd"

var plan
var factions
var human
var factory
var tank
var harvest
var tank_scene


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	plan = load("res://source/match/SkirmishPlan.gd")
	factions = load("res://source/match/FactionCatalog.gd")
	tank_scene = load("res://source/match/units/Tank.tscn")
	harvest = load("res://source/match/units/actions/CollectingResourcesSequentially.gd")
	for faction in ["bastion", "helix"]:
		await _fixture(faction)
		await _conventional(faction)
		await _retrofit(faction)
		paused = false
		game.queue_free()
		await _frames(5)
	for error in errors:
		push_error(error)
	print("Opening armor and retrofit: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _fixture(faction):
	await _skirmish(faction, "res://source/match/maps/CoastalFoundry.tscn", false)
	human = game._get_human_player()
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	_spawn("Barracks", Vector3(12, 0, 23))
	factory = _spawn("VehicleFactory", Vector3(24, 0, 33))
	for index in 2:
		_spawn("Infantry", Vector3(18 + index * 2, 0, 30))
	var workers = _units(human, "Worker")
	for kind in ["resource_a", "resource_b"]:
		var worker = workers[0 if kind == "resource_a" else 1]
		var deposits = get_nodes_in_group("resource_units").filter(func(unit): return kind in unit)
		deposits.sort_custom(
			func(a, b):
				return (
					a.position.distance_to(worker.position)
					< b.position.distance_to(worker.position)
				)
		)
		worker.issue_manual_order(harvest.new(deposits[0]))
	human.resource_a = 100
	human.resource_b = 100
	await _frames(5)
	game.hud._toggle_pause()
	_check(paused and not human.basic_programs_unlocked(), "Opening fixture has chip access")


func _conventional(faction):
	var step = plan.next_step(human)
	_check(step.id == "armor", faction + ": factory guidance skips conventional armor")
	_check(step.units == [factory], "Armor guidance did not select its producer")
	await _review(faction + "-armor")
	var price = factions.cost(human, "Tank")
	_check(
		str(price.resource_a) in step.description and str(price.resource_b) in step.description,
		"Armor guidance omitted the faction price"
	)
	var funds = Vector2i(human.resource_a, human.resource_b)
	human.resource_a = price.resource_a - 1
	human.resource_b = price.resource_b - 1
	_check(plan.next_step(human).id == "fund_armor", "Armor guidance ignored missing funds")
	await _review(faction + "-funds")
	human.resource_a = funds.x
	human.resource_b = funds.y
	factory.production_queue.fit_chips = false
	var job = factory.production_queue.produce(tank_scene)
	_check(job != null and not job.fitted_chip, "Conventional armor required a lab")
	_check(
		(
			Vector2i(human.resource_a, human.resource_b)
			== funds - Vector2i(price.resource_a, price.resource_b)
		),
		"Conventional armor charged a chip fee"
	)
	_check(plan.next_step(human).id == "armor_pending", "Paid conventional armor was ignored")
	await _review(faction + "-queued")
	factory.production_queue.cancel(job)
	_check(
		Vector2i(human.resource_a, human.resource_b) == funds, "Conventional queue refund differs"
	)
	_check(plan.next_step(human).id == "armor", "Cancelled armor queue still suppresses advice")
	factory.production_queue.produce(tank_scene)
	await _archive()
	_check(
		plan.next_step(human).id == "armor_pending", "Paid opening advice changed across archive"
	)
	game.hud._toggle_pause()
	for frame in 1800:
		await physics_frame
		if not _units(human, "Tank").is_empty():
			break
	_check(not _units(human, "Tank").is_empty(), "Paid conventional armor never completed")
	tank = _units(human, "Tank")[0]
	_check(
		not tank.program.installed and not human.basic_programs_unlocked(),
		"Conventional tank gained free hardware or technology"
	)
	var point = _units(human, "CommandCenter")[0].position + Vector3(6, 0, 0)
	tank.issue_manual_order(load("res://source/match/units/actions/Moving.gd").new(point))
	for frame in 1200:
		await physics_frame
		if tank.position.distance_to(point) < 1.5:
			break
	_check(tank.position.distance_to(point) < 1.5, "Conventional tank did not obey manual move")
	tank.issue_manual_order(null)
	game.hud._toggle_pause()
	_check(
		plan.next_step(human).id == "CommandLab",
		"Conventional armor did not hand off to lab progression"
	)
	await _review(faction + "-lab")
	print(
		"OPENING ARMOR ", faction, " conventional=true hp=", tank.hp, " time=", game.simulation_time
	)


func _retrofit(faction):
	_spawn("CommandLab", Vector3(25, 0, 22))
	await _frames(5)
	_check(human.basic_programs_unlocked(), "Completed lab did not unlock chip technology")
	_check(
		plan.next_step(human).id == "retrofit",
		"Surviving conventional tank was not offered retrofit"
	)
	_check(
		plan.next_step(human).units == [tank], "Retrofit advice does not select the existing tank"
	)
	await _review(faction + "-retrofit")
	var fitted = factory.production_queue
	fitted.fit_chips = true
	var queued = fitted.produce(tank_scene)
	_check(
		queued != null and plan.next_step(human).id == "chips_pending",
		"Already-paid fitted armor was ignored"
	)
	fitted.cancel(queued)
	fitted.fit_chips = false
	var funds = human.resource_b
	human.resource_b = 3
	_check(plan.next_step(human).id == "fund_chip", "Retrofit advice ignored its fee")
	human.resource_b = funds
	var hq = _units(human, "CommandCenter")[0]
	_check(tank.program.install_at(hq), "Surviving tank could not start paid retrofit")
	_check(human.resource_b == funds - 4, "Retrofit charged the wrong fee")
	_check(
		plan.next_step(human).id == "chips_installing",
		"Paid retrofit still recommends another purchase"
	)
	await _review(faction + "-installing")
	tank.issue_manual_order(null)
	_check(human.resource_b == funds, "Manual cancellation lost the retrofit refund")
	_check(plan.next_step(human).id == "retrofit", "Cancelled retrofit remained pending")
	_check(tank.program.install_at(hq), "Retry of explicit retrofit was refused")
	await _archive()
	_check(
		plan.next_step(human).id == "chips_installing",
		"Retrofit guidance lost across paused archive"
	)
	var clock = game.simulation_time
	var left = tank.program.install_left
	await _frames(30)
	_check(
		game.simulation_time == clock and tank.program.install_left == left,
		"Paused retrofit advanced"
	)
	game.hud._toggle_pause()
	for frame in 1200:
		await physics_frame
		if tank.program.installed:
			break
	_check(tank.program.ready_to_run(), "Paid retrofit never reached programmable readiness")
	game.hud._toggle_pause()
	_check(plan.next_step(human).id == "programs", "Retrofitted tank skipped program setup")
	await _review(faction + "-programs")
	tank.program.configure(load("res://source/match/programs/ProgramLibrary.gd").defaults("guard"))
	tank.program.anchor = tank.position
	tank.program.safe_point = tank.position
	_check(tank.program.run(), "Retrofitted opening tank refused its first guard program")
	game.hud._toggle_pause()
	await _frames(120)
	_check(
		tank.program.mode in ["Running", "Waiting"], "Opening tank failed to execute its program"
	)
	print(
		"OPENING RETROFIT ",
		faction,
		" installed=",
		tank.program.installed,
		" mode=",
		tank.program.mode
	)


func _archive():
	var capture = Snapshot.new()
	var saved = capture.capture(game)
	var factory_id = capture._reference(factory)
	var tank_id = capture._reference(tank) if is_instance_valid(tank) else ""
	var file = "user://opening-armor-%d.json" % OS.get_process_id()
	_check(FileStore.new().write_file(file, saved), "Opening archive write failed")
	var restore = Restore.new()
	var loaded = await restore.restore(self, FileStore.new().read_file(file))
	DirAccess.remove_absolute(file)
	_check(loaded.ok, "Opening archive restore failed")
	game = loaded.game
	human = game._get_human_player()
	factory = restore.entities[factory_id]
	if tank_id != "":
		tank = restore.entities[tank_id]
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	await _frames(5)


func _spawn(role, point):
	var unit = load("res://source/match/units/%s.tscn" % role).instantiate()
	game._setup_and_spawn_unit(unit, Transform3D(Basis(), point), human, false)
	return unit


func _review(_label):
	return true
