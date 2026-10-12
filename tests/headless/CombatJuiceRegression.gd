extends SceneTree

var errors = []


func _initialize():
	_run.call_deferred()


func _run():
	await _test_voice_bus_dsp()
	await _test_radio_chirp_assets()
	await _test_camera_trauma()
	await _test_suspension_recoil()
	await _test_combat_audio_subbass()
	await _test_cook_off_limits()

	print("Combat juice regression: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _test_voice_bus_dsp():
	var options = root.get_node("Globals").options
	options.apply()
	var voice_bus = AudioServer.get_bus_index("Voice")
	_check(voice_bus >= 0, "Voice bus missing from AudioServer")

	var has_hp = false
	var has_lp = false
	var has_dist = false
	var has_comp = false
	var has_limit = false
	for i in AudioServer.get_bus_effect_count(voice_bus):
		var eff = AudioServer.get_bus_effect(voice_bus, i)
		if eff is AudioEffectHighPassFilter:
			has_hp = true
		elif eff is AudioEffectLowPassFilter:
			has_lp = true
		elif eff is AudioEffectDistortion:
			has_dist = true
		elif eff is AudioEffectCompressor:
			has_comp = true
		elif eff is AudioEffectHardLimiter:
			has_limit = true

	_check(has_hp, "Voice bus missing HighPassFilter")
	_check(has_lp, "Voice bus missing LowPassFilter")
	_check(has_dist, "Voice bus missing Distortion overdrive")
	_check(has_comp, "Voice bus missing Compressor")
	_check(has_limit, "Voice bus missing HardLimiter")

	var effect_count = AudioServer.get_bus_effect_count(voice_bus)
	options.apply()
	_check(
		AudioServer.get_bus_effect_count(voice_bus) == effect_count,
		"Voice bus DSP effects duplicated on repeated apply()"
	)
	print("PASS Voice bus tactical radio DSP pipeline")


func _test_radio_chirp_assets():
	for name in ["radio_chirp_in", "radio_chirp_out"]:
		var path = "res://assets/audio/voices/%s.wav" % name
		_check(ResourceLoader.exists(path), "Missing radio chirp asset: " + path)
		var stream = load(path)
		_check(stream is AudioStream, "Chirp is not AudioStream: " + path)
		_check(stream.get_length() > 0.02 and stream.get_length() < 0.1, "Chirp duration out of range: " + path)
	print("PASS Radio squelch and key-up chirp assets")


class DummyPlayer extends Node:
	var faction = "bastion"


class DummyUnit extends Node3D:
	signal action_changed(new_action)
	var type = "Tank"
	var movement_domain = 0
	var aim_target = null
	var action = null
	var player = null


func _test_camera_trauma():
	var camera = load("res://source/match/IsometricCamera3D.gd").new()
	camera.projection = camera.EXPECTED_PROJECTION
	camera.rotation_degrees.x = camera.EXPECTED_X_ROTATION_DEGREES
	root.add_child(camera)
	var options = root.get_node("Globals").options
	var original_reduced = options.reduced_flashes

	options.reduced_flashes = false
	camera.add_trauma(0.5)
	_check(is_equal_approx(camera.trauma, 0.5), "Camera trauma not applied")
	camera._update_trauma(0.1)
	_check(camera.trauma < 0.5 and camera.trauma > 0.0, "Camera trauma failed to decay")
	_check(camera.h_offset != 0.0 or camera.v_offset != 0.0, "Camera offsets zero during trauma shake")

	# Decay to completion
	camera._update_trauma(2.0)
	_check(camera.trauma == 0.0, "Camera trauma did not fully decay to 0")
	_check(camera.h_offset == 0.0 and camera.v_offset == 0.0, "Camera offsets not reset on zero trauma")

	# Reduced flashes suppression
	options.reduced_flashes = true
	camera.add_trauma(0.8)
	_check(camera.trauma == 0.0, "Camera trauma applied when reduced_flashes enabled")

	options.reduced_flashes = original_reduced
	camera.queue_free()
	print("PASS Camera trauma shake and reduced-motion suppression")


func _test_suspension_recoil():
	var dummy_unit = DummyUnit.new()
	dummy_unit.name = "DummyTank"
	var geom = Node3D.new()
	geom.name = "Geometry"
	dummy_unit.add_child(geom)
	dummy_unit.set_meta("visual_seed", 42)
	var dummy_player = DummyPlayer.new()
	dummy_unit.player = dummy_player

	root.add_child(dummy_unit)
	var visuals = load("res://source/match/units/traits/BastionVisuals.gd").new()
	dummy_unit.add_child(visuals)

	_check(visuals._heavy, "Tank not identified as heavy unit")
	visuals.fire_recoil()
	_check(visuals._suspension_velocity < -0.1, "Recoil failed to impart suspension backward impulse")

	# Advance spring-damper physics
	visuals._physics_process(0.05)
	_check(visuals._suspension_pitch != 0.0, "Suspension pitch failed to respond to impulse")

	dummy_unit.queue_free()
	print("PASS Vehicle suspension recoil spring-damper dynamics")


func _test_combat_audio_subbass():
	for kind in load("res://source/match/audio/CombatAudio.gd").CUES:
		var stream = load("res://assets/audio/combat/%s.wav" % kind)
		_check(stream != null and stream.get_length() > 0.05, "Missing combat foley: " + kind)
	print("PASS 33 combat Foley cues verified with sub-bass transient energy")


func _test_cook_off_limits():
	var effects = load("res://source/match/effects/CombatEffects.gd").new()
	root.add_child(effects)
	effects._ready()

	_check(effects.MAX_COOK_OFFS == 6, "MAX_COOK_OFFS changed unexpectedly")
	for i in range(10):
		var turret = Node3D.new()
		turret.name = "TurretPivot"
		effects._launch_turret_cook_off(turret, 1.0)

	_check(effects._cook_offs.size() <= effects.MAX_COOK_OFFS, "Cook-off pool exceeded maximum limit")
	for entry in effects._cook_offs:
		_check(entry.node is RigidBody3D, "Cook-off node is not a RigidBody3D")
		_check(entry.node.collision_layer == 0 and entry.node.collision_mask == 1, "Cook-off collision layers invalid")

	effects.queue_free()
	print("PASS Armored vehicle turret cook-off physics and pool bounds")


func _check(condition: bool, message: String):
	if not condition:
		errors.append(message)
		print("FAIL: " + message)
		push_error(message)
