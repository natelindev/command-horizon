extends Node3D

const AtmosphereProfiles = preload("res://source/match/environment/AtmosphereProfiles.gd")
const GroundDecals = preload("res://source/match/effects/GroundDecals.gd")

# Presentation is derived from the saved match clock; no gameplay or global RNG changes.
var environment: Environment
var sun: DirectionalLight3D
var camera: Camera3D
var attributes: CameraAttributesPractical
var rain: GPUParticles3D
var effects
var cloud_cover = 0.0
var wetness = 0.0
var hour = 14.0
var profile: Dictionary
var _game
var _options
var _base_ambient: Color
var _base_sun: Color
var _haze: Color
var _sky: ProceduralSkyMaterial
var _wet_materials = []
var _last_wetness = -1.0


func _ready():
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	name = "WorldAtmosphere"
	_game = get_parent()
	_options = Globals.options
	var world = _game.get_node("WorldEnvironment")
	world.environment = world.environment.duplicate(true)
	environment = world.environment
	sun = _game.get_node("DirectionalLight3D")
	sun.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	profile = AtmosphereProfiles.for_map(_game.map)
	_base_ambient = profile.fill
	_base_sun = profile.key
	_haze = profile.haze
	camera = _game.get_node("IsometricCamera3D")
	attributes = CameraAttributesPractical.new()
	camera.attributes = attributes
	if environment.sky and environment.sky.sky_material is ProceduralSkyMaterial:
		_sky = environment.sky.sky_material
		_sky.sun_angle_max = 3.0
	# The battle arena removes the tactical fog layer before the match is ready.
	var fog = _game.get_node_or_null("Fog")
	if fog != null:
		fog.hide()
	sun.shadow_bias = .025
	sun.shadow_normal_bias = .65
	sun.shadow_blur = 1.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_split_1 = .15
	sun.directional_shadow_split_2 = .35
	sun.directional_shadow_split_3 = .65
	sun.directional_shadow_max_distance = 120
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = profile.exposure
	environment.adjustment_enabled = true
	environment.adjustment_contrast = profile.contrast
	environment.adjustment_saturation = profile.saturation
	environment.adjustment_color_correction = AtmosphereProfiles.grade(profile)
	environment.ssao_radius = 1.6
	environment.ssao_intensity = 1.5
	environment.ssao_power = 1.25
	environment.ssao_detail = .65
	environment.ssao_light_affect = .12
	environment.glow_intensity = .45
	environment.glow_bloom = .035
	environment.fog_height_density = 0.0
	environment.fog_aerial_perspective = .22
	environment.fog_sun_scatter = .15
	_collect_weather_materials(_game.map)
	_create_rain()
	effects = load("res://source/match/environment/BattlefieldEffects.gd").new()
	add_child(effects)
	effects.setup(_game, camera, AtmosphereProfiles.biome(_game.map))
	_options.changed.connect(apply_options)
	apply_options()


func apply_options():
	var forward = RenderingServer.get_current_rendering_method() == "forward_plus"
	sun.shadow_enabled = _options.graphics_shadows
	environment.ssao_enabled = _options.graphics_ao and forward
	environment.glow_enabled = _options.graphics_glow
	GroundDecals.set_detail(_game.map, _options.graphics_ground_detail)
	environment.fog_enabled = _options.graphics_fog
	attributes.dof_blur_far_enabled = _options.graphics_dof and forward
	attributes.dof_blur_near_enabled = false
	attributes.dof_blur_amount = .12
	get_viewport().msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][
		_options.graphics_msaa
	]
	effects.apply_options()
	# Preview edits even while settings pause the scene.
	_update(0.0)
	_game.base_area_lighting.refresh()


func _process(delta):
	_update(delta)


