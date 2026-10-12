extends "res://tests/headless/MechanicsRegression.gd"


func _run():
	waiting = load("res://source/match/units/actions/WaitingForTargets.gd")
	attack_move = load("res://source/match/units/actions/AttackMoving.gd")
	auto_attack = load("res://source/match/units/actions/AutoAttacking.gd")
	root.get_node("SaveManager").autosaves_enabled = false
	for faction in ["bastion", "helix", "frontier"]:
		await _open(faction)
		await _automatic_counters()
		await _clear()
		await _stance_authority()
		await _clear()
		_game.queue_free()
		await _frames(5)
	for message in _errors:
		push_error(message)
	print("Main merge integration: %d failures" % _errors.size())
	quit(0 if _errors.is_empty() else 1)


func _stance_authority():
	var soldier = _spawn("RocketInfantry", _human, Vector3(35, 0, 35))
	var enemy = _spawn("Tank", _enemy, Vector3(39, 0, 35))
	await _frames(5)
	_game.battlefield.invalidate()
	_check(_game.battlefield.can_fire(soldier, enemy), "Stance fixture cannot fire")
	var defense_script = load("res://source/match/combat/AlliedDefense.gd")
	var defenders = _game.get_children().filter(
		func(node): return node.get_script() == defense_script
	)
	var defense = defenders[0]
	soldier.stance = soldier.Stance.HOLD_FIRE
	soldier.action = waiting.new()
	soldier.action._on_timer_timeout()
	_check(soldier.action._sub_action == null, "Counter targeting bypassed Hold fire")
	_check(not defense._available(soldier, enemy), "Allied assistance bypassed Hold fire")
	soldier.stance = soldier.Stance.HOLD_POSITION
	_check(
		not defense._available(soldier, enemy), "Allied assistance could move a Hold position unit"
	)
	soldier.action._on_timer_timeout()
	_check(
		soldier.action._sub_action != null,
		"Hold position stopped firing at an eligible in-range target"
	)
