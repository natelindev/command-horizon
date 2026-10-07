extends "res://source/match/Skirmish.gd"

const Progress = preload("res://source/match/campaign/CampaignProgress.gd")
const Library = preload("res://source/match/programs/ProgramLibrary.gd")
const ProductionFactions = preload("res://source/match/FactionCatalog.gd")
const AttackMove = preload("res://source/match/units/actions/AttackMoving.gd")
var nodes = []
var alarm = false
var hold_seconds = 0.0
var command_left = 60.0
var response_left = -1.0
var response_done = false
var progress_path = Progress.PATH
var progress_error = ""
var _enemy


func _ready():
	super()
	var opponents = get_tree().get_nodes_in_group("players").filter(
		func(side): return side != _get_human_player()
	)
	_enemy = opponents[0]
	_enemy.set_process(false)
	MatchSignals.unit_production_finished.connect(_produced)
	map.relay.captured.connect(_control_captured)
	_checkpoint("Operation start")
	hud.show_notice("Disable both production nodes, then secure the foundry with infantry.")


func _create_hud():
	return load("res://source/match/campaign/BrokenFoundryHUD.gd").new()


func _spawn_player_units(side, _spawn_transform):
	if side.faction == "helix":
		# Finite funds cover all six production batches; no income or hidden refills.
		side.resource_a = 600
		side.resource_b = 300
		_spawn("CommandLab", side, Vector3(145, 0, 87))
		for z in [27, 35]:
			_spawn("PowerPlant", side, Vector3(145, 0, z))
		for index in 2:
			var point = map.NODES[index]
			var factory = _spawn("VehicleFactory", side, point)
			factory.get_node("ProductionQueue").fit_chips = true
			nodes.append({"unit": factory, "disabled": false, "batches": 0, "left": 10.0})
			for member in [3, 4, 5][side.difficulty]:
				_spawn("Infantry", side, point + Vector3(-8 + member * 1.8, 0, 5))
			var tank = _spawn("Tank", side, point + Vector3(-5, 0, -4))
			_guard(tank, point + Vector3(-4, 0, 0))
			var support = _spawn("RepairRobot", side, point + Vector3(7, 0, 3))
			_guard(support, point + Vector3(5, 0, 2), "hold_service")
		for offset in [-5, 5]:
			var gun = _spawn("AdvancedTank", side, map.CONTROL + Vector3(4, 0, offset))
			_guard(gun, gun.position, "fire_support")
		for index in [4, 6, 8][side.difficulty]:
			_spawn(
				"Infantry", side, map.CONTROL + Vector3(-5 + index % 3 * 2, 0, -3 + index / 3 * 2)
			)
		_spawn("RepairDepot", side, map.CONTROL + Vector3(12, 0, 0))
		return
	var progress = Progress.new()
	progress.read_progress(progress_path)
	side.resource_a = 160
	side.resource_b = 80 + (20 if progress.air_support else 0)
	for entry in [
		["CommandCenter", Vector3(15, 0, 49)],
		["PowerPlant", Vector3(7, 0, 39)],
		["PowerPlant", Vector3(7, 0, 48)],
		["PowerPlant", Vector3(7, 0, 57)],
		["Barracks", Vector3(23, 0, 39)],
		["VehicleFactory", Vector3(31, 0, 48)],
		["CommandLab", Vector3(23, 0, 57)],
		["RepairDepot", Vector3(31, 0, 64)],
		["Worker", Vector3(9, 0, 72)],
		["Worker", Vector3(12, 0, 72)],
		["Drone", Vector3(35, 0, 58)],
		["RepairRobot", Vector3(33, 0, 35)],
		["RepairRobot", Vector3(33, 0, 81)],
		["AdvancedTank", Vector3(35, 0, 44)],
		["AdvancedTank", Vector3(35, 0, 72)]
	]:
		_spawn(entry[0], side, entry[1])
	for index in 6:
		_spawn("Tank", side, Vector3(35 + index % 3 * 2.6, 0, 29 + index / 3 * 53))
	for index in 12:
		_spawn("Infantry", side, Vector3(34 + index % 6 * 1.6, 0, 34 + index / 6 * 43))


