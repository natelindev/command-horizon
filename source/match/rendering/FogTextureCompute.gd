extends RefCounted

## World-space visibility textures on the main RenderingDevice. Scene state is
## packed on the scene thread; all RD work is queued on the rendering thread.
const TILE_PIXELS = 16
const SHADER_PATH = "res://source/shaders/compute/fog_visibility.glsl"
var ready := false
var failed := false
var size := Vector2i.ZERO
var texture: Texture2DRD
var history: Texture2DRD
var _closed := false
var _rd: RenderingDevice
var _shader: RID
var _pipeline: RID
var _textures: Array[RID] = []
var _buffers: Array[RID] = [RID(), RID(), RID()]
var _capacities: Array[int] = [0, 0, 0]
var _uniforms: RID
var _packer: RefCounted


func initialize(dimensions: Vector2i):
	size = dimensions
	_packer = load("res://source/match/rendering/NativePosePacker.gd").create()
	if _packer != null and not _packer.has_method("pack_fog"):
		_packer = null
	var shader_file := load(SHADER_PATH) as RDShaderFile
	if shader_file == null:
		failed = true
		return
	RenderingServer.call_on_render_thread(
		_initialize_render.bind(dimensions, shader_file.get_spirv())
	)


static func pack(reveals: Array, dimensions: Vector2i) -> Array[PackedByteArray]:
	var columns := ceili(float(dimensions.x) / TILE_PIXELS)
	var rows := ceili(float(dimensions.y) / TILE_PIXELS)
	var bins: Array[PackedInt32Array] = []
	bins.resize(columns * rows)
	var primitives := PackedFloat32Array()
	for reveal in reveals:
		var center: Vector2 = reveal.position
		var triangles: PackedVector2Array = reveal.triangles
		if triangles.size() < 3:
			var radius: float = reveal.radius
			_add_primitive(
				primitives,
				bins,
				columns,
				rows,
				PackedFloat32Array([center.x, center.y, radius, 0, 0, 0, 0, 0]),
				Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)
			)
		else:
			for index in range(0, triangles.size() - 2, 3):
				var a := triangles[index] + center
				var b := triangles[index + 1] + center
				var c := triangles[index + 2] + center
				var low := a.min(b).min(c)
				var high := a.max(b).max(c)
				_add_primitive(
					primitives,
					bins,
					columns,
					rows,
					PackedFloat32Array([a.x, a.y, b.x, b.y, c.x, c.y, 1, 0]),
					Rect2(low, high - low)
				)
	var ranges := PackedInt32Array()
	var indices := PackedInt32Array()
	for bin in bins:
		ranges.append(indices.size())
		ranges.append(bin.size())
		indices.append_array(bin)
	# Storage buffers cannot be empty. Unreferenced padding is never sampled.
	if primitives.is_empty():
		primitives.resize(8)
	if indices.is_empty():
		indices.resize(1)
	return [primitives.to_byte_array(), ranges.to_byte_array(), indices.to_byte_array()]


static func _add_primitive(
	data: PackedFloat32Array,
	bins: Array[PackedInt32Array],
	columns: int,
	rows: int,
	primitive: PackedFloat32Array,
	bounds: Rect2
):
	var low := Vector2i(
		floori(bounds.position.x / TILE_PIXELS), floori(bounds.position.y / TILE_PIXELS)
	)
	var high := Vector2i(floori(bounds.end.x / TILE_PIXELS), floori(bounds.end.y / TILE_PIXELS))
	if high.x < 0 or high.y < 0 or low.x >= columns or low.y >= rows:
		return
	var index := data.size() / 8
	data.append_array(primitive)
	for y in range(maxi(0, low.y), mini(rows - 1, high.y) + 1):
		for x in range(maxi(0, low.x), mini(columns - 1, high.x) + 1):
			bins[y * columns + x].append(index)


func update(reveals: Array, reveal_all: bool, explored: Color, visible: Color):
	if not ready or _closed:
		return
	var buffers: Array[PackedByteArray] = []
	if _packer != null:
		buffers.assign(_packer.pack_fog(reveals, size))
	if buffers.size() != 3:
		buffers = pack(reveals, size)
	var constants := PackedByteArray()
	constants.resize(48)
	constants.encode_s32(0, size.x)
	constants.encode_s32(4, size.y)
	constants.encode_s32(8, ceili(float(size.x) / TILE_PIXELS))
	constants.encode_s32(12, 0)
	for index in 4:
		constants.encode_float(16 + index * 4, explored[index])
		constants.encode_float(32 + index * 4, visible[index])
	constants.encode_float(44, 1.0 if reveal_all else 0.0)
	RenderingServer.call_on_render_thread(_update_render.bind(buffers, constants))


func restore(image: Image):
	if _closed or not ready:
		return
	var copy := image.duplicate() as Image
	if copy.get_size() != size:
		copy.resize(size.x, size.y, Image.INTERPOLATE_NEAREST)
	copy.convert(Image.FORMAT_RGBA8)
	RenderingServer.call_on_render_thread(_restore_render.bind(copy.get_data()))


