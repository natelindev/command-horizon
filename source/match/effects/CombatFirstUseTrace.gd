extends Node

## Opt-in render diagnostic. Observe completed draws without touching live effects,
## their RNG or emission budgets. No node is created during ordinary gameplay.
const LIMIT = 192
var events = []
var game
var _seen = {}


func _ready():
	RenderingServer.frame_post_draw.connect(_drawn)


func _drawn():
	if not is_instance_valid(game) or game.is_queued_for_deletion():
		return
	var effects = game.combat_effects
	for kind in effects._emitters:
		var emitter = effects._emitters[kind]
		if emitter.has_method("is_inactive") and not emitter.is_inactive():
			_record("particle/" + kind)
	for entry in effects._hit_flashes:
		var unit = entry.unit.get_ref()
		if is_instance_valid(unit):
			_record("hit/" + unit.player.faction + "/" + unit.type)
	for entry in effects._shockwaves:
		if is_instance_valid(entry.node):
			_record("shockwave/" + entry.node.material_override.shader.resource_path.get_file())
	if not effects._tracers.is_empty():
		_record("tracer")
	if not effects.aftermath.lights.is_empty():
		_record("local_light")
	if not effects.aftermath.debris.is_empty():
		_record("rigid_debris")
	if game.battlefield_wear.texture != null:
		_record("terrain_wear")
	for kind in game.projectile_system.renderer._pools:
		if not game.projectile_system.renderer._pools[kind].used.is_empty():
			_record("projectile/" + kind)


func _record(key):
	if _seen.has(key) or events.size() >= LIMIT:
		return
	_seen[key] = true
	var entry = {
		"owner": key,
		"usec": Time.get_ticks_usec(),
		"simulation_time": game.simulation_time,
		"draw_frame": Engine.get_frames_drawn(),
		"render_cpu_ms":
		RenderingServer.viewport_get_measured_render_time_cpu(get_viewport().get_viewport_rid()),
		"pipeline_totals": load("res://source/match/effects/CombatPrewarm.gd")._pipelines(),
	}
	events.append(entry)
	print("COMBAT_FIRST_USE ", JSON.stringify(entry))
