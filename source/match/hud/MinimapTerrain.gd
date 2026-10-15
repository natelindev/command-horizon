extends TextureRect

# One-time orthographic render of the battlefield ground and static scenery for the minimap.
# Copies only visual meshes into a private world; gameplay, navigation and sight are untouched.

signal captured

const AtmosphereProfiles = preload("res://source/match/environment/AtmosphereProfiles.gd")

const EXCLUDED_BRANCHES = ["LivingWorld", "AmbientLife", "SpawnPoints"]
const EXCLUDED_GROUPS = ["units", "resource_units"]

var is_captured = false


func _init():
	name = "MinimapTerrain"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	stretch_mode = TextureRect.STRETCH_SCALE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Sit below the ownership markers, which carry the minimap's information.
	self_modulate = Color(.78, .8, .82)


func capture(map, pixel_scale):
	# Headless runs have no renderer to read back from.
	if DisplayServer.get_name() == "headless":
		return
	await get_tree().process_frame
	if not is_instance_valid(map):
		return
	var viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.size = Vector2i(map.size * pixel_scale)
	viewport.msaa_3d = Viewport.MSAA_2X
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	viewport.add_child(_environment(map))
	viewport.add_child(_sun())
	viewport.add_child(_camera(map))
	var copies = Node3D.new()
	viewport.add_child(copies)
	_copy_visuals(map, map, copies)
	add_child(viewport)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	if not is_instance_valid(viewport):
		return
	var image = viewport.get_texture().get_image()
	viewport.queue_free()
	if image == null or image.is_empty():
		return
	texture = ImageTexture.create_from_image(image)
	is_captured = true
	captured.emit()


func _environment(map):
	var profile = AtmosphereProfiles.for_map(map)
	var environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("0a1216")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = profile.fill
	environment.ambient_light_energy = .45
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = profile.exposure
	environment.adjustment_enabled = true
	environment.adjustment_contrast = profile.contrast * 1.1
	environment.adjustment_saturation = profile.saturation * .9
	var world = WorldEnvironment.new()
	world.environment = environment
	return world


func _sun():
	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 175, 0)
	sun.light_energy = .95
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 400
	return sun


func _camera(map):
	var camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.size = map.size.y
	camera.near = .05
	camera.far = 400
	# Looking straight down: screen right is world +X and screen down is world +Z,
	# matching the minimap's pixel layout.
	camera.position = Vector3(map.size.x / 2.0, 150, map.size.y / 2.0)
	camera.rotation_degrees = Vector3(-90, 0, 0)
	camera.current = true
	return camera


func _copy_visuals(map, node, target):
	if node != map and (node.name in EXCLUDED_BRANCHES or _is_dynamic(node)):
		return
	if node is GeometryInstance3D and node.is_visible_in_tree():
		var copy = _copy(node)
		if copy:
			target.add_child(copy)
	for child in node.get_children():
		_copy_visuals(map, child, target)


func _is_dynamic(node):
	for group in EXCLUDED_GROUPS:
		if node.is_in_group(group):
			return true
	return false


func _copy(node):
	var copy
	if node is MeshInstance3D and node.mesh:
		# The far anti-aliasing backdrop would only cover the terrain.
		if node.name == "BlackBackgroundFixingAntiAliasingBug":
			return null
		copy = MeshInstance3D.new()
		copy.mesh = node.mesh
		copy.skeleton = NodePath()
		for surface in node.mesh.get_surface_count():
			copy.set_surface_override_material(surface, node.get_surface_override_material(surface))
	elif node is MultiMeshInstance3D and node.multimesh:
		copy = MultiMeshInstance3D.new()
		copy.multimesh = node.multimesh
	else:
		return null
	copy.material_override = node.material_override
	copy.cast_shadow = node.cast_shadow
	copy.transform = node.global_transform
	return copy
