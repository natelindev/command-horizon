# gdlint: disable=max-file-lines,max-returns
extends RefCounted

## Hardware Ray Tracing (RTGI + RT Reflections + Water RT Reflections) manager and
## CompositorEffects for Godot 4.7 Forward+ on Vulkan RT-capable GPUs (e.g. RTX 4090).

const Shaders = preload("res://source/match/rendering/RaytracingShaders.gd")
const RTScene = preload("res://source/match/rendering/RaytracingScene.gd")


class TraceEffect:
	extends CompositorEffect
	var owner_ref: WeakRef

	func _init(owner):
		owner_ref = weakref(owner)
		effect_callback_type = EFFECT_CALLBACK_TYPE_POST_OPAQUE
		access_resolved_color = true
		access_resolved_depth = true
		needs_normal_roughness = true

	func _render_callback(_effect_callback_type: int, render_data: RenderData):
		var owner = owner_ref.get_ref()
		if owner != null:
			owner._render_trace(render_data)


class CompositeEffect:
	extends CompositorEffect
	var owner_ref: WeakRef

	func _init(owner):
		owner_ref = weakref(owner)
		effect_callback_type = EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
		access_resolved_color = true
		access_resolved_depth = true
		needs_normal_roughness = false

	func _render_callback(_effect_callback_type: int, render_data: RenderData):
		var owner = owner_ref.get_ref()
		if owner != null:
			owner._render_composite_post_transparent(render_data)


var scene: RTScene
var compositor: Compositor
var trace_effect: TraceEffect
var composite_effect: CompositeEffect
var water_reflection_texture: Texture2DRD
var active := false
var rt_gi_enabled := false
var rt_reflections_enabled := false
var rt_quality := 1

# Shared lighting state pushed from WorldAtmosphere (thread-safe packed copy)
var _sun_dir := Vector3(0.4, 0.7, 0.5).normalized()
var _sun_color := Color(1.0, 0.94, 0.84)
var _sun_energy := 1.2
var _daylight := 1.0
var _sky_top := Color(0.22, 0.4, 0.52)
var _sky_horizon := Color(0.7, 0.76, 0.8)
var _ground_color := Color(0.32, 0.28, 0.22)
var _ambient_energy := 0.5
var _cloud_cover := 0.0
var _reset_requested := true

# Render-thread GPU state
var _rd: RenderingDevice
var _initialized := false
var _failed := false
var _closed := false
var _s_rgen: RID
var _s_rmiss_sky: RID
var _s_rmiss_shadow: RID
var _s_rchit: RID
var _rt_pipe: RID
var _hit_sbt: RID
var _hit_sbt_range := -1
var _s_temporal: RID
var _p_temporal: RID
var _s_denoise: RID
var _p_denoise: RID
var _s_snapshot: RID
var _p_snapshot: RID
var _s_composite: RID
var _p_composite: RID
var _sampler_linear: RID
var _sampler_nearest: RID
var _ubo: RID

# Resolution-dependent targets
var _full_size := Vector2i.ZERO
var _rt_size := Vector2i.ZERO
var _gi_raw: RID
var _refl_raw: RID
var _water_refl: RID
var _nd_ping: Array[RID] = [RID(), RID()]
var _gi_hist: Array[RID] = [RID(), RID()]
var _refl_hist: Array[RID] = [RID(), RID()]
var _gi_denoise: Array[RID] = [RID(), RID()]
var _refl_denoise: Array[RID] = [RID(), RID()]
var _opaque_snap: RID
var _ping := 0
var _frame_index := 0
var _prev_view_proj := Projection.IDENTITY
var _has_prev_vp := false
var _set1_cached: RID
var _set1_revision := -1
var _last_traced_msaa := 0
var _retired_rids: Array = []
var _cached_t_sets: Array[RID] = [RID(), RID()]
var _cached_d_sets0: Array[RID] = [RID(), RID()]
var _cached_d_set1: RID
var _cached_rgen_set: Array[RID] = [RID(), RID()]
var _cached_rgen_key: Array = [[], []]
var _cached_snap_set: RID
var _cached_snap_key: Array = []
var _cached_comp_set: RID
var _cached_comp_key: Array = []


