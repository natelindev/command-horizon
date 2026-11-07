extends "res://tests/headless/FactionAsymmetryRegression.gd"


func _run():
	var logger = RuntimeErrorLog.new()
	OS.add_logger(logger)
	factions = load("res://source/match/FactionCatalog.gd")
	root.get_node("SaveManager").autosaves_enabled = false
	var options = root.get_node("Globals").options
	var original = options.capture()
	options.reduced_flashes = false
	await _fixture("helix")
	_prepare_effects()
	await _cloak_materials()
	await _blink_hook()
	await _persistent_abilities()
	await _blueprint_projection()
	game.queue_free()
	await _frames(5)
	await _fixture("bastion")
	_prepare_effects()
	await _overhaul_field()
	game.queue_free()
	await _frames(5)
	options.restore(original)
	OS.remove_logger(logger)
	errors.append_array(logger.messages)
	for message in errors:
		push_error(message)
	print("Ability feedback integration: %d failures" % errors.size())
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)


func _prepare_effects():
	game.settings.visibility = game.settings.Visibility.FULL
	game.combat_effects._headless = false
	game.combat_effects._camera = null
	game.combat_effects.set_process(false)
	game.combat_effects.set_physics_process(false)


func _cloak_materials():
	var unit = _dedicated("SniperInfantry", Vector3(24, 0, 26))
	await _frames(3)
	var visual = unit.get_node("OpticalCloakVisual")
	visual.refresh(0)
	var surfaces = []
	for mesh in unit.get_node("Geometry").find_children("*", "MeshInstance3D", true, false):
		surfaces.append(
			[mesh, mesh.material_override, mesh.cast_shadow, mesh.get_active_material(0)]
		)
	unit.optical_cloak._previous = unit.global_position
	unit.optical_cloak.advance(3)
	visual.refresh(.175)
	_check(is_equal_approx(visual.blend, .5), "Cloak has no eased entry transition")
	visual.refresh(.2)
	_check(visual.blend == 1 and not visual._surfaces.is_empty(), "Concealed sniper stayed opaque")
	for entry in visual._surfaces:
		_check(
			entry.mesh.get_active_material(entry.surface) == entry.material,
			"Cloak shader did not replace a surface"
		)
		_check(
			entry.material.get_shader_parameter("concealment") == 1, "Hull did not finish fading"
		)
	unit.hide()
	visual.refresh(.1)
	_check(not unit.visible, "Cloak presentation overrode fog visibility")
	unit.show()
	unit.optical_cloak.reveal()
	visual.refresh(.4)
	_check(visual._surfaces.is_empty(), "Reveal retained temporary cloak materials")
	for entry in surfaces:
		_check(
			(
				entry[0].material_override == entry[1]
				and entry[0].cast_shadow == entry[2]
				and entry[0].get_active_material(0) == entry[3]
			),
			"Cloak altered original finish or shadow mode"
		)
	unit.queue_free()
	await _frames(2)


func _blink_hook():
	var unit = _dedicated("CombatRobot", Vector3(40, 0, 28))
	await _frames(5)
	var origin = unit.global_position
	var movement = unit.get_node("Movement")
	_check(movement.phase_shift(origin + Vector3(5, 0, 0)), "Phase relocation fixture was rejected")
	_check(
		game.combat_effects._phase_remnants.size() == 2,
		"Successful movement did not emit both endpoints"
	)
	if game.combat_effects._phase_remnants.size() == 2:
		_check(
			game.combat_effects._phase_remnants[0].point == origin,
			"Blink used the relocated origin"
		)
		_check(
			game.combat_effects._phase_remnants[0]._silhouette != null,
			"Blink lost origin silhouette"
		)
	_check(not movement.phase_shift(Vector3.INF), "Invalid blink succeeded")
	_check(game.combat_effects._phase_remnants.size() == 2, "Rejected blink emitted effects")
	game.combat_effects._advance_phase_remnants(1)
	unit.queue_free()
	await _frames(2)


