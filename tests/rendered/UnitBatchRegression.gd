extends "res://tests/headless/SaveRestoreEdges.gd"

var _batching


func _run():
	_batching = load("res://source/match/rendering/UnitBatchRenderer.gd")
	var loader = load("res://source/match/rendering/NativePosePacker.gd")
	root.get_node("SaveManager").autosaves_enabled = false
	Engine.max_fps = 120
	# Both paths must use the same geometry for the material comparison.
	root.mesh_lod_threshold = 0.0
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
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
		if loader.runtime_enabled("--native-presentation"):
			_check(
				(
					renderer._presentation != null
					and renderer._presentation_entries.size() == renderer._units.size()
				),
				"Native presentation did not cover every batched unit: " + faction
			)
		if (
			loader.runtime_enabled("--native-pose-rigs")
			or loader.runtime_enabled("--native-presentation")
		):
			_check(
				renderer._native_pose_rigs and renderer._resident_rigs == renderer._units.size(),
				"Resident pose rigs did not cover all batched units"
			)
		_check_notification_contract(renderer)
		for player in get_nodes_in_group("players"):
			var soldiers = _units(player, "Infantry")
			_check(soldiers.size() >= 2, "Repeated infantry fixture missing")
			if soldiers.size() >= 2:
				_check(
					renderer._units[soldiers[0]].mesh == renderer._units[soldiers[1]].mesh,
					"Identical infantry split model batches: " + player.faction
				)
		for unit in renderer._units.keys():
			_check_bounds(renderer, unit)
			var position = unit.global_position
			# Cell crossing, altitude and teleport publication must grow bounds
			# before the render server can cull the new pose.
			unit.global_position += Vector3(25, 40, -25)
			renderer._upload_poses()
			_check_bounds(renderer, unit)
			unit.global_position = position
			renderer._upload_poses()
		for role in ["Tank", "Infantry"]:
			var unit = _units(game._get_human_player(), role)[0]
			await _check_unit(renderer, unit, faction + "-" + role)
		paused = false
		game.queue_free()
		await _frames(8)
	for message in errors:
		push_error(message)
	print("Unit batch regression: %d failures" % errors.size())
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)


func _check_unit(renderer, unit, faction):
	var materials = load("res://source/match/ObjectMaterials.gd")
	_check(renderer._units.has(unit), "Unit did not enter GPU batch: " + faction)
	var entry = renderer._units[unit]
	var geometry = unit.get_node("Geometry")
	var muted_sources := []
	for source in entry.sources:
		if source.get_script() == null:
			_check(
				not source.is_transform_notification_enabled(),
				"Empty mesh still dispatches transforms"
			)
			if source.has_meta("gpu_transform_notify"):
				muted_sources.append(source)
	var expected = (
		geometry.find_children("*", "MeshInstance3D", true, false).size() + entry.detached.size()
	)
	_check(not entry.detached.is_empty(), "Decorative leaves still in unit transform hierarchy")
	for flags in [0, 15]:
		var copy = _batching.duplicate_geometry(geometry, flags)
		_check(
			copy.find_children("*", "MeshInstance3D", true, false).size() == expected,
			"Wreck/memory lost meshes"
		)
		_check(not copy.has_meta("gpu_batch_renderer"), "Clone retained live renderer")
		for source in copy.find_children("*", "MeshInstance3D", true, false):
			_check(
				not source.has_meta("gpu_transform_notify"),
				"Clone retained suppressed notifications"
			)
			if source.get_script() == null:
				_check(
					source.is_transform_notification_enabled(), "Clone cannot publish transforms"
				)
		copy.free()
	var flash = materials.hit_flash(geometry, Color.ORANGE)
	renderer._upload_poses()
	_check(_palette_pulse(renderer, entry) > 0.0, "Hit pulse missing from GPU palette")
	materials.clear_hit_flash(flash)
	renderer._upload_poses()
	_check(_palette_pulse(renderer, entry) == 0.0, "Hit pulse remained after clear")
	unit.hide()
	renderer._upload_poses()
	_check(
		not _palette_shown(renderer, entry) and renderer._units.has(unit),
		"Fog visibility discarded batch"
	)
	unit.show()
	renderer._upload_poses()
	_check(_palette_shown(renderer, entry), "Fog reveal did not restore unit")
	var camera = game.get_node("IsometricCamera3D")
	camera.set_size_safely(8)
	camera.set_position_safely(unit.global_position)
	await _frames(8)
	_check(
		DirAccess.make_dir_recursive_absolute("user://batch-review") == OK,
		"Cannot create batch review directory"
	)
	await RenderingServer.frame_post_draw
	var batched = root.get_texture().get_image()
	_check(
		batched.save_png("user://batch-review/" + faction + "-gpu.png") == OK,
		"Cannot save batched capture: " + faction
	)
	renderer._invalidate(unit)
	for source in muted_sources:
		_check(source.is_transform_notification_enabled(), "Fallback cannot publish transforms")
		_check(not source.has_meta("gpu_transform_notify"), "Fallback retained notification marker")
	_check(
		geometry.find_children("*", "MeshInstance3D", true, false).size() == expected,
		"Fallback lost meshes"
	)
	await _frames(8)
	await RenderingServer.frame_post_draw
	var ordinary = root.get_texture().get_image()
	_check(
		ordinary.save_png("user://batch-review/" + faction + "-native.png") == OK,
		"Cannot save ordinary capture: " + faction
	)
	_check_material_parity(camera, geometry, batched, ordinary, faction)
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