func initialize(camera: Camera3D, game) -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	if RenderingServer.get_current_rendering_method() != "forward_plus":
		return false
	var rd := RenderingServer.get_rendering_device()
	if rd == null or not rd.has_feature(RenderingDevice.SUPPORTS_RAYTRACING_PIPELINE):
		return false
	scene = RTScene.new()
	water_reflection_texture = Texture2DRD.new()
	water_reflection_texture.get_rid()
	trace_effect = TraceEffect.new(self)
	composite_effect = CompositeEffect.new(self)
	compositor = Compositor.new()
	compositor.compositor_effects = [trace_effect, composite_effect]
	camera.compositor = compositor
	RenderingServer.call_on_render_thread(_init_pipelines)
	scene.build_static(game)
	return true


func configure(gi_on: bool, refl_on: bool, quality: int):
	var changed := (
		gi_on != rt_gi_enabled or refl_on != rt_reflections_enabled or quality != rt_quality
	)
	rt_gi_enabled = gi_on
	rt_reflections_enabled = refl_on
	rt_quality = clampi(quality, 0, 2)
	active = (gi_on or refl_on) and not _failed and not _closed
	if trace_effect != null:
		trace_effect.enabled = active
	if composite_effect != null:
		composite_effect.enabled = active
	if changed:
		_reset_requested = true


func set_lighting(
	sun_dir: Vector3,
	sun_color: Color,
	sun_energy: float,
	daylight: float,
	sky_top: Color,
	sky_horizon: Color,
	ground_color: Color,
	ambient_energy: float,
	cloud_cover: float
):
	_sun_dir = sun_dir.normalized()
	_sun_color = sun_color.srgb_to_linear()
	_sun_energy = sun_energy
	_daylight = daylight
	_sky_top = sky_top.srgb_to_linear()
	_sky_horizon = sky_horizon.srgb_to_linear()
	_ground_color = ground_color.srgb_to_linear()
	_ambient_energy = ambient_energy
	_cloud_cover = cloud_cover


func sync_scene(game):
	if active and scene != null and not _closed:
		scene.sync_frame(game)


func reset_history():
	_reset_requested = true


func has_water_reflections() -> bool:
	return (
		active
		and rt_reflections_enabled
		and scene != null
		and scene.has_water()
		and water_reflection_texture != null
		and water_reflection_texture.texture_rd_rid.is_valid()
	)


func close(camera: Camera3D = null):
	if _closed:
		return
	_closed = true
	active = false
	if trace_effect != null:
		trace_effect.enabled = false
	if composite_effect != null:
		composite_effect.enabled = false
	if camera != null and is_instance_valid(camera) and camera.compositor == compositor:
		camera.compositor = null
	if water_reflection_texture != null:
		water_reflection_texture.texture_rd_rid = RID()
		water_reflection_texture = null
	if scene != null:
		scene.close()
	RenderingServer.call_on_render_thread(_release_pipelines.bind(self))


