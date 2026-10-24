extends "res://tests/headless/SaveRestoreEdges.gd"

var _prewarm
var _logger


class RenderErrors:
	extends Logger
	var messages = []
	var mutex = Mutex.new()

	func _log_error(_function, file, _line, code, rationale, _notify, kind, _backtraces):
		if kind == Logger.ERROR_TYPE_WARNING:
			return
		mutex.lock()
		messages.append(file + ": " + code + " " + rationale)
		mutex.unlock()


func _run():
	_prewarm = load("res://source/match/effects/CombatPrewarm.gd")
	root.get_node("SaveManager").autosaves_enabled = false
	var options = root.get_node("Globals").options
	var original = options.capture()
	options.restore(
		{
			"screen": 1,
			"edge_scrolling": false,
			"reduced_flashes": false,
			"battlefield_wear": true,
			"graphics_ground_detail": true
		}
	)
	_logger = RenderErrors.new()
	OS.add_logger(_logger)
	if DisplayServer.get_name() != "headless":
		Engine.max_fps = 60
		root.mode = Window.MODE_WINDOWED
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
		root.size = Vector2i(1280, 720)
		root.content_scale_size = root.size
	await _skirmish("bastion")
	paused = true
	if DisplayServer.get_name() == "headless":
		await _headless_skip()
	else:
		await _seed_live_presentation()
		await _preserved_state("default")
		for variant in [
			{"reduced_flashes": true},
			{"reduced_flashes": false, "battlefield_wear": false},
			{"battlefield_wear": true, "graphics_ground_detail": false}
		]:
			options.restore(variant)
			await _settle_draws()
			await _preserved_state(str(variant))
		options.restore(
			{"reduced_flashes": false, "battlefield_wear": true, "graphics_ground_detail": true}
		)
		await _settle_draws()
		paused = false
		var unpaused_result = await _prewarm.prepare(game)
		_check(unpaused_result and not paused, "Prewarm acquired or changed caller pause")
		paused = true
		await _restore_stays_paused()
		await _scene_replacement_cancels()
		await _deleted_game_cancels()
		await _restore_replacement_cancels()
		await _loading_success()
		await _loading_cancel()
		await _loading_quit_guard()
	await _finish_prewarm(options, original)


func _headless_skip():
	var before_nodes = get_node_count()
	var before = _process_modes(game)
	var result = await _prewarm.prepare(game)
	_check(result and paused, "Headless skip changed paused caller")
	_check(get_node_count() == before_nodes, "Headless skip created rendering nodes")
	_check(not game.has_node("CombatPrewarm"), "Headless skip retained a helper")
	_check(_process_modes(game) == before, "Headless skip changed process modes")
	paused = false
	result = await _prewarm.prepare(game)
	_check(result and not paused, "Headless skip changed unpaused caller")
	print("PASS headless prewarm skip leaves nodes, processing and caller pause unchanged")


func _seed_live_presentation():
	var human = game._get_human_player()
	var tank = _units(human, "Tank")[0]
	var enemy = get_nodes_in_group("players").filter(func(player): return player != human)[0]
	var target = _units(enemy, "Tank")[0]
	var camera = game.get_node("IsometricCamera3D")
	camera.set_position_safely(tank.position)
	camera.set_size_safely(24)
	await _settle_draws()
	var fx = game.combat_effects
	var tracer = fx._take_tracer()
	tracer.node.hide()
	fx._free_tracers.append(tracer)
	fx._material_hit(tank)
	fx._advance_hit_flashes(.3)
	fx._shockwave(tank.global_position, 2.0)
	game.projectile_system.launch(tank, target)
	game.battlefield_wear.add_mark(Vector2(tank.position.x, tank.position.z), 1.0, 0.0, 1)
	game.battlefield_wear._paint()
	await _settle_draws()
	_check(not fx._free_tracers.is_empty(), "Fixture lacks a retained tracer pool")
	_check(not fx._free_hit_flashes.is_empty(), "Fixture lacks a retained hit material")
	_check(not fx._shockwaves.is_empty(), "Fixture lacks a live shockwave")
	_check(not game.projectile_system._rounds.is_empty(), "Fixture lacks a live projectile")
	_check(
		game.map.get_node("Geometry/Terrain").material_overlay != null,
		"Fixture lacks an existing terrain overlay"
	)


