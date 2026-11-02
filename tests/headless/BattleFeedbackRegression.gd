extends "res://tests/headless/SaveRestoreEdges.gd"


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	await _skirmish("bastion", "res://source/match/maps/DesertFrontier.tscn")
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	paused = true
	await _formation_preview()
	await _minimap_phases()
	await _command_rings()
	_lights_and_ricochets()
	await _restore_without_minimap()
	paused = false
	game.queue_free()
	await _frames(5)
	for message in errors:
		push_error(message)
	print("Battle feedback regression: %d failures" % errors.size())
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)


func _restore_without_minimap():
	var flags = root.get_node("FeatureFlags")
	var original = flags.show_minimap
	flags.show_minimap = false
	var saved = Snapshot.new().capture(game)
	var result = await Restore.new().restore(self, saved)
	flags.show_minimap = original
	_check(result.ok, "Restore without minimap failed: " + result.get("error", ""))
	if result.ok:
		game = result.game
		_check(game.find_child("Minimap") == null, "Disabled minimap was recreated during restore")
		_check(paused, "Restore without minimap released tactical pause")
	print("PASS restored initialization also supports a disabled minimap")


func _formation_preview():
	var human = game._get_human_player()
	var units = _units(human, "Tank").slice(0, 3)
	root.get_node("MatchSignals").deselect_all_units.emit()
	for unit in units:
		unit.get_node("Selection").select()
	var camera = game.get_node("IsometricCamera3D")
	var destination = Vector3(45, 0, 35)
	camera.set_position_safely(destination)
	var terrain = game.get_node("Terrain")
	var pointer = camera.unproject_position(destination)
	var press = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_RIGHT
	press.pressed = true
	press.position = pointer
	terrain._on_input_event(camera, press, destination, Vector3.UP, 0)
	terrain.set_process(false)
	var controller = human.get_node("UnitActionsController")
	_check(
		controller._ground_dispatch.tokens.size() == units.size(), "Formation press cohort differs"
	)
	var before = units.map(func(unit): return unit.manual_orders.pending.size())
	terrain._update_formation_preview(pointer + Vector2(90, 0))
	_check(is_instance_valid(terrain._formation_preview), "Right drag has no formation ribbon")
	if is_instance_valid(terrain._formation_preview):
		_check(
			terrain._formation_preview.mesh.get_surface_count() == 1,
			"Formation ribbon has no geometry"
		)
	terrain._resolve_rmb(pointer + Vector2(90, 0))
	_check(
		terrain._formation_preview == null and terrain._rmb_drag_start == null,
		"Release retained preview"
	)
	_check(
		units.map(func(unit): return unit.manual_orders.pending.size()) == before,
		"Drag queued duplicate orders"
	)
	var utility = root.get_node("Utils").Match.Unit.Movement
	for layout in ["line", "wedge", "staggered"]:
		var slots = utility.formation_positions(units, destination, Vector3.RIGHT, layout)
		var assigned = utility.calculate_formation_slots(units, destination, Vector3.RIGHT, layout)
		_check(slots.size() == assigned.size(), "Preview and formation counts differ")
		for pair in assigned:
			_check(
				pair[1] * Vector3(1, 0, 1) in slots, "Preview differs from actual formation layout"
			)
	terrain._on_input_event(camera, press, destination, Vector3.UP, 0)
	terrain.set_process(false)
	terrain._update_formation_preview(pointer + Vector2(90, 0))
	game.hud._open_menu()
	terrain._finish_drag(pointer + Vector2(90, 0))
	_check(
		terrain._rmb_drag_start == null and terrain._formation_preview == null,
		"Menu retained drag preview"
	)
	game.hud._close_menu()
	await _frames(2)
	print("PASS formation layout, facing release, tactical pause and menu cancellation")