func _init_pipelines():
	if _closed:
		return
	_rd = RenderingServer.get_rendering_device()
	if _rd == null or not _rd.has_feature(RenderingDevice.SUPPORTS_RAYTRACING_PIPELINE):
		_failed = true
		return

	_s_rgen = _compile_stage(Shaders.RAYGEN, "raygen")
	_s_rmiss_sky = _compile_stage(Shaders.MISS_SKY, "miss")
	_s_rmiss_shadow = _compile_stage(Shaders.MISS_SHADOW, "miss")
	_s_rchit = _compile_stage(Shaders.CLOSEST_HIT, "closest_hit")
	if (
		not _s_rgen.is_valid()
		or not _s_rmiss_sky.is_valid()
		or not _s_rmiss_shadow.is_valid()
		or not _s_rchit.is_valid()
	):
		_failed = true
		return

	var ps_rgen := RDPipelineShader.new()
	ps_rgen.shader = _s_rgen
	var ps_miss0 := RDPipelineShader.new()
	ps_miss0.shader = _s_rmiss_sky
	var ps_miss1 := RDPipelineShader.new()
	ps_miss1.shader = _s_rmiss_shadow
	var ps_chit := RDPipelineShader.new()
	ps_chit.shader = _s_rchit
	var hg := RDHitGroup.new()
	hg.closest_hit_shader = ps_chit

	_rt_pipe = _rd.raytracing_pipeline_create([ps_rgen], [ps_miss0, ps_miss1], [hg], 1)
	if not _rt_pipe.is_valid():
		_failed = true
		return
	_hit_sbt = _rd.hit_sbt_create(_rt_pipe, 4)
	_hit_sbt_range = _rd.hit_sbt_range_alloc(_hit_sbt, 1)
	_rd.hit_sbt_range_update(_hit_sbt, _hit_sbt_range, 0, PackedInt32Array([0]))
	if scene != null:
		scene.set_hit_sbt_range(_hit_sbt_range)

	_s_temporal = _compile_stage(Shaders.TEMPORAL_COMPUTE, "compute")
	_s_denoise = _compile_stage(Shaders.DENOISE_COMPUTE, "compute")
	_s_snapshot = _compile_stage(Shaders.SNAPSHOT_COMPUTE, "compute")
	_s_composite = _compile_stage(Shaders.COMPOSITE_COMPUTE, "compute")
	if (
		not _s_temporal.is_valid()
		or not _s_denoise.is_valid()
		or not _s_snapshot.is_valid()
		or not _s_composite.is_valid()
	):
		_failed = true
		return

	_p_temporal = _rd.compute_pipeline_create(_s_temporal)
	_p_denoise = _rd.compute_pipeline_create(_s_denoise)
	_p_snapshot = _rd.compute_pipeline_create(_s_snapshot)
	_p_composite = _rd.compute_pipeline_create(_s_composite)

	var sl := RDSamplerState.new()
	sl.min_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	sl.mag_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	sl.repeat_u = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	sl.repeat_v = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	_sampler_linear = _rd.sampler_create(sl)

	var sn := RDSamplerState.new()
	sn.min_filter = RenderingDevice.SAMPLER_FILTER_NEAREST
	sn.mag_filter = RenderingDevice.SAMPLER_FILTER_NEAREST
	sn.repeat_u = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	sn.repeat_v = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	_sampler_nearest = _rd.sampler_create(sn)

	var empty_ubo := PackedByteArray()
	empty_ubo.resize(400)
	_ubo = _rd.uniform_buffer_create(400, empty_ubo)
	_initialized = true


func _compile_stage(code: String, stage: String) -> RID:
	var src := RDShaderSource.new()
	src.language = RenderingDevice.SHADER_LANGUAGE_GLSL
	match stage:
		"raygen":
			src.source_raygen = code
		"miss":
			src.source_miss = code
		"closest_hit":
			src.source_closest_hit = code
		"compute":
			src.source_compute = code
	var spirv := _rd.shader_compile_spirv_from_source(src)
	var err := ""
	match stage:
		"raygen":
			err = spirv.compile_error_raygen
		"miss":
			err = spirv.compile_error_miss
		"closest_hit":
			err = spirv.compile_error_closest_hit
		"compute":
			err = spirv.compile_error_compute
	if not err.is_empty():
		push_warning("RT %s shader compile error: %s" % [stage, err])
		return RID()
	return _rd.shader_create_from_spirv(spirv)


