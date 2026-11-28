extends "res://tests/headless/SaveRestoreEdges.gd"


func _run():
	var preferences = root.get_node("Globals").options
	var original = preferences.capture()
	preferences.restore({"screen": 1, "day_cycle": false, "time_of_day": 0, "weather": 1})
	root.get_node("SaveManager").autosaves_enabled = false
	await _skirmish("bastion", "res://source/match/maps/IndustrialCrossroads.tscn", false)
	var atmosphere = game.get_node("WorldAtmosphere")
	var life = game.map.get_node("LivingWorld")
	_check(atmosphere.sun.shadow_enabled, "Shadows disabled by default")
	_check(atmosphere.sun.shadow_bias < .05, "Excessive shadow bias")
	_check(life.actors.size() >= 20, "City population missing")
	for actor in life.actors:
		_check(not actor.is_in_group("units"), "Scenery became a combat unit")
	_check(
		life.find_children("*", "CollisionObject3D", true, false).all(
			func(body): return body.collision_layer == 0 and not body.input_ray_pickable
		),
		"Scenery intercepts gameplay"
	)
	var detached = Node3D.new()
	_check(
		not game.battlefield.can_observe_point(detached, Vector3.ZERO),
		"Detached observer used during map transition"
	)
	_check(
		not game.battlefield.can_observe(null, detached),
		"Detached target used during map transition"
	)
	detached.free()
	var energy = atmosphere.sun.light_energy
	preferences.time_of_day = 2
	preferences.weather = 3
	preferences.apply()
	_check(atmosphere.hour == 0, "Night preset not applied immediately")
	_check(atmosphere.sun.light_energy < energy, "Night failed to change illumination")
	_check(atmosphere.rain.emitting, "Rain preset missing precipitation")
	_check(life.windows.emission_energy_multiplier > 2, "Nighttime windows are unlit")
	preferences.graphics_shadows = false
	preferences.graphics_ao = false
	preferences.graphics_fog = false
	preferences.graphics_glow = false
	preferences.weather_particles = false
	preferences.living_world = false
	preferences.apply()
	_check(
		not atmosphere.sun.shadow_enabled and not atmosphere.environment.ssao_enabled,
		"Effects ignored Off"
	)
	_check(
		not atmosphere.environment.fog_enabled and not atmosphere.environment.glow_enabled,
		"Post-processing ignored Off"
	)
	_check(not atmosphere.rain.emitting and not life.visible, "World settings ignored Off")
	for actor in game.map.get_node("AmbientLife").actors:
		_check(actor.interactive, "Graphics setting removed an interactive neutral target")
	var before = preferences.capture()
	var dialog = root.get_node("Globals").open_settings()
	dialog._preview("time_of_day", 1)
	dialog._preview("weather", 1)
	dialog._preview("graphics_shadows", true)
	_check(atmosphere.hour == 17 and atmosphere.sun.shadow_enabled, "Paused preview did not apply")
	dialog._finish(false)
	await _frames(3)
	_check(preferences.capture() == before, "Graphics Cancel did not roll back")
	_check(
		atmosphere.hour == 0 and not atmosphere.sun.shadow_enabled,
		"Cancel left live rendering modified"
	)
	preferences.day_cycle = true
	preferences.time_of_day = 0
	preferences.weather = 0
	preferences.graphics_tonemap = 1
	preferences.graphics_extreme_shadows = true
	preferences.graphics_rt_gi = true
	preferences.graphics_reflections = 2
	preferences.graphics_rt_quality = 2
	preferences.graphics_anisotropy = 3
	preferences.graphics_post_aa = 2
	preferences.apply()
	_check(
		atmosphere.environment.tonemap_mode == Environment.TONE_MAPPER_AGX,
		"AgX tonemapping not applied"
	)
	_check(
		atmosphere.environment.ambient_light_source == Environment.AMBIENT_SOURCE_SKY,
		"Sky hemisphere ambient lighting not applied"
	)
	_check(atmosphere.sun.shadow_bias < .014, "Extreme shadows bias tuning not applied")
	preferences.graphics_tonemap = 0
	preferences.graphics_extreme_shadows = false
	preferences.apply()
	_check(
		atmosphere.environment.tonemap_mode == Environment.TONE_MAPPER_FILMIC,
		"Filmic tonemapping switch did not apply"
	)
	game.simulation_time = 240.0
	atmosphere._update(120)
	_check(absf(atmosphere.hour - 18) < .01, "Cycle not derived from saved clock")
	_check(atmosphere.wetness > .9, "Dynamic weather never reached rain")
	var archive = "user://graphics-regression-%d.tres" % OS.get_process_id()
	_check(preferences.persist(archive) == OK, "Graphics settings save failed")
	var loaded = ResourceLoader.load(archive, "", ResourceLoader.CACHE_MODE_IGNORE)
	_check(loaded.capture() == preferences.capture(), "Graphics settings did not round-trip")
	DirAccess.remove_absolute(archive)
	game.queue_free()
	await _frames(5)
	preferences.restore(original)
	for error in errors:
		push_error(error)
	print("Graphics regression: %d failures" % errors.size())
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)
