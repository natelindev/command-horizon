extends "res://source/match/Skirmish.gd"

const Progress = preload("res://source/match/campaign/CampaignProgress.gd")
const AttackMove = preload("res://source/match/units/actions/AttackMoving.gd")
const WAVE_TIMES = [10.0, 28.0, 44.0]
var phase = 0
var relay
var hold_seconds = 0.0
var command_left = 60.0
var defence_started = false
var defence_time = 0.0
var waves_sent = 0
var waves_warned = 0
var reuse_badge = false
var progress_path = Progress.PATH
var progress_error = ""
var _enemy


func _ready():
	super()
	relay = map.get_node("Relay")
	var opponents = get_tree().get_nodes_in_group("players").filter(
		func(side): return side != _get_human_player()
	)
	_enemy = opponents[0]
	_enemy.set_process(false)
	relay.captured.connect(_relay_captured)
	_checkpoint("Operation start")
	hud.show_notice(
		"First Orders: build your command lab. There is no attack timer while you learn."
	)


func _create_hud():
	return load("res://source/match/campaign/FirstOrdersHUD.gd").new()


func _spawn_player_units(player, _spawn_transform):
	if player.faction != "bastion":
		for point in [Vector3(43, 0, 40), Vector3(44, 0, 42)]:
			_spawn("Infantry", player, point)
		return
	var progress = Progress.new()
	progress.read_progress(progress_path)
	player.resource_a = 100 if progress.supply_complete else 80
	player.resource_b = 32
	for entry in [
		["CommandCenter", Vector3(14, 0, 15)],
		["PowerPlant", Vector3(8, 0, 15)],
		["Barracks", Vector3(14, 0, 9)],
		["VehicleFactory", Vector3(21, 0, 15)],
		["Worker", Vector3(10, 0, 21)],
		["Worker", Vector3(13, 0, 21)],
		["Worker", Vector3(16, 0, 21)],
		["Tank", Vector3(20, 0, 23)],
		["Tank", Vector3(23, 0, 23)],
		["Tank", Vector3(26, 0, 23)],
		["RepairRobot", Vector3(17, 0, 24)]
	]:
		_spawn(entry[0], player, entry[1])
	for index in range(6):
		_spawn("Infantry", player, Vector3(18 + (index % 3) * 1.5, 0, 27 + (index / 3) * 1.5))


func _spawn(role, side, point):
	var unit = load(Catalog.scene_path(role)).instantiate()
	_setup_and_spawn_unit(unit, Transform3D(Basis(), point), side, false)
	return unit


func _check_outcome(delta):
	if relay == null:
		return
	var human = _get_human_player()
	command_left = 60.0 if human.has_completed_structure("CommandCenter") else command_left - delta
	if human.population() == 0 and not human.has_completed_structure("CommandCenter"):
		_finish("Defeat")
		return
	if command_left <= 0:
		_finish("Defeat")
		return
	var units = human.get_children().filter(
		func(unit): return "program" in unit and unit.program != null
	)
	for unit in units:
		var program = unit.program
		if program.mode not in ["Running", "Ready"] or not program.ready_to_run():
			continue
		if not program.saved_record.is_empty():
			var saved = program.saved_record
			if saved.mode == "preset" and saved.config.retreat != 30:
				reuse_badge = true
		if phase == 1 and program.anchor != null:
			if unit.type == "RepairRobot" or program.safe_point != null:
				phase = 2
				_checkpoint("Program assigned")
				(
					hud
					. show_notice(
						"Program online. Move infantry to the relay; tanks screen and repair supports them."
					)
				)
	if phase == 0 and human.basic_programs_unlocked():
		phase = 1
		_checkpoint("Command lab complete")
		hud.show_notice(
			"Lab complete. Your repair robot already has a chip; tanks can fit one at HQ for 4 E."
		)
	if phase == 2 and relay.captured_by == human:
		if not defence_started:
			defence_started = true
		if not relay.contested:
			hold_seconds += delta
	elif relay.captured_by != human:
		hold_seconds = 0.0
	if hold_seconds >= 60.0:
		_finish("Victory")
		return
	if defence_started:
		defence_time += delta
		if waves_warned < WAVE_TIMES.size() and defence_time >= WAVE_TIMES[waves_warned] - 10:
			waves_warned += 1
			hud.show_notice(
				"Helix response %d / 3 · eastern approach in 10 seconds." % waves_warned
			)
		if waves_sent < WAVE_TIMES.size() and defence_time >= WAVE_TIMES[waves_sent]:
			_send_wave()


func _relay_captured(side):
	if side == _get_human_player():
		_checkpoint("Relay secured")
	(
		hud
		. show_notice(
			(
				"Relay secured. Hold for 60 uncontested seconds."
				if side == _get_human_player()
				else "Helix controls the relay. Infantry can recapture it after the defenders are cleared."
			)
		)
	)


func _send_wave():
	# A player who occupies the authored arrival zone can deny this entry.
	var entry = Vector3(66, 0, 34)
	var defenders = battlefield.nearby_units(entry, 12.0)
	if defenders.any(func(unit): return unit.player == _get_human_player()):
		return
	var difficulty = _enemy.difficulty
	var counts = [3, 4, 5]
	var count = counts[difficulty]
	for index in range(count):
		var role = "Tank" if index == count - 1 and waves_sent > 0 else "Infantry"
		var unit = _spawn(role, _enemy, Vector3(66 + (index % 2) * 2, 0, 34 + (index / 2) * 2))
		combat_effects.movement_dust(unit)
		unit.issue_manual_order(AttackMove.new(relay.global_position + Vector3(index * 0.6, 0, 0)))
	waves_sent += 1
	hud.show_notice("Helix response %d / 3 approaching the relay from the east." % waves_sent)


func _finish(value):
	if finished:
		return
	finished = true
	result = value
	if value == "Victory":
		var progress = Progress.new()
		if not progress.record_victory(reuse_badge, progress_path):
			progress_error = progress.error
	hud.show_result("First Orders · " + value)


func objective_text():
	if command_left < 60:
		return "Rebuild HQ · %ds remaining" % ceili(command_left)
	return [
		"Build a command lab",
		"Assign a retreat or repair program",
		"Secure relay · %d / 60 s" % int(hold_seconds)
	][phase]


func result_summary():
	var text = (
		"Relay logistics are back online."
		if result == "Victory"
		else "Command lost. Rebuild the HQ within 60 seconds to stay in the operation."
	)
	text += (
		"\n"
		+ (
			"Adaptive doctrine badge earned."
			if reuse_badge
			else "Optional: change a retreat threshold, save it, then load and apply that version."
		)
	)
	if not progress_error.is_empty():
		text += "\n" + progress_error
	return text


func _checkpoint(reason):
	get_node("/root/SaveManager").request_checkpoint(self, reason)