func _preserved_state(label):
	var snapshot_before = Snapshot.new().capture(game)
	_check(snapshot_before != null, label + ": fixture snapshot unavailable")
	var cosmetics_before = _cosmetic_state()
	var materials_before = _material_state()
	var modes_before = _process_modes(game)
	var nodes_before = get_node_count()
	var result = await _prewarm.prepare(game)
	_check(result, label + ": prewarm did not complete")
	_check(paused, label + ": paused caller was resumed")
	_check(Snapshot.new().capture(game) == snapshot_before, label + ": saved state changed")
	_check(_cosmetic_state() == cosmetics_before, label + ": live RNG, effects or pools changed")
	_check(_material_state() == materials_before, label + ": live mesh/material state changed")
	_check(_process_modes(game) == modes_before, label + ": process modes were not restored")
	_check(get_node_count() == nodes_before, label + ": disposable nodes leaked")
	_check(not game.has_node("CombatPrewarm"), label + ": helper remained in the match")
	print("PASS prewarm state and resource preservation: ", label)


func _cosmetic_state():
	var fx = game.combat_effects
	var result = {
		"simulation_time": game.simulation_time,
		"combat_rng": fx._random.state,
		"aftermath_rng": fx.aftermath._random.state,
		"projectile_rng": game.projectile_system._random.state,
		"shots": fx.shots_emitted,
		"impacts": fx.impacts_emitted,
		"deaths": fx.deaths_emitted,
		"rounds_fired": game.projectile_system.rounds_fired,
		"unit_rng": {},
		"pools": {},
		"projectile_pools": {},
	}
	for key in [
		"_tracers",
		"_free_tracers",
		"_wrecks",
		"_cook_offs",
		"_hit_flashes",
		"_free_hit_flashes",
		"_shockwaves",
		"_materials"
	]:
		result.pools[key] = _value_state(fx.get(key))
	for key in ["scars", "debris", "lights", "_free_lights"]:
		result.pools[key] = _value_state(fx.aftermath.get(key))
	for unit in get_nodes_in_group("units"):
		var visuals = unit.get_node_or_null("BastionVisuals")
		if visuals != null:
			result.unit_rng[str(unit.get_instance_id())] = visuals.motion.random.state
	for kind in game.projectile_system.renderer._pools:
		var pool = game.projectile_system.renderer._pools[kind]
		var instances = []
		for slot in pool.used:
			instances.append(
				[
					pool.node.multimesh.get_instance_transform(slot),
					pool.node.multimesh.get_instance_color(slot)
				]
			)
		result.projectile_pools[kind] = {
			"node": pool.node.get_instance_id(),
			"multimesh": pool.node.multimesh.get_instance_id(),
			"used": pool.used,
			"free": pool.free.duplicate(),
			"visible": pool.node.multimesh.visible_instance_count,
			"instances": instances,
		}
	return result


func _material_state():
	var state = {"instances": {}, "materials": {}}
	for node in game.find_children("*", "GeometryInstance3D", true, false):
		var entry = {
			"override": _remember_material(node.material_override, state),
			"overlay": _remember_material(node.material_overlay, state),
		}
		var mesh = null
		if node is MeshInstance3D:
			mesh = node.mesh
			entry.surface_overrides = []
			for surface in node.get_surface_override_material_count():
				entry.surface_overrides.append(
					_remember_material(node.get_surface_override_material(surface), state)
				)
		elif node is MultiMeshInstance3D and node.multimesh != null:
			mesh = node.multimesh.mesh
		if mesh != null:
			entry.mesh = mesh.get_instance_id()
			entry.surface_materials = []
			for surface in mesh.get_surface_count():
				entry.surface_materials.append(
					_remember_material(mesh.surface_get_material(surface), state)
				)
		state.instances[str(node.get_instance_id())] = entry
	return state


func _remember_material(material, state):
	if material == null:
		return 0
	var id = material.get_instance_id()
	if state.materials.has(str(id)):
		return id
	var properties = {}
	state.materials[str(id)] = properties
	for property in material.get_property_list():
		if property.usage & PROPERTY_USAGE_STORAGE:
			var value = material.get(property.name)
			properties[property.name] = _value_state(value)
			if value is Material:
				_remember_material(value, state)
			elif value is Shader:
				properties[property.name + "/code"] = value.code
	return id


func _value_state(value):
	if value is Dictionary:
		var result = {}
		for key in value:
			result[str(key)] = _value_state(value[key])
		return result
	if value is Array:
		return value.map(_value_state)
	if value is WeakRef:
		return _value_state(value.get_ref())
	if value is Object:
		return value.get_instance_id() if is_instance_valid(value) else 0
	return value


func _process_modes(node):
	var modes = {str(node.get_instance_id()): node.process_mode}
	for child in node.get_children():
		modes.merge(_process_modes(child))
	return modes


