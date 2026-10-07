extends "res://tests/headless/SkirmishBudgetRegression.gd"

const ARCHIVE = (
	"res://docs/playtests/2026-10-06/relay-commitment/" + "final6-earned-case6-10-technology.json"
)
var policy


func _run():
	factions = load("res://source/match/FactionCatalog.gd")
	catalog = load("res://source/match/BastionCatalog.gd")
	policy = load("res://source/match/players/skirmish-ai/SkirmishProduction.gd")
	root.get_node("SaveManager").autosaves_enabled = false
	await _earned_budget()
	for faction in factions.IDS:
		await _independent_budget(faction)
	for message in errors:
		push_error(message)
	print("Independent resource reserves: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _earned_budget():
	var restore = Restore.new()
	var loaded = await restore.restore(self, FileStore.new().read_file(ARCHIVE))
	_check(loaded.ok, "Earned economy failed to restore")
	if not loaded.ok:
		return
	game = loaded.game
	var human = game._get_human_player()
	var player = get_nodes_in_group("players").filter(func(side): return side != human)[0]
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	var desired = player._next_building(player._units())
	var reserve = policy.reserve(player, player._units(), desired)
	var funds = Vector2i(player.resource_a, player.resource_b)
	var requests = policy.requests(game, player, player._units())
	var requested = requests.map(
		func(job): return {"role": job.role, "cost": job.cost, "priority": job.priority}
	)
	print(
		"EARNED RESERVES ",
		JSON.stringify(
			{
				"faction": player.faction,
				"time": game.simulation_time,
				"funds": str(funds),
				"desired": desired,
				"reserve": str(reserve),
				"requests": requested
			}
		)
	)
	var infantry = requests.filter(func(job): return job.role == "Infantry")
	_check(infantry.size() == 1, "Earned archive lost its infantry request")
	if infantry.is_empty():
		await _close_budget()
		return
	var producer = infantry[0].producer
	var price = Vector2i(infantry[0].cost.resource_a, infantry[0].cost.resource_b)
	_check(
		price.y == 0 and funds.y < reserve.y and funds.x >= reserve.x + price.x,
		"Earned archive lost cross-resource shortage"
	)
	player._train(player._units(), desired)
	_check(_queued(producer) == "Infantry", "Unspent electronics shortage blocked earned infantry")
	_check(
		Vector2i(player.resource_a, player.resource_b) == funds - price,
		"Earned infantry charged wrong funds"
	)
	if producer.production_queue.size() == 0:
		await _close_budget()
		return
	var builder = Snapshot.new()
	var data = builder.capture(game)
	var producer_id = builder._reference(producer)
	var remaining = producer.production_queue.get_elements()[0].time_left
	var disk = "user://resource-reserve-%d.json" % OS.get_process_id()
	_check(FileStore.new().write_file(disk, data), "Paid reserve queue disk write failed")
	restore = Restore.new()
	loaded = await restore.restore(self, FileStore.new().read_file(disk))
	DirAccess.remove_absolute(disk)
	_check(loaded.ok, "Paid reserve queue failed to restore")
	if not loaded.ok:
		return
	game = loaded.game
	producer = restore.entities[producer_id]
	player = producer.player
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	await _frames(90)
	_check(
		Vector2i(player.resource_a, player.resource_b) == funds - price,
		"Paused reload changed paid funds"
	)
	_check(
		(
			_queued(producer) == "Infantry"
			and producer.production_queue.get_elements()[0].time_left == remaining
		),
		"Paused reload advanced/lost production"
	)
	var previous = _units(player, "Infantry")
	var started = game.simulation_time
	var completed = -1.0
	paused = false
	for frame in 1800:
		await physics_frame
		if _units(player, "Infantry").any(func(unit): return unit not in previous):
			completed = game.simulation_time - started
			break
	_check(completed > 0, "Paid archived infantry never spawned")
	print(
		"EARNED PAID INFANTRY completed=",
		completed,
		" electronics_before=",
		funds.y,
		" after=",
		player.resource_b
	)
	await _close_budget()


func _independent_budget(faction):
	var settings = load("res://source/data-model/MatchSettings.gd").new()
	settings.skirmish = true
	settings.advanced_start = true
	settings.map_path = "res://source/match/maps/PlainAndSimple.tscn"
	for index in 2:
		var side = load("res://source/data-model/PlayerSettings.gd").new()
		side.controller = index + 1
		side.faction = "bastion" if index == 0 else faction
		settings.players.append(side)
	game = load("res://source/match/Skirmish.tscn").instantiate()
	game.settings = settings
	game.map = load(settings.map_path).instantiate()
	root.add_child(game)
	current_scene = game
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	for unit in get_nodes_in_group("units"):
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	await _frames(3)
	paused = true
	var opponents = get_nodes_in_group("players").filter(
		func(side): return side != game._get_human_player()
	)
	var player = opponents[0]
	var barracks = _units(player, "Barracks")[0]
	var factory = _units(player, "VehicleFactory")[0]
	barracks.production_queue.cancel_all()
	factory.production_queue.cancel_all()
	var reserve = policy.reserve(player, player._units(), "AircraftFactory")
	var price = factions.cost(player, "Infantry")
	# Restrict offered producers to isolate the budget contract. All real
	# prerequisites and faction prices still come from the existing player.
	for electronics in [0, reserve.y - 1, reserve.y]:
		player.resource_a = reserve.x + price.resource_a
		player.resource_b = electronics
		player._train([barracks], "AircraftFactory")
		_check(
			_queued(barracks) == "Infantry", faction + ": surplus materials did not fund infantry"
		)
		_check(
			player.resource_a == reserve.x and player.resource_b == electronics,
			faction + ": reserve was consumed"
		)
		barracks.production_queue.cancel_all()
		_check(
			player.resource_a == reserve.x + price.resource_a and player.resource_b == electronics,
			"Cancellation refunded wrong currency"
		)
	player.resource_a = reserve.x + price.resource_a - 1
	player.resource_b = 100
	var before = Vector2i(player.resource_a, player.resource_b)
	player._train([barracks], "AircraftFactory")
	_check(
		(
			barracks.production_queue.size() == 0
			and Vector2i(player.resource_a, player.resource_b) == before
		),
		"Infantry spent construction's material reserve"
	)
	player._production_index = 0
	var job = policy.requests(game, player, [factory])[0]
	player.resource_a = 1000
	player.resource_b = reserve.y - 1
	before = Vector2i(player.resource_a, player.resource_b)
	_check(job.cost.resource_b > 0, "Vehicle exclusion did not consume electronics")
	player._train([factory], "AircraftFactory")
	_check(
		(
			factory.production_queue.size() == 0
			and Vector2i(player.resource_a, player.resource_b) == before
		),
		"Vehicle consumed protected electronics"
	)
	_check(player._production_index == 0, "Rejected purchase advanced production sequence")
	await _counter_reserve(player, barracks, factory)
	print("INDEPENDENT BUDGET ", faction, " construction=", reserve, " infantry=", price)
	await _close_budget()


func _close_budget():
	paused = false
	game.queue_free()
	await _frames(5)
	game = null


func _counter_reserve(player, barracks, factory):
	var target = _spawn(
		"Helicopter", game._get_human_player(), barracks.position + Vector3(3, 3, 0)
	)
	game.battlefield.invalidate()
	_check(game.battlefield.is_observed(player, target), "Reserve counter fixture is hidden")
	var requests = policy.requests(game, player, [factory, barracks])
	_check(
		requests.size() == 2 and requests[0].role == "CombatRobot",
		"Missing priority counter request"
	)
	if requests.size() != 2 or requests[0].role != "CombatRobot":
		return
	var counter = requests[0].cost
	var infantry = factions.cost(player, "Infantry")
	player.resource_a = counter.resource_a + infantry.resource_a
	player.resource_b = counter.resource_b - 1
	var electronics = player.resource_b
	player._train([factory, barracks], "")
	_check(_queued(barracks) == "Infantry", "Unfunded counter blocked noncompeting infantry")
	_check(factory.production_queue.size() == 0, "Unfunded counter entered production")
	_check(
		player.resource_a == counter.resource_a and player.resource_b == electronics,
		"Infantry spent priority counter savings"
	)
	barracks.production_queue.cancel_all()
	player.resource_a = counter.resource_a + infantry.resource_a - 1
	player._train([factory, barracks], "")
	_check(barracks.production_queue.size() == 0, "Infantry spent priority counter materials")
	# Once both are funded, preserve priority ordering and exact paid prices.
	player.resource_a = counter.resource_a + infantry.resource_a
	player.resource_b = counter.resource_b
	player._train([factory, barracks], "")
	_check(
		_queued(factory) == "CombatRobot" and _queued(barracks) == "Infantry",
		"Funded priority pair did not purchase"
	)
	_check(
		player.resource_a == 0 and player.resource_b == 0, "Funded priority pair paid wrong price"
	)
	factory.production_queue.cancel_all()
	barracks.production_queue.cancel_all()
