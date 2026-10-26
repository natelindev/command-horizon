extends "res://tests/rendered/HeavyTeamFrameBenchmark.gd"

## Diagnostic ablations retain the complete army/art, then stop subsystems in
## stages. These frozen/disabled-system results cannot establish the FPS goal.
var _disabled_systems: Array[String] = []
var _stage := "live_control_combat"


func _phase(label):
	if label != "day_combat":
		return
	_report.diagnostic = true
	_report.diagnostic_note = "Cumulative subsystem ablation; frozen stages are not gameplay FPS."
	await _measure_mode("live_control_combat")
	for player in _players:
		player.set_process(false)
	_disabled_systems.append("commander decisions")
	await _measure_mode("commanders_off")
	for army in _armies:
		for unit in army:
			var movement = unit.get_node("Movement")
			movement.avoidance_enabled = false
			movement.set_physics_process(false)
	_disabled_systems.append("movement and avoidance")
	await _measure_mode("navigation_off")
	for unit in _game.get_units():
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	_game.commander_support.process_mode = Node.PROCESS_MODE_DISABLED
	_disabled_systems.append("unit actions, traits and commander support")
	await _measure_mode("unit_logic_off")
	_game.process_mode = Node.PROCESS_MODE_DISABLED
	_disabled_systems.append("remaining match processes; renderer still active")
	await _measure_mode("world_logic_off_pose_live")
	var renderer = _game.get_node("UnitBatchRenderer")
	renderer.set_process(false)
	renderer.set_physics_process(false)
	var capture = Callable(renderer, "_capture_physics_roots")
	if physics_frame.is_connected(capture):
		physics_frame.disconnect(capture)
	renderer._pending_pose_delta = 0.0
	_disabled_systems.append("pose evaluation, uploads and interpolation dispatch")
	await _measure_mode("frozen_render")
	_game.hud.process_mode = Node.PROCESS_MODE_DISABLED
	_game.hud.hide()
	for viewport in _game.find_children("*", "SubViewport", true, false):
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_disabled_systems.append("HUD and auxiliary viewport redraw")
	await _measure_mode("frozen_world_only")
	_options.time_of_day = 2
	_game.get_node("WorldAtmosphere")._update(0.0)
	_game.base_area_lighting.refresh()
	await _measure_mode("frozen_night_render")
	# Let the ordinary fixture tear down its match using the normal shutdown path.
	_game.process_mode = Node.PROCESS_MODE_INHERIT


func _measure_mode(label):
	_stage = label
	await _warmup(1.0)
	var renderer = _game.get_node("UnitBatchRenderer")
	print("ABLATION ", label, " disabled=", _disabled_systems)
	await super._phase(label)
	var entry = _report.phases[-1]
	entry.disabled_systems = _disabled_systems.duplicate()
	entry.renderer_processing = renderer.is_processing()
	entry.game_processing = _game.can_process()
	entry.expected_runtime_activity = {}
	for system in ["movement", "unit_state", "visibility", "exploration", "poses", "rosters"]:
		entry.expected_runtime_activity[system] = _expects_runtime_activity(system)
	if label == "navigation_off":
		for army in _armies:
			for unit in army:
				_check(
					not unit.get_node("Movement").is_physics_processing(),
					"Movement remained enabled in navigation ablation"
				)
	if label == "unit_logic_off":
		for unit in _game.get_units():
			_check(not unit.can_process(), "Unit remained enabled in logic ablation")
	if label == "frozen_render":
		entry.active_script_nodes = []
		for node in root.find_children("*", "Node", true, false):
			if (
				node.get_script() != null
				and node.can_process()
				and (node.is_processing() or node.is_physics_processing())
			):
				entry.active_script_nodes.append(str(node.get_path()))


func _expects_runtime_activity(system: String) -> bool:
	if _stage == "live_control_combat":
		return true
	if system == "rosters":
		return false
	if _stage == "commanders_off":
		return true
	if system == "movement":
		return false
	if _stage == "navigation_off":
		return true
	if system in ["unit_state", "visibility", "exploration"]:
		return false
	return _stage in ["unit_logic_off", "world_logic_off_pose_live"]