func _ensure_targets(full_sz: Vector2i):
	_drain_retired()
	var target_rt: Vector2i
	if rt_quality == 0:
		target_rt = Vector2i(
			maxi(16, int(round(full_sz.x * 0.5))), maxi(16, int(round(full_sz.y * 0.5)))
		)
	elif rt_quality == 1:
		# 75% up to 1440p; capped at 1080p RT (2.07M rays/pass) on 4K displays for 60+ FPS.
		var scale := minf(
			0.75, minf(1920.0 / maxf(1.0, float(full_sz.x)), 1080.0 / maxf(1.0, float(full_sz.y)))
		)
		scale = maxf(scale, 0.5)
		target_rt = Vector2i(
			maxi(16, int(round(full_sz.x * scale))), maxi(16, int(round(full_sz.y * scale)))
		)
	else:
		target_rt = full_sz
	if full_sz == _full_size and target_rt == _rt_size and _gi_raw.is_valid():
		return
	var old_water := _water_refl
	_water_refl = RID()
	_free_targets(false)
	_full_size = full_sz
	_rt_size = target_rt
	_gi_raw = _make_tex(_rt_size, RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT)
	_refl_raw = _make_tex(_rt_size, RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT)
	_water_refl = _make_tex(_rt_size, RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT)
	for i in 2:
		_nd_ping[i] = _make_tex(_rt_size, RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT)
		_gi_hist[i] = _make_tex(_rt_size, RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT)
		_refl_hist[i] = _make_tex(_rt_size, RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT)
		_gi_denoise[i] = _make_tex(_rt_size, RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT)
		_refl_denoise[i] = _make_tex(_rt_size, RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT)
	# Full 32-bit float depth snapshot prevents FP16 quantization banding on flat planes!
	_opaque_snap = _make_tex(_full_size, RenderingDevice.DATA_FORMAT_R32G32_SFLOAT)
	if old_water.is_valid():
		# Keep previous water reflection alive until the next frame rebinds the Texture2DRD
		_retired_rids.append([_frame_index + 4, old_water])
	_bind_water_tex.call_deferred(_water_refl)
	_has_prev_vp = false
	_reset_requested = true


func _bind_water_tex(rid: RID):
	if not _closed and water_reflection_texture != null and rid.is_valid():
		water_reflection_texture.texture_rd_rid = rid


func _drain_retired(force := false):
	if _rd == null or _retired_rids.is_empty():
		return
	var kept: Array = []
	for entry in _retired_rids:
		if force or _frame_index >= int(entry[0]):
			var rid: RID = entry[1]
			if rid.is_valid():
				_rd.free_rid(rid)
		else:
			kept.append(entry)
	_retired_rids = kept


func _make_tex(sz: Vector2i, fmt: int) -> RID:
	var tf := RDTextureFormat.new()
	tf.width = sz.x
	tf.height = sz.y
	tf.format = fmt
	tf.usage_bits = (
		RenderingDevice.TEXTURE_USAGE_STORAGE_BIT
		| RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT
		| RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT
		| RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	)
	return _rd.texture_create(tf, RDTextureView.new())


func _free_cached_sets():
	if _rd == null:
		return
	for arr in [_cached_t_sets, _cached_d_sets0, _cached_rgen_set]:
		for i in 2:
			if arr[i].is_valid() and _rd.uniform_set_is_valid(arr[i]):
				_rd.free_rid(arr[i])
			arr[i] = RID()
	_cached_rgen_key = [[], []]
	for rid in [_cached_d_set1, _cached_snap_set, _cached_comp_set]:
		if rid.is_valid() and _rd.uniform_set_is_valid(rid):
			_rd.free_rid(rid)
	_cached_d_set1 = RID()
	_cached_snap_set = RID()
	_cached_snap_key = []
	_cached_comp_set = RID()
	_cached_comp_key = []


func _free_targets(clear_water_binding := true):
	if _rd == null:
		return
	_free_cached_sets()
	if clear_water_binding and water_reflection_texture != null:
		water_reflection_texture.texture_rd_rid = RID()
	for rid in [_gi_raw, _refl_raw, _water_refl, _opaque_snap]:
		if rid.is_valid():
			_rd.free_rid(rid)
	_gi_raw = RID()
	_refl_raw = RID()
	_water_refl = RID()
	_opaque_snap = RID()
	for arr in [_nd_ping, _gi_hist, _refl_hist, _gi_denoise, _refl_denoise]:
		for i in 2:
			if arr[i].is_valid():
				_rd.free_rid(arr[i])
			arr[i] = RID()


