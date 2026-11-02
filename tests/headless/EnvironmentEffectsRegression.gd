extends "res://tests/headless/SaveRestoreEdges.gd"


func _run():
	var options = root.get_node("Globals").options
	var original = options.capture()
	options.restore({"screen": 1, "day_cycle": false, "weather": 1})
	root.get_node("SaveManager").autosaves_enabled = false
	for map_name in ["CoastalFoundryMap", "CinderRingMap", "RedrockDivideMap"]:
		await _skirmish("bastion", "res://source/match/maps/battlefields/%s.tscn" % map_name)
		paused = true
		var atmosphere = game.get_node("WorldAtmosphere")
		var effects = atmosphere.effects
		options.time_of_day = 0
		options.weather = 1
		atmosphere._update(0.0)
		var daylight_energy = atmosphere.sun.light_energy
		options.time_of_day = 2
		for weather in [1, 2, 3, 4]:
			options.weather = weather
			atmosphere._update(0.0)
			_check(atmosphere.sun.light_energy >= .69, "Clouds erased the moon key")
			_check(atmosphere.environment.ambient_light_energy >= .72, "Night lost sky fill")
			_check(atmosphere.sun.light_energy < daylight_energy, "Night became brighter than day")
		options.time_of_day = 0
		options.weather = 1
		atmosphere._update(0.0)
		_check(is_equal_approx(atmosphere.sun.light_energy, daylight_energy), "Day key changed")
		_check(
			(
				effects.weather_material.render_priority
				< game.get_node("FogOfWar/ScreenOverlay").material_override.render_priority
			),
			"Weather draws over tactical fog"
		)
		_check(not effects.liquids.is_empty(), map_name + ": liquid materials were not connected")
		game.simulation_time = 37.0
		atmosphere._update(0.0)
		for material in effects.liquids:
			_check(
				material.get_shader_parameter("simulation_time") == 37.0,
				"Liquid ignores match clock"
			)
		await _frames(5)
		_check(game.simulation_time == 37.0, "Weather advanced paused match")
		options.graphics_clouds = false
		options.graphics_dust = false
		options.graphics_fog = false
		options.graphics_liquids = false
		options.apply()
		_check(not effects.overlay.visible, "Disabled weather still draws")
		for material in effects.liquids:
			_check(material.get_shader_parameter("surface_effects") == false, "Liquid off ignored")
			_check(
				material.get_shader_parameter("simulation_time") == 0.0,
				"Disabled liquid still animates"
			)
		if effects.embers:
			_check(
				not effects.embers.emitting and not effects.embers.visible,
				"Disabled embers still draw"
			)
		options.graphics_clouds = true
		options.graphics_dust = true
		options.graphics_fog = true
		options.graphics_liquids = true
		options.environment_quality = 1
		options.weather = 4
		options.apply()
		_check(effects.overlay.visible, "Weather did not resume")
		_check(effects.weather_material.get_shader_parameter("mist") > .5, "Mist is not visible")
		if map_name == "CinderRingMap":
			_check(effects.embers != null and effects.embers.amount == 96, "Lava budget missing")
			_check(effects.embers.lifetime == 4.0, "Embers lost their four-second lifetime")
			var processor = effects.embers.process_material
			_check(processor is ShaderMaterial, "Embers require an owned particle processor")
			var points = processor.get_shader_parameter("emission_points").get_image()
			_check(points.get_width() == 96, "Ember emission points were lost")
			var pools = game.map.layout.water.filter(func(pool): return pool.get("lava", false))
			for index in points.get_width():
				var point = points.get_pixel(index, 0)
				var inside_lava = false
				for pool in pools:
					inside_lava = inside_lava or (
						Geometry2D.is_point_in_polygon(Vector2(point.r, point.b), pool.polygon)
						and is_equal_approx(point.g, pool.get("level", 0.0) - .2)
					)
				_check(inside_lava, "Ember emission escaped authored lava")
			_check(
				effects.embers.emitting and effects.embers.amount_ratio == 1.0,
				"High detail lava budget"
			)
			options.environment_quality = 0
			options.apply()
			_check(effects.embers.amount_ratio == .5, "Low detail lava budget")
		if map_name == "RedrockDivideMap":
			_check(effects.weather_material.get_shader_parameter("dust") > .5, "Desert has no dust")
			options.weather = 3
			options.apply()
			_check(
				effects.weather_material.get_shader_parameter("dust") == 0.0,
				"Dust persists in rain"
			)
		var liquid = effects.liquids[0]
		game.simulation_time = 12.0
		atmosphere._update(0.0)
		_check(
			liquid.get_shader_parameter("simulation_time") == 12.0,
			"Restored clock did not rewind effects"
		)
		game.queue_free()
		await _frames(5)
		paused = false
	options.restore(original)
	for message in errors:
		push_error(message)
	print("Environment effects regression: %d failures" % errors.size())
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)
