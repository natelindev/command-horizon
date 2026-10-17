extends "res://tests/headless/WeaponModeRegression.gd"


class MaterialErrorLog:
	extends Logger

	var _messages = []
	var _lock = Mutex.new()

	func _log_error(function, file, _line, code, _rationale, _notify, _type, _backtraces):
		if file.ends_with("material_storage.cpp") and code.contains('"material" is null'):
			_lock.lock()
			_messages.append(function + ": " + code)
			_lock.unlock()

	func messages():
		_lock.lock()
		var result = _messages.duplicate()
		_lock.unlock()
		return result


func _run():
	if DisplayServer.get_name() == "headless":
		push_error("Construction wreck regression requires a renderer; omit --headless")
		quit(1)
		return
	var preferences = root.get_node("Globals").options
	var original = preferences.capture()
	preferences.restore({"screen": 1, "edge_scrolling": false})
	root.get_node("SaveManager").autosaves_enabled = false
	await _batch_upload()
	var logger = MaterialErrorLog.new()
	OS.add_logger(logger)
	for faction in ["bastion", "helix", "frontier"]:
		await _setup(faction)
		game.settings.visibility = game.settings.Visibility.FULL
		game.fog_of_war.reveal()
		var effects = game.combat_effects
		var human = game._get_human_player()
		var survivor = _units(human, "PowerPlant")[0].get_node("Geometry")
		var surfaces = _active_materials(survivor)
		var wreck = await _destroy_foundation(human)
		_check(is_instance_valid(wreck), faction + ": destruction did not create a wreck")
		effects._physics_process(21.0)
		await _frames(5)
		_check(not is_instance_valid(wreck), faction + ": expired wreck was not freed")
		wreck = await _destroy_foundation(human)
		var tank = _units(human, "Tank")[0]
		for index in effects.MAX_WRECKS:
			effects._wreck(tank, false)
		await _frames(5)
		_check(not is_instance_valid(wreck), faction + ": pool did not evict oldest wreck")
		_check(effects._wrecks.size() == effects.MAX_WRECKS, "Wreck pool exceeded its cap")
		await _destroy_foundation(human)
		_check(_active_materials(survivor) == surfaces, "Wreck changed shared living geometry")
		await _clean_match()
		_check(logger.messages().is_empty(), faction + ": renderer accessed freed materials")
		print("CHECKED %s construction wreck expiry, eviction and scene teardown" % faction)
	OS.remove_logger(logger)
	preferences.restore(original)
	print("Construction wreck regression: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _batch_upload():
	var rig = load("res://source/match/effects/construction/ConstructionRig.gd").new()
	root.add_child(rig)
	var pose = Transform3D(
		Basis.from_euler(Vector3(.2, .5, -.1)).scaled(Vector3(2, 3, 4)), Vector3(7, 8, 9)
	)
	var tint = Color(.2, .4, .7, .9)
	rig._add("Probe", rig.BOX, rig.finish("probe"), pose, tint, 2.0)
	rig._add("Probe", rig.BOX, rig.finish("probe"), Transform3D.IDENTITY, Color.WHITE, 1.0)
	rig._commit(rig._batches.Probe)
	var batch = rig._batches.Probe.node.multimesh
	_check(
		batch.get_instance_transform(0).is_equal_approx(Transform3D.IDENTITY),
		"Batch sort changed pose"
	)
	_check(
		batch.get_instance_transform(1).is_equal_approx(pose), "Batch upload transposed/scaled pose"
	)
	_check(batch.get_instance_color(1).is_equal_approx(tint), "Batch upload changed colour")
	rig.queue_free()
	await process_frame


func _destroy_foundation(human):
	var unit = _spawn_weapon("PowerPlant", human, Vector3(20, 0, 20))
	await _frames(3)
	_check(not unit.is_constructed(), "Fixture must die during construction")
	_check(
		_active_materials(unit.get_node("Geometry")).any(
			func(material): return material is ShaderMaterial
		),
		"Fixture lacks construction shaders"
	)
	unit.visible = true
	unit.hp = 0
	var wreck = game.combat_effects._wrecks[-1].node
	for mesh in wreck.find_children("*", "MeshInstance3D", true, false):
		_check(mesh.material_override is StandardMaterial3D, "Wreck lost its charred finish")
		for surface in mesh.get_surface_override_material_count():
			_check(
				mesh.get_surface_override_material(surface) == null,
				"Wreck retained hidden construction/team surface materials"
			)
	# Allow the renderer to register the override before expiry; same-frame cleanup
	# misses the stale surface-material RID failure in Godot's renderer.
	await _frames(5)
	return wreck


func _active_materials(geometry):
	var result = []
	for mesh in geometry.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count():
			result.append(mesh.get_active_material(surface))
	return result