func _ensure_set1() -> RID:
	var rev := scene.get_revision()
	if _set1_cached.is_valid() and _set1_revision == rev and _rd.uniform_set_is_valid(_set1_cached):
		return _set1_cached
	if _set1_cached.is_valid() and _rd.uniform_set_is_valid(_set1_cached):
		_rd.free_rid(_set1_cached)
	_set1_cached = RID()
	var bufs := scene.get_closest_hit_buffers()
	for b in bufs:
		if not b.is_valid():
			return RID()
	var uniforms: Array[RDUniform] = []
	for i in 4:
		var u := RDUniform.new()
		u.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
		u.binding = i
		u.add_id(bufs[i])
		uniforms.append(u)
	_set1_cached = _rd.uniform_set_create(uniforms, _s_rchit, 1)
	_set1_revision = rev
	return _set1_cached


func _pack_ubo(
	scene_data: RenderSceneData, full_sz: Vector2i, msaa_post: bool, reset_hist: bool
) -> PackedByteArray:
	var cam_xf: Transform3D = scene_data.get_cam_transform()
	var proj: Projection = scene_data.get_cam_projection()
	var inv_proj := proj.inverse()
	var inv_view := Projection(cam_xf)
	var view_mat := Projection(cam_xf.affine_inverse())
	var view_proj := proj * view_mat
	var prev_vp := _prev_view_proj if _has_prev_vp else view_proj
	var is_ortho := 1.0 if absf(proj.w.w) > 0.5 else 0.0
	var gi_rays := 2.0 if rt_quality >= 2 else 1.0

	var bytes := PackedByteArray()
	bytes.resize(400)
	_encode_proj(bytes, 0, inv_view)
	_encode_proj(bytes, 64, inv_proj)
	_encode_proj(bytes, 128, view_proj)
	_encode_proj(bytes, 192, prev_vp)
	_encode_vec4(bytes, 256, _sun_dir.x, _sun_dir.y, _sun_dir.z, _sun_energy)
	_encode_vec4(bytes, 272, _sun_color.r, _sun_color.g, _sun_color.b, _daylight)
	_encode_vec4(bytes, 288, _sky_top.r, _sky_top.g, _sky_top.b, _ambient_energy)
	_encode_vec4(bytes, 304, _sky_horizon.r, _sky_horizon.g, _sky_horizon.b, _cloud_cover)
	_encode_vec4(bytes, 320, _ground_color.r, _ground_color.g, _ground_color.b, 1.0 - _daylight)
	_encode_vec4(
		bytes,
		336,
		1.0 if rt_gi_enabled else 0.0,
		1.0 if rt_reflections_enabled else 0.0,
		1.0 if (scene != null and scene.has_water()) else 0.0,
		gi_rays
	)
	# gi_strength, rtao_strength, refl_strength, frame_index
	_encode_vec4(bytes, 352, 0.72, 0.72, 0.92, float(_frame_index))
	bytes.encode_s32(368, full_sz.x)
	bytes.encode_s32(372, full_sz.y)
	bytes.encode_s32(376, _rt_size.x)
	bytes.encode_s32(380, _rt_size.y)
	_encode_vec4(bytes, 384, is_ortho, 1.0 if reset_hist else 0.0, 1.0 if msaa_post else 0.0, 1.0)
	_prev_view_proj = view_proj
	_has_prev_vp = true
	return bytes


static func _encode_proj(bytes: PackedByteArray, offset: int, p: Projection):
	var cols := [p.x, p.y, p.z, p.w]
	for c in 4:
		var v: Vector4 = cols[c]
		var base := offset + c * 16
		bytes.encode_float(base + 0, v.x)
		bytes.encode_float(base + 4, v.y)
		bytes.encode_float(base + 8, v.z)
		bytes.encode_float(base + 12, v.w)


static func _encode_vec4(
	bytes: PackedByteArray, offset: int, x: float, y: float, z: float, w: float
):
	bytes.encode_float(offset + 0, x)
	bytes.encode_float(offset + 4, y)
	bytes.encode_float(offset + 8, z)
	bytes.encode_float(offset + 12, w)


