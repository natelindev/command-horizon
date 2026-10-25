extends RefCounted

## One GPU invocation per articulated part, shared by every mesh surface and
## shadow pass. All RenderingDevice work stays on Godot's render thread.
const KERNEL = preload("res://source/shaders/3d/pose_interpolation.glsl")
var texture := Texture2DRD.new()
var _device: RenderingDevice
var _shader := RID()
var _pipeline := RID()
var _output := RID()
var _sampler := RID()
var _old_input := RID()
var _new_input := RID()
var _capacity := 0


func setup(previous: Texture2D, current: Texture2D, capacity: int):
	_old_input = previous.get_rid()
	_new_input = current.get_rid()
	_capacity = capacity
	RenderingServer.call_on_render_thread(_initialize)


func _initialize():
	_device = RenderingServer.get_rendering_device()
	_shader = _device.shader_create_from_spirv(KERNEL.get_spirv())
	_pipeline = _device.compute_pipeline_create(_shader)
	var format := RDTextureFormat.new()
	format.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
	format.width = 4
	format.height = _capacity
	format.usage_bits = (
		RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT
		| RenderingDevice.TEXTURE_USAGE_STORAGE_BIT
		| RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	)
	_output = _device.texture_create(format, RDTextureView.new())
	_sampler = _device.sampler_create(RDSamplerState.new())
	texture.texture_rd_rid = _output


func dispatch(fraction: float, rows: int):
	RenderingServer.call_on_render_thread(_dispatch.bind(fraction, rows))


func _dispatch(fraction: float, rows: int):
	if rows == 0 or not _pipeline.is_valid():
		return
	var old := RDUniform.new()
	old.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	old.binding = 0
	old.add_id(_sampler)
	old.add_id(RenderingServer.texture_get_rd_texture(_old_input))
	var current := RDUniform.new()
	current.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	current.binding = 1
	current.add_id(_sampler)
	current.add_id(RenderingServer.texture_get_rd_texture(_new_input))
	var output := RDUniform.new()
	output.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	output.binding = 2
	output.add_id(_output)
	var uniforms := UniformSetCacheRD.get_cache(_shader, 0, [old, current, output])
	var constants := PackedFloat32Array([fraction, rows, 0.0, 0.0]).to_byte_array()
	var commands := _device.compute_list_begin()
	_device.compute_list_bind_compute_pipeline(commands, _pipeline)
	_device.compute_list_bind_uniform_set(commands, uniforms, 0)
	_device.compute_list_set_push_constant(commands, constants, constants.size())
	_device.compute_list_dispatch(commands, ceili(rows / 64.0), 1, 1)
	_device.compute_list_end()


func release():
	RenderingServer.call_on_render_thread(_release)


func _release():
	texture.texture_rd_rid = RID()
	for handle in [_pipeline, _shader, _sampler, _output]:
		if handle.is_valid():
			_device.free_rid(handle)
	_pipeline = RID()