func _spawn(role, side, point):
	var unit = load(Catalog.scene_path(role)).instantiate()
	if role == "Tank":
		unit.set_meta("chip_installed", true)
	_setup_and_spawn_unit(unit, Transform3D(Basis(), point), side, false)
	return unit


func _guard(unit, point, preset = "guard"):
	if unit.program == null:
		return
	var config = Library.defaults(preset)
	if preset == "fire_support":
		config.radius = 12.0
	unit.program.configure(config)
	unit.program.anchor = point
	unit.program.safe_point = point + Vector3(4, 0, 0)
	unit.program.run()


func _produced(unit, factory):
	for index in nodes.size():
		if nodes[index].unit == factory:
			_guard(unit, map.NODES[index] + Vector3(-5, 0, 0))
			return


func _alive(unit):
	return is_instance_valid(unit) and not unit.is_queued_for_deletion() and unit.hp > 0


func production_disabled():
	return nodes.size() == 2 and nodes.all(func(entry): return entry.disabled)


func _check_outcome(delta):
	if _enemy == null or nodes.size() != 2:
		return
	var human = _get_human_player()
	command_left = 60.0 if human.has_completed_structure("CommandCenter") else command_left - delta
	if (
		command_left <= 0
		or (human.population() == 0 and not human.has_completed_structure("CommandCenter"))
	):
		_finish("Defeat")
		return
	if (
		not alarm
		and human.get_children().any(
			func(unit): return unit.is_in_group("units") and _alive(unit) and unit.position.x >= 46
		)
	):
		alarm = true
		hud.show_notice("Production starts in 10s · three paid batches per node.")
	for index in nodes.size():
		var entry = nodes[index]
		if entry.disabled:
			continue
		if not _alive(entry.unit):
			entry.unit = null
			entry.disabled = true
			entry.left = 0.0
			_checkpoint("Production node disabled")
			continue
		if alarm and entry.batches < 3:
			var before = entry.left
			entry.left = maxf(0, entry.left - delta)
			if before > 10 and entry.left <= 10:
				hud.show_notice(
					"%s node · next production batch in 10 seconds." % ["North", "South"][index]
				)
			if entry.left == 0:
				_start_batch(entry)
	if production_disabled() and response_left < 0:
		response_left = 10.0
		hud.show_notice("Nodes disabled. Capture the foundry. East response in 10s.")
	if response_left >= 0 and not response_done:
		response_left = maxf(0, response_left - delta)
		if response_left == 0:
			_send_response()
	var relay = map.relay
	if production_disabled() and relay.captured_by == human and not relay.contested:
		# Infantry must stay to secure the works; a remote owned marker is insufficient.
		if has_capture_infantry():
			hold_seconds = minf(30, hold_seconds + delta)
	if hold_seconds >= 30:
		_finish("Victory")


func batch_size():
	return [1, 2, 3][_enemy.difficulty]


func batch_wait_reason(entry):
	if not _alive(entry.unit) or not entry.unit.is_constructed():
		return "Factory unavailable"
	var queue = entry.unit.get_node("ProductionQueue")
	var count = batch_size()
	if queue.size() + count > Constants.Match.Units.PRODUCTION_QUEUE_LIMIT:
		return "Queue space needed"
	if _enemy.population(true) + count > Catalog.POPULATION_LIMIT:
		return "Unit limit"
	if queue.fit_chips and not _enemy.has_completed_structure("CommandLab"):
		return "Lab required"
	var cost = ProductionFactions.cost(_enemy, "Tank").duplicate()
	if queue.fit_chips:
		cost.resource_b += ProductionFactions.chip_cost(_enemy.faction)
	cost.resource_a *= count
	cost.resource_b *= count
	if not _enemy.has_resources(cost):
		return "Funds needed"
	return ""


