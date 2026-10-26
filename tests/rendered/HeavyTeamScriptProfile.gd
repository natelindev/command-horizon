extends "res://tests/rendered/HeavyTeamFrameBenchmark.gd"


## Function-level diagnostic using the editor/debug script profiler. Gameplay
## remains live, but debug/profiler overhead excludes these timings from the goal.
func _phase(label):
	if label != "day_combat":
		return
	_report.diagnostic = true
	_report.diagnostic_note = "Editor/debug script profiling with live gameplay; not production FPS."
	if not EngineDebugger.is_active() or not EngineDebugger.has_profiler("scripts"):
		_check(false, "Run with --debug using an editor/debug binary")
		return
	EngineDebugger.profiler_enable("scripts", true)
	await _warmup(1.0)
	await super._phase(label)
	EngineDebugger.profiler_enable("scripts", false)
