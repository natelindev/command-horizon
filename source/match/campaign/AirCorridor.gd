extends "res://source/match/Skirmish.gd"

const Progress = preload("res://source/match/campaign/CampaignProgress.gd")
const Moving = preload("res://source/match/units/actions/Moving.gd")
const AttackMove = preload("res://source/match/units/actions/AttackMoving.gd")
var sites = []
var flights = []
var command_left = 60.0
var progress_path = Progress.PATH
var progress_error = ""
var _enemy


func _ready():
	super()
	var opponents = get_tree().get_nodes_in_group("players").filter(
		func(p): return p != _get_human_player()
	)
	_enemy = opponents[0]
	_enemy.set_process(false)
	if not restoring:
		for index in 3:
			flights.append(
				{"state": "ready", "unit": null, "response_left": -1.0, "response_done": false}
			)
	_checkpoint("Operation start")
	hud.show_notice(
		"Clear both batteries with ground troops. Position your screen before launching."
	)


func _create_hud():
	return load("res://source/match/campaign/AirCorridorHUD.gd").new()


func _spawn_player_units(side, _spawn_transform):
	if side.faction == "helix":
		for point in map.SITES:
			sites.append({"unit": _spawn("AntiAirTurret", side, point), "cleared": false})
			for index in [2, 3, 4][side.difficulty]:
				_spawn("Infantry", side, point + Vector3(-3 + index * 2, 0, -4))
			_spawn("Tank", side, point + Vector3(4, 0, 4))
		var progress = Progress.new()
		progress.read_progress(progress_path)
		if not progress.network_badge:
			var patrol = _spawn("Helicopter", side, Vector3(108, 0, 34))
			var orders = load("res://source/match/orders/ManualOrders.gd")
			for index in 16:
				patrol.manual_orders.submit(
					orders.point_order(
						"attack_move", Vector3(102, 0, 38 if index % 2 == 0 else 66)
					),
					index > 0
				)
		return
	side.resource_a = 140
	side.resource_b = 80
	for entry in [
		["CommandCenter", Vector3(15, 0, 31)],
		["PowerPlant", Vector3(7, 0, 25)],
		["PowerPlant", Vector3(7, 0, 34)],
		["PowerPlant", Vector3(7, 0, 43)],
		["Barracks", Vector3(23, 0, 26)],
		["VehicleFactory", Vector3(31, 0, 31)],
		["CommandLab", Vector3(23, 0, 36)],
		["RepairDepot", Vector3(31, 0, 41)],
		["AircraftFactory", Vector3(14, 0, 62)],
		["Worker", Vector3(9, 0, 66)],
		["Worker", Vector3(12, 0, 69)],
		["Drone", Vector3(32, 0, 56)],
		["Helicopter", Vector3(18, 0, 62)],
		["Helicopter", Vector3(22, 0, 62)],
		["RepairRobot", Vector3(33, 0, 48)],
		["RepairRobot", Vector3(33, 0, 58)]
	]:
		_spawn(entry[0], side, entry[1])
	for index in 4:
		_spawn("Tank", side, Vector3(36 + index * 2.4, 0, 49))
		_spawn("CombatRobot", side, Vector3(36 + index * 2.4, 0, 55))
	for index in 6:
		_spawn("Infantry", side, Vector3(35 + index % 3 * 1.7, 0, 61 + index / 3 * 1.7))


func _spawn(role, side, point):
	var unit = load(Catalog.scene_path(role)).instantiate()
	if role == "Tank" and side.faction == "bastion":
		unit.set_meta("chip_installed", true)
	_setup_and_spawn_unit(unit, Transform3D(Basis(), point), side, false)
	return unit


func _alive(unit):
	return is_instance_valid(unit) and not unit.is_queued_for_deletion() and unit.hp > 0


func rescued():
	return flights.filter(func(flight): return flight.state == "extracted").size()


func launch_reason():
	if finished:
		return "Operation ended."
	if sites.any(func(site): return not site.cleared):
		return "Destroy both anti-air batteries first."
	if flights.any(func(flight): return flight.state == "flying"):
		return "Escort the active flight before launching another."
	if not flights.any(func(flight): return flight.state == "ready"):
		return "No flights remaining."
	if _get_human_player().population(true) >= Catalog.POPULATION_LIMIT:
		return "Reserve one unit slot for the rescue VTOL."
	return ""


