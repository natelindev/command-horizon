extends RefCounted

# Draw lazy combat and command-feedback shader paths behind the loading screen, in the
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
	_captions(game, holder)
	var point = camera._calculate_pivot_point()
	point.y = game.map.height_at(Vector2(point.x, point.z)) + 1.0
	var effects = load("res://source/match/effects/CombatEffects.gd")
	_beams(holder, point, effects)
	_projectiles(holder, point)
	_particle_buffers(holder, point, effects)
	if not Globals.options.reduced_flashes:
		_hit_meshes(game, holder, point)
		var ring = effects.create_shockwave(2.0)
		holder.add_child(ring)
		ring.global_position = point
		ring.material_override.set_shader_parameter("progress", .35)
		_muzzle(holder, point, effects)
	if Globals.options.battlefield_wear and Globals.options.graphics_ground_detail:
		_wear(game, holder, point)
	# Command rings/ribbons and local muzzle lighting must compile behind the
	# same cover as combat shaders, using disposable resources only.
	var feedback = load("res://source/match/effects/TerrainFeedback.gd").new()
	feedback.map = game.map
	holder.add_child(feedback)
	var hud = game.get("hud")
	var commands = hud.get("command_feedback") if is_instance_valid(hud) else null
	if is_instance_valid(commands):
		commands._pose_marker(
			{
				"node": feedback,
				"point": point,
				"heading": Vector3.FORWARD,
				"kind": "move",
				"accepted": true,
				"age": .1
			}
		)
		feedback.fade(.7)
	else:
		feedback.begin()
		feedback.ring(point, 1.0, .1, Color.WHITE)
		feedback.finish()
	if not Globals.options.reduced_flashes:
		var light = OmniLight3D.new()
		light.shadow_enabled = false
		light.omni_range = 5.0
		holder.add_child(light)
		light.global_position = point + Vector3.UP
	var previous = _pipelines()
	var stable = 0
	for draw in MAX_DRAWS:
		if not await _draw(game, tree, scene_id):
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
	var completed = await _draw(game, tree, scene_id)
	_cleanup(holder, cover, frozen)
	return completed


static func _draw(game, tree, scene_id) -> bool:
	# A covered/idle or unfocused native window may skip automatic draws.
	# Request the preparation draw explicitly and watch scene ownership on
	# update ticks too, so cancellation never waits for a future window redraw.
	var state = {"drawn": false}
	var drawn = func(): state.drawn = true
	RenderingServer.frame_post_draw.connect(drawn, CONNECT_ONE_SHOT)
	await tree.process_frame
	if _active(game, tree, scene_id):
		RenderingServer.force_draw()
	while not state.drawn and _active(game, tree, scene_id):
		await tree.process_frame
	if RenderingServer.frame_post_draw.is_connected(drawn):
		RenderingServer.frame_post_draw.disconnect(drawn)
	return state.drawn and _active(game, tree, scene_id)


static func _cover(game):
	var layer = CanvasLayer.new()
	layer.name = "CombatPrewarmCover"
	layer.layer = 128
	game.add_child(layer)
	var loading = load("res://source/main-menu/Loading.tscn").instantiate()
	loading.presentation_only = true
	layer.add_child(loading)
	return layer


static func _captions(game, holder):
	# Use the production card without changing a live caption or playing a voice.
	# Its engraved plate and font paths first appear when a unit acknowledges an
	# order. All disposable canvas resources remain behind the loading cover.
	var layer = CanvasLayer.new()
	layer.layer = 8
	holder.add_child(layer)
	var card = load("res://source/match/hud/SubtitleCard.gd").new()
	layer.add_child(card)
	var viewport = game.get_viewport().get_visible_rect().size
	card.custom_minimum_size.x = minf(560, maxf(1, viewport.x - 24))
	card.position = Vector2(12, 96)
	card.set_line("Move", TranslationServer.translate("Move"), Globals.options.subtitle_size)
	var routes = load("res://source/match/hud/OrderRoutes.gd").new()
	routes.prepare_for_loading()
	layer.add_child(routes)


static func _projectiles(holder, point):
	# Compile the vertex-colored MultiMesh path using a disposable flight pool.
	var renderer = load("res://source/match/effects/ProjectileRenderer.gd").new()
	holder.add_child(renderer)
	(
		renderer
		. add(
			{
				"weapon": {"visual": "missile"},
				"shot": {"player": {"faction": "bastion"}},
				"position": point,
				"velocity": Vector3.FORWARD * 35,
				"shown": true,
				"slot": -1,
			}
		)
	)


static func _beams(holder, point, effects):
	var mesh = effects.create_beam_mesh()
	for prism in [false, true]:
		var beam = MeshInstance3D.new()
		beam.mesh = mesh
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material = ShaderMaterial.new()
		material.shader = effects.RAY_BEAM_SHADER
		material.set_shader_parameter("is_prism", prism)
		material.set_shader_parameter("progress", .2)
		beam.material_override = material
		holder.add_child(beam)
		beam.global_position = point
		beam.scale = Vector3(.5, .5, 2.0)


static func _particle_buffers(holder, point, effects):
	# Build only disposable buffers off-tree; do not run CombatEffects._ready,
	# attach observers or emit through any live game pool/cosmetic RNG.
	var temporary = effects.new()
	for setup in [
		["flash", 128, .075, Vector3.ZERO, 2.4, .25],
		["spark", 768, .65, Vector3(0, -9.8, 0), 1.6, .1],
		["smoke", 384, 1.8, Vector3(.08, .16, .035), 0, .95],
		["dust", 512, 2.1, Vector3(0, -.15, 0), 0, .95],
		["fire", 256, .65, Vector3(0, .8, 0), 2.0, .85],
		["mote", 192, 1.2, Vector3(0, .25, 0), 2.2, .2],
		["trail_smoke", 2048, 1.25, Vector3(.06, .22, .025), 0, .72],
		["exhaust", 768, .1, Vector3.ZERO, 2.8, .38],
	]:
		temporary.callv("_emitter", setup)
	temporary._debris_emitter()
	temporary._debris_emitter("clod", 0.0)
	for emitter in temporary.get_children():
		temporary.remove_child(emitter)
		emitter.process_mode = Node.PROCESS_MODE_ALWAYS
		holder.add_child(emitter)
		emitter.emit_particle(
			Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * .2), point),
			Vector3.UP,
			Color(.7, .6, .4, .6),
			Color(point.y - 1, 0, 0),
			31
		)
	temporary.free()


static func _muzzle(holder, point, effects):
	var ring = MeshInstance3D.new()
	ring.mesh = QuadMesh.new()
	ring.mesh.size = Vector2.ONE * 3.2
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material = ShaderMaterial.new()
	material.shader = (
		effects.MUZZLE_FALLBACK
		if RenderingServer.get_current_rendering_method() == "gl_compatibility"
		else effects.MUZZLE_SHADER
	)
	material.set_shader_parameter("progress", .35)
	ring.material_override = material
	holder.add_child(ring)
	ring.global_transform = Transform3D(Basis.looking_at(Vector3.FORWARD), point)


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
