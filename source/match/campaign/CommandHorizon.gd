extends "res://source/match/Skirmish.gd"

const InfantryRoster = preload("res://source/match/BastionCatalog.gd")

const Progress = preload("res://source/match/campaign/CampaignProgress.gd")
const Posts = preload("res://source/match/campaign/CampaignPosts.gd")
const AttackMove = preload("res://source/match/units/actions/AttackMoving.gd")
const WAVE_TIMES = [20.0, 50.0, 80.0, 110.0]
const CHALLENGES = ["", "lean", "reinforced"]
var alternate_route = false
var deployed = false
var hold_seconds = 0.0
var command_left = 60.0
var command_destroyed = false
var target_command = null
var defence_started = false
var defence_time = 0.0
var waves_sent = 0
var waves_warned = 0
var progress_path = Progress.PATH
var progress_error = ""
var opposition
var siege_commander
var _enemy


func _ready():
	if settings.campaign_challenge not in CHALLENGES:
		settings.campaign_challenge = ""
	super()
	var opponents = get_tree().get_nodes_in_group("players").filter(
		func(side): return side != _get_human_player()
	)
	_enemy = opponents[0]
	_enemy.set_process(false)
	opposition = load("res://source/match/campaign/CampaignOpposition.gd").new()
	opposition.name = "CampaignOpposition"
	add_child(opposition)
	opposition.configure(self, _enemy, map.DEPLOYMENT, siege_commander)
	map.relay.captured.connect(_zone_captured)
	_checkpoint("Operation start")
	hud.show_notice("Infantry secure deployment. Leave a guard while your strike force advances.")


func _create_hud():
	return load("res://source/match/campaign/CommandHorizonHUD.gd").new()


func _spawn_player_units(side, _spawn_transform):
	if side.faction == "helix":
		side.resource_a = 100
		side.resource_b = 30
		target_command = _spawn("CommandCenter", side, map.TARGET)
		for entry in [
			["PowerPlant", Vector3(174, 0, 43)],
			["PowerPlant", Vector3(174, 0, 51)],
			["PowerPlant", Vector3(174, 0, 59)],
			["Barracks", Vector3(160, 0, 43)],
			["VehicleFactory", Vector3(169, 0, 75)],
			["CommandLab", Vector3(173, 0, 87)],
			["RepairDepot", Vector3(162, 0, 84)],
			["AircraftFactory", Vector3(161, 0, 99)],
			["AntiAirTurret", Vector3(146, 0, 51)],
			["AntiGroundTurret", Vector3(132, 0, 104)],
			["AntiGroundTurret", Vector3(142, 0, 88)]
		]:
			_spawn(entry[0], side, entry[1])
		for index in [4, 6, 8][side.difficulty]:
			_spawn(
				"Infantry",
				side,
				map.DEPLOYMENT + Vector3(-3 + index % 4 * 2, 0, -3 + index / 4 * 5)
			)
		for z in [-7, 7]:
			Posts.guard(
				_spawn("Tank", side, map.DEPLOYMENT + Vector3(7, 0, z)),
				map.DEPLOYMENT + Vector3(4, 0, z)
			)
		Posts.guard(
			_spawn("RepairRobot", side, map.DEPLOYMENT + Vector3(11, 0, 0)),
			map.DEPLOYMENT + Vector3(8, 0, 0)
		)
		for index in 4:
			_spawn("Infantry", side, Vector3(137 + index * 1.7, 0, 108))
		for z in [101, 115]:
			Posts.guard(_spawn("Tank", side, Vector3(141, 0, z)), Vector3(138, 0, z))
		var extra = 4 if settings.campaign_challenge == "reinforced" else 0
		for index in [6, 8, 10][side.difficulty] + extra:
			_spawn(
				"Infantry", side, map.TARGET + Vector3(-10 + index % 4 * 1.8, 0, -5 + index / 4 * 3)
			)
		for z in [-9, 9]:
			Posts.guard(
				_spawn("CombatRobot", side, map.TARGET + Vector3(-5, 0, z)),
				map.TARGET + Vector3(-6, 0, z)
			)
			var artillery = _spawn("AdvancedTank", side, map.TARGET + Vector3(0, 0, z))
			Posts.guard(artillery, map.TARGET + Vector3(0, 0, z))
			if z == 9:
				siege_commander = artillery
			Posts.guard(
				_spawn("Helicopter", side, map.TARGET + Vector3(8, 0, z)),
				map.TARGET + Vector3(2, 0, z)
			)
			Posts.guard(
				_spawn("RepairRobot", side, map.TARGET + Vector3(5, 0, z)),
				map.TARGET + Vector3(4, 0, z)
			)
		for index in 4:
			_spawn("Worker", side, Vector3(165 + index * 2, 0, 34))
		return
	var lean = settings.campaign_challenge == "lean"
	side.resource_a = 80 if lean else 180
	side.resource_b = 40 if lean else 100
	side.coordination_unlocked = true
	for entry in [
		["CommandCenter", Vector3(16, 0, 57)],
		["PowerPlant", Vector3(7, 0, 42)],
		["PowerPlant", Vector3(7, 0, 51)],
		["PowerPlant", Vector3(7, 0, 60)],
		["Barracks", Vector3(23, 0, 44)],
		["VehicleFactory", Vector3(32, 0, 54)],
		["CommandLab", Vector3(23, 0, 64)],
		["RepairDepot", Vector3(32, 0, 73)],
		["AircraftFactory", Vector3(15, 0, 77)],
		["Drone", Vector3(39, 0, 59)],
		["RepairRobot", Vector3(37, 0, 45)],
		["RepairRobot", Vector3(37, 0, 82)],
		["AdvancedTank", Vector3(37, 0, 49)],
		["AdvancedTank", Vector3(37, 0, 77)],
		["Helicopter", Vector3(22, 0, 80)],
		["Helicopter", Vector3(27, 0, 80)]
	]:
		_spawn(entry[0], side, entry[1])
	for index in 2 if lean else 4:
		_spawn("Worker", side, Vector3(9 + index * 2, 0, 86))
	for index in 4 if lean else 8:
		_spawn("Tank", side, Vector3(38 + index % 4 * 2.7, 0, 37 + index / 4 * 48))
	for index in 4:
		_spawn("CombatRobot", side, Vector3(39 + index * 2.5, 0, 65))
	for index in 8 if lean else 12:
		_spawn("Infantry", side, Vector3(39 + index % 6 * 1.8, 0, 42 + index / 6 * 38))


