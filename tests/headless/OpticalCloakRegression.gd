extends "res://tests/headless/FactionAsymmetryRegression.gd"


func _run():
	var logger = RuntimeErrorLog.new()
	OS.add_logger(logger)
	factions = load("res://source/match/FactionCatalog.gd")
	root.get_node("SaveManager").autosaves_enabled = false
	await _fixture("helix")
	enemy = get_nodes_in_group("players").filter(func(side): return side != human)[0]
	var infiltrator = _dedicated("SniperInfantry", Vector3(24, 0, 26))
	var witness = _dedicated("Tank", Vector3(30, 0, 26), enemy)
	await _frames(2)
	infiltrator.global_position = Vector3(24, 0, 26)
	witness.global_position = Vector3(30, 0, 26)
	infiltrator.optical_cloak._previous = infiltrator.global_position
	infiltrator.optical_cloak.advance(3.0)
	game.battlefield.invalidate()
	_check(infiltrator.optical_cloak.concealed, "Stationary Phase Infiltrator did not conceal after3s")
	_check(game.battlefield.is_observed(human, infiltrator), "Cloak hid friendly infantry from its owner")
	_check(not game.battlefield.is_observed(enemy, infiltrator), "Native visibility exposed a distant cloaked infiltrator")
	_check(not game.battlefield.can_fire(witness, infiltrator), "Native weapon authority targeted a cloaked infiltrator")
	witness.global_position = Vector3(26, 0, 26)
	game.battlefield.invalidate()
	_check(game.battlefield.is_observed(enemy, infiltrator), "Nearby witness did not defeat optical camouflage")
	witness.global_position = Vector3(30, 0, 26)
	game.battlefield.invalidate()
	game.projectile_system.launch(infiltrator, witness)
	_check(not infiltrator.optical_cloak.concealed and infiltrator.optical_cloak.idle_left == 3.0, "Thermal rifle fire did not reveal its shooter")
	infiltrator.optical_cloak.advance(3.0)
	infiltrator.get_node("Movement")._has_destination = true
	infiltrator.optical_cloak.advance(0.1)
	_check(not infiltrator.optical_cloak.concealed, "Moving infiltrator retained stationary camouflage")
	# A hostile player's normal visibility pass also disables picking the hidden body.
	infiltrator.get_node("Movement")._has_destination = false
	infiltrator.optical_cloak.advance(3.0)
	var visibility = game.get_node("Handlers/UnitVisibilityHandler")
	infiltrator.remove_from_group("revealed_units")
	visibility._recalculate_unit_visibility(infiltrator, null, [enemy])
	_check(not infiltrator.visible and not infiltrator.input_ray_pickable, "Hidden infiltrator remained visible or mouse-targetable")
	visibility._recalculate_unit_visibility(infiltrator, null, [human])
	_check(infiltrator.visible, "Owner visibility failed to restore its cloaked model")
	game.queue_free()
	await _frames(5)
	OS.remove_logger(logger)
	errors.append_array(logger.messages)
	for message in errors:
		push_error(message)
	print("Stationary optical cloak and native targeting: %d failures" % errors.size())
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)
