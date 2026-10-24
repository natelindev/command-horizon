extends RefCounted

# Draw the three lazy combat shader paths behind the loading screen, in the
# battle's real viewport. Every mesh, overlay and wear texture belongs to this
# disposable holder; live effect pools, unit materials and RNG stay untouched.
const MAX_DRAWS = 12
const STABLE_DRAWS = 3


static func prepare(game) -> bool:
	if not is_instance_valid(game) or not game.is_inside_tree():
		return false
	if DisplayServer.get_name() == "headless":
		return true
	var tree = game.get_tree()
	var scene_id = _scene_id(tree)
	var camera = game.get_node_or_null("IsometricCamera3D")
	if camera == null or game.has_node("CombatPrewarm"):
		return false
	# Skirmish normally defers this attachment. Include its ALWAYS-processing
	# story/subtitle nodes in the freeze before the first preparation draw.
	if game.has_method("_attach_campaign_story"):
		game._attach_campaign_story()
	var frozen = []
	_freeze(game, frozen)
	game.process_mode = Node.PROCESS_MODE_DISABLED
	var holder = Node3D.new()
	holder.name = "CombatPrewarm"
	game.add_child(holder)
	var cover = _cover(game)
	var point = camera._calculate_pivot_point()
	point.y = game.map.height_at(Vector2(point.x, point.z)) + 1.0
	if not Globals.options.reduced_flashes:
		_hit_meshes(game, holder, point)
		var ring = load("res://source/match/effects/CombatEffects.gd").create_shockwave(2.0)
		holder.add_child(ring)
		ring.global_position = point
		ring.material_override.set_shader_parameter("progress", .35)
	if Globals.options.battlefield_wear and Globals.options.graphics_ground_detail:
		_wear(game, holder, point)
	var previous = _pipelines()
	var stable = 0
	for draw in MAX_DRAWS:
		await RenderingServer.frame_post_draw
		if not _active(game, tree, scene_id):
			_cleanup(holder, cover, frozen)
			return false
		var counts = _pipelines()
		stable = stable + 1 if counts == previous else 0
		previous = counts
		if stable >= STABLE_DRAWS:
			break
	# Keep the battle frozen until deferred proxy destruction reaches the render
	# thread. The caller owns the global pause and the scene handoff.
	holder.queue_free()
	for frame in 2:
		await tree.process_frame
		if not _active(game, tree, scene_id):
			_cleanup(holder, cover, frozen)
			return false
	await RenderingServer.frame_post_draw
	var completed = _active(game, tree, scene_id)
	_cleanup(holder, cover, frozen)
	return completed


static func _cover(game):
	var layer = CanvasLayer.new()
	layer.name = "CombatPrewarmCover"
	layer.layer = 128
	game.add_child(layer)
	var loading = load("res://source/main-menu/Loading.tscn").instantiate()
	loading.presentation_only = true
	layer.add_child(loading)
	return layer


static func _hit_meshes(game, holder, point):
	var geometry = Node3D.new()
	holder.add_child(geometry)
	var layouts = {}
	for unit in game.get_tree().get_nodes_in_group("units"):
		if not game.is_ancestor_of(unit):
			continue
		for source in unit.get_node("Geometry").find_children(
			"*", "GeometryInstance3D", true, false
		):
			var mesh = null
			var multi = source is MultiMeshInstance3D and source.multimesh != null
			if source is MeshInstance3D:
				mesh = source.mesh
			elif multi:
				mesh = source.multimesh.mesh
			if mesh == null:
				continue
			var key = [mesh.get_class(), source.cast_shadow, source.global_basis.determinant() < 0]
			if mesh is ArrayMesh:
				for surface in mesh.get_surface_count():
					key.append(mesh.surface_get_format(surface))
					key.append(mesh.surface_get_primitive_type(surface))
			if multi:
				(
					key
					. append(
						[
							source.multimesh.transform_format,
							source.multimesh.use_colors,
							source.multimesh.use_custom_data,
						]
					)
				)
			var layout = str(key)
			if layouts.has(layout):
				continue
			layouts[layout] = true
			var proxy
			if multi:
				proxy = MultiMeshInstance3D.new()
				proxy.multimesh = MultiMesh.new()
				proxy.multimesh.transform_format = source.multimesh.transform_format
				proxy.multimesh.use_colors = source.multimesh.use_colors
				proxy.multimesh.use_custom_data = source.multimesh.use_custom_data
				proxy.multimesh.mesh = mesh
				proxy.multimesh.instance_count = 1
				proxy.multimesh.set_instance_transform(0, Transform3D.IDENTITY)
			else:
				proxy = MeshInstance3D.new()
				proxy.mesh = mesh
			proxy.material_override = source.material_override
			proxy.cast_shadow = source.cast_shadow
			geometry.add_child(proxy)
			proxy.global_transform = Transform3D(
				source.global_basis,
				point + Vector3(layouts.size() % 3 - 1, 0, layouts.size() / 3 - 1)
			)
	load("res://source/match/ObjectMaterials.gd").hit_flash(geometry, Color("ffd6a1"))


static func _wear(game, holder, point):
	var terrain = game.map.get_node_or_null("Geometry/Terrain")
	if terrain == null or terrain.mesh == null:
		return
	var proxy = MeshInstance3D.new()
	proxy.mesh = terrain.mesh
	proxy.material_override = terrain.material_override
	proxy.cast_shadow = terrain.cast_shadow
	holder.add_child(proxy)
	proxy.global_transform = terrain.global_transform
	var wear = load("res://source/match/effects/BattlefieldWear.gd").new()
	holder.add_child(wear)
	wear.set_process(false)
	wear._game = game
	wear._create_texture()
	# _create_texture reads the real map without assigning its overlay. Redirect
	# before _paint so the saved terrain material/history is never modified.
	wear._terrain = proxy
	wear.add_mark(Vector2(point.x, point.z), 1.0, 0.0, 0)
	wear.add_mark(Vector2(point.x, point.z), 1.0, 0.0, 1)
	wear._paint()


static func _freeze(node, frozen):
	frozen.append({"node": weakref(node), "mode": node.process_mode})
	node.process_mode = Node.PROCESS_MODE_INHERIT
	for child in node.get_children():
		_freeze(child, frozen)


static func _cleanup(holder, cover, frozen):
	# Await boundaries above resume outside node processing. Release the final
	# cover synchronously so completion also guarantees no preparation nodes.
	if is_instance_valid(holder):
		holder.free()
	if is_instance_valid(cover):
		cover.free()
	for entry in frozen:
		var node = entry.node.get_ref()
		if node != null:
			node.process_mode = entry.mode


static func _scene_id(tree):
	return tree.current_scene.get_instance_id() if is_instance_valid(tree.current_scene) else 0


static func _active(game, tree, scene_id):
	return (
		is_instance_valid(game)
		and game.is_inside_tree()
		and not game.is_queued_for_deletion()
		and not Globals._quitting
		and _scene_id(tree) == scene_id
	)


static func _pipelines():
	return [
		RenderingServer.get_rendering_info(
			RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_CANVAS
		),
		RenderingServer.get_rendering_info(
			RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_MESH
		),
		RenderingServer.get_rendering_info(
			RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SURFACE
		),
		RenderingServer.get_rendering_info(
			RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_DRAW
		),
		RenderingServer.get_rendering_info(
			RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SPECIALIZATION
		),
	]
