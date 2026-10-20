extends "res://tests/headless/SaveRestoreEdges.gd"

const ARCHIVE = "res://docs/playtests/2026-10-06/program-recovery/pressure-helix-unsupported.json"
var owner
var tank
var depot
var engineer
var peak_health = 0.0
var returned = false


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	await _earned_service()
	for error in errors:
		push_error(error)
	print("Earned service recovery: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _earned_service():
	var loaded = await Restore.new().restore(self, FileStore.new().read_file(ARCHIVE))
	_check(loaded.ok, "Earned unserviced tank could not restore")
	if not loaded.ok:
		return
	game = loaded.game
	owner = game._get_human_player()
	var candidates = _units(owner, "Tank")
	candidates.sort_custom(func(a, b): return a.hp / a.hp_max < b.hp / b.hp_max)
	tank = candidates[0]
	_check(tank.hp < tank.hp_max * .8, "Earned archive has no damaged tank")
	var workers = _units(owner, "Worker")
	workers.sort_custom(
		func(a, b):
			return a.position.distance_to(tank.position) < b.position.distance_to(tank.position)
	)
	engineer = workers[0]
	var action = tank.action
	var start = game.simulation_time
	peak_health = tank.hp
	_check(
		get_nodes_in_group("players").any(
			func(side): return side != owner and side.is_processing()
		),
		"Earned continuation disabled the enemy AI"
	)
	await _review_earned_service("unsupported")
	_place_earned_depot()
	_check(depot != null, "No legal paid service placement near retreat point")
	if depot == null:
		return
	_check(tank.action == action, "Construction changed the tank's orders")
	await _review_earned_service("paid-foundation")
	_resume_earned_review()
	var healing_captured = false
	for frame in 9000:
		await _frames(1)
		if not is_instance_valid(tank) or tank.is_queued_for_deletion():
			break
		peak_health = maxf(peak_health, tank.hp)
		if not healing_captured and tank.hp > 14:
			game.hud.pause_after_load()
			await _review_earned_service("healing")
			_resume_earned_review()
			healing_captured = true
		if peak_health >= tank.hp_max * .8:
			returned = true
			break
	_check(is_instance_valid(tank), "Earned recovering tank was destroyed")
	_check(returned, "Paid service did not heal the earned tank to its return threshold")
	game.hud.pause_after_load()
	await _review_earned_service("returned")
	print(
		"EARNED SERVICE peak_hp=",
		peak_health,
		" returned=",
		returned,
		" seconds=",
		game.simulation_time - start
	)


func _place_earned_depot():
	var handler = owner.get_node("StructurePlacementHandler")
	var catalog = load("res://source/match/FactionCatalog.gd")
	var cost = catalog.cost(owner, "RepairDepot", true)
	_check(owner.has_resources(cost), "Earned snapshot cannot pay for ground service")
	handler._start_structure_placement(load("res://source/match/units/RepairDepot.tscn"))
	for radius in [4.5, 4.8, 4.1]:
		for index in 24:
			var angle = index * TAU / 24
			handler._active_blueprint_node.global_position = (
				tank.position + Vector3(cos(angle), 0, sin(angle)) * radius
			)
			if (
				handler._calculate_blueprint_position_validity()
				!= handler.BlueprintPositionValidity.VALID
			):
				continue
			root.get_node("MatchSignals").deselect_all_units.emit()
			engineer.get_node("Selection").select()
			var funds = Vector2i(owner.resource_a, owner.resource_b)
			handler._finish_structure_placement()
			depot = _units(owner, "RepairDepot")[0]
			_check(
				(
					Vector2i(owner.resource_a, owner.resource_b)
					== funds - Vector2i(cost.resource_a, cost.resource_b)
				),
				"Earned depot charged an incorrect fee"
			)
			print("EARNED SERVICE paid=", cost, " position=", depot.position)
			return
	handler._cancel_structure_placement()


func _review_earned_service(_label):
	return true


func _resume_earned_review():
	if paused:
		game.hud._toggle_pause()