func _render_trace(render_data: RenderData):
	if not active or not _initialized or _failed or _closed:
		return
	if scene == null or not scene.is_ready():
		return
	var bufs := render_data.get_render_scene_buffers() as RenderSceneBuffersRD
	if bufs == null:
		return
	var full_sz := bufs.get_internal_size()
	if full_sz.x <= 0 or full_sz.y <= 0:
		return
	var col := bufs.get_color_layer(0)
	var dep := bufs.get_depth_layer(0)
	if not col.is_valid() or not dep.is_valid():
		return
	if not bufs.has_texture("forward_clustered", "normal_roughness"):
		return
	var nr := bufs.get_texture("forward_clustered", "normal_roughness")
	if not nr.is_valid():
		return
	_ensure_targets(full_sz)
	var geo_bufs := scene.get_closest_hit_buffers()
	for b in geo_bufs:
		if not b.is_valid():
			return

	var msaa_on := bufs.get_msaa_3d() != Viewport.MSAA_DISABLED
	_last_traced_msaa = bufs.get_msaa_3d()
	var reset_hist := _reset_requested or not _has_prev_vp
	_reset_requested = false
	var scene_data := render_data.get_render_scene_data()
	var ubo_bytes := _pack_ubo(scene_data, full_sz, msaa_on, reset_hist)
	_rd.buffer_update(_ubo, 0, ubo_bytes.size(), ubo_bytes)

	var cur_idx := _ping
	var prev_idx := 1 - _ping

	# 1. Hardware Ray Tracing Pass (RTGI + Opaque RTR + Transparent Water RTR)
	var rgen_key := [dep, nr, col, scene.get_tlas(), scene.get_revision()]
	if (
		not _cached_rgen_set[cur_idx].is_valid()
		or not _rd.uniform_set_is_valid(_cached_rgen_set[cur_idx])
		or _cached_rgen_key[cur_idx] != rgen_key
	):
		if (
			_cached_rgen_set[cur_idx].is_valid()
			and _rd.uniform_set_is_valid(_cached_rgen_set[cur_idx])
		):
			_rd.free_rid(_cached_rgen_set[cur_idx])
		_cached_rgen_set[cur_idx] = _make_set(
			_s_rgen,
			[
				_u_ubo(0, _ubo),
				_u_tlas(1, scene.get_tlas()),
				_u_tex(2, _sampler_nearest, dep),
				_u_tex(3, _sampler_nearest, nr),
				_u_tex(4, _sampler_linear, col),
				_u_img(5, _gi_raw),
				_u_img(6, _refl_raw),
				_u_img(7, _water_refl),
				_u_img(8, _nd_ping[cur_idx]),
				_u_ssbo(9, geo_bufs[0]),
				_u_ssbo(10, geo_bufs[1]),
				_u_ssbo(11, geo_bufs[2]),
				_u_ssbo(12, geo_bufs[3]),
			]
		)
		_cached_rgen_key[cur_idx] = rgen_key
	var rt_list := _rd.raytracing_list_begin()
	_rd.raytracing_list_bind_raytracing_pipeline(rt_list, _rt_pipe)
	_rd.raytracing_list_bind_uniform_set(rt_list, _cached_rgen_set[cur_idx], 0)
	_rd.raytracing_list_trace_rays(rt_list, 0, _hit_sbt, _rt_size.x, _rt_size.y, 1)
	_rd.raytracing_list_end()

	var gx := ceili(float(_rt_size.x) / 8.0)
	var gy := ceili(float(_rt_size.y) / 8.0)

	# 2. Spatiotemporal Reprojection + Variance-Clamped Accumulation (cached descriptor set)
	if (
		not _cached_t_sets[cur_idx].is_valid()
		or not _rd.uniform_set_is_valid(_cached_t_sets[cur_idx])
	):
		_cached_t_sets[cur_idx] = _make_set(
			_s_temporal,
			[
				_u_ubo(0, _ubo),
				_u_tex(1, _sampler_nearest, _gi_raw),
				_u_tex(2, _sampler_nearest, _refl_raw),
				_u_tex(3, _sampler_linear, _gi_hist[prev_idx]),
				_u_tex(4, _sampler_linear, _refl_hist[prev_idx]),
				_u_tex(5, _sampler_nearest, _nd_ping[cur_idx]),
				_u_tex(6, _sampler_nearest, _nd_ping[prev_idx]),
				_u_img(7, _gi_hist[cur_idx]),
				_u_img(8, _refl_hist[cur_idx]),
			]
		)
	var cl := _rd.compute_list_begin()
	_rd.compute_list_bind_compute_pipeline(cl, _p_temporal)
	_rd.compute_list_bind_uniform_set(cl, _cached_t_sets[cur_idx], 0)
	_rd.compute_list_dispatch(cl, gx, gy, 1)
	_rd.compute_list_end()

	# 3. Two-pass Edge-Aware A-Trous Spatial Denoiser (step = 1, then step = 2)
	var d_set0 := _make_set(
		_s_denoise,
		[
			_u_ubo(0, _ubo),
			_u_tex(1, _sampler_nearest, _gi_hist[cur_idx]),
			_u_tex(2, _sampler_nearest, _refl_hist[cur_idx]),
			_u_tex(3, _sampler_nearest, _nd_ping[cur_idx]),
			_u_tex(4, _sampler_nearest, nr),
			_u_img(5, _gi_denoise[0]),
			_u_img(6, _refl_denoise[0]),
		]
	)
	var d_set1 := _make_set(
		_s_denoise,
		[
			_u_ubo(0, _ubo),
			_u_tex(1, _sampler_nearest, _gi_denoise[0]),
			_u_tex(2, _sampler_nearest, _refl_denoise[0]),
			_u_tex(3, _sampler_nearest, _nd_ping[cur_idx]),
			_u_tex(4, _sampler_nearest, nr),
			_u_img(5, _gi_denoise[1]),
			_u_img(6, _refl_denoise[1]),
		]
	)
	var pc := PackedByteArray()
	pc.resize(16)
	cl = _rd.compute_list_begin()
	_rd.compute_list_bind_compute_pipeline(cl, _p_denoise)
	pc.encode_s32(0, 1)
	_rd.compute_list_bind_uniform_set(cl, d_set0, 0)
	_rd.compute_list_set_push_constant(cl, pc, 16)
	_rd.compute_list_dispatch(cl, gx, gy, 1)
	_rd.compute_list_add_barrier(cl)
	pc.encode_s32(0, 2)
	_rd.compute_list_bind_uniform_set(cl, d_set1, 0)
	_rd.compute_list_set_push_constant(cl, pc, 16)
	_rd.compute_list_dispatch(cl, gx, gy, 1)
	_rd.compute_list_end()
	_rd.free_rid(d_set0)
	_rd.free_rid(d_set1)

	# 4. Composite now (MSAA off) or save opaque snapshot for POST_TRANSPARENT (MSAA on).
	var fx := ceili(float(full_sz.x) / 8.0)
	var fy := ceili(float(full_sz.y) / 8.0)
	if msaa_on:
		var snap_key := [col, dep]
		if (
			not _cached_snap_set.is_valid()
			or not _rd.uniform_set_is_valid(_cached_snap_set)
			or _cached_snap_key != snap_key
		):
			if _cached_snap_set.is_valid() and _rd.uniform_set_is_valid(_cached_snap_set):
				_rd.free_rid(_cached_snap_set)
			_cached_snap_set = _make_set(
				_s_snapshot,
				[
					_u_tex(0, _sampler_nearest, col),
					_u_tex(1, _sampler_nearest, dep),
					_u_img(2, _opaque_snap),
				]
			)
			_cached_snap_key = snap_key
		pc.encode_s32(0, full_sz.x)
		pc.encode_s32(4, full_sz.y)
		cl = _rd.compute_list_begin()
		_rd.compute_list_bind_compute_pipeline(cl, _p_snapshot)
		_rd.compute_list_bind_uniform_set(cl, _cached_snap_set, 0)
		_rd.compute_list_set_push_constant(cl, pc, 16)
		_rd.compute_list_dispatch(cl, fx, fy, 1)
		_rd.compute_list_end()
	else:
		_dispatch_composite(col, dep, nr, fx, fy)

	_ping = 1 - _ping
	_frame_index += 1


