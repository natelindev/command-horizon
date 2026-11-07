extends "res://tests/rendered/OcclusionPreview.gd"


# Run graphically with -- --enable-native-kernels. Compatibility uses ordinary
# imported mesh LODs; this test specifically exercises the Forward+ pose batches.
func _abilities_gallery():
	_output = "res://art/occlusion/lod/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_output))
	_camera_node.set_process(false)
	_camera_node.set_size_safely(48)
	_camera_node.set_position_safely(ORIGIN + Vector3(0, 1, 0))
	for faction in ["bastion", "helix", "frontier"]:
		_human.faction = faction
		var x = ["bastion", "helix", "frontier"].find(faction) * 7 - 7
		_actor("Tank", _human, Vector3(x, 0, -2))
		_actor("AdvancedTank", _human, Vector3(x, 0, 3))
	await _frames(12)
	var batch = game.get_node("UnitBatchRenderer")
	if batch._native == null:
		_check(false, "Unit LOD regression requires Forward+ and native kernels")
		return
	for actor in _actors:
		_check(batch._units.has(actor), "LOD fixture bypasses native renderer")
	# Hide unrelated draws; hiding a batched unit only zeroes its pose, and its
	# degenerate triangles still count in the renderer's primitive statistics.
	var selected_batches = []
	var sources = []
	for entry in batch._units.values():
		sources.append_array(entry.sources)
	for actor in _actors:
		selected_batches.append(batch._units[actor].group.mm)
	for mesh in game.find_children("*", "GeometryInstance3D", true, false):
		if mesh in sources:
			continue
		if mesh is MultiMeshInstance3D and mesh.multimesh in selected_batches:
			continue
		mesh.hide()
	paused = true
	var full = await _measure_lod("full-detail", 0.0)
	var reduced = await _measure_lod("automatic-lod", 1.0)
	print("Isolated native batch primitives: ", full, " -> ", reduced)
	_check(reduced > 0 and reduced < full, "Native LOD levels do not reduce rendered geometry")
	paused = false


func _measure_lod(label, threshold):
	root.mesh_lod_threshold = threshold
	await _frames(5)
	await _pixels(label)
	var full = RenderingServer.get_rendering_info(
		RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME
	)
	return full
