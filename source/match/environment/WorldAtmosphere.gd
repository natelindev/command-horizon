extends Node3D

const AtmosphereProfiles = preload("res://source/match/environment/AtmosphereProfiles.gd")
const GroundDecals = preload("res://source/match/effects/GroundDecals.gd")
const HardwareProfile = preload("res://source/data-model/HardwareProfile.gd")

# Presentation is derived from the saved match clock; no gameplay or global RNG changes.
var environment: Environment
var sun: DirectionalLight3D
var camera: Camera3D
var attributes: CameraAttributesPractical
var rain: GPUParticles3D
var effects
var rt_system = null
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
var _lighting_key: Array = []
var _mist_volumes: Array[FogVolume] = []
var _mist_material: FogMaterial
var _last_rt_water_ready := false


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
	sun.shadow_bias = .015
	sun.shadow_normal_bias = .20
	sun.shadow_blur = 1.0
	# Orthographic projection has no perspective size falloff. Use the complete
	# shadow atlas for one map instead of submitting the scene to four cascades.
	# Perspective cameras retain their cascade distribution.
	sun.directional_shadow_mode = (
		DirectionalLight3D.SHADOW_ORTHOGONAL
		if camera.projection == Camera3D.PROJECTION_ORTHOGONAL
		else DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	)
	sun.directional_shadow_split_1 = .15
	sun.directional_shadow_split_2 = .35
	sun.directional_shadow_split_3 = .65
	sun.directional_shadow_max_distance = 140
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = profile.exposure
	environment.adjustment_enabled = true
	environment.adjustment_contrast = profile.contrast
	environment.adjustment_saturation = profile.saturation
	environment.adjustment_color_correction = AtmosphereProfiles.grade(profile)
	environment.ssao_radius = 2.8
	environment.ssao_intensity = 2.0
	environment.ssao_power = 1.45
	environment.ssao_detail = .70
	environment.ssao_light_affect = .40
	environment.ssil_radius = 4.5
	environment.ssil_intensity = .85
	environment.ssil_sharpness = .90
	environment.ssil_normal_rejection = 1.0
	environment.ssr_max_steps = 64
	environment.ssr_fade_in = 0.12
	environment.ssr_fade_out = 1.8
	environment.ssr_depth_tolerance = 0.25
	environment.sdfgi_use_occlusion = true
	environment.sdfgi_read_sky_light = true
	environment.sdfgi_bounce_feedback = 0.65
	environment.sdfgi_cascades = 4
	environment.sdfgi_min_cell_size = 0.4
	environment.sdfgi_energy = 1.0
	environment.sdfgi_y_scale = Environment.SDFGI_Y_SCALE_75_PERCENT
	environment.glow_normalized = true
	environment.glow_hdr_threshold = 1.05
	environment.glow_intensity = .50
	environment.glow_bloom = .04
	environment.fog_height_density = 0.0
	environment.fog_aerial_perspective = .22
	environment.fog_sun_scatter = .18
	_collect_weather_materials(_game.map)
	_create_rain()
	_create_local_mist()
	effects = load("res://source/match/environment/BattlefieldEffects.gd").new()
	add_child(effects)
	effects.setup(_game, camera, AtmosphereProfiles.biome(_game.map))
	if HardwareProfile.supports_raytracing():
		var rt_candidate = load("res://source/match/rendering/RaytracingCompositorEffect.gd").new()
		if rt_candidate.initialize(camera, _game):
			rt_system = rt_candidate
	_options.changed.connect(apply_options)
	apply_options()


func _exit_tree():
	if rt_system != null:
		rt_system.close(camera)
		rt_system = null


