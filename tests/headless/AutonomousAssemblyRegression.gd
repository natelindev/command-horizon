extends SceneTree


class WorkClock:
	extends Node
	var seconds = 0.0

	func _process(delta):
		seconds += delta


var errors = []
var game
var human
var construct
var harvest
var factions
var work_clock


func _initialize():
	_run.call_deferred()


func _run():
	work_clock = WorkClock.new()
	work_clock.process_priority = -10000
	root.add_child(work_clock)
	root.get_node("SaveManager").autosaves_enabled = false
	construct = load("res://source/match/units/actions/Constructing.gd")
	harvest = load("res://source/match/units/actions/CollectingResourcesSequentially.gd")
	factions = load("res://source/match/FactionCatalog.gd")
	await _helix_beacon()
	await _queued_orders()
	await _paused_restore()
	await _campaign_rate()
	for faction in ["bastion", "frontier"]:
		await _tethered(faction)
	for message in errors:
		push_error(message)
	print("Autonomous assembly regression: %d failures" % errors.size())
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)


func _fixture(faction = "helix"):
	if is_instance_valid(game):
		paused = false
		game.queue_free()
		await _frames(5)
	var settings = load("res://source/data-model/MatchSettings.gd").new()
	settings.skirmish = true
	settings.advanced_start = true
	settings.map_path = "res://source/match/maps/BastionDesert.tscn"
	for index in 2:
		var side = load("res://source/data-model/PlayerSettings.gd").new()
		side.controller = index + 1
		side.faction = faction if index == 0 else "bastion"
		settings.players.append(side)
	game = load("res://source/match/Skirmish.tscn").instantiate()
	game.settings = settings
	game.map = load(settings.map_path).instantiate()
	root.add_child(game)
	current_scene = game
	game.get_node("IsometricCamera3D").set_physics_process(false)
	await _frames(60)
	human = game._get_human_player()
	human.resource_a = 10000
	human.resource_b = 10000
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	for unit in get_nodes_in_group("units"):
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	game.repair_service.set_physics_process(false)


func _spawn(role, point, foundation = false):
	var unit = load(factions.Bastion.scene_path(role)).instantiate()
	game._setup_and_spawn_unit(unit, Transform3D(Basis(), point), human, foundation)
	return unit


func _worker_at(site):
	var worker = _spawn("Worker", site.position + Vector3(0, 0, site.radius + .7))
	_check(
		root.get_node("Utils").Match.Unit.Movement.units_adhere(worker, site),
		"Worker fixture cannot reach beacon"
	)
	return worker


func _helix_beacon():
	await _fixture()
	var site = _spawn("PowerPlant", Vector3(40, 0, 12), true)
	var worker = _worker_at(site)
	await _frames(60)
	_check(site.has_node("AutonomousAssembly"), "Helix foundation lacks assembly trait")
	_check(site.construction_progress() == 0.0, "Beacon activated without an on-site engineer")
	var deposits = get_nodes_in_group("resource_units").filter(
		func(unit): return "resource_b" in unit and unit.resource_b > 0
	)
	var deposit = deposits[0]
	worker.action = harvest.new(deposit)
	var controller = human.get_node("UnitActionsController")
	controller._submit(worker, worker.manual_orders.target_order("construct", site))
	await _frames(12)
	_check(site.construction_progress() > 0.0, "Adjacent engineer did not deploy beacon")
	_check(not site.needs_constructor(), "Active nanite site still demands a builder")
	_check(not construct.is_applicable(worker, site), "Active beacon accepts tethered work orders")
	_check(
		is_instance_of(worker.action, harvest), "Released Helix engineer did not resume gathering"
	)
	if is_instance_of(worker.action, harvest):
		_check(worker.action._kind == 2, "Nanite build lost engineer's prior resource field")
	worker.hp = 0
	await _frames(3)
	var progress = site.construction_progress()
	var started = work_clock.seconds
	await _frames(120)
	var elapsed = work_clock.seconds - started
	_check(
		(
			absf(
				site.construction_progress() - progress - elapsed / factions.BUILD_TIMES.PowerPlant
			)
			< .002
		),
		"Beacon did not continue at its authored rate after engineer death"
	)
	var funds = Vector2i(human.resource_a, human.resource_b)
	var refund = site.construction_refund()
	_check(site.cancel_construction(), "Active beacon could not be cancelled")
	_check(
		(
			Vector2i(human.resource_a, human.resource_b)
			== funds + Vector2i(refund.resource_a, refund.resource_b)
		),
		"Nanite cancellation changed the unused-cost refund"
	)
	await _frames(3)


