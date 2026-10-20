extends "res://tests/headless/SaveRestoreEdges.gd"

const AtmosphereProfiles = preload("res://source/match/environment/AtmosphereProfiles.gd")


func _run():
	_check_palette()
	_check_biomes()
	await _skirmish("bastion", "res://source/match/maps/battlefields/DesertFrontierMap.tscn")
	_check_atmosphere("desert")
	_check_team_readability()
	_check_command_card()
	game.queue_free()
	await _frames(5)
	await _skirmish("helix", "res://source/match/maps/AlpineRelay.tscn")
	_check_atmosphere("alpine")
	game.queue_free()
	await _frames(5)
	for error in errors:
		push_error(error)
	print("Art direction regression: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _check_palette():
	var colors = load("res://source/Constants.gd").Player.COLORS
	for index in colors.size():
		var color = colors[index]
		# Designed hues: no pure primaries, mid value, moderate saturation.
		_check(color.s < .8 and color.v > .5 and color.v < .95, "Undesigned team color %s" % color)
		for other in range(index):
			var distance = Vector3(color.r, color.g, color.b).distance_to(
				Vector3(colors[other].r, colors[other].g, colors[other].b)
			)
			_check(distance > .2, "Team colors %d and %d are too similar" % [other, index])
	var fallback = load("res://source/data-model/PlayerSettings.gd").new()
	_check(fallback.color in colors, "Unconfigured players fall back to a raw color")


func _check_biomes():
	var expected = {
		"battlefields/DesertFrontierMap": "desert",
		"AlpineRelay": "alpine",
		"SplitSignalMap": "alpine",
		"battlefields/CoastalFoundryMap": "coastal",
		"BrokenFoundryMap": "urban",
		"PlainAndSimple": "temperate",
	}
	for map_name in expected:
		var stub = Node3D.new()
		stub.scene_file_path = "res://source/match/maps/%s.tscn" % map_name
		_check(
			AtmosphereProfiles.biome(stub) == expected[map_name],
			"%s did not resolve to %s" % [map_name, expected[map_name]]
		)
		stub.free()


func _check_atmosphere(biome):
	var atmosphere = game.get_node("WorldAtmosphere")
	var profile = AtmosphereProfiles.PROFILES[biome]
	var environment = atmosphere.environment
	_check(atmosphere.profile == profile, "%s profile not selected" % biome)
	_check(environment.adjustment_enabled, "Color grade disabled")
	_check(
		environment.adjustment_color_correction is GradientTexture1D, "Color grade curve missing"
	)
	_check(
		is_equal_approx(environment.tonemap_exposure, profile.exposure),
		"%s exposure not applied" % biome
	)
	var preferences = root.get_node("Globals").options
	var original = preferences.capture()
	preferences.day_cycle = false
	preferences.time_of_day = 0
	preferences.weather = 1
	preferences.apply()
	atmosphere._update(0.0)
	# Warm key, cooler fill at midday.
	_check(atmosphere.sun.light_color.r > atmosphere.sun.light_color.b, "Key light is not warm")
	_check(
		environment.ambient_light_color.b > environment.ambient_light_color.r,
		"Fill light is not cool"
	)
	_check(
		-atmosphere.sun.rotation_degrees.x < 50.0, "Midday sun too high for readable cast shadows"
	)
	preferences.restore(original)


func _check_team_readability():
	var human = game._get_human_player()
	var mobile = 0
	for unit in get_nodes_in_group("units"):
		if not ("player" in unit) or unit.player != human:
			continue
		var footprint = unit.get_node_or_null("TeamFootprint")
		if unit.has_node("Movement"):
			mobile += 1
			_check(footprint != null, "%s has no team footprint" % unit.type)
			if footprint != null:
				_check(
					footprint.material_override.get_shader_parameter("color") == human.color,
					"Footprint ignores the team color"
				)
		else:
			_check(footprint == null, "Structure %s received a footprint" % unit.type)
	_check(mobile > 0, "No mobile units to inspect")
	var tank = _units(human, "Tank")[0]
	var bar = tank.get_node("HealthBar")
	tank.hp = int(tank.hp_max * .25)
	# The bar's own image is inspected; headless textures have no GPU readback.
	var image = bar._image
	var middle = image.get_height() / 2
	_check(_near(image.get_pixel(bar.FRAME + 1, middle), bar.CRITICAL), "Critical health color")
	_check(
		_near(image.get_pixel(image.get_width() - bar.FRAME - 1, middle), bar.MISSING),
		"Missing health is not drawn"
	)
	_check(_near(image.get_pixel(0, 0), bar.BACKING), "Health bar has no contrast frame")
	tank.hp = tank.hp_max
	_check(_near(bar._image.get_pixel(bar.FRAME + 1, middle), bar.HEALTHY), "Healthy color")


func _check_command_card():
	var human = game._get_human_player()
	var card = load("res://source/match/hud/CommandCard.gd").new()
	root.add_child(card)
	card.update_layout([_units(human, "Tank")[0]], null)
	_check(card._slots[0].all(func(slot): return slot.visible), "Assigned command row hidden")
	_check(card._slots[2].all(func(slot): return not slot.visible), "Empty command row shown")
	card.queue_free()


func _near(a, b):
	# Bar pixels are stored with 8-bit channels.
	return maxf(maxf(absf(a.r - b.r), absf(a.g - b.g)), absf(a.b - b.b)) < .01
