extends "res://tests/rendered/HeavyTeamFrameBenchmark.gd"


## Cumulative diagnostic only. Frozen palettes and unavoided velocities are
## deliberately incorrect presentation/gameplay and cannot qualify as FPS wins.
class DirectVelocity:
	extends Node
	var agents := []
	var callbacks := 0

	func _physics_process(_delta):
		for agent in agents:
			if not is_instance_valid(agent) or not agent.can_process():
				continue
			if agent._native_runtime != null:
				agent._native_runtime.receive_velocity(agent.velocity, agent._native_handle)
			else:
				agent._on_velocity_computed(agent.velocity)
			callbacks += 1


var _stage := "live_control_combat"
var _direct: DirectVelocity


func _phase(label):
	if label != "day_combat":
		return
	_report.diagnostic = true
	_report.diagnostic_note = "Frozen poses / unavoided movement ablation; never gameplay FPS."
	await _measure_pipeline("live_control_combat")
	var renderer = _game.get_node("UnitBatchRenderer")
	renderer.set_process(false)
	renderer.set_physics_process(false)
	var capture = Callable(renderer, "_capture_physics_roots")
	if physics_frame.is_connected(capture):
		physics_frame.disconnect(capture)
	renderer._pending_pose_delta = 0.0
	await _measure_pipeline("pose_publication_off")
	_direct = DirectVelocity.new()
	_direct.process_physics_priority = 9999
	for army in _armies:
		for unit in army:
			var movement = unit.get_node("Movement")
			# Fixed-wing movement already bypasses RVO. Preserve that path.
			if movement.avoidance_enabled:
				movement.avoidance_enabled = false
				_direct.agents.append(movement)
	_game.add_child(_direct)
	_check(_direct.agents.size() >= 360, "Direct-velocity diagnostic missed ground agents")
	await _measure_pipeline("direct_velocity_no_avoidance")
	_direct.set_physics_process(false)
	for army in _armies:
		for unit in army:
			unit.get_node("Movement").set_physics_process(false)
	await _measure_pipeline("motion_disabled")


func _measure_pipeline(label):
	_stage = label
	await _warmup(1.0)
	var before := _direct.callbacks if _direct != null else 0
	await super._phase(label)
	var entry = _report.phases[-1]
	entry.pose_publication_enabled = _stage == "live_control_combat"
	entry.direct_velocity_callbacks = (_direct.callbacks if _direct != null else 0) - before
	if label == "direct_velocity_no_avoidance":
		_check(entry.direct_velocity_callbacks > 0, "Direct velocities were not published")
		_check(entry.moving_units >= 40, "Direct-velocity phase stopped the army")
	if label == "motion_disabled":
		_check(entry.direct_velocity_callbacks == 0, "Direct velocities continued after disabling")
		for army in _armies:
			for unit in army:
				_check(
					not unit.get_node("Movement").is_physics_processing(),
					"Movement remained enabled"
				)


func _expects_runtime_activity(system: String) -> bool:
	if system == "poses":
		return _stage == "live_control_combat"
	if system == "movement":
		return _stage != "motion_disabled"
	return true
