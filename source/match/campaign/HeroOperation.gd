extends "res://source/match/Skirmish.gd"

const Operations = preload("res://source/match/campaign/CampaignCatalog.gd")
const Progress = preload("res://source/match/campaign/CampaignProgress.gd")
const AttackMove = preload("res://source/match/units/actions/AttackMoving.gd")
const Moving = preload("res://source/match/units/actions/Moving.gd")
var stage = 0
var elapsed = 0.0
var wave_left = 30.0
var waves = 0
var targets = []
var escort
var progress_path = Progress.PATH
var progress_error = ""
var _enemy
var _definition:
	get:
		return Operations.STORIES[settings.mission_id]


func _ready():
	super()
	_enemy = get_node("Players").get_children().filter(func(p): return p != _get_human_player())[0]
	_enemy.set_process(false)
	if not restoring:
		_enter_stage()


func _spawn_player_units(side, _spawn_transform):
	if side != _get_human_player():
		var support = Progress.new()
		support.read_progress(progress_path)
		var reduction = (
			1 if settings.mission_id == "bastion_cinder_ford" and support.network_badge else 0
		)
		for index in _definition.objectives.size():
			var objective = _definition.objectives[index]
			var point = _point(objective.point)
			var target = null
			if objective.kind == "destroy":
				target = _spawn(objective.role, side, point)
			targets.append(target)
			for member in maxi(1, int(objective.guards) + side.difficulty - 1 - reduction):
				if objective.guards == 0:
					break
				_spawn(
					"Tank" if member == 4 else "Infantry",
					side,
					point + Vector3((member % 3 - 1) * 3, 0, 6 + int(member / 3) * 3)
				)
		return
	side.resource_a = 140
	side.resource_b = 60
	for entry in [
		["CommandCenter", Vector3(18, 0, 100)],
		["PowerPlant", Vector3(10, 0, 100)],
		["Barracks", Vector3(18, 0, 92)],
		["VehicleFactory", Vector3(27, 0, 100)],
		["CommandLab", Vector3(10, 0, 91)],
		["RepairDepot", Vector3(27, 0, 91)]
	]:
		_spawn(entry[0], side, entry[1])
	for index in 4:
		_spawn("Worker", side, Vector3(12 + index * 2, 0, 109))
	for index in 8:
		_spawn("Infantry", side, Vector3(26 + index % 4 * 2, 0, 82 + int(index / 4) * 2))
	for index in 3:
		_spawn("Tank", side, Vector3(34 + index * 3, 0, 94))
	for index in 2:
		_spawn("RepairRobot", side, Vector3(28 + index * 3, 0, 87))


func _spawn(role, side, point):
	var unit = load(Catalog.scene_path(role)).instantiate()
	_setup_and_spawn_unit(unit, Transform3D(Basis(), point), side, false)
	return unit


func _point(value):
	return Vector3(value[0], 0, value[1])


func current_objective():
	return _definition.objectives[mini(stage, _definition.objectives.size() - 1)]


func _enter_stage():
	elapsed = 0.0
	wave_left = 25.0
	waves = 0
	var objective = current_objective()
	if objective.kind == "escort":
		escort = _spawn(
			"SupplyTruck", _get_human_player(), _point(objective.point) + Vector3(0, 0, -4)
		)
	get_node("/root/SaveManager").request_checkpoint(self, "Objective updated")


func advance_escort():
	if finished or current_objective().kind != "escort" or not is_instance_valid(escort):
		return
	escort.issue_manual_order(Moving.new(_point(current_objective().destination)))