func apply_options():
	var forward = RenderingServer.get_current_rendering_method() == "forward_plus"
	var rt_available: bool = rt_system != null and forward
	var use_rt_gi: bool = rt_available and _options.graphics_gi and _options.graphics_rt_gi
	var use_rt_refl: bool = rt_available and _options.graphics_reflections == 2
	var use_sdfgi: bool = (
		forward and _options.graphics_gi and _options.graphics_rt_gi and not rt_available
	)
	var use_ssr: bool = (
		forward
		and (
			_options.graphics_reflections == 1
			or (_options.graphics_reflections == 2 and not rt_available)
		)
	)
	var agx: bool = _options.graphics_tonemap == 1
	environment.tonemap_mode = (
		Environment.TONE_MAPPER_AGX if agx else Environment.TONE_MAPPER_FILMIC
	)
	if agx:
		environment.tonemap_agx_white = 4.0
		environment.tonemap_agx_contrast = 1.18
		environment.tonemap_exposure = profile.exposure * 1.08
		environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	else:
		environment.tonemap_exposure = profile.exposure
		environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	var sky_lighting: bool = (
		agx or _options.graphics_reflections > 0 or _options.graphics_gi or use_rt_gi
	)
	environment.ambient_light_source = (
		Environment.AMBIENT_SOURCE_SKY if sky_lighting else Environment.AMBIENT_SOURCE_COLOR
	)
	environment.ambient_light_sky_contribution = 0.65 if sky_lighting else 0.0
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY

	sun.shadow_enabled = _options.graphics_shadows
	if _options.graphics_extreme_shadows:
		sun.shadow_bias = .012
		sun.shadow_normal_bias = .14
		sun.shadow_blur = .85
	else:
		sun.shadow_bias = .015
		sun.shadow_normal_bias = .20
		sun.shadow_blur = 1.0
	environment.ssao_enabled = _options.graphics_ao and forward
	environment.ssao_intensity = 1.65 if use_rt_gi else 2.0
	environment.ssil_enabled = _options.graphics_gi and forward and not use_rt_gi
	environment.sdfgi_enabled = use_sdfgi
	environment.ssr_enabled = use_ssr
	environment.glow_enabled = _options.graphics_glow
	GroundDecals.set_detail(_game.map, _options.graphics_ground_detail)
	environment.fog_enabled = _options.graphics_fog
	environment.volumetric_fog_enabled = (
		forward and _options.graphics_fog and _options.environment_quality == 1
	)
	environment.volumetric_fog_density = 0.0
	environment.volumetric_fog_gi_inject = 1.25 if (use_rt_gi or use_sdfgi) else 1.0
	environment.volumetric_fog_anisotropy = 0.55 if _options.graphics_extreme_shadows else 0.2
	for volume in _mist_volumes:
		volume.visible = environment.volumetric_fog_enabled
	attributes.dof_blur_far_enabled = _options.graphics_dof and forward
	attributes.dof_blur_near_enabled = false
	attributes.dof_blur_amount = .12
	get_viewport().msaa_3d = [
		Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X, Viewport.MSAA_8X
	][clampi(_options.graphics_msaa, 0, 3)]
	if rt_system != null:
		rt_system.configure(use_rt_gi, use_rt_refl, _options.graphics_rt_quality)
	effects.apply_options()
	_sync_rt_water()
	# Preview edits even while settings pause the scene.
	_lighting_key.clear()
	_update(0.0)
	_game.base_area_lighting.refresh()


func _sync_rt_water():
	var water_ready: bool = rt_system != null and rt_system.has_water_reflections()
	_last_rt_water_ready = water_ready
	if effects != null and effects.has_method("set_rt_water_reflection"):
		effects.set_rt_water_reflection(
			water_ready, rt_system.water_reflection_texture if water_ready else null
		)


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
	var lighting_key = [hour, cloud_cover, previous_weather, weather, blend]
	if lighting_key != _lighting_key:
		_lighting_key = lighting_key
		_apply_lighting(altitude, daylight, golden, weather, previous_weather, blend, cloud_levels)
	var mist = lerpf(
		.8 if previous_weather == 4 else .08 * cloud_levels[previous_weather],
		.8 if weather == 4 else .08 * cloud_levels[weather],
		blend
	)
	if _mist_material != null:
		_mist_material.density = mist * .018
		_mist_material.albedo = environment.fog_light_color
	# High detail uses local light-scattering mist instead of doubling its veil.
	var veil_mist: float = 0.0 if environment.volumetric_fog_enabled else mist
	effects.update(elapsed, cloud_cover, wetness, veil_mist, daylight, environment.fog_light_color)
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
	if rt_system != null:
		rt_system.sync_scene(_game)
		var water_ready: bool = rt_system.has_water_reflections()
		if water_ready != _last_rt_water_ready:
			_sync_rt_water()