func _queued_orders():
	await _fixture()
	var site = _spawn("PowerPlant", Vector3(40, 0, 12), true)
	var worker = _worker_at(site)
	var destination = worker.position + Vector3(9, 0, 0)
	worker.manual_orders.submit(worker.manual_orders.target_order("construct", site))
	worker.manual_orders.submit(worker.manual_orders.point_order("move", destination), true)
	await _frames(12)
	_check(site.construction_progress() > 0, "Queued builder did not activate beacon")
	_check(
		worker.manual_orders.current.get("kind") == "move",
		"Automatic harvesting replaced the engineer's queued movement order"
	)
	_check(
		worker.manual_orders.current.get("point") == destination,
		"Beacon deployment changed queued movement destination"
	)


func _paused_restore():
	await _fixture()
	var site = _spawn("PowerPlant", Vector3(40, 0, 12), true)
	var dormant = _spawn("PowerPlant", Vector3(48, 0, 12), true)
	var worker = _worker_at(site)
	worker.issue_manual_order(construct.new(site))
	await _frames(45)
	worker.hp = 0
	await _frames(3)
	paused = true
	var snapshotter = load("res://source/match/saves/MatchSnapshot.gd").new()
	var snapshot = snapshotter.capture(game)
	_check(snapshot != null, "Nanite foundation snapshot failed: " + snapshotter.error)
	if snapshot == null:
		paused = false
		return
	var id = snapshotter._reference(site)
	var dormant_id = snapshotter._reference(dormant)
	var progress = site.construction_progress()
	var restore = load("res://source/match/saves/MatchRestore.gd").new()
	var loaded = await restore.restore(self, snapshot)
	_check(loaded.ok, "Nanite foundation restore failed: " + loaded.get("error", ""))
	if not loaded.ok:
		paused = false
		return
	game = loaded.game
	human = game._get_human_player()
	site = restore.entities[id]
	dormant = restore.entities[dormant_id]
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	await _frames(30)
	_check(site.construction_progress() == progress, "Paused restore advances nanite construction")
	_check(dormant.construction_progress() == 0.0, "Restore activates an undeployed beacon")
	paused = false
	await _frames(60)
	_check(site.construction_progress() > progress, "Restored beacon waits for a dead engineer")
	_check(dormant.construction_progress() == 0.0, "Dormant site builds without an engineer")
	var assembly = site.get_node("AutonomousAssembly")
	assembly._process(100.0)
	await _frames(3)
	_check(site.is_constructed(), "Nanite beacon did not complete structure")
	_check(not site.has_node("AutonomousAssembly"), "Completed structure retains active assembly")
	_check(not site.has_node("ConstructionVisual"), "Completed beacon retains construction visual")


func _campaign_rate():
	await _fixture()
	human.set_meta("skirmish", false)
	var site = _spawn("PowerPlant", Vector3(40, 0, 12), true)
	var first = _worker_at(site)
	var second = _worker_at(site)
	first.issue_manual_order(construct.new(site))
	second.issue_manual_order(construct.new(site))
	await _frames(12)
	first.hp = 0
	second.hp = 0
	await _frames(3)
	var progress = site.construction_progress()
	var started = work_clock.seconds
	await _frames(60)
	var elapsed = work_clock.seconds - started
	_check(
		(
			absf(
				(
					site.construction_progress()
					- progress
					- elapsed * root.get_node("Constants").Match.Units.STRUCTURE_CONSTRUCTING_SPEED
				)
			)
			< .01
		),
		"Campaign Helix assembly still depends on engineer count"
	)


func _tethered(faction):
	await _fixture(faction)
	var site = _spawn("PowerPlant", Vector3(40, 0, 12), true)
	var worker = _worker_at(site)
	_check(not site.has_node("AutonomousAssembly"), faction + ": gained Helix nanite trait")
	worker.issue_manual_order(construct.new(site))
	await _frames(30)
	_check(site.construction_progress() > 0, faction + ": engineer did not start construction")
	worker.issue_manual_order(null)
	await _frames(3)
	var progress = site.construction_progress()
	await _frames(60)
	_check(site.construction_progress() == progress, faction + ": untethered site kept building")


func _frames(count):
	for frame in count:
		await process_frame


func _check(condition, message):
	if not condition:
		errors.append(message)