func launch_flight():
	var reason = launch_reason()
	if not reason.is_empty():
		hud.show_notice(reason)
		return false
	var flight = flights.filter(func(entry): return entry.state == "ready")[0]
	flight.unit = _spawn("EvacTransport", _get_human_player(), map.LAUNCH)
	flight.state = "flying"
	flight.response_left = 10.0
	flight.unit.issue_manual_order(Moving.new(map.EXIT))
	hud.show_notice(
		"Flight launched. Helix ground/air response in 10 seconds at the east approaches."
	)
	_checkpoint("Evacuation launched")
	return true


func continue_flight():
	if finished:
		return false
	for flight in flights:
		if flight.state == "flying" and _alive(flight.unit):
			flight.unit.issue_manual_order(Moving.new(map.EXIT))
			return true
	return false


func finish_evacuation():
	if rescued() >= 2 and not finished:
		_finish("Victory")


func _check_outcome(delta):
	if _enemy == null or flights.size() != 3:
		return
	var human = _get_human_player()
	command_left = 60.0 if human.has_completed_structure("CommandCenter") else command_left - delta
	if (
		command_left <= 0
		or (human.population() == 0 and not human.has_completed_structure("CommandCenter"))
	):
		_finish("Defeat")
		return
	for site in sites:
		if not site.cleared and not _alive(site.unit):
			site.unit = null
			site.cleared = true
			_checkpoint("Anti-air battery destroyed")
	for flight in flights:
		if flight.state == "flying":
			if not _alive(flight.unit):
				flight.state = "lost"
				flight.unit = null
				hud.show_notice("Evacuation flight lost. Two losses end the operation.")
			elif flight.unit.global_position_yless.distance_to(map.EXIT) <= 5:
				flight.state = "extracted"
				flight.unit.queue_free()
				flight.unit = null
				hud.show_notice("Flight safe. Launch another when your escort is ready.")
				_checkpoint("Evacuation secured")
		if flight.response_left >= 0 and not flight.response_done:
			flight.response_left = maxf(0, flight.response_left - delta)
			if flight.response_left == 0:
				_send_response(flight)
	var losses = flights.filter(func(flight): return flight.state == "lost").size()
	if losses >= 2:
		_finish("Defeat")
	elif (
		rescued() >= 2 and not flights.any(func(flight): return flight.state in ["ready", "flying"])
	):
		_finish("Victory")


func _send_response(flight):
	if flight.response_done:
		return
	flight.response_done = true
	flight.response_left = 0.0
	var spawned = 0
	for lane in 2:
		var entry = map.ENTRIES[lane]
		if _get_human_player().get_children().any(
			func(unit):
				return (
					unit.is_in_group("units")
					and _alive(unit)
					and unit.global_position_yless.distance_to(entry) <= 12
				)
		):
			continue
		var count = ([1, 2, 3] if lane == 0 else [1, 1, 2])[_enemy.difficulty]
		for member in count:
			var role = "CombatRobot" if lane == 0 else "Helicopter"
			var unit = _spawn(role, _enemy, entry + Vector3(member * 2.5, 0, 0))
			if role == "CombatRobot":
				unit.request_weapon_mode("interception")
			unit.issue_manual_order(AttackMove.new(map.SCREEN + Vector3(member, 0, 0)))
			spawned += 1
	hud.show_notice(
		"Helix response entered · %d units. Ground troops counter the Lancers." % spawned
	)


func _finish(value):
	if finished:
		return
	finished = true
	result = value
	if value == "Victory":
		var progress = Progress.new()
		if not progress.record_air_victory(rescued() == 3, progress_path):
			progress_error = progress.error
	hud.show_result("Air Corridor · " + value)


func objective_text():
	if command_left < 60:
		return "Rebuild HQ · %ds remaining" % ceili(command_left)
	var batteries = sites.filter(func(site): return site.cleared).size()
	return (
		"Destroy both batteries · %d / 2" % batteries
		if batteries < 2
		else "Evacuate two flights · %d / 2 safe" % rescued()
	)


func result_summary():
	var text = "%d / 3 flights evacuated." % rescued()
	if result == "Victory":
		text += (
			"\n"
			+ (
				"All flights saved · operation 05 electronics support recorded."
				if rescued() == 3
				else "Optional: evacuate all three flights for operation 05 support."
			)
		)
	else:
		text += "\nProtect your HQ and at least two flights."
	return text + ("\n" + progress_error if not progress_error.is_empty() else "")


func _checkpoint(reason):
	get_node("/root/SaveManager").request_checkpoint(self, reason)
