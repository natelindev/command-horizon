extends "res://tests/headless/SkirmishCoordinationRegression.gd"


func _run():
	catalog = load("res://source/match/BastionCatalog.gd")
	coordination = load("res://source/match/players/skirmish-ai/SkirmishCoordination.gd")
	var probe = load("res://tests/headless/SkirmishCoordinationMetrics.gd").new()
	await _fixture("bastion", 1)
	opponent._command_army(actors)
	_check(probe.inspect(opponent, actors).is_empty(), "Valid coordination rejected")
	var group = opponent._army_groups[0]
	var member = group.members[0]
	var original = member.action.destination
	member.action.destination = Vector3(2, 0, 2)
	_check("detached_attack_order" in probe.inspect(opponent, actors), "Stale order not detected")
	member.action.destination = original
	group.members.erase(member)
	_check(
		"unassigned_attack_order" in probe.inspect(opponent, actors), "Extra mission not detected"
	)
	group.members.append(member)
	opponent._army_groups.append(group)
	var issues = probe.inspect(opponent, actors)
	_check("group_budget" in issues and "duplicate_member" in issues, "Invalid roster not detected")
	opponent._army_groups.pop_back()
	probe.sample(game, opponent)
	_check(probe.samples == 1 and probe.violations.is_empty(), "Valid metric sample failed")
	game.queue_free()
	await _frames(5)
	for error in errors:
		push_error(error)
	print("Coordination metrics: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)
