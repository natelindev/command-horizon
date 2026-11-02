extends "res://tests/headless/SaveRestoreEdges.gd"

var _factions


func _run():
	_factions = load("res://source/match/FactionCatalog.gd")
	Engine.physics_ticks_per_second = 60
	root.get_node("SaveManager").autosaves_enabled = false
	for faction in ["bastion", "helix", "frontier"]:
		await _grid(faction)
		paused = false
		game.queue_free()
		await _frames(5)
	for message in errors:
		push_error(message)
	print("Active power grid: %d failures" % errors.size())
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)


func _spawn_grid(role, player, point):
	var unit = load(_factions.scene_path(player.faction, role)).instantiate()
	game._setup_and_spawn_unit(unit, Transform3D(Basis(), point), player, false)
	unit.process_mode = Node.PROCESS_MODE_DISABLED
	return unit


func _grid(faction):
	await _skirmish(faction, "res://source/match/maps/PlainAndSimple.tscn", false)
	game.settings.visibility = game.settings.Visibility.FULL
	var human = game._get_human_player()
	var enemy = get_nodes_in_group("players").filter(func(side): return side != human)[0]
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	for unit in get_nodes_in_group("units"):
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	human.resource_a = 1000
	human.resource_b = 1000
	_spawn_grid("Barracks", human, Vector3(14, 0, 20))
	var factory = _spawn_grid("VehicleFactory", human, Vector3(20, 0, 20))
	_spawn_grid("CommandLab", human, Vector3(14, 0, 28))
	var turret = _spawn_grid("AntiGroundTurret", human, Vector3(25, 0, 25))
	var target = _spawn_grid("Infantry", enemy, Vector3(28, 0, 25))
	var rules = load("res://source/match/combat/CombatRules.gd")
	_check(human.power_state() == "brownout", faction + ": grid deficit was passive")
	_check(human.production_factor() == 0.25, faction + ": brownout production rate differs")
	_check(not rules.can_target(turret, target), faction + ": brownout turret can fire")
	var prototype = load(_factions.scene_path(faction, "Tank"))
	var job = factory.production_queue.produce(prototype)
	_check(job != null, faction + ": production fixture could not be paid")
	if job != null:
		var before = job.time_left
		factory.production_queue._process(1.0)
		_check(
			is_equal_approx(before - job.time_left, 0.25), faction + ": live queue ignored brownout"
		)
	var generator = _spawn_grid("PowerPlant", human, Vector3(32, 0, 18))
	_check(human.power_state() == "surplus", faction + ": generator did not restore grid")
	_check(rules.can_target(turret, target), faction + ": powered turret remained disabled")
	human.logistics = 0.0
	human.logistics_left = 5.0
	human._advance_economy(4.9)
	_check(human.logistics == 0.0, faction + ": generator produced Logistics early")
	human._advance_economy(.1)
	_check(human.logistics == 1.0, faction + ": generator must produce 1 Logistics every 5s")
	human._advance_economy(10.0)
	_check(human.logistics == 3.0, faction + ": generator lost elapsed Logistics ticks")
	human.logistics = 99.0
	human._advance_economy(10.0)
	_check(human.logistics == 100.0, faction + ": Logistics exceeded its reserve cap")
	paused = true
	var fuel_clock = human.logistics_left
	await _frames(8)
	_check(human.logistics_left == fuel_clock, faction + ": paused Logistics clock advanced")
	paused = false
	human.logistics = 25.0
	var original = human.power_totals()
	var surge = generator.abilities.get_ability("grid_surge")
	_check(surge != null and surge.trigger(), faction + ": generator surge refused")
	_check(human.power_totals().x == original.x + 6, faction + ": surge output is not 50%")
	generator.abilities._physics_process(29.0)
	_check(human.power_totals().x == original.x + 6, faction + ": surge expired too soon")
	paused = true
	var remaining = surge.active_left
	await _frames(8)
	_check(surge.active_left == remaining, faction + ": paused surge advanced")
	paused = false
	generator.abilities._physics_process(1.0)
	_check(human.power_totals() == original, faction + ": surge output persisted after 30s")
	_check(is_equal_approx(surge.cooldown_left, 10.0), faction + ": post-surge cooldown differs")
	_check(not surge.trigger(), faction + ": surge bypassed its cooldown")
	generator.abilities._physics_process(10.0)
	_check(surge.trigger(), faction + ": surge did not recharge")
	var gap = human.power_totals().x - human.power_totals().y
	var draw = _factions.power_usage(faction, "AntiGroundTurret")
	for index in gap / draw:
		_spawn_grid("AntiGroundTurret", human, Vector3(8 + index * .5, 0, 35))
	_check(human.power_state() == "balanced", faction + ": balanced grid fixture failed")
	game.hud._assignment_hint.text = ""
	var lab = _units(human, "CommandLab")[0]
	var research = load("res://source/match/research/TechnologyCatalog.gd")
	var branch = research.FACTION_TECHNOLOGIES[faction][0]
	human.coordination_unlocked = true
	_check(human.technology.start(branch, lab), faction + ": balanced research fixture refused")
	_check(
		game.hud._assignment_hint.text == "Power grid balanced · no reserve for new facilities.",
		faction + ": starting research on a balanced grid did not warn"
	)
	if faction == "helix":
		var tank = _spawn_grid("Tank", human, Vector3(27, 0, 20))
		generator.queue_free()
		tank.shields = 0.0
		tank.last_shield_damage_time = game.simulation_time - 6.0
		tank._physics_process(0.5)
		_check(is_equal_approx(tank.shields, 2.0), "Brownout did not halve shield recharge")
		var minimap = game.find_child("Minimap")
		if minimap != null:
			minimap._process(0.0)
			_check(minimap._brownout_overlay.visible, "Brownout did not interfere with minimap")
	if faction == "frontier":
		human.coordination_unlocked = true
		var raider = _spawn_grid("Tank", human, Vector3(27, 0, 20))
		var fuel = human.logistics
		_check(human.signatures.activate([raider]) == 1, "Fueled vehicle boost refused")
		_check(human.logistics == fuel - 5.0, "Vehicle boost did not consume Logistics")
		human.logistics = 4.0
		var other = _spawn_grid("Tank", human, Vector3(27, 0, 22))
		_check(human.signatures.activate([other]) == 0, "Unfunded vehicle boost activated")
		_check(
			other.signature.kind == "" and human.logistics == 4.0, "Rejected boost altered state"
		)
		var start = Vector2i(human.resource_a, human.resource_b)
		var quote = human.market_quote("buy_electronics")
		_check(human.market_exchange("buy_electronics"), "Black Market refused paid exchange")
		_check(
			Vector2i(human.resource_a, human.resource_b) == start + Vector2i(-quote.x, quote.y),
			"Black Market payment differs"
		)
		_check(
			human.market_quote("buy_electronics").y < quote.y,
			"Black Market prices did not react to trade"
		)
		paused = true
		_check(not human.market_exchange("buy_materials"), "Paused market accepted a trade")
		paused = false
	for plant in _units(human, "PowerPlant"):
		plant.hp = 0
	human.logistics = 0.0
	human._advance_economy(5.0)
	_check(human.logistics == 0.0, faction + ": destroyed generators produced Logistics")