func _check_outcome(delta):
	if _enemy == null or restoring:
		return
	var objective = current_objective()
	var human = _get_human_player()
	var complete = false
	var relay = map.relays[stage]
	match objective.kind:
		"capture":
			complete = relay.captured_by == human and not relay.contested
		"hold":
			if relay.captured_by == human and not relay.contested:
				elapsed = minf(objective.seconds, elapsed + delta)
			complete = elapsed >= objective.seconds
		"destroy":
			complete = (
				not is_instance_valid(targets[stage])
				or targets[stage].is_queued_for_deletion()
				or targets[stage].hp <= 0
			)
		"escort":
			if not is_instance_valid(escort) or escort.is_queued_for_deletion() or escort.hp <= 0:
				_finish("Defeat")
				return
			complete = escort.global_position_yless.distance_to(_point(objective.destination)) < 5
	if complete and _hero_at_objective():
		if is_instance_valid(campaign_story):
			campaign_story.cue(settings.mission_id + ".milestone")
		stage += 1
		if stage == _definition.objectives.size():
			_finish("Victory")
		else:
			_enter_stage()
		return
	# Finite, warned waves begin only after the hero reaches the objective sector.
	if (
		campaign_hero.alive()
		and campaign_hero.unit.global_position_yless.distance_to(_point(objective.point)) < 28
	):
		var previous = wave_left
		wave_left = maxf(0, wave_left - delta)
		if previous > 10 and wave_left <= 10 and waves < 2 + _enemy.difficulty:
			hud.show_notice("Enemy response approaching the objective.")
		if wave_left == 0 and waves < 2 + _enemy.difficulty:
			_send_wave()


func _hero_at_objective():
	var objective = current_objective()
	var point = objective.destination if objective.kind == "escort" else objective.point
	return (
		campaign_hero.alive()
		and campaign_hero.unit.global_position_yless.distance_to(_point(point)) <= 24
	)


func _send_wave():
	var objective = current_objective()
	var point = _point(objective.point)
	var entry = Vector3(minf(158, point.x + 26), 0, clampf(point.z - 22, 12, 108))
	for index in 2 + _enemy.difficulty:
		var unit = _spawn(
			"Tank" if index == 3 else "Infantry", _enemy, entry + Vector3(0, 0, index * 2)
		)
		unit.issue_manual_order(AttackMove.new(point))
	waves += 1
	wave_left = 40.0
	hud.show_notice("Enemy response approaching the objective.")


func _finish(value):
	if finished:
		return
	finished = true
	result = value
	if value == "Victory":
		var progress = Progress.new()
		if not progress.record_operation(settings.mission_id, progress_path):
			progress_error = progress.error
	hud.show_result(tr(_definition.title) + " · " + tr(value))


func objective_text():
	var objective = current_objective()
	var text = objective.zh_CN if Globals.options.language == "zh_CN" else objective.title
	if not _hero_at_objective():
		text += " · " + tr("Bring your hero to the objective.")
	if objective.kind in ["capture", "hold"]:
		text += (
			"\n"
			+ tr(map.relays[mini(stage, map.relays.size() - 1)].capture_status(_get_human_player()))
		)
	if objective.kind == "hold":
		text += " · %d / %d s" % [int(elapsed), objective.seconds]
	return (
		"%d / %d · %s"
		% [mini(stage + 1, _definition.objectives.size()), _definition.objectives.size(), text]
	)


func result_summary():
	return (
		tr("Your hero must survive.")
		+ ("\n" + progress_error if not progress_error.is_empty() else "")
	)


func capture_operation(reference):
	var target_ids = []
	for target in targets:
		target_ids.append(
			(
				reference.call(target)
				if is_instance_valid(target) and not target.is_queued_for_deletion()
				else ""
			)
		)
	var relay_states = []
	for relay in map.relays:
		relay_states.append(
			{
				"owner": reference.call(relay.captured_by),
				"candidate": reference.call(relay.candidate),
				"progress": relay.progress,
				"contested": relay.contested
			}
		)
	return {
		"stage": stage,
		"elapsed": elapsed,
		"wave_left": wave_left,
		"waves": waves,
		"targets": target_ids,
		"escort":
		(
			reference.call(escort)
			if is_instance_valid(escort) and not escort.is_queued_for_deletion()
			else ""
		),
		"relays": relay_states
	}


func restore_operation(data, entities):
	for key in ["stage", "elapsed", "wave_left", "waves"]:
		set(key, data[key])
	targets = data.targets.map(func(id): return entities.get(id))
	escort = entities.get(data.escort)
	for index in map.relays.size():
		var relay = map.relays[index]
		var saved = data.relays[index]
		relay.captured_by = entities.get(saved.owner)
		relay.candidate = entities.get(saved.candidate)
		relay.progress = saved.progress
		relay.contested = saved.contested
		relay._update_presentation()