func _start_batch(entry):
	# Admit the whole batch through the ordinary queue. A rejected attempt must
	# retain its budget; no partial batch, overflow slot or unpaid unit is allowed.
	if not batch_wait_reason(entry).is_empty():
		return
	var queue = entry.unit.get_node("ProductionQueue")
	var jobs = []
	for index in batch_size():
		var job = queue.produce(load(Catalog.scene_path("Tank")))
		if job == null:
			for admitted in jobs:
				queue.cancel(admitted)
			return
		jobs.append(job)
	entry.batches += 1
	entry.left = 45.0 if entry.batches < 3 else 0.0
	hud.show_notice(
		(
			"Production batch %d / 3 queued. Destroy its node to cancel unfinished units."
			% entry.batches
		)
	)


func _send_response():
	if response_done:
		return
	response_done = true
	response_left = 0.0
	if _get_human_player().get_children().any(
		func(unit):
			return (
				unit.is_in_group("units")
				and _alive(unit)
				and unit.global_position_yless.distance_to(map.ENTRY) <= 12
			)
	):
		hud.show_notice("East entry secured · final response denied.")
		return
	for index in [3, 5, 7][_enemy.difficulty]:
		var unit = _spawn(
			"Tank" if index % 3 == 0 else "Infantry",
			_enemy,
			map.ENTRY + Vector3(0, 0, index * 1.8 - 5)
		)
		unit.issue_manual_order(AttackMove.new(map.CONTROL))
	hud.show_notice("Final Helix response entered from the east.")


func _finish(value):
	if finished:
		return
	finished = true
	result = value
	if value == "Victory":
		var progress = Progress.new()
		if not progress.record_foundry_victory(progress_path):
			progress_error = progress.error
	hud.show_result("Broken Foundry · " + value)


func _control_captured(side):
	if side == _get_human_player():
		_checkpoint("Foundry control captured")
		hud.show_notice("Control captured. Keep infantry here for 30 uncontested seconds.")
	else:
		hud.show_notice("Helix controls the foundry. Recapture it; secured time is retained.")


func objective_text():
	if command_left < 60:
		return "Rebuild HQ · %ds remaining" % ceili(command_left)
	if not production_disabled():
		var count = nodes.filter(func(entry): return entry.disabled).size()
		return "Disable production · %d / 2 nodes" % count
	return "Foundry · " + control_status()


func has_capture_infantry():
	var human = _get_human_player()
	return battlefield.nearby_units(map.CONTROL, map.relay.RADIUS).any(
		func(unit): return unit.player == human and unit.type == "Infantry" and _alive(unit)
	)


func control_status():
	if not production_disabled():
		return "Control locked · disable both nodes"
	if finished and result == "Victory":
		return "Secured · 30 / 30 s"
	var relay = map.relay
	var human = _get_human_player()
	if relay.capture_side() != null:
		return relay.capture_status(human)
	if relay.contested:
		return "Contested · %d / 30 s held" % int(hold_seconds)
	if relay.captured_by == human:
		return (
			"Securing · %d / 30 s" % int(hold_seconds)
			if has_capture_infantry()
			else "Infantry needed · %d / 30 s held" % int(hold_seconds)
		)
	return relay.capture_status(human)


func control_help():
	if not production_disabled():
		return "Destroy both production nodes before infantry can capture foundry control."
	var text = map.relay.capture_help(_get_human_player())
	text += " Keep infantry within 3 m for 30 uncontested seconds after capture."
	text += " Secured time is retained when you leave or lose control."
	if map.relay.captured_by == _get_human_player() and not has_capture_infantry():
		text += " Return infantry to resume securing."
	return text


func result_summary():
	var text = (
		"Foundry secured · alternate finale approach unlocked."
		if result == "Victory"
		else "Command lost. Protect repair support and rebuild HQ within 60 seconds."
	)
	return text + ("\n" + progress_error if not progress_error.is_empty() else "")


func _checkpoint(reason):
	get_node("/root/SaveManager").request_checkpoint(self, reason)
