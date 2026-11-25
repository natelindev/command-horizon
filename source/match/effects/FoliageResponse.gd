extends Node

## Constant GPU cost regardless of foliage count; simulation time freezes on pause.
var _ages := Vector4(10, 10, 10, 10)
var _next := 0
var _wind_time := 0.0


func _ready():
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_clear()
	Globals.options.changed.connect(_apply_options)


func _apply_options():
	if Globals.options.reduced_flashes:
		_ages = Vector4(10, 10, 10, 10)
		_clear()


func impulse(point: Vector3, radius: float):
	if Globals.options.reduced_flashes or DisplayServer.get_name() == "headless":
		return
	RenderingServer.global_shader_parameter_set(
		"foliage_impulse_%d" % _next, Vector4(point.x, point.y, point.z, radius)
	)
	_ages[_next] = 0.0
	_next = (_next + 1) % 4
	_publish()


func _physics_process(delta):
	if Globals.options.reduced_flashes:
		_ages = Vector4(10, 10, 10, 10)
	else:
		_wind_time += delta
		for index in 4:
			_ages[index] = minf(10.0, _ages[index] + delta)
	_publish()


func _clear():
	_wind_time = 0.0
	RenderingServer.global_shader_parameter_set("foliage_strengths", Vector4.ZERO)
	RenderingServer.global_shader_parameter_set("foliage_wind_time", 0.0)
	for index in 4:
		RenderingServer.global_shader_parameter_set("foliage_impulse_%d" % index, Vector4.ZERO)


func _exit_tree():
	_clear()


func _publish():
	var strengths := Vector4.ZERO
	for index in 4:
		var age: float = _ages[index]
		if age < .85:
			strengths[index] = sin(age / .85 * PI) * exp(-age * 2.0)
	RenderingServer.global_shader_parameter_set("foliage_strengths", strengths)
	RenderingServer.global_shader_parameter_set("foliage_wind_time", _wind_time)