func _render_composite_post_transparent(render_data: RenderData):
	if not active or not _initialized or _failed or _closed:
		return
	if _last_traced_msaa == Viewport.MSAA_DISABLED:
		return
	if scene == null or not scene.is_ready() or not _gi_denoise[1].is_valid():
		return
	var bufs := render_data.get_render_scene_buffers() as RenderSceneBuffersRD
	if bufs == null:
		return
	var full_sz := bufs.get_internal_size()
	if full_sz != _full_size:
		return
	var col := bufs.get_color_layer(0)
	var dep := bufs.get_depth_layer(0)
	if not col.is_valid() or not dep.is_valid():
		return
	if not bufs.has_texture("forward_clustered", "normal_roughness"):
		return
	var nr := bufs.get_texture("forward_clustered", "normal_roughness")
	if not nr.is_valid():
		return
	_dispatch_composite(col, dep, nr, ceili(float(full_sz.x) / 8.0), ceili(float(full_sz.y) / 8.0))


func _dispatch_composite(col: RID, dep: RID, nr: RID, fx: int, fy: int):
	var comp_key := [col, dep, nr]
	if (
		not _cached_comp_set.is_valid()
		or not _rd.uniform_set_is_valid(_cached_comp_set)
		or _cached_comp_key != comp_key
	):
		if _cached_comp_set.is_valid() and _rd.uniform_set_is_valid(_cached_comp_set):
			_rd.free_rid(_cached_comp_set)
		_cached_comp_set = _make_set(
			_s_composite,
			[
				_u_ubo(0, _ubo),
				_u_img(1, col),
				_u_tex(2, _sampler_nearest, dep),
				_u_tex(3, _sampler_nearest, nr),
				_u_tex(4, _sampler_linear, _gi_denoise[1]),
				_u_tex(5, _sampler_linear, _refl_denoise[1]),
				_u_tex(6, _sampler_nearest, _opaque_snap),
			]
		)
		_cached_comp_key = comp_key
	var cl := _rd.compute_list_begin()
	_rd.compute_list_bind_compute_pipeline(cl, _p_composite)
	_rd.compute_list_bind_uniform_set(cl, _cached_comp_set, 0)
	_rd.compute_list_dispatch(cl, fx, fy, 1)
	_rd.compute_list_end()


