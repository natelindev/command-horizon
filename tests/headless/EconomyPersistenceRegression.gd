extends "res://tests/headless/MacroEconomyRegression.gd"


func _run():
	Engine.physics_ticks_per_second = 60
	factions = load("res://source/match/FactionCatalog.gd")
	constants = root.get_node("Constants")
	harvest = load("res://source/match/units/actions/CollectingResourcesSequentially.gd")
	orders = load("res://source/match/orders/ManualOrders.gd")
	root.get_node("SaveManager").autosaves_enabled = false
	for faction in ["bastion", "helix"]:
		var settings = _settings(faction, "frontier", false)
		settings.map_path = "res://source/match/maps/PlainAndSimple.tscn"
		game = await _start(settings)
		human = game._get_human_player()
		for player in get_nodes_in_group("players"):
			player.set_process(false)
		for unit in get_nodes_in_group("units"):
			unit.issue_manual_order(null)
			unit.process_mode = Node.PROCESS_MODE_DISABLED
		workers = get_nodes_in_group("units").filter(
			func(unit): return unit.player == human and unit.type == "Worker"
		)
		var hq = _unit(human, "CommandCenter")
		var worker = workers[0]
		worker.process_mode = Node.PROCESS_MODE_INHERIT
		var special
		var resource
		if faction == "bastion":
			special = load("res://source/match/units/ForwardRefinery.tscn").instantiate()
			game._setup_and_spawn_unit(
				special, Transform3D(Basis(), Vector3(19, 0, 26)), human, false
			)
			special.refine_materials(8)
			resource = _deposit("A", Vector3(13, 0, 17), 100)
			resource.harvest_origin = Vector3(13, 0, 17)
			_reset_worker(worker, Vector3(13, 0, 19))
			await _frames(5)
			_check(
				hq.abilities.trigger("industrial_overhaul", resource.global_position),
				"Persistence fixture failed to activate Industrial Overhaul"
			)
		else:
			special = load(Catalog.scene_path("VehicleFactory")).instantiate()
			game._setup_and_spawn_unit(
				special, Transform3D(Basis(), Vector3(26, 0, 30)), human, false
			)
			await _frames(5)
			hq.energy = 50.0
			_check(
				hq.abilities.trigger("flux_resonance", Vector3.INF, special),
				"Persistence fixture failed to activate Flux Resonance"
			)
			_reset_worker(worker, hq.global_position + Vector3(16, 0, 5))
			worker.resource_b = 4
			worker.issue_manual_order(harvest.new(hq))
			await _frames(20)
		paused = true
		var snapshotter = load("res://source/match/saves/MatchSnapshot.gd").new()
		var saved = snapshotter.capture(game)
		_check(saved != null, "Economy snapshot failed: " + snapshotter.error)
		if saved == null:
			paused = false
			game.queue_free()
			await _frames(5)
			continue
		var schema = load("res://source/match/saves/SnapshotSchema.gd").new()
		_check(
			schema.validate(saved), "Economy snapshot schema rejected live state: " + schema.error
		)
		var worker_id = snapshotter._reference(worker)
		var hq_id = snapshotter._reference(hq)
		var special_id = snapshotter._reference(special)
		var resource_id = snapshotter._reference(resource) if resource != null else ""
		var phase_time = worker.action._phase_left if faction == "helix" else 0.0
		var hq_energy = hq.energy
		var loader = load("res://source/match/saves/MatchRestore.gd").new()
		var restored = await loader.restore(self, saved)
		_check(restored.ok, "Economy snapshot restore failed: " + restored.get("error", ""))
		if restored.ok:
			game = restored.game
			worker = loader.entities[worker_id]
			hq = loader.entities[hq_id]
			special = loader.entities[special_id]
			human = worker.player
			_check(
				paused and is_equal_approx(hq.energy, hq_energy),
				"Paused restore changed Nexus Energy"
			)
			if faction == "bastion":
				_check(
					is_equal_approx(special.smelting_remainder, .2),
					"Refinery fractional smelting was lost on restore"
				)
				resource = loader.entities[resource_id]
				_check(
					is_equal_approx(human.harvesting_factor(resource), 1.3),
					"Industrial field acceleration was lost on restore"
				)
				var remaining = _deposit("B", resource.global_position + Vector3(5, 0, 0), 100)
				remaining.harvest_origin = resource.harvest_origin
				resource.queue_free()
				await _frames(3)
				human._advance_economy(.1)
				_check(
					is_equal_approx(human.harvesting_factor(remaining), 1.3),
					"Exhausted macro target removed the remaining field effect"
				)
				var after_exhaustion = snapshotter.capture(game)
				var remaining_id = snapshotter._reference(remaining)
				_check(
					schema.validate(after_exhaustion),
					"Exhausted macro target made save invalid: " + schema.error
				)
				var second = await loader.restore(self, after_exhaustion)
				_check(
					second.ok,
					"Exhausted macro target could not restore: " + second.get("error", "")
				)
				if second.ok:
					game = second.game
					human = game._get_human_player()
					remaining = loader.entities[remaining_id]
					_check(
						is_equal_approx(human.harvesting_factor(remaining), 1.3),
						"Restoring an exhausted macro target lost the field effect"
					)
					_check(
						snapshotter.capture(game) != null, "Re-saving an expired weak target failed"
					)
			else:
				_check(
					(
						worker.action != null
						and worker.action._state == harvest.State.PHASE_RETURN
						and is_equal_approx(worker.action._phase_left, phase_time)
					),
					"Phase channel state changed on paused restore"
				)
				_check(
					is_equal_approx(human.production_factor(special), 1.5),
					"Flux Resonance was lost on restore"
				)
				var before = human.resource_b
				paused = false
				await _frames(100)
				_check(
					worker.resource_b == 0 and human.resource_b == before + 4,
					"Restored phase channel did not deliver exactly once"
				)
		paused = false
		game.queue_free()
		await _frames(5)
	for message in _errors:
		push_error(message)
	print("Economy persistence: %d failures" % _errors.size())
	await root.get_node("Globals").quit_game(0 if _errors.is_empty() else 1)