func _restore_stays_paused():
	var saved = Snapshot.new().capture(game)
	_check(saved != null, "Prewarm restore fixture snapshot unavailable")
	if saved == null:
		return
	var result = await Restore.new().restore(self, saved)
	_check(result.ok, "Restore with prewarm failed: " + result.get("error", ""))
	if not result.ok:
		return
	game = result.game
	_check(paused, "Prewarm resumed a restored battle")
	_check(game.simulation_time == saved.simulation_time, "Prewarm advanced restored battle time")
	_check(not game.has_node("CombatPrewarm"), "Restore returned before prewarm cleanup")
	print("PASS restore retains caller pause and simulation boundary")


func _prepare_async(target, state):
	state.result = await _prewarm.prepare(target)
	state.done = true


func _wait_preparation(state):
	for frame in 300:
		if state.done:
			return
		await process_frame
	_check(state.done, "Cancelled prewarm did not return within 300 frames")


func _scene_replacement_cancels():
	var modes_before = _process_modes(game)
	var replacement = Node.new()
	replacement.name = "PrewarmReplacement"
	root.add_child(replacement)
	var before_nodes = get_node_count()
	var state = {"done": false, "result": true}
	_prepare_async(game, state)
	_check(game.has_node("CombatPrewarm"), "Cancellation fixture did not start prewarm")
	current_scene = replacement
	await _wait_preparation(state)
	_check(state.done and not state.result, "Scene replacement did not cancel prewarm")
	_check(paused, "Scene replacement cancellation changed caller pause")
	_check(current_scene == replacement, "Cancelled prewarm replaced the current scene")
	_check(_process_modes(game) == modes_before, "Cancelled prewarm retained frozen process modes")
	_check(get_node_count() == before_nodes, "Cancelled prewarm retained disposable nodes")
	current_scene = game
	replacement.queue_free()
	await process_frame
	print("PASS current-scene replacement cancels and restores the original match modes")


func _deleted_game_cancels():
	var old_game = game
	var replacement = Node.new()
	replacement.name = "PrewarmDeletedReplacement"
	root.add_child(replacement)
	var state = {"done": false, "result": true}
	_prepare_async(old_game, state)
	_check(old_game.has_node("CombatPrewarm"), "Deletion fixture did not start prewarm")
	old_game.queue_free()
	current_scene = replacement
	await _wait_preparation(state)
	_check(state.done and not state.result, "Deleted match did not cancel prewarm")
	_check(not is_instance_valid(old_game), "Deleted match remained alive after cancellation")
	_check(paused and current_scene == replacement, "Deleted match prewarm changed its replacement")
	game = null
	replacement.queue_free()
	await process_frame
	print("PASS deleted-game cancellation leaves the replacement and pause owner intact")


func _restore_async(restorer, saved, state):
	state.result = await restorer.restore(self, saved)
	state.done = true


func _restore_replacement_cancels():
	paused = false
	await _skirmish("bastion")
	paused = true
	var saved = Snapshot.new().capture(game)
	_check(saved != null, "Restore cancellation fixture snapshot unavailable")
	if saved == null:
		return
	var manager = root.get_node("SaveManager")
	manager._freeze()
	var state = {"done": false, "result": {}}
	_restore_async(Restore.new(), saved, state)
	var pending = null
	for frame in 300:
		if is_instance_valid(current_scene) and current_scene.has_node("CombatPrewarm"):
			pending = current_scene
			break
		if state.done:
			break
		await process_frame
	_check(is_instance_valid(pending), "Actual restore did not enter rendering preparation")
	if not is_instance_valid(pending):
		await _wait_preparation(state)
		manager.close_dialog()
		game = current_scene
		return
	_check(pending.restoring and paused, "Restore exposed its provisional battle")
	var replacement = Node.new()
	replacement.name = "RestoreCancellationReplacement"
	replacement.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(replacement)
	current_scene = replacement
	# A separate scene transition owns this new pause state.
	paused = false
	await _wait_preparation(state)
	manager.close_dialog()
	await _frames(5)
	_check(
		state.done and not state.result.get("ok", true) and state.result.get("cancelled", false),
		"Actual restore did not report cancellation"
	)
	_check(not is_instance_valid(pending), "Cancelled restore retained its provisional match")
	_check(get_nodes_in_group("units").is_empty(), "Cancelled restore retained unit group members")
	_check(
		get_nodes_in_group("players").is_empty(), "Cancelled restore retained player group members"
	)
	_check(
		current_scene == replacement and not paused,
		"Cancelled restore changed replacement scene or pause"
	)
	_check(
		replacement.process_mode == Node.PROCESS_MODE_ALWAYS,
		"Cancelled restore changed replacement processing"
	)
	_check(
		manager._frozen.is_empty() and manager._frozen_scene == null,
		"Cancelled restore retained save-dialog freeze ownership"
	)
	# Also clean the original failing scenario so later groups remain independent.
	if is_instance_valid(pending):
		pending.queue_free()
	replacement.queue_free()
	game = null
	await _frames(5)
	print("PASS actual restore cancellation disposes its match and preserves replacement state")


