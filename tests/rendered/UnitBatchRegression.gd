extends "res://tests/headless/SaveRestoreEdges.gd"


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	Engine.max_fps = 120
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	for faction in ["bastion", "helix", "frontier"]:
		await _skirmish(faction, "res://source/match/maps/BigArena.tscn")
		root.mode = Window.MODE_WINDOWED
		root.size = Vector2i(1280, 720)
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
		root.content_scale_size = Vector2i(1280, 720)
		paused = true
		var renderer = game.get_node("UnitBatchRenderer")
		_check(renderer._native != null, "Native pose module is required for this test")
		if renderer._native == null:
			break
		for role in ["Tank", "Infantry"]:
			var unit = _units(game._get_human_player(), role)[0]
			await _check_unit(renderer, unit, faction + "-" + role)
		paused = false
		game.queue_free()
		await _frames(8)
	for message in errors:
		push_error(message)
	print("Unit batch regression: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _check_unit(renderer, unit, faction):
	var materials = load("res://source/match/ObjectMaterials.gd")
	var batching = load("res://source/match/rendering/UnitBatchRenderer.gd")
	_check(renderer._units.has(unit), "Unit did not enter GPU batch: " + faction)
	var entry = renderer._units[unit]
	var geometry = unit.get_node("Geometry")
	var expected = (
		geometry.find_children("*", "MeshInstance3D", true, false).size() + entry.detached.size()
	)
	_check(not entry.detached.is_empty(), "Decorative leaves still in unit transform hierarchy")
	for flags in [0, 15]:
		var copy = batching.duplicate_geometry(geometry, flags)
		_check(
			copy.find_children("*", "MeshInstance3D", true, false).size() == expected,
			"Wreck/memory lost meshes"
		)
		_check(not copy.has_meta("gpu_batch_renderer"), "Clone retained live renderer")
		copy.free()
	var flash = materials.hit_flash(geometry, Color.ORANGE)
	renderer._upload_poses()
	_check(entry.pulse.a > 0.0, "Hit pulse missing from GPU palette")
	materials.clear_hit_flash(flash)
	renderer._upload_poses()
	_check(entry.pulse.a == 0.0, "Hit pulse remained after clear")
	unit.hide()
	renderer._upload_poses()
	_check(not entry.shown and renderer._units.has(unit), "Fog visibility discarded batch")
	unit.show()
	renderer._upload_poses()
	_check(entry.shown, "Fog reveal did not restore unit")
	var camera = game.get_node("IsometricCamera3D")
	camera.set_size_safely(8)
	camera.set_position_safely(unit.global_position)
	await _frames(8)
	DirAccess.make_dir_recursive_absolute("res://tmp/batch-review")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tmp/batch-review/" + faction + "-gpu.png")
	renderer._invalidate(unit)
	_check(
		geometry.find_children("*", "MeshInstance3D", true, false).size() == expected,
		"Fallback lost meshes"
	)
	await _frames(8)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tmp/batch-review/" + faction + "-native.png")
	renderer._add_unit(unit)
	_check(renderer._units.has(unit), "Rebatch failed")
	var part = renderer._units[unit].sources[0]
	part.hide()
	_check(not renderer._units.has(unit), "Hidden part failed to restore ordinary rendering")
	part.show()
	renderer._add_unit(unit)
	var orphan_count = renderer._orphans.get_child_count()
	var detached_count = renderer._units[unit].detached.size()
	unit.queue_free()
	await _frames(4)
	_check(
		renderer._orphans.get_child_count() == orphan_count - detached_count,
		"Unit destruction leaked detached meshes"
	)
