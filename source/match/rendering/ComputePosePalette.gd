extends RefCounted

## One GPU invocation per articulated part, shared by every mesh surface and
## shadow pass. All RenderingDevice work stays on Godot's render thread.
const KERNEL = preload("res://source/shaders/3d/pose_interpolation.glsl")
var texture := Texture2DRD.new()
var _device: RenderingDevice
var _shader := RID()
var _pipeline := RID()
var _uniforms := RID()
var _output := RID()
var _old_input := RID()
var _new_input := RID()
var _capacity := 0
var _pending_previous := PackedByteArray()
var _pending_current := PackedByteArray()


func setup(capacity: int):
	_capacity = capacity
	# Create the placeholder before the render thread can publish its replacement.
	texture.get_rid()
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
	# Storage inputs upload only occupied pose rows instead of full textures.
	for previous in [true, false]:
		var input := _device.storage_buffer_create(_capacity * 64)
		if previous:
			_old_input = input
		else:
			_new_input = input
	texture.texture_rd_rid = _output
	var old := RDUniform.new()
	old.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	old.binding = 0
	old.add_id(_old_input)
	var latest := RDUniform.new()
	latest.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	latest.binding = 1
	latest.add_id(_new_input)
	var output := RDUniform.new()
	output.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	output.binding = 2
	output.add_id(_output)
	_uniforms = _device.uniform_set_create([old, latest, output], _shader, 0)


func upload(previous: PackedByteArray, current: PackedByteArray):
	# Multiple spawns or pose flushes can happen before one draw. Retain only the
	# final snapshot, so each input buffer is updated once per rendered frame.
	_pending_previous = previous
	_pending_current = current


func dispatch(fraction: float, rows: int):
	RenderingServer.call_on_render_thread(
		_dispatch.bind(fraction, rows, _pending_previous, _pending_current)
	)
	_pending_previous = PackedByteArray()
	_pending_current = PackedByteArray()


func _dispatch(fraction: float, rows: int, previous: PackedByteArray, current: PackedByteArray):
	if rows == 0 or not _pipeline.is_valid():
		return
	if not current.is_empty():
		_device.buffer_update(_old_input, 0, rows * 64, previous)
		_device.buffer_update(_new_input, 0, rows * 64, current)
	var constants := PackedFloat32Array([fraction, rows, 0.0, 0.0]).to_byte_array()
	var commands := _device.compute_list_begin()
	_device.compute_list_bind_compute_pipeline(commands, _pipeline)
	_device.compute_list_bind_uniform_set(commands, _uniforms, 0)
	_device.compute_list_set_push_constant(commands, constants, constants.size())
	_device.compute_list_dispatch(commands, ceili(rows / 64.0), 1, 1)
	_device.compute_list_end()


func release():
	# A method Callable only retains an ObjectID. Keep the palette alive until
	# the queued release (and all earlier dispatches) finishes after scene teardown.
	RenderingServer.call_on_render_thread(_release.bind(self))


func _release(_keep_alive: RefCounted):
	texture.texture_rd_rid = RID()
	for handle in [_uniforms, _pipeline, _shader, _old_input, _new_input, _output]:
		if handle.is_valid():
			_device.free_rid(handle)
	_pipeline = RID()