func _minimap_phases():
	var minimap = game.find_child("Minimap")
	minimap.set_physics_process(false)
	minimap._sync_real_units_with_minimap_representations()
	var units = _units(game._get_human_player(), "Tank").slice(0, 3)
	for unit in units:
		_check(minimap._unit_is_mapped(unit), "Known own unit has no minimap marker")
		var marker = minimap._unit_to_corresponding_node_mapping[unit]
		var previous = marker.position
		unit.position += Vector3.RIGHT
		var phase = unit.get_instance_id() % minimap.MARKER_PHASES
		minimap._sync_real_units_with_minimap_representations((phase + 1) % minimap.MARKER_PHASES)
		_check(marker.position == previous, "Minimap updated outside marker phase")
		minimap._sync_real_units_with_minimap_representations(phase)
		_check(marker.position != previous, "Minimap phase did not update marker")
		unit.hide()
		minimap._sync_real_units_with_minimap_representations((phase + 1) % minimap.MARKER_PHASES)
		_check(not marker.visible, "Hidden unit retained a visible minimap marker")
		unit.show()
	var victim = units[0]
	victim.queue_free()
	await _frames(2)
	minimap._sync_real_units_with_minimap_representations(0)
	_check(
		not minimap._unit_to_corresponding_node_mapping.has(victim),
		"Staggered minimap retained dead unit"
	)
	print("PASS staggered minimap positions, hidden units and removed markers")


func _command_rings():
	var feedback = game.hud.command_feedback
	for index in 12:
		feedback._add_marker(Vector3(30 + index, 0, 30), "move", "Move", true)
	_check(feedback.markers.size() == feedback.MAX_MARKERS, "Unbounded command rings")
	for marker in feedback.markers:
		_check(marker.node is MeshInstance3D, "Accepted order lacks a world-space ring")
		_check(marker.node.map == game.map, "Command ring does not sample battlefield terrain")
		_check(
			not marker.node.material_override.no_depth_test, "Command rings draw through terrain"
		)
	var first = feedback.markers[0].node
	var second = feedback.markers[1].node
	first.fade(.25)
	_check(
		first.material_override != second.material_override,
		"Command rings share mutable fade state"
	)
	_check(
		is_equal_approx(second.material_override.albedo_color.a, 1.0),
		"Fading one ring changed another marker"
	)
	game.hud._open_menu()
	feedback._process(0)
	_check(
		feedback.markers.all(func(marker): return not marker.node.visible),
		"Command rings cover modal UI"
	)
	game.hud._close_menu()
	feedback._process(3)
	_check(feedback.markers.is_empty(), "Command rings never expire")
	await _frames(2)
	print("PASS bounded terrain command rings, modal visibility and expiry")


func _lights_and_ricochets():
	var effects = load("res://source/match/effects/CombatEffects.gd")
	var incoming = Vector3(1, 0, .3).normalized()
	var reflected = effects.ricochet_direction(incoming, Vector3.LEFT)
	_check(
		reflected.x < 0 and reflected.z > 0, "Armor sparks do not reflect the incoming direction"
	)
	var aftermath = load("res://source/match/effects/BattleAftermath.gd").new()
	game.add_child(aftermath)
	var options = root.get_node("Globals").options
	var reduced = options.reduced_flashes
	options.reduced_flashes = false
	for index in 20:
		aftermath.flash(Vector3.ONE, .5, Color.WHITE, true)
	_check(
		aftermath.lights.size() == aftermath.MAX_LIGHTS / 2,
		"Muzzle flash lights exceeded reserved budget"
	)
	var light = aftermath.lights[0].node
	_check(not light.shadow_enabled, "Muzzle light adds dynamic shadow cost")
	aftermath.advance(.1)
	_check(aftermath.lights.is_empty(), "Muzzle lighting outlasts its flash")
	var count = aftermath.get_child_count()
	aftermath.flash(Vector3.ONE, .2, Color.WHITE, true)
	_check(aftermath.get_child_count() == count, "Muzzle light pool allocated instead of reusing")
	options.reduced_flashes = true
	aftermath.advance(0)
	aftermath.flash(Vector3.ONE, .5, Color.WHITE, true)
	_check(aftermath.lights.is_empty(), "Reduced flashes still shows muzzle lights")
	options.reduced_flashes = reduced
	aftermath.queue_free()
	print("PASS ricochet reflection, pooled muzzle light budgets and reduced flashes")
