extends "res://tests/headless/CautiousRelayRegression.gd"


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	policy_script = load("res://tests/playtest/reference/CautiousRelayPolicy.gd")
	for faction in ["bastion", "helix", "frontier"]:
		await _authority(faction)
	for message in errors:
		push_error(message)
	print("Cautious relay authority: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _authority(faction):
	var player = await _setup(faction, "IndustrialCrossroads")
	var hq = _units(player, "CommandCenter")[0]
	var home = hq.position + Vector3(0, 0, 6)
	_extra_infantry(player, home)
	await _frames(5)
	var infantry = _units(player, "Infantry")
	var funds = Vector2i(player.resource_a, player.resource_b)
	for ending in ["recovery", "replaced", "timeout", "home"]:
		for unit in infantry:
			unit.position = home + Vector3(unit.get_index() % 3, 0, 0)
			unit.issue_manual_order(null)
		var policy = policy_script.new()
		var held = policy.update(game, player, _owned(player), "defend", [], home)
		_check(held.size() == 1, "Authority fixture did not dispatch")
		if held.is_empty():
			continue
		var scout = held[0]
		scout.position = policy.relay.get_ref().position + Vector3(-2, 0, -2)
		# Isolate command ownership after an opposition decision. The companion
		# regression covers actual observation and live travel under enemy fire.
		policy._finish(game, held, [], home, "opposition")
		var withdrawal = scout.action
		var protected = policy.update(game, player, _owned(player), "attack", [], home)
		_check(scout in protected and scout.action == withdrawal, "Assault replaced withdrawal")
		var unavailable = []
		var replacement = null
		match ending:
			"recovery":
				replacement = load("res://source/match/units/actions/RecoveringAtService.gd").new(
					null
				)
				scout.issue_manual_order(replacement)
				unavailable = [scout]
			"replaced":
				replacement = load("res://source/match/units/actions/Moving.gd").new(
					home + Vector3(0, 0, 10)
				)
				scout.issue_manual_order(replacement)
			"timeout":
				policy.withdrawals[-1].start -= 60
			"home":
				scout.position = home
		protected = policy.update(game, player, _owned(player), "attack", unavailable, home)
		_check(scout not in protected, "Withdrawal did not release on " + ending)
		_check(policy.withdrawals[-1].result == ending, "Withdrawal end reason mismatch")
		if replacement != null:
			_check(
				scout.action == replacement, "Withdrawal replaced external recovery/manual order"
			)
		_check(
			Vector2i(player.resource_a, player.resource_b) == funds, "Withdrawal changed resources"
		)
	# Losing HQ suspends optional expeditions even with three healthy infantry.
	for unit in infantry:
		unit.position = home
		unit.issue_manual_order(null)
	hq.hp = 0
	await _frames(3)
	var policy = policy_script.new()
	_check(
		policy.update(game, player, _owned(player), "defend", [], home).is_empty(),
		"Missing HQ dispatched expedition"
	)
	print(
		"RELAY AUTHORITY ",
		faction,
		" assault, recovery, replacement, bounded return and missing HQ"
	)
	game.queue_free()
	await _frames(5)
