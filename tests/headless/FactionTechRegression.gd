extends "res://tests/headless/StructureActivityRegression.gd"


func _run():
	factions = load("res://source/match/FactionCatalog.gd")
	root.get_node("SaveManager").autosaves_enabled = false
	for faction in factions.IDS:
		await _fixture(faction)
		await _tech_path(faction)
		game.queue_free()
		await _frames(5)
	for message in errors:
		push_error(message)
	print("Faction tech paths: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _tech_path(faction):
	for unit in _units(human, "CommandLab") + _units(human, "RepairDepot"):
		unit.queue_free()
	human.coordination_unlocked = false
	await _frames(5)
	var factory = _units(human, "VehicleFactory")[0]
	var walker = load(factions.Bastion.scene_path("CombatRobot"))
	var heavy = load(factions.Bastion.scene_path("AdvancedTank"))
	_check(
		factions.available(human, "CombatRobot") == (faction == "frontier"),
		"Wrong early walker branch: " + faction
	)
	_check(not factions.available(human, "AdvancedTank"), "Heavy armor lacks tech gate")
	var required = factions.requirement(human, "AircraftFactory", true)
	_check(
		required == ("Barracks" if faction == "helix" else "VehicleFactory"),
		"Early Helix aviation missing"
	)
	var depot = _spawn("RepairDepot", Vector3(40, 0, 12))
	await _frames(5)
	_check(
		factions.available(human, "CombatRobot") == (faction != "helix"),
		"Workshop walker unlock wrong"
	)
	_check(
		factions.available(human, "AdvancedTank") == (faction == "frontier"),
		"Frontier workshop heavy unlock wrong"
	)
	if faction == "frontier":
		var job = factory.production_queue.produce(heavy)
		_check(job != null, "Unlocked Ironback could not be bought")
		depot.queue_free()
		await _frames(3)
		_check(
			not factory.production_queue.blocked_reason().is_empty(),
			"Lost field workshop did not suspend Ironback"
		)
		var left = job.time_left
		factory.production_queue._process(2.0)
		_check(job.time_left == left, "Locked queue consumed paid time")
		depot = _spawn("RepairDepot", Vector3(40, 0, 12))
		await _frames(3)
		_check(
			factory.production_queue.blocked_reason().is_empty(),
			"Rebuilt field workshop did not resume Ironback"
		)
		factory.production_queue.cancel(job)
	_spawn("CommandLab", Vector3(50, 0, 12))
	await _frames(5)
	_check(
		factions.available(human, "CombatRobot"),
		"Specialist unavailable after faction prerequisites"
	)
	_check(
		factions.available(human, "AdvancedTank") == (faction == "frontier"),
		"Coordination requirement lost"
	)
	human.coordination_unlocked = true
	_check(factions.available(human, "AdvancedTank"), "Final heavy tier unavailable")
	var info = load("res://source/match/hud/RosterInfo.gd").inspect(factory, "AdvancedTank", false)
	_check(info.allowed and "Tech path:" in info.text, "Unlocked heavy hides tech path")
	var trained = _spawn("CombatRobot", Vector3(60, 0, 12))
	_check(trained.can_switch_weapon() == (faction == "helix"), "Lancer unique weapon modes lost")
	factory.production_queue.produce(walker)
	paused = true
	var capture = Snapshot.new()
	var data = capture.capture(game)
	var schema = load("res://source/match/saves/SnapshotSchema.gd").new()
	_check(
		data != null and schema.validate(data),
		"Faction queue archive invalid: " + capture.error + " " + schema.error
	)
	paused = false
	print(
		"TECH ",
		faction,
		" walker=",
		factions.requirement(human, "CombatRobot"),
		" heavy=",
		factions.requirement(human, "AdvancedTank"),
		" coordination=",
		factions.requires_coordination(human, "AdvancedTank")
	)
