extends Node


## Optional full SceneTree callback spans. These contain existing fine-grained
## timers and must not be added to them. Engine work before/after dispatch and
## render-thread/GPU work are outside these spans.
class Probe:
	extends Node
	var profiler: Node
	var begin := false

	func _process(_delta):
		profiler.mark(1, begin)

	func _physics_process(_delta):
		profiler.mark(0, begin)


var _started := PackedInt64Array([0, 0])
var _started_cpu := PackedInt64Array([0, 0])
var totals := PackedInt64Array([0, 0, 0, 0, 0, 0])
var native: RefCounted


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	native = load("res://source/match/rendering/NativePosePacker.gd").create()
	for first in [true, false]:
		var probe := Probe.new()
		probe.profiler = self
		probe.begin = first
		probe.process_mode = Node.PROCESS_MODE_ALWAYS
		probe.process_priority = -2147483647 if first else 2147483647
		probe.process_physics_priority = probe.process_priority
		add_child(probe)


func cpu_sample() -> Array:
	return native.cpu_sample() if native != null and native.has_method("cpu_sample") else []


func mark(index: int, begin: bool):
	var now := Time.get_ticks_usec()
	var cpu := cpu_sample()
	var thread_us: int = cpu[2] if cpu.size() == 4 and cpu[0] == 1 else 0
	if begin:
		_started[index] = now
		_started_cpu[index] = thread_us
	elif _started[index] > 0:
		totals[index] += now - _started[index]
		totals[index + 2] += thread_us - _started_cpu[index]
		totals[index + 4] += 1
		_started[index] = 0
