extends "res://tests/headless/PreparationRegression.gd"


func _run():
	shooting = load("res://source/match/units/actions/AttackingWhileInRange.gd")
	moving = load("res://source/match/units/actions/Moving.gd")
	rules = load("res://source/match/combat/CombatRules.gd")
	await _setup("bastion")
	_check(await _anchor() == true, "Anchor suite did not finish")
	await _clean_match()
	await _setup("helix")
	_check(await _precision() == true, "Precision suite did not finish")
	await _clean_match()
	await _setup("bastion")
	_check(await _opponent_ability() == true, "Opponent ability suite did not finish")
	await _clean_match()
	print("Faction signatures: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _anchor():
	var sides = _sides()
	var human = sides[0]
	var members = []
	for index in 8:
		members.append(
			_spawn_weapon(
				"CombatRobot", human, Vector3(40 - (index % 4) * 2.2, 0, 10 + (index / 4) * 2.4)
			)
		)
	var source = _spawn_weapon("Tank", sides[1], Vector3(54, 0, 10))
	var support = _spawn_weapon("RepairRobot", human, Vector3(40, 0, 16))
	await _frames(40)
	_check(human.signatures.activate(members, Vector3(37, 0, 11)) == 0, "Anchor bypasses research")
	human.coordination_unlocked = true
	_check(
		human.signatures.activate([support, source], Vector3(37, 0, 11)) == 0,
		"Anchor accepts support/enemy units"
	)
	for unit in members:
		unit.process_mode = Node.PROCESS_MODE_PAUSABLE
	var orders = members.map(func(unit): return unit.action)
	_check(human.signatures.activate(members, Vector3(37, 0, 11)) == 6, "Anchor did not cap at six")
	for index in members.size():
		_check(members[index].action == orders[index], "Anchor replaced an order")
	var active = members.filter(func(unit): return unit.signature.kind == "anchor")
	await _frames(60)
	_check(
		active.all(func(unit): return not unit.signature.anchored),
		"Anchor activates before two seconds"
	)
	_check(await _archive_ability(active[0]) == true, "Anchor archive suite failed")
	human = game._get_human_player()
	active = _units(human, "CombatRobot").filter(func(unit): return unit.signature.kind == "anchor")
	source = _units(_sides()[1], "Tank").filter(func(unit): return unit.position.z < 15)[0]
	game.hud._toggle_pause()
	await _frames(70)
	_check(active.all(func(unit): return unit.signature.anchored), "Anchor could not settle")
	var unit = active[0]
	var damage = float(source.attack_damage)
	# Autocannon/light-machine armor makes the tank cannon multiplier exactly one.
	var hp = unit.hp
	unit.receive_weapon_hit(source)
	_check(
		is_equal_approx(hp - unit.hp, damage * 0.85), "Anchor did not reduce weapon damage by 15%"
	)
	source.global_position.x = 20
	hp = unit.hp
	unit.receive_weapon_hit(source)
	_check(is_equal_approx(hp - unit.hp, damage * 0.85), "Anchor fails against rear damage")
	unit.hp = unit.hp_max
	_check(
		human.signatures.activate([unit], unit.global_position_yless) == 0,
		"Anchored unit reactivated during its window"
	)
	unit.issue_manual_order(moving.new(unit.global_position_yless + Vector3(5, 0, 0)))
	_check(
		is_equal_approx(rules.damage(source, unit), damage),
		"Move order retained anchored protection"
	)
	_check(unit.signature.kind == "", "Movement did not break Anchor")
	await _frames(650)
	_check(not unit.signature.anchored, "Anchor reactivated automatically after movement")
	_check(
		human.signatures.activate([unit], unit.global_position_yless) == 1,
		"Anchor cannot reactivate after cooldown"
	)
	active[1].hp = 0
	await _frames(3)
	paused = true
	var saved = Snapshot.new().capture(game)
	_check(saved != null and Restore.new().prepare(saved), "Death left stale activation references")
	_check(
		not Restore.new().prepare(_legacy_snapshot(saved, 3)),
		"Retired version-three archive was accepted"
	)
	print(
		(
			"PASS: six-unit Anchor, research/eligibility, all-direction damage, "
			+ "manual movement, cooldown, archives/death"
		)
	)
	return true


func _archive_ability(unit):
	paused = true
	var before = unit.signature.capture()
	var builder = Snapshot.new()
	var snapshot = builder.capture(game)
	_check(snapshot != null, "Ability snapshot failed: " + builder.error)
	if snapshot == null:
		return false
	var id = builder._reference(unit)
	var invalid = snapshot.duplicate(true)
	invalid.players[0].signatures.groups[0].left = 11
	_check(not Restore.new().prepare(invalid), "Oversized group cooldown accepted")
	invalid = snapshot.duplicate(true)
	invalid.units.filter(func(entry): return entry.id == id)[0].signature.group_id = 999
	_check(not Restore.new().prepare(invalid), "Missing activation group accepted")
	invalid = snapshot.duplicate(true)
	invalid.players[0].signatures.groups[0].members.append(
		invalid.players[0].signatures.groups[0].members[0]
	)
	_check(not Restore.new().prepare(invalid), "Duplicate activation member accepted")
	var file = FileStore.new()
	var archive = "user://signature-%d.json" % OS.get_process_id()
	_check(file.write_file(archive, snapshot), "Ability archive write failed")
	var reader = Restore.new()
	var restored = await reader.restore(self, file.read_file(archive))
	DirAccess.remove_absolute(archive)
	_check(restored.ok, "Ability archive failed: " + restored.get("error", ""))
	if not restored.ok:
		return false
	game = restored.game
	var enemy = _sides()[1]
	enemy.set_process(false)
	for other in enemy.get_children():
		if "hp" in other:
			other.process_mode = Node.PROCESS_MODE_DISABLED
	unit = reader.entities[id]
	await _frames(30)
	_check(unit.signature.capture() == before, "Loaded paused ability changed its exact state")
	_check(
		(
			game._get_human_player().signatures.groups[0].left
			== snapshot.players[0].signatures.groups[0].left
		),
		"Group cooldown changed while paused"
	)
	return true


func _precision():
	var sides = _sides()
	var human = sides[0]
	human.coordination_unlocked = true
	var lancer = _spawn_weapon("CombatRobot", human, Vector3(40, 0, 10))
	var target = _spawn_weapon("Tank", sides[1], Vector3(46, 0, 10))
	await _frames(40)
	lancer.process_mode = Node.PROCESS_MODE_PAUSABLE
	lancer.issue_manual_order(shooting.new(target))
	await _frames(15)
	var shot = lancer.action
	var left = shot._charge_left
	var interval = lancer.attack_interval
	_check(human.signatures.activate([lancer]) == 1, "Precision rejected a legal charging shot")
	_check(lancer.action == shot, "Precision replaced the attack")
	_check(
		(
			is_equal_approx(shot._charge_total, 0.6)
			and is_equal_approx(shot._charge_left, left - 0.15)
		),
		"Precision did not shorten preparation by 20%"
	)
	_check(not lancer.signature.precision_ready, "Applied Precision remains reusable")
	_check(await _archive_ability(lancer) == true, "Precision archive suite failed")
	human = game._get_human_player()
	lancer = _units(human, "CombatRobot")[0]
	target = _units(_sides()[1], "Tank").filter(func(unit): return unit.position.z < 15)[0]
	_check(
		is_equal_approx(lancer.action._charge_total, 0.6), "Archive lost accelerated preparation"
	)
	game.hud._toggle_pause()
	await _frames(13)
	_check(target.hp == target.hp_max, "Precision fired before reduced preparation finished")
	await _frames(25)
	_check(
		is_equal_approx(target.hp_max - target.hp, 30.0),
		"Precision changed damage or failed to fire"
	)
	_check(lancer.attack_interval == interval, "Precision changed reload speed")
	await _frames(75)
	_check(
		is_equal_approx(lancer.action._charge_total, 0.75),
		"Precision accelerated more than one preparation"
	)
	_check(human.signatures.activate([lancer]) == 0, "Precision cooldown bypassed")
	# A separate eligible unit can activate, but a cancelled shot never refunds its use.
	var other = _spawn_weapon("CombatRobot", human, Vector3(42, 0, 13))
	await _frames(5)
	other.process_mode = Node.PROCESS_MODE_PAUSABLE
	other.issue_manual_order(shooting.new(target))
	await _frames(5)
	_check(human.signatures.activate([other]) == 1, "Disjoint activation group was blocked")
	other.issue_manual_order(moving.new(Vector3(37, 0, 13)))
	_check(not other.signature.precision_ready, "Cancelled accelerated shot refunded Precision")
	var hidden = _spawn_weapon("CombatRobot", human, Vector3(10, 0, 50))
	await _frames(5)
	_check(
		human.signatures.activate([hidden]) == 0,
		"Precision activates without a visible legal target"
	)
	await _frames(130)
	_check(
		other.signature.kind == "" and other.signature.cooldown > 0, "Window expiry lost cooldown"
	)
	print(
		(
			"PASS: one-use Precision, exact charge archive, unchanged damage/reload, "
			+ "cancellation/visibility/cooldowns"
		)
	)
	return true


func _opponent_ability():
	var sides = _sides()
	var ai = sides[1]
	ai.coordination_unlocked = true
	var unit = _spawn_weapon("CombatRobot", ai, Vector3(40, 0, 10))
	_spawn_weapon("Tank", sides[0], Vector3(45, 0, 10))
	await _frames(40)
	ai._use_signatures([unit])
	_check(unit.signature.kind == "precision", "Opponent commander cannot activate its signature")
	return true