func _palette_pulse(renderer, entry) -> float:
	# Inspect the buffer sent to the draw shader. Resident presentation keeps
	# these facts in native memory rather than mirroring them in entry fields.
	return renderer._last_pixels.decode_float(entry.offset * 64 + 60)


func _palette_shown(renderer, entry) -> bool:
	for axis in 3:
		for column in 3:
			if renderer._last_pixels.decode_float(entry.offset * 64 + axis * 16 + column * 4) != 0:
				return true
	return false


func _check_bounds(renderer, unit):
	var copy = _batching.duplicate_geometry(unit.get_node("Geometry"), 0)
	unit.add_child(copy)
	var bounds: AABB = renderer._units[unit].group.mm.custom_aabb
	for mesh in copy.find_children("*", "MeshInstance3D", true, false):
		var box: AABB = mesh.mesh.get_aabb()
		for corner in 8:
			_check(
				bounds.has_point(mesh.to_global(box.get_endpoint(corner))),
				"Batch bounds clipped " + unit.type + "/" + str(mesh.name)
			)
	copy.free()


func _check_notification_contract(renderer):
	var source := MeshInstance3D.new()
	source.mesh = BoxMesh.new()
	for enabled in [false, true]:
		source.set_notify_transform(enabled)
		renderer._suppress_mesh(source)
		_check(
			not source.is_transform_notification_enabled(),
			"Suppression left transform notifications"
		)
		renderer._restore_mesh(source)
		_check(
			source.is_transform_notification_enabled() == enabled,
			"Restoration changed notification preference"
		)
		_check(not source.has_meta("gpu_transform_notify"), "Restoration left notification marker")
	source.free()


# Compare the unit, not the mostly unchanged ground. This catches dropped
# surface overrides as well as material-palette/normal errors after unbatching.
func _check_material_parity(camera, geometry, batched: Image, ordinary: Image, label):
	_check(batched.get_size() == ordinary.get_size(), "Batch comparison raster changed: " + label)
	if batched.get_size() != ordinary.get_size():
		return
	var low = Vector2(INF, INF)
	var high = Vector2(-INF, -INF)
	for mesh in geometry.find_children("*", "MeshInstance3D", true, false):
		var box = mesh.mesh.get_aabb()
		for corner in 8:
			var point = camera.unproject_position(mesh.to_global(box.get_endpoint(corner)))
			low = low.min(point)
			high = high.max(point)
	var rect = Rect2i(Rect2(low, high - low).grow(3)).intersection(
		Rect2i(Vector2i.ZERO, batched.get_size())
	)
	var different = 0
	var samples = 0
	for x in range(rect.position.x, rect.end.x, 2):
		for y in range(rect.position.y, rect.end.y, 2):
			var a = batched.get_pixel(x, y)
			var b = ordinary.get_pixel(x, y)
			different += int(maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b))) > .04)
			samples += 1
	_check(
		samples > 0 and different < samples * .015,
		"Batch/native materials differ on %s: %d/%d pixels" % [label, different, samples]
	)
