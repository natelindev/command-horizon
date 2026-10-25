extends "res://tests/headless/PreparationRegression.gd"


func _run():
	shooting = load("res://source/match/units/actions/AttackingWhileInRange.gd")
	moving = load("res://source/match/units/actions/Moving.gd")
	var options = root.get_node("Globals").options
	var original = options.capture()
	options.restore({"screen": 1, "effects_volume": 0.75, "master_volume": 1.0})
	await _setup("bastion")
	await _presentation_contracts()
	await _attack_lifecycle()
	await _voice_limits()
	await _clean_match()
	await _setup("helix")
	await _lock_and_mode_switch()
	await _clean_match()
	options.restore(original)
	print("Charge presentation regression: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _voices(unit):
	return game.combat_audio._players.filter(
		func(entry):
			return entry.active and entry.kind == "weapon_charge" and entry.unit.get_ref() == unit
	)


func _presentation_contracts():
	var unit = _spawn_weapon("AdvancedTank", _sides()[0], Vector3(40, 0, 10))
	var rocket = _spawn_weapon("RocketInfantry", _sides()[0], Vector3(41, 0, 10))
	await _frames(5)
	var display = unit.get_node("WeaponPreparationVisual")
	var lock_display = rocket.get_node("WeaponPreparationVisual")
	var options = root.get_node("Globals").options
	options.reduced_flashes = false
	unit.weapon_charge_progress = 0.4
	display.refresh()
	_check(
		display._orb.visible and display._sparks.visible, "Charge has no focus/converging sparks"
	)
	_check(display._orb.mesh is QuadMesh, "Charge still uses an expanding sphere")
	var scale = display._orb.scale
	display._process(0.05)
	await _frames(2)
	var before = display._sparks.multimesh.get_instance_transform(0).origin.length()
	display._process(0.05)
	await _frames(2)
	var after = display._sparks.multimesh.get_instance_transform(0).origin.length()
	# Dummy rendering does not retain MultiMesh transforms; exercise direction
	# against the real renderer when this suite runs without --headless.
	if DisplayServer.get_name() != "headless":
		_check(
			after < before, "Energy sparks move away from the muzzle: %f -> %f" % [before, after]
		)
	unit.weapon_charge_progress = 0.95
	display.refresh()
	_check(display._orb.scale == scale, "Charge focus inflates with progress")
	_check(
		display._orb.global_position.distance_to(display._marker.global_position) > 0.001,
		"Late charge has no focus vibration"
	)
	options.reduced_flashes = true
	display.refresh()
	_check(not display._sparks.visible, "Reduced flashes retains charge sparks")
	_check(
		display._orb.global_position.is_equal_approx(display._marker.global_position),
		"Reduced flashes retains charge vibration"
	)
	rocket.weapon_charge_progress = 0.7
	lock_display.refresh()
	_check(lock_display._lock and lock_display._orb.visible, "Rocket has no lock telegraph")
	_check(lock_display._sparks == null, "Rocket lock uses heavy-weapon energy sparks")
	game.get_node("Debug/DiagnosticHUD").show()
	rocket.get_node("Selection").select()
	lock_display.refresh()
	_check(display._label.text.begins_with("CHARGE"), "Charge diagnostics lost their contract")
	_check(lock_display._label.text.begins_with("LOCK"), "Lock diagnostics lost their contract")
	game.get_node("Debug/DiagnosticHUD").hide()
	unit.weapon_charge_progress = -1
	display.refresh()
	_check(not display._orb.visible and not display._sparks.visible, "Cancel leaves charge visuals")
	_check(not display.is_processing(), "Idle preparation still animates")
	options.reduced_flashes = false
	unit.queue_free()
	rocket.queue_free()
	await _frames(3)
	print("PASS compact core, inward sparks, late vibration, reduced flashes and tactical lock")


func _attack_lifecycle():
	var sides = _sides()
	var unit = _spawn_weapon("AdvancedTank", sides[0], Vector3(40, 0, 10))
	var target = _spawn_weapon("Tank", sides[1], Vector3(46, 0, 10))
	var camera = game.get_node("IsometricCamera3D")
	camera.set_position_safely(Vector3(42, 0, 10))
	camera.set_size_safely(24)
	await _frames(40)
	unit.process_mode = Node.PROCESS_MODE_PAUSABLE
	unit.issue_manual_order(shooting.new(target, 1))
	_check(_voices(unit).size() == 1, "Attack starts without a synchronized charge voice")
	if _voices(unit).is_empty():
		return
	var voice = _voices(unit)[0]
	var player = voice.node
	_check(is_equal_approx(player.pitch_scale, 0.75), "Capacitor does not begin at pitch 0.75")
	_check(player.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "Capacitor is not sustained")
	await _frames(25)
	_check(
		_voices(unit).size() == 1 and voice.node == player, "Charge restarts/duplicates its loop"
	)
	_check(player.pitch_scale > 1.0, "Charge audio pitch does not rise")
	paused = true
	await _frames(3)
	var pitch = player.pitch_scale
	await _frames(5)
	_check(player.stream_paused and player.pitch_scale == pitch, "Pause advances capacitor audio")
	unit.issue_manual_order(null)
	await _frames(2)
	_check(_voices(unit).is_empty() and not player.playing, "Paused Stop leaves charge audio")
	_check(not unit.get_node("WeaponPreparationVisual")._orb.visible, "Paused Stop leaves focus")
	paused = false
	unit.issue_manual_order(shooting.new(target, 1))
	await _frames(10)
	unit.issue_manual_order(moving.new(Vector3(37, 0, 10)))
	await _frames(3)
	_check(_voices(unit).is_empty(), "Movement retains charge audio")
	unit.issue_manual_order(null)
	unit.get_node("Movement").stop()
	unit.global_position = Vector3(40, 0, 10)
	unit.issue_manual_order(shooting.new(target, 1))
	await _frames(8)
	target.queue_free()
	await _frames(3)
	_check(_voices(unit).is_empty(), "Lost target retains charge audio")
	target = _spawn_weapon("Tank", sides[1], Vector3(46, 0, 10))
	await _frames(5)
	var hp = target.hp
	unit.issue_manual_order(shooting.new(target, 1))
	await _frames(55)
	_check(target.hp < hp and _voices(unit).is_empty(), "Firing retains the capacitor loop")
	_check(not unit.get_node("WeaponPreparationVisual")._orb.visible, "Firing retains focus")
	unit.process_mode = Node.PROCESS_MODE_DISABLED
	unit.weapon_charge_progress = 1.0
	game.combat_audio.update_charge(unit)
	_check(_voices(unit).size() == 1, "Charge cannot restart on a reused voice")
	if not _voices(unit).is_empty():
		_check(
			is_equal_approx(_voices(unit)[0].node.pitch_scale, 1.6), "Full charge pitch is not 1.6"
		)
	camera.set_position_safely(Vector3(100, 0, 100))
	await _frames(2)
	_check(_voices(unit).is_empty(), "Offscreen charge remains audible")
	camera.set_position_safely(Vector3(42, 0, 10))
	game.combat_audio.update_charge(unit)
	var options = root.get_node("Globals").options
	options.effects_volume = 0.0
	options.apply()
	_check(_voices(unit).is_empty(), "Effects mute retains capacitor audio")
	options.effects_volume = 0.75
	options.apply()
	game.restoring = true
	game.combat_audio.update_charge(unit)
	_check(_voices(unit).is_empty(), "Restoration emits charge audio")
	game.restoring = false
	game.combat_audio.update_charge(unit)
	game.finished = true
	await _frames(2)
	_check(_voices(unit).is_empty(), "Battle end leaves a sustained charge")
	game.finished = false
	game.combat_audio.update_charge(unit)
	unit.queue_free()
	target.queue_free()
	await _frames(3)
	_check(
		game.combat_audio._players.all(
			func(entry): return not entry.active or entry.kind != "weapon_charge"
		),
		"Deleting a charging unit retains its voice"
	)
	print(
		"PASS actual charge pitch, reuse, pause/Stop, move, target loss, shot, mute and end gates"
	)


func _voice_limits():
	var audio = game.combat_audio
	var camera = game.get_node("IsometricCamera3D")
	camera.set_position_safely(Vector3(42, 0, 10))
	game.settings.visibility = game.settings.Visibility.FULL
	var units = []
	for index in range(audio.MAX_PLAYERS + 4):
		units.append(_spawn_weapon("AdvancedTank", _sides()[0], Vector3(40, 0, 10)))
	await _frames(5)
	for unit in units:
		unit.global_position = Vector3(40, 0, 10)
		unit.weapon_charge_progress = 0.5
		audio.update_charge(unit)
	_check(audio._players.size() == audio.MAX_PLAYERS, "Capacitors exceeded the shared voice cap")
	var first = _voices(units[0])
	_check(not first.is_empty(), "Charge saturation stole an existing capacitor voice")
	_check(audio.shot(units[0], units[0].global_position), "Charge loops starve weapon reports")
	_check(audio._players.size() == audio.MAX_PLAYERS, "Report bypassed bounded pool")
	for unit in units:
		unit.queue_free()
	await _frames(3)
	print("PASS bounded capacitor voices and weapon-report priority")


func _lock_and_mode_switch():
	var sides = _sides()
	var lancer = _spawn_weapon("CombatRobot", sides[0], Vector3(40, 0, 10))
	var target = _spawn_weapon("Tank", sides[1], Vector3(45, 0, 10))
	var rocket = _spawn_weapon("RocketInfantry", sides[0], Vector3(40, 0, 14))
	var air = _spawn_weapon("Drone", sides[1], Vector3(44, 0, 14))
	var camera = game.get_node("IsometricCamera3D")
	camera.set_position_safely(Vector3(42, 0, 12))
	camera.set_size_safely(24)
	await _frames(40)
	for unit in [lancer, rocket]:
		unit.process_mode = Node.PROCESS_MODE_PAUSABLE
	lancer.issue_manual_order(shooting.new(target, 1))
	rocket.issue_manual_order(shooting.new(air, 1))
	await _frames(10)
	_check(_voices(lancer).size() == 1, "Precision Lancer lacks charge audio")
	_check(_voices(rocket).size() == 1, "Rocket lock lacks preparation audio")
	var lock_display = rocket.get_node("WeaponPreparationVisual")
	_check(lock_display._lock and lock_display._orb.visible, "Actual SAM lock lacks reticle")
	paused = true
	_check(lancer.request_weapon_mode("interception"), "Lancer mode switch was rejected")
	await _frames(2)
	_check(_voices(lancer).is_empty(), "Paused mode switch leaves Precision audio")
	_check(not lancer.get_node("WeaponPreparationVisual")._orb.visible, "Mode switch leaves focus")
	rocket.issue_manual_order(null)
	await _frames(2)
	_check(_voices(rocket).is_empty() and not lock_display._orb.visible, "Stop leaves SAM lock")
	print("PASS actual SAM lock and paused Lancer mode-switch audio cancellation")
