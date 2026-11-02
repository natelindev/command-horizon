extends Node3D

# Presentation only: one weather draw, up to 96 embers across the entire map,
# and local uniforms on existing liquid surfaces. No gameplay RNG or physics.
const WEATHER = preload("res://source/shaders/3d/battlefield_atmosphere.gdshader")
const EMBERS = preload("res://source/shaders/3d/lava_embers.gdshader")
const LIQUID_SHADERS = [
	"authored_water.gdshader",
	"authored_lava.gdshader",
	"coastal_water.gdshader",
	"living_river.gdshader"
]
const Registry = preload("res://source/match/maps/terrain/BattlefieldRegistry.gd")
var water_interactions
var liquids = []
var overlay: MeshInstance3D
var weather_material: ShaderMaterial
var embers: GPUParticles3D
var _game
var _options
var _biome = "temperate"
var _volcanic = false
var _dust_strength = 0.0


func setup(game, camera, biome):
	name = "BattlefieldEffects"
	_game = game
	_options = Globals.options
	_biome = biome
	_collect_liquids(game.map)
	water_interactions = load("res://source/match/environment/WaterInteractions.gd").new()
	add_child(water_interactions)
	water_interactions.setup(
		game,
		camera,
		liquids.filter(
			func(m): return m.shader.resource_path.get_file() == "authored_water.gdshader"
		)
	)
	var layout = Registry.layout(game.map.scene_file_path)
	var lava = layout.get("water", []).filter(func(w): return w.get("lava", false))
	_volcanic = not lava.is_empty()
	_dust_strength = 1.0 if biome == "desert" else (.65 if _volcanic else .15)
	weather_material = ShaderMaterial.new()
	weather_material.shader = WEATHER
	# Draw before selection (1) and tactical fog (2), preserving hidden terrain.
	weather_material.render_priority = 0
	weather_material.set_shader_parameter("ground_height", game.map.min_height())
	if _volcanic:
		weather_material.set_shader_parameter("dust_color", Color("81786e"))
	var quad = QuadMesh.new()
	quad.size = Vector2(2, 2)
	overlay = MeshInstance3D.new()
	overlay.name = "WeatherVeil"
	overlay.mesh = quad
	overlay.material_override = weather_material
	overlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	overlay.extra_cull_margin = 16384
	camera.add_child(overlay)
	overlay.position.z = -1
	if not lava.is_empty():
		_create_embers(lava)


func apply_options():
	water_interactions.apply_options()
	for material in liquids:
		material.set_shader_parameter("surface_effects", _options.graphics_liquids)
	weather_material.set_shader_parameter("high_quality", _options.environment_quality == 1)
	if embers:
		embers.visible = _options.graphics_liquids
		embers.emitting = _options.graphics_liquids
		embers.amount_ratio = .5 if _options.environment_quality == 0 else 1.0


func update(elapsed, cloud_cover, wetness, mist, daylight, haze):
	water_interactions.update(elapsed)
	for material in liquids:
		material.set_shader_parameter(
			"simulation_time", elapsed if _options.graphics_liquids else 0.0
		)
	var cloud_amount = maxf(.25, cloud_cover) if _options.graphics_clouds else 0.0
	var dust_amount = _dust_strength * (1.0 - wetness) if _options.graphics_dust else 0.0
	var mist_amount = mist if _options.graphics_fog else 0.0
	overlay.visible = cloud_amount + dust_amount + mist_amount > .001
	if not overlay.visible:
		return
	weather_material.set_shader_parameter("simulation_time", elapsed)
	weather_material.set_shader_parameter("clouds", cloud_amount)
	weather_material.set_shader_parameter("dust", dust_amount)
	weather_material.set_shader_parameter("mist", mist_amount)
	weather_material.set_shader_parameter("daylight", daylight)
	weather_material.set_shader_parameter("haze_color", haze)


func _collect_liquids(node):
	if node is MeshInstance3D and node.mesh:
		for surface in node.mesh.get_surface_count():
			var material = node.get_active_material(surface)
			if material is ShaderMaterial and material.shader:
				if (
					material.shader.resource_path.get_file() in LIQUID_SHADERS
					and material not in liquids
				):
					liquids.append(material)
	for child in node.get_children():
		_collect_liquids(child)


func _create_embers(lava):
	# Sample only authored lava interiors; a private seed leaves the battle's
	# random stream untouched. Fixed total budget even on maps with many pools.
	var rng = RandomNumberGenerator.new()
	rng.seed = 87031
	var points = PackedVector3Array()
	for index in 96:
		var pool = lava[index % lava.size()]
		var polygon: PackedVector2Array = pool.polygon
		var bounds = Rect2(polygon[0], Vector2.ZERO)
		for vertex in polygon:
			bounds = bounds.expand(vertex)
		for attempt in 100:
			var point = bounds.position + Vector2(rng.randf(), rng.randf()) * bounds.size
			if Geometry2D.is_point_in_polygon(point, polygon):
				points.append(Vector3(point.x, pool.get("level", 0.0) - .2, point.y))
				break
	if points.is_empty():
		return
	var image = Image.create(points.size(), 1, false, Image.FORMAT_RGBF)
	for index in points.size():
		var point = points[index]
		image.set_pixel(index, 0, Color(point.x, point.y, point.z))
	# A fixed processor owns its shader normally, avoiding the generated
	# ParticleProcessMaterial color-ramp shader retained by the dummy backend.
	var process = ShaderMaterial.new()
	process.shader = EMBERS
	process.set_shader_parameter("emission_points", ImageTexture.create_from_image(image))
	process.set_shader_parameter("point_count", points.size())
	var material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var mesh = QuadMesh.new()
	mesh.size = Vector2(.08, .16)
	mesh.material = material
	embers = GPUParticles3D.new()
	embers.name = "LavaEmbers"
	embers.amount = 96
	embers.lifetime = 4.0
	embers.preprocess = 4.0
	embers.process_material = process
	embers.draw_pass_1 = mesh
	embers.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	embers.visibility_aabb = AABB(
		Vector3(0, -20, 0), Vector3(_game.map.size.x, 80, _game.map.size.y)
	)
	add_child(embers)
