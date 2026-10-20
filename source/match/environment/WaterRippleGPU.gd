extends RefCounted

# Owns render-thread resources. All operations are queued in order on the main
# renderer; there is no GPU readback or CPU synchronization in the game loop.
const RESOLUTION = 128
const MAX_IMPULSES = 32
var texture = Texture2DRD.new()
var _rd: RenderingDevice
var _shader = RID()
var _pipeline = RID()
var _states: Array[RID] = []
var _sets: Array[RID] = []
var _field = RID()
var _sources = RID()
var _output = RID()
var _index = 0


func initialize(field: Image):
	var shader_file = load("res://source/shaders/3d/water_ripple.glsl")
	RenderingServer.call_on_render_thread(_initialize.bind(field, shader_file.get_spirv()))


func step(parameters: PackedFloat32Array, impulses: PackedFloat32Array):
	RenderingServer.call_on_render_thread(
		_step.bind(parameters.to_byte_array(), impulses.to_byte_array())
	)


func dispose():
	RenderingServer.call_on_render_thread(_dispose)


func _initialize(field: Image, spirv: RDShaderSPIRV):
	_rd = RenderingServer.get_rendering_device()
	if _rd == null:
		return
	_shader = _rd.shader_create_from_spirv(spirv)
	if not _shader.is_valid():
		return
	_pipeline = _rd.compute_pipeline_create(_shader)
	_field = _create_texture(field.get_width(), field.get_height(), field.get_data())
	for index in 2:
		_states.append(_create_texture(RESOLUTION, RESOLUTION))
	_output = _create_texture(RESOLUTION, RESOLUTION)
	var data = PackedByteArray()
	data.resize(MAX_IMPULSES * 16)
	_sources = _rd.storage_buffer_create(data.size(), data)
	for index in 2:
		var uniforms: Array[RDUniform] = []
		var ids = [_states[index], _states[1 - index], _output, _field, _sources]
		for binding in ids.size():
			var uniform = RDUniform.new()
			uniform.binding = binding
			uniform.uniform_type = (
				RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
				if binding == 4
				else RenderingDevice.UNIFORM_TYPE_IMAGE
			)
			uniform.add_id(ids[binding])
			uniforms.append(uniform)
		_sets.append(_rd.uniform_set_create(uniforms, _shader, 0))
	texture.texture_rd_rid = _output


func _create_texture(width: int, height: int, data = PackedByteArray()) -> RID:
	var format = RDTextureFormat.new()
	format.width = width
	format.height = height
	format.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
	format.usage_bits = (
		RenderingDevice.TEXTURE_USAGE_STORAGE_BIT
		| RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT
		| RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
		| RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT
	)
	if data.is_empty():
		data.resize(width * height * 16)
	return _rd.texture_create(format, RDTextureView.new(), [data])


func _step(parameters: PackedByteArray, impulses: PackedByteArray):
	if not _pipeline.is_valid():
		return
	if not impulses.is_empty():
		_rd.buffer_update(_sources, 0, impulses.size(), impulses)
	var list = _rd.compute_list_begin()
	_rd.compute_list_bind_compute_pipeline(list, _pipeline)
	_rd.compute_list_bind_uniform_set(list, _sets[_index], 0)
	_rd.compute_list_set_push_constant(list, parameters, parameters.size())
	_rd.compute_list_dispatch(list, RESOLUTION / 8, RESOLUTION / 8, 1)
	_rd.compute_list_end()
	_index = 1 - _index


func _dispose():
	texture.texture_rd_rid = RID()
	if _rd == null:
		return
	# Free dependencies before their textures/shader to avoid stale RID warnings.
	for uniform_set in _sets:
		_rd.free_rid(uniform_set)
	_sets.clear()
	if _pipeline.is_valid():
		_rd.free_rid(_pipeline)
	for rid in _states + [_output, _field, _sources, _shader]:
		if rid.is_valid():
			_rd.free_rid(rid)
	_states.clear()
	_pipeline = RID()