func _make_set(shader_rid: RID, items: Array) -> RID:
	var typed: Array[RDUniform] = []
	for item in items:
		typed.append(item)
	return _rd.uniform_set_create(typed, shader_rid, 0)


func _u_ubo(binding: int, rid: RID) -> RDUniform:
	var u := RDUniform.new()
	u.uniform_type = RenderingDevice.UNIFORM_TYPE_UNIFORM_BUFFER
	u.binding = binding
	u.add_id(rid)
	return u


func _u_tlas(binding: int, rid: RID) -> RDUniform:
	var u := RDUniform.new()
	u.uniform_type = RenderingDevice.UNIFORM_TYPE_ACCELERATION_STRUCTURE
	u.binding = binding
	u.add_id(rid)
	return u


func _u_tex(binding: int, sampler: RID, tex: RID) -> RDUniform:
	var u := RDUniform.new()
	u.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	u.binding = binding
	u.add_id(sampler)
	u.add_id(tex)
	return u


func _u_img(binding: int, tex: RID) -> RDUniform:
	var u := RDUniform.new()
	u.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	u.binding = binding
	u.add_id(tex)
	return u


func _u_ssbo(binding: int, buf: RID) -> RDUniform:
	var u := RDUniform.new()
	u.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	u.binding = binding
	u.add_id(buf)
	return u


func _release_pipelines(_keep_alive: RefCounted = null):
	if _rd == null:
		return
	if _set1_cached.is_valid() and _rd.uniform_set_is_valid(_set1_cached):
		_rd.free_rid(_set1_cached)
	_set1_cached = RID()
	_drain_retired(true)
	_free_targets(true)
	for rid in [
		_ubo,
		_sampler_linear,
		_sampler_nearest,
		_p_composite,
		_p_snapshot,
		_p_denoise,
		_p_temporal,
		_s_composite,
		_s_snapshot,
		_s_denoise,
		_s_temporal,
		_hit_sbt,
		_rt_pipe,
		_s_rgen,
		_s_rmiss_sky,
		_s_rmiss_shadow,
		_s_rchit,
	]:
		if rid.is_valid():
			_rd.free_rid(rid)
	_initialized = false