func _new_loading():
	var settings = load("res://source/data-model/MatchSettings.gd").new()
	settings.skirmish = true
	settings.advanced_start = true
	settings.map_path = "res://source/match/maps/BastionDesert.tscn"
	for index in 2:
		var side = load("res://source/data-model/PlayerSettings.gd").new()
		side.controller = index + 1
		side.faction = "bastion" if index == 0 else "helix"
		settings.players.append(side)
	var loading = load("res://source/main-menu/Loading.tscn").instantiate()
	loading.match_settings = settings
	loading.map_path = settings.map_path
	paused = false
	root.add_child(loading)
	current_scene = loading
	return loading


func _await_loading_preparation(loading):
	for frame in 300:
		if not is_instance_valid(loading):
			break
		var pending = loading._pending_match
		if is_instance_valid(pending) and pending.has_node("CombatPrewarm"):
			return pending
		await process_frame
	_check(false, "Loading fixture did not enter rendering preparation")
	return null


func _loading_success():
	var loading = _new_loading()
	var pending = await _await_loading_preparation(loading)
	_check(
		current_scene == loading and paused,
		"Loading surrendered its scene/pause before preparation"
	)
	_check(
		root.get_node("SaveManager").active_game() == null, "Incomplete new match became saveable"
	)
	# Native window transitions can run update ticks without submitting draws.
	# Preparation owns a draw budget; allow wall time for those draws instead
	# of failing after a small number of update-only ticks.
	var deadline = Time.get_ticks_msec() + 30000
	while is_instance_valid(loading) and Time.get_ticks_msec() < deadline:
		await process_frame
	_check(not is_instance_valid(loading), "Completed loading screen was retained")
	_check(
		is_instance_valid(pending) and current_scene == pending,
		"Loading did not hand off the prepared match"
	)
	_check(not paused, "New battle retained loading's temporary pause")
	if is_instance_valid(pending):
		_check(not pending.has_node("CombatPrewarm"), "New match retained prewarm resources")
		_check(not pending.has_node("CombatPrewarmCover"), "New match retained loading cover")
		pending.queue_free()
	await _frames(5)
	game = null
	print("PASS actual Loading keeps preparation private, hands off and releases its own pause")


func _loading_cancel():
	var loading = _new_loading()
	var pending = await _await_loading_preparation(loading)
	var replacement = Node.new()
	root.add_child(replacement)
	current_scene = replacement
	# The replacement establishes its own pause state before the old loader exits.
	paused = false
	loading.queue_free()
	await _frames(5)
	_check(not is_instance_valid(loading), "Cancelled loader remained alive")
	_check(not is_instance_valid(pending), "Cancelled loader retained its provisional match")
	_check(
		current_scene == replacement and not paused,
		"Cancelled loader changed replacement pause/scene"
	)
	replacement.queue_free()
	await process_frame
	print("PASS actual Loading cancellation disposes its match and preserves replacement state")


func _loading_quit_guard():
	var loading = _new_loading()
	var pending = await _await_loading_preparation(loading)
	var globals = root.get_node("Globals")
	# Simulate the ownership flag at quit_game's entry without terminating the test.
	globals._quitting = true
	await _frames(5)
	_check(paused, "Loading released the pause owned by application shutdown")
	_check(not is_instance_valid(pending), "Quit cancellation retained its provisional match")
	globals._quitting = false
	if is_instance_valid(loading):
		loading.queue_free()
	await process_frame
	paused = false
	print("PASS actual Loading respects application-shutdown pause ownership")


func _settle_draws():
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	await process_frame


func _finish_prewarm(options, original):
	if is_instance_valid(game):
		game.queue_free()
		await _frames(5)
	paused = false
	options.restore(original)
	OS.remove_logger(_logger)
	for message in _logger.messages:
		_check(false, message)
	for message in errors:
		push_error(message)
	print("Combat prewarm regression: %d failures" % errors.size())
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)