func _persistent_abilities():
	var factory = _dedicated("VehicleFactory", Vector3(28, 0, 32))
	var drone = _dedicated("Drone", Vector3(40, 0, 8))
	var sniper = _dedicated("SniperInfantry", Vector3(24, 0, 26))
	await _frames(3)
	sniper.optical_cloak.idle_left = 0
	sniper.optical_cloak.concealed = true
	var hq = _units(human, "CommandCenter")[0]
	hq.energy = 50
	_check(
		hq.abilities.trigger("flux_resonance", Vector3.INF, factory), "Flux fixture was rejected"
	)
	_check(drone.abilities.trigger("drone_chaff"), "Chaff fixture was rejected")
	var world = game.combat_effects.world_abilities
	world.advance(.2)
	_check(world.active.size() == 2, "Macro/chaff state has no persistent world cues")
	factory.hide()
	world.advance(.01)
	var flux_key = "flux:%d" % factory.get_instance_id()
	_check(not world.active[flux_key].node.visible, "Flux aura exposed a hidden factory")
	factory.show()
	var before = human.production_boosts[0].left
	paused = true
	game.combat_effects._process(1)
	_check(human.production_boosts[0].left == before, "Visual update advanced macro gameplay timer")
	var snapshot = Snapshot.new().capture(game)
	var restored = await Restore.new().restore(self, snapshot)
	_check(restored.ok, "Active feedback save failed to restore: " + restored.get("error", ""))
	if not restored.ok:
		paused = false
		return
	game = restored.game
	human = game._get_human_player()
	_prepare_effects()
	world = game.combat_effects.world_abilities
	world.advance(0)
	_check(world.active.size() == 2, "Paused load failed to reconstruct persistent cues")
	sniper = _units(human, "SniperInfantry")[0]
	var cloak_visual = sniper.get_node("OpticalCloakVisual")
	cloak_visual.refresh(0)
	_check(cloak_visual.blend == 1.0, "Paused load left a concealed sniper opaque")
	_check(
		cloak_visual.process_mode == Node.PROCESS_MODE_ALWAYS,
		"Paused load cannot initialize cloak presentation"
	)
	var cloak_phase = cloak_visual._phase
	cloak_visual.refresh(1)
	_check(cloak_visual._phase == cloak_phase, "Paused cloak shader kept animating")
	_check(game.combat_effects._phase_remnants.is_empty(), "Load replayed an activation burst")
	_check(human.production_boosts[0].left == before, "Load changed Flux remaining duration")
	paused = false
	for unit in game.get_units():
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	drone = _units(human, "Drone").filter(func(u): return u.abilities.is_active("drone_chaff"))[0]
	drone.abilities._physics_process(8)
	human._physics_process(25)
	world.advance(.2)
	_check(world.active.is_empty(), "Expired macro or chaff aura survived")


func _blueprint_projection():
	var handler = human.get_node("StructurePlacementHandler")
	handler._start_structure_placement(load("res://source/match/units/AircraftFactory.tscn"))
	handler._active_blueprint_node.position = Vector3(40, 0, 36)
	handler._update_blueprint_color(true)
	var footprint = handler._footprint
	_check(
		footprint.outline.size() == 4 and footprint._vertices > 100,
		"Airfield has no true polygon/grid projection"
	)
	_check(
		footprint.portal_direction == Vector3.RIGHT,
		"Airfield exit alignment points down its runway"
	)
	var initial = footprint._last_pose
	handler._try_rotating_blueprint_by(45)
	_check(footprint._last_pose != initial, "Keyboard rotation left footprint behind")
	for mesh in handler._active_blueprint_node.find_children("*", "MeshInstance3D", true, false):
		_check(
			mesh.material_override is ShaderMaterial, "Blueprint still uses flat plastic material"
		)
	handler._cancel_structure_placement()
	_check(
		handler._footprint == null and footprint.is_queued_for_deletion(),
		"Cancelled blueprint leaked its grid"
	)
	await _frames(2)


func _overhaul_field():
	var deposit = get_nodes_in_group("resource_units")[0]
	var hq = _units(human, "CommandCenter")[0]
	_check(
		hq.abilities.trigger("industrial_overhaul", deposit.global_position),
		"Overhaul fixture rejected"
	)
	var world = game.combat_effects.world_abilities
	world.advance(.2)
	_check(world.active.size() == 1, "Resource field has no overhaul beacons")
	var field = human.harvesting_boosts[0].field
	deposit.queue_free()
	await _frames(2)
	world.advance(.2)
	_check(
		world.active.size() == 1 and human.harvesting_boosts[0].field == field,
		"Exhausted target removed the still-active field cue"
	)
	human._physics_process(30)
	world.advance(.2)
	_check(world.active.is_empty(), "Expired overhaul retained perimeter beacons")