func _update(_delta):
	var elapsed = _game.simulation_time
	hour = fposmod(
		(
			[14.0, 17.0, 0.0, 7.0][_options.time_of_day]
			+ (elapsed / 60.0 if _options.day_cycle else 0.0)
		),
		24.0
	)
	var weather = _options.weather
	var previous_weather = weather
	var blend = 1.0
	if weather == 0:
		# Stateless eased fronts restore exactly from the archived match clock.
		var fronts = [1, 2, 3, 2, 1, 4]
		var front = int(elapsed / 100.0)
		weather = fronts[front % fronts.size()]
		previous_weather = fronts[maxi(0, front - 1) % fronts.size()]
		blend = smoothstep(0.0, 20.0, fposmod(elapsed, 100.0))
	var cloud_levels = [0.0, 0.0, .8, 1.0, .45]
	cloud_cover = lerpf(cloud_levels[previous_weather], cloud_levels[weather], blend)
	wetness = lerpf(1.0 if previous_weather == 3 else 0.0, 1.0 if weather == 3 else 0.0, blend)
	var altitude = sin((hour - 6.0) / 24.0 * TAU)
	var daylight = smoothstep(-.12, .35, altitude)
	_game.base_area_lighting.daylight = daylight
	var golden = (1.0 - smoothstep(.0, .5, absf(altitude))) * daylight
	# A lower key keeps cast shadows readable at midday; a cool moon key takes over at night
	# to retain tactical silhouettes.
	sun.rotation_degrees = Vector3(-maxf(12.0, absf(altitude) * 54.0), -35.0 + hour * 15.0, 0)
	sun.light_color = Color("9ebae5").lerp(_base_sun.lerp(Color("ffb56a"), golden), daylight)
	sun.light_energy = lerpf(.38, 1.35, daylight) * (1.0 - cloud_cover * .58)
	environment.ambient_light_color = Color("7086ac").lerp(_base_ambient, daylight)
	environment.ambient_light_energy = lerpf(.36, .48, daylight) + cloud_cover * .08
	environment.background_energy_multiplier = lerpf(.3, 1.0, daylight)
	environment.fog_light_color = Color("263955").lerp(_haze, daylight).lerp(
		Color("d4aa83"), golden * .35
	)
	var target_fog = .0015 if weather == 4 else lerpf(.00015, .00065, cloud_levels[weather])
	var previous_fog = (
		.0015 if previous_weather == 4 else lerpf(.00015, .00065, cloud_levels[previous_weather])
	)
	environment.fog_density = lerpf(previous_fog, target_fog, blend)
	var mist = lerpf(
		.8 if previous_weather == 4 else .08 * cloud_levels[previous_weather],
		.8 if weather == 4 else .08 * cloud_levels[weather],
		blend
	)
	effects.update(elapsed, cloud_cover, wetness, mist, daylight, environment.fog_light_color)
	if _sky:
		_sky.sky_top_color = Color("0a162b").lerp(Color("376585"), daylight).lerp(
			Color("677984"), cloud_cover * .7
		)
		_sky.sky_horizon_color = environment.fog_light_color
		_sky.ground_horizon_color = environment.fog_light_color
	var focus_distance = camera.global_position.y / maxf(.1, camera.global_basis.z.y)
	attributes.dof_blur_far_distance = focus_distance + camera.size * .6
	attributes.dof_blur_far_transition = maxf(12.0, camera.size * .7)
	rain.visible = _options.weather_particles and wetness > .03
	rain.emitting = _options.weather_particles and wetness > .1
	rain.amount_ratio = maxf(.05, wetness)
	var center = camera.global_position - camera.global_basis.z * focus_distance
	rain.global_position = Vector3(center.x, 16, center.z)
	if absf(_last_wetness - wetness) > .01:
		for material in _wet_materials:
			material.set_shader_parameter("wetness", wetness)
		_last_wetness = wetness
	# Local material parameters avoid coupling concurrently loaded viewports/matches.
	if _game.map.has_node("LivingWorld"):
		_game.map.get_node("LivingWorld").set_atmosphere(daylight, wetness)


func _create_rain():
	rain = GPUParticles3D.new()
	rain.name = "Rain"
	rain.amount = 1800
	rain.lifetime = 1.4
	rain.preprocess = 1.4
	rain.visibility_aabb = AABB(Vector3(-55, -25, -55), Vector3(110, 50, 110))
	rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var process = ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(45, 1, 45)
	process.direction = Vector3(.1, -1, .06)
	process.spread = 4
	process.initial_velocity_min = 18
	process.initial_velocity_max = 24
	process.gravity = Vector3(0, -4, 0)
	rain.process_material = process
	var mesh = BoxMesh.new()
	mesh.size = Vector3(.018, .65, .018)
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(.65, .76, .84, .35)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = material
	rain.draw_pass_1 = mesh
	add_child(rain)


func _collect_weather_materials(node):
	if node is MeshInstance3D and node.mesh:
		for surface in node.mesh.get_surface_count():
			var material = node.get_active_material(surface)
			if (
				material is ShaderMaterial
				and material.shader
				and (
					material.shader.resource_path
					in [
						"res://source/shaders/3d/district_ground.gdshader",
						"res://source/shaders/3d/foundry_ground.gdshader",
						"res://source/shaders/3d/district_surface.gdshader"
					]
				)
			):
				var local_material = material.duplicate()
				node.set_surface_override_material(surface, local_material)
				_wet_materials.append(local_material)
	for child in node.get_children():
		_collect_weather_materials(child)