func _apply_lighting(altitude, daylight, golden, weather, previous_weather, blend, cloud_levels):
	# Reassigning identical sky uniforms still dirties their renderer material.
	# Keep water, rain and camera work live, but publish lighting only when its
	# saved-clock/weather inputs change (including between physics ticks).
	# A lower key keeps cast shadows readable at midday; a cool moon key takes over at night
	# to retain tactical silhouettes.
	sun.rotation_degrees = Vector3(-maxf(12.0, absf(altitude) * 42.0), -35.0 + hour * 15.0, 0)
	sun.light_color = Color("9ebae5").lerp(_base_sun.lerp(Color("ffb56a"), golden), daylight)
	# Keep the moon key and sky fill readable under overcast skies. Daylight
	# keeps the existing weather attenuation; tactical visibility is unchanged.
	sun.light_energy = lerpf(.85, 1.35, daylight) * (1.0 - cloud_cover * lerpf(.18, .25, daylight))
	environment.ambient_light_color = Color("a5b7d0").lerp(_base_ambient, daylight)
	environment.ambient_light_energy = lerpf(.72, .48, daylight) + cloud_cover * .12
	environment.background_energy_multiplier = lerpf(.55, 1.0, daylight)
	environment.fog_light_color = Color("263955").lerp(_haze, daylight).lerp(
		Color("d4aa83"), golden * .35
	)
	var target_fog = .0005 if weather == 4 else lerpf(.00008, .00025, cloud_levels[weather])
	var previous_fog = (
		.0005 if previous_weather == 4 else lerpf(.00008, .00025, cloud_levels[previous_weather])
	)
	environment.fog_density = lerpf(previous_fog, target_fog, blend)
	var sky_top := Color("0a162b").lerp(Color("2d5e87"), daylight).lerp(
		Color("677984"), cloud_cover * .7
	)
	var ground_bottom := Color("121822").lerp(_base_ambient.lerp(_haze, 0.45) * 0.48, daylight)
	if _sky:
		_sky.sky_top_color = sky_top
		_sky.sky_horizon_color = environment.fog_light_color
		_sky.ground_horizon_color = environment.fog_light_color.lerp(ground_bottom, 0.35)
		_sky.ground_bottom_color = ground_bottom
		_sky.sky_curve = 0.18
		_sky.ground_curve = 0.08
	if rt_system != null:
		rt_system.set_lighting(
			sun.global_basis.z,
			sun.light_color,
			sun.light_energy,
			daylight,
			sky_top,
			environment.fog_light_color,
			ground_bottom,
			environment.ambient_light_energy,
			cloud_cover
		)
		rt_system.reset_history()


func _create_local_mist():
	if RenderingServer.get_current_rendering_method() != "forward_plus":
		return
	_mist_material = FogMaterial.new()
	_mist_material.density = 0.0
	_mist_material.edge_fade = .5
	var map = _game.map
	var candidates: Array[Vector3] = []
	for z in range(1, 5):
		for x in range(1, 5):
			var point := Vector2(map.size.x * x / 5.0, map.size.y * z / 5.0)
			candidates.append(Vector3(point.x, map.height_at(point), point.y))
	candidates.sort_custom(func(a: Vector3, b: Vector3): return a.y < b.y)
	var separation: float = minf(map.size.x, map.size.y) * .25
	for point in candidates:
		var nearby := false
		for volume in _mist_volumes:
			if (
				(volume.position * Vector3(1, 0, 1)).distance_to(point * Vector3(1, 0, 1))
				< separation
			):
				nearby = true
		if nearby:
			continue
		var volume := FogVolume.new()
		volume.name = "ValleyMist%d" % _mist_volumes.size()
		volume.shape = RenderingServer.FOG_VOLUME_SHAPE_ELLIPSOID
		volume.size = Vector3(separation * 1.5, 3.0, separation)
		volume.position = point + Vector3.UP * .8
		volume.material = _mist_material
		add_child(volume)
		_mist_volumes.append(volume)
		if _mist_volumes.size() == 3:
			break
	environment.volumetric_fog_length = minf(camera.far, 160.0)
	environment.volumetric_fog_temporal_reprojection_enabled = true
	# Brief muzzle flashes should not leave temporal light trails in the mist.
	# Transient combat lights disable their volumetric contribution.


func _create_rain():
	rain = GPUParticles3D.new()
	rain.name = "Rain"
	rain.amount = 600
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
	mesh.size = Vector3(.012, .45, .012)
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(.65, .76, .84, .18)
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