func close():
	if _closed:
		return
	_closed = true
	ready = false
	if texture != null:
		texture.texture_rd_rid = RID()
	if history != null:
		history.texture_rd_rid = RID()
	texture = null
	history = null
	# A queued method does not own its receiver; teardown may drop the last
	# scene reference before the rendering thread drains the queue.
	RenderingServer.call_on_render_thread(_release_render.bind(self))


func _initialize_render(dimensions: Vector2i, spirv: RDShaderSPIRV):
	_rd = RenderingServer.get_rendering_device()
	if _rd == null:
		_initialized.call_deferred(RID(), RID())
		return
	if not spirv.compile_error_compute.is_empty():
		push_warning("Compute fog unavailable: " + spirv.compile_error_compute)
		_initialized.call_deferred(RID(), RID())
		return
	_shader = _rd.shader_create_from_spirv(spirv)
	if not _shader.is_valid():
		_initialized.call_deferred(RID(), RID())
		return
	_pipeline = _rd.compute_pipeline_create(_shader)
	if not _pipeline.is_valid():
		_release_render()
		_initialized.call_deferred(RID(), RID())
		return
	var format := RDTextureFormat.new()
	format.width = dimensions.x
	format.height = dimensions.y
	format.format = RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM
	format.usage_bits = (
		RenderingDevice.TEXTURE_USAGE_STORAGE_BIT
		| RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT
		| RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT
		| RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	)
	if not _rd.texture_is_format_supported_for_usage(format.format, format.usage_bits):
		_release_render()
		_initialized.call_deferred(RID(), RID())
		return
	var zeros := PackedByteArray()
	zeros.resize(dimensions.x * dimensions.y * 4)
	for index in 3:
		var rid := _rd.texture_create(format, RDTextureView.new(), [zeros])
		if not rid.is_valid():
			_release_render()
			_initialized.call_deferred(RID(), RID())
			return
		_textures.append(rid)
	_initialized.call_deferred(_textures[2], _textures[0])


func _initialized(output: RID, exploration: RID):
	if _closed:
		return
	if not output.is_valid():
		failed = true
		return
	texture = Texture2DRD.new()
	texture.get_rid()
	texture.texture_rd_rid = output
	history = Texture2DRD.new()
	history.get_rid()
	history.texture_rd_rid = exploration
	ready = true


func _update_render(data: Array[PackedByteArray], constants: PackedByteArray):
	if _rd == null or not _pipeline.is_valid():
		return
	var changed := false
	for index in data.size():
		if data[index].size() > _capacities[index]:
			if _buffers[index].is_valid():
				_rd.free_rid(_buffers[index])
			_capacities[index] = maxi(16, nearest_po2(data[index].size()))
			_buffers[index] = _rd.storage_buffer_create(_capacities[index])
			changed = true
		_rd.buffer_update(_buffers[index], 0, data[index].size(), data[index])
	if changed or not _uniforms.is_valid():
		if _uniforms.is_valid() and _rd.uniform_set_is_valid(_uniforms):
			_rd.free_rid(_uniforms)
		var uniforms: Array[RDUniform] = []
		for index in 3:
			var image := RDUniform.new()
			image.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
			image.binding = index
			image.add_id(_textures[index])
			uniforms.append(image)
			var buffer := RDUniform.new()
			buffer.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
			buffer.binding = index + 3
			buffer.add_id(_buffers[index])
			uniforms.append(buffer)
		_uniforms = _rd.uniform_set_create(uniforms, _shader, 0)
	var commands := _rd.compute_list_begin()
	_rd.compute_list_bind_compute_pipeline(commands, _pipeline)
	_rd.compute_list_bind_uniform_set(commands, _uniforms, 0)
	_rd.compute_list_set_push_constant(commands, constants, constants.size())
	_rd.compute_list_dispatch(commands, ceili(float(size.x) / 8), ceili(float(size.y) / 8), 1)
	_rd.compute_list_add_barrier(commands)
	constants.encode_s32(12, 1)
	_rd.compute_list_set_push_constant(commands, constants, constants.size())
	_rd.compute_list_dispatch(commands, ceili(float(size.x) / 8), ceili(float(size.y) / 8), 1)
	_rd.compute_list_end()


func _restore_render(bytes: PackedByteArray):
	if _rd != null and not _textures.is_empty():
		_rd.texture_update(_textures[0], 0, bytes)


func _release_render(_keep_alive: RefCounted = null):
	if _rd == null:
		return
	if _uniforms.is_valid() and _rd.uniform_set_is_valid(_uniforms):
		_rd.free_rid(_uniforms)
	_uniforms = RID()
	for buffer in _buffers:
		if buffer.is_valid():
			_rd.free_rid(buffer)
	_buffers = [RID(), RID(), RID()]
	for rid in _textures:
		_rd.free_rid(rid)
	_textures.clear()
	if _pipeline.is_valid():
		_rd.free_rid(_pipeline)
	if _shader.is_valid():
		_rd.free_rid(_shader)
	_shader = RID()
	_pipeline = RID()
