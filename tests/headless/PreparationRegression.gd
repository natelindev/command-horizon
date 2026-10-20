extends "res://tests/headless/WeaponModeRegression.gd"


func _run():
	shooting = load("res://source/match/units/actions/AttackingWhileInRange.gd")
	moving = load("res://source/match/units/actions/Moving.gd")
	await _setup("bastion")
	_check(await _rail() == true, "Rail suite did not finish")
	await _clean_match()
	await _setup("helix")
	_check(await _prism() == true, "Prism suite did not finish")
	await _clean_match()
	await _setup("helix")
	_check(await _lancer() == true, "Lancer preparation suite did not finish")
	await _clean_match()
	print("Weapon preparation: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _rail():
	var sides = _sides()
	var rail = _spawn_weapon("AdvancedTank", sides[0], Vector3(40, 0, 10))
	var target = _spawn_weapon("Tank", sides[1], Vector3(46, 0, 10))
	await _frames(40)
	rail.process_mode = Node.PROCESS_MODE_PAUSABLE
	rail.issue_manual_order(shooting.new(target))
	await _frames(30)
	_check(target.hp == target.hp_max, "Rail fired before preparation completed")
	_check(rail.weapon_charge_progress > 0.5, "Rail has no visible charging state")
	var left = rail.action._charge_left
	paused = true
	await _frames(40)
	_check(rail.action._charge_left == left, "Preparation advances while paused")
	paused = false
	await _frames(20)
	_check(is_equal_approx(target.hp_max - target.hp, 25.2), "Rail charge did not resolve one hit")
	await _frames(90)
	_check(rail.weapon_charge_progress < 0, "Rail charges before its reload ends")
	await _frames(35)
	_check(rail.weapon_charge_progress >= 0, "Rail did not charge after reloading")
	var hp = target.hp
	rail.issue_manual_order(moving.new(Vector3(37, 0, 10)))
	await _frames(50)
	_check(target.hp == hp and rail.weapon_charge_progress < 0, "Move retained a charged attack")
	# Retargeting starts a full preparation; it cannot transfer an almost-ready shot.
	rail.issue_manual_order(null)
	rail.get_node("Movement").stop()
	rail.global_position = Vector3(40, 0, 10)
	rail.set_meta("next_attack_availability_time", 0)
	var other = _spawn_weapon("Tank", sides[1], Vector3(46, 0, 12))
	await _frames(5)
	rail.issue_manual_order(shooting.new(target))
	await _frames(25)
	rail.issue_manual_order(shooting.new(other))
	await _frames(30)
	_check(other.hp == other.hp_max and target.hp == hp, "Retarget transferred a charge")
	await _frames(20)
	_check(other.hp < other.hp_max, "Retarget could not finish fresh preparation")
	# Losing direct line of sight during the warning cancels damage.
	rail.set_meta("next_attack_availability_time", 0)
	rail.issue_manual_order(shooting.new(target))
	await _frames(15)
	var blocker = _spawn_weapon("Barracks", sides[0], Vector3(43, 0, 10))
	# The North Refinery site at (43, 11) cuts the navigation mesh, so spawn alignment
	# slides the structure off the firing lane; pin it back onto the lane.
	blocker.global_position = Vector3(43, 0, 10)
	blocker.construct(1)
	game.battlefield.invalidate()
	await _frames(50)
	_check(target.hp == hp, "Preparation fired through a newly completed blocker")
	_check(rail.weapon_charge_progress < 0, "Blocked shot retained its charge visual")
	print("PASS: rail preparation, reload, pause, movement, retarget and lost firing lane")
	return true


func _prism():
	var sides = _sides()
	var prism = _spawn_weapon("AdvancedTank", sides[0], Vector3(40, 0, 10))
	var target = _spawn_weapon("Tank", sides[1], Vector3(48, 0, 10))
	await _frames(40)
	_check(prism.attack_range == 14, "Prism lost its range advantage")
	prism.process_mode = Node.PROCESS_MODE_PAUSABLE
	prism.issue_manual_order(shooting.new(target))
	await _frames(35)
	_check(prism.deployment_left > 0.8, "Prism skipped initial deployment")
	_check(
		prism.weapon_charge_progress < 0 and target.hp == target.hp_max,
		"Prism fired while deploying"
	)
	_check(await _reload_preparation(prism, target) == true, "Deployment restoration failed")
	prism = _units(game._get_human_player(), "AdvancedTank")[0]
	target = _units(_sides()[1], "Tank").filter(func(unit): return unit.position.z < 15)[0]
	game.hud._toggle_pause()
	await _frames(76)
	_check(
		prism.deployment_left == 0 and prism.weapon_charge_progress > 0,
		"Prism did not charge after setup"
	)
	_check(target.hp == target.hp_max, "Prism skipped charge after setup")
	_check(await _reload_preparation(prism, target) == true, "Charge restoration failed")
	prism = _units(game._get_human_player(), "AdvancedTank")[0]
	target = _units(_sides()[1], "Tank").filter(func(unit): return unit.position.z < 15)[0]
	game.hud._toggle_pause()
	await _frames(35)
	_check(
		is_equal_approx(target.hp_max - target.hp, 25.2),
		"Restored Prism charge did not hit exactly once"
	)
	var hp = target.hp
	prism.issue_manual_order(moving.new(Vector3(37, 0, 10)))
	await _frames(10)
	_check(prism.deployment_left > 1.45, "Movement did not retract Prism deployment")
	_check(prism.weapon_charge_progress < 0 and target.hp == hp, "Moving Prism retained a shot")
	await _frames(100)
	prism.issue_manual_order(null)
	prism.get_node("Movement").stop()
	await _frames(100)
	_check(prism.deployment_left == 0, "Stationary Prism did not redeploy")
	# Passive displacement also breaks a deployed position.
	prism.global_position.x += 0.15
	await _frames(2)
	_check(prism.deployment_left > 1.4, "Displacement retained deployed state")
	paused = true
	var legacy = _legacy_snapshot(Snapshot.new().capture(game), 2)
	var restored = await Restore.new().restore(self, legacy)
	_check(restored.ok, "Version-two Prism archive failed reconstruction")
	if not restored.ok:
		return false
	game = restored.game
	prism = _units(game._get_human_player(), "AdvancedTank")[0]
	_check(prism.deployment_left == 1.5, "Legacy Prism bypassed fresh deployment")
	game.hud._toggle_pause()
	await _frames(60)
	_check(prism.deployment_left > 0.4, "Legacy Prism setup completed too early")
	await _frames(40)
	_check(prism.deployment_left == 0, "Legacy Prism could not deploy after resume")
	print("PASS: Prism setup/charge, movement/displacement, exact disk restoration and resume")
	return true


func _reload_preparation(unit, target):
	paused = true
	var snapshot = Snapshot.new().capture(game)
	_check(snapshot != null, "Preparation capture failed")
	if snapshot == null:
		return false
	var saved = snapshot.units.filter(func(entry): return entry.role == "AdvancedTank")[0]
	var setup_left = unit.deployment_left
	var charge_left = unit.action._charge_left
	var hp = target.hp
	var invalid = snapshot.duplicate(true)
	invalid.units.filter(func(entry): return entry.id == saved.id)[0].deployment.deployment_left = 2
	_check(not Restore.new().prepare(invalid), "Oversized deployment accepted")
	invalid = snapshot.duplicate(true)
	var bad_action = invalid.units.filter(func(entry): return entry.id == saved.id)[0].action
	bad_action.state._charge_left = 1
	bad_action.state._charge_total = 1
	_check(not Restore.new().prepare(invalid), "Oversized preparation accepted")
	for version in [1, 2]:
		_check(
			Restore.new().prepare(_legacy_snapshot(snapshot, version)),
			"Legacy preparation archive rejected"
		)
	var file = FileStore.new()
	var archive = "user://preparation-%d.json" % OS.get_process_id()
	_check(file.write_file(archive, snapshot), "Preparation archive write failed")
	var restored = await Restore.new().restore(self, file.read_file(archive))
	DirAccess.remove_absolute(archive)
	_check(restored.ok, "Preparation restore failed: " + restored.get("error", ""))
	if not restored.ok:
		return false
	game = restored.game
	unit = _units(game._get_human_player(), "AdvancedTank")[0]
	var enemy = _sides()[1]
	enemy.set_process(false)
	for other in enemy.get_children():
		if "hp" in other:
			other.process_mode = Node.PROCESS_MODE_DISABLED
	target = _units(enemy, "Tank").filter(func(other): return other.position.z < 15)[0]
	await _frames(30)
	_check(unit.deployment_left == setup_left, "Loaded setup duration changed while paused")
	_check(unit.action._charge_left == charge_left, "Loaded charge duration changed while paused")
	if charge_left < 0:
		_check(
			unit.get_node("WeaponPreparationVisual")._label.text == "DEPLOY %.1f" % setup_left,
			"Paused deployment display lost the restored duration"
		)
	_check(target.hp == hp, "Loading dealt weapon damage")
	return true


func _lancer():
	var sides = _sides()
	var lancer = _spawn_weapon("CombatRobot", sides[0], Vector3(40, 0, 10))
	var target = _spawn_weapon("Tank", sides[1], Vector3(45, 0, 10))
	await _frames(40)
	lancer.process_mode = Node.PROCESS_MODE_PAUSABLE
	lancer.issue_manual_order(shooting.new(target))
	await _frames(25)
	_check(
		lancer.weapon_charge_progress > 0 and target.hp == target.hp_max,
		"Precision Lancer has no wind-up"
	)
	paused = true
	lancer.request_weapon_mode("interception")
	_check(lancer.weapon_charge_progress < 0, "Paused mode switch retains the charge warning")
	await _frames(10)
	_check(lancer.weapon_switch_left == 2, "Paused cancellation advanced the mode switch")
	paused = false
	await _frames(125)
	_check(target.hp == target.hp_max, "Mode switch let an old Precision charge fire")
	_check(lancer.weapon_charge_progress < 0, "Interception retained Precision charge")
	var air = _spawn_weapon("Drone", sides[1], Vector3(44, 0, 10))
	await _frames(5)
	lancer.issue_manual_order(shooting.new(air, 1))
	await _frames(15)
	_check(air.hp < air.hp_max, "Interception incorrectly gained precision preparation")
	print("PASS: Lancer Precision charge, mode-switch cancellation and immediate Interception")
	return true