func _spawn(role, side, point):
	var unit = load(Catalog.scene_path(role)).instantiate()
	_setup_and_spawn_unit(unit, Transform3D(Basis(), point), side, false)
	return unit


func _alive(unit):
	return is_instance_valid(unit) and not unit.is_queued_for_deletion() and unit.hp > 0


func has_deployment_infantry():
	var human = _get_human_player()
	if battlefield == null or human == null:
		return false
	return battlefield.nearby_units(map.DEPLOYMENT, map.relay.RADIUS).any(
		func(unit):
			return unit.player == human and InfantryRoster.is_infantry(unit.type) and _alive(unit)
	)


func zone_held():
	return (
		map.relay.captured_by == _get_human_player()
		and not map.relay.contested
		and has_deployment_infantry()
	)


func deployment_status():
	if finished and result == "Victory":
		return "Secured · 30 / 30 s"
	var relay = map.relay
	var human = _get_human_player()
	if relay.capture_side() != null:
		return relay.capture_status(human)
	if relay.contested:
		return "Contested · %d / 30 s held" % int(hold_seconds)
	if human != null and relay.captured_by == human:
		if not has_deployment_infantry():
			return "Infantry needed · %d / 30 s held" % int(hold_seconds)
		return (
			"Guard in place · 30 / 30 s" if deployed else "Securing · %d / 30 s" % int(hold_seconds)
		)
	return relay.capture_status(human)


func deployment_help():
	var text = map.relay.capture_help(_get_human_player()).replace(". ", ".\n")
	text += "\nAfter capture, keep infantry here for 30 uncontested seconds."
	text += "\nSecured time is retained when you leave or lose control."
	text += "\nTo win, destroy enemy command and its siege commander; "
	text += "keep an uncontested infantry guard here."
	if map.relay.captured_by == _get_human_player() and not has_deployment_infantry():
		text += "\nReturn infantry; no recapture is needed unless ownership changes."
	return text


func _check_outcome(delta):
	if _enemy == null:
		return
	Posts.service(_enemy)
	var human = _get_human_player()
	command_left = 60.0 if human.has_completed_structure("CommandCenter") else command_left - delta
	if (
		command_left <= 0
		or (human.population() == 0 and not human.has_completed_structure("CommandCenter"))
	):
		_finish("Defeat")
		return
	if not command_destroyed and not _alive(target_command):
		target_command = null
		command_destroyed = true
		_checkpoint("Enemy command destroyed")
		if not deployed or not zone_held():
			hud.show_notice("Helix command destroyed. Secure deployment with infantry to finish.")
	if not deployed and zone_held():
		hold_seconds = minf(30, hold_seconds + delta)
		if hold_seconds >= 30:
			deployed = true
			_checkpoint("Deployment secured")
			hud.show_notice(
				"Deployment ready. Keep infantry here while your strike force destroys command."
			)
	if deployed and command_destroyed and opposition.boss_defeated and zone_held():
		if (
			campaign_hero.alive()
			and campaign_hero.unit.global_position_yless.distance_to(map.TARGET) < 18
		):
			_finish("Victory")
		return
	if not defence_started:
		return
	opposition.activate()
	opposition.step(delta)
	defence_time += delta
	if waves_warned < WAVE_TIMES.size() and defence_time >= WAVE_TIMES[waves_warned] - 10:
		waves_warned += 1
		hud.show_notice("Response %d / 4 in 10s · ground south, aircraft northeast." % waves_warned)
	if waves_sent < WAVE_TIMES.size() and defence_time >= WAVE_TIMES[waves_sent]:
		_send_wave()


func _zone_captured(side):
	if side == _get_human_player():
		defence_started = true
		_checkpoint("Deployment control captured")
		hud.show_notice("Deployment control captured. Hold with infantry; guard both approaches.")
	else:
		hud.show_notice("Deployment lost. Recapture with infantry; secured time is retained.")


func _send_wave():
	if waves_sent >= WAVE_TIMES.size():
		return
	var ground = [2, 3, 4][_enemy.difficulty]
	if settings.campaign_challenge == "reinforced":
		ground += 1
	var air = [1, 1, 2][_enemy.difficulty]
	var count = 0
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
		for index in ground if lane == 0 else air:
			var role = (
				"Helicopter" if lane == 1 else ("Tank" if index == ground - 1 else "Infantry")
			)
			var unit = _spawn(role, _enemy, entry + Vector3(index * 2.5, 0, lane * 2))
			unit.issue_manual_order(AttackMove.new(map.DEPLOYMENT + Vector3(index, 0, 0)))
			count += 1
	waves_sent += 1
	hud.show_notice(
		(
			"Response %d / 4 entered · %d units. Keep the deployment guard in place."
			% [waves_sent, count]
		)
	)


func _finish(value):
	if finished:
		return
	finished = true
	result = value
	if value == "Victory":
		var progress = Progress.new()
		if not progress.record_horizon_victory(settings.campaign_challenge, progress_path):
			progress_error = progress.error
	hud.show_result("Command Horizon · " + value)


func objective_text():
	if deployed and command_destroyed and opposition.boss_defeated and zone_held():
		return "Bring Aegis to the Spire controls to open the gates."
	if command_left < 60:
		return "Rebuild HQ · %ds remaining" % ceili(command_left)
	if command_destroyed and not opposition.boss_defeated:
		return "Destroy the siege commander and keep deployment guarded."
	if command_destroyed:
		var deployment = "retake deployment with infantry"
		if not deployed:
			deployment = (
				"capture deployment with infantry"
				if deployment_status() == "Unclaimed"
				else "deployment · " + deployment_status().to_lower()
			)
		elif zone_held():
			deployment = "deployment secured"
		elif map.relay.captured_by == _get_human_player() and not map.relay.contested:
			deployment = "return infantry to deployment"
		return "Command destroyed · " + deployment
	if not deployed or not zone_held():
		return "Deployment · " + deployment_status()
	return "Hold deployment; destroy Helix command and its siege commander."


func result_summary():
	if result != "Victory":
		return "Command lost. Keep a deployment guard and protect your strike force's repair support."
	var progress = Progress.new()
	progress.read_progress(progress_path)
	var text = (
		"Bastion campaign complete · all six operations secured."
		if progress.campaign_finished()
		else "Finale complete · %d / 6 operations secured." % progress.completed_count()
	)
	text += "\nReplay challenges unlocked: Lean deployment and Reinforced garrison."
	if settings.campaign_challenge != "":
		text += (
			"\nChallenge completed: "
			+ (
				"Lean deployment"
				if settings.campaign_challenge == "lean"
				else "Reinforced garrison"
			)
		)
	return text + ("\n" + progress_error if not progress_error.is_empty() else "")


func _checkpoint(reason):
	get_node("/root/SaveManager").request_checkpoint(self, reason)
