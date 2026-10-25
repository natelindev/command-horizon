extends "res://tests/headless/FrontierGameplayRegression.gd"


func _run():
	factions = load("res://source/match/FactionCatalog.gd")
	combat_rules = load("res://source/match/combat/CombatRules.gd")
	harvest = load("res://source/match/units/actions/CollectingResourcesSequentially.gd")
	root.get_node("SaveManager").autosaves_enabled = false
	await _fixture()
	_check(await _edges() == true, "Salvage adverse suite aborted")
	await _cleanup()
	for message in errors:
		push_error(message)
	print("Frontier salvage adverse flows: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _edges():
	var worker = _units(human, "Worker")[0]
	var victim = _spawn_frontier("Tank", enemy, Vector3(45, 0, 45))
	await _frames(3)
	victim.hp = 0
	await _frames(15)
	var wreck = get_nodes_in_group("salvage_wrecks")[0]
	_check(
		not wreck.visible and not wreck.can_harvest(worker), "Hidden wreck leaked a harvest target"
	)
	_check(
		not load("res://source/match/hud/Ownership.gd").known_now(wreck, game),
		"Minimap exposed an unobserved death"
	)
	worker.global_position = wreck.global_position + Vector3(0, 0, .9)
	await _frames(15)
	_check(wreck.visible and wreck.can_harvest(worker), "Scouting did not reveal salvage")
	var funds = human.resource_a
	worker.resource_a = 2
	worker.global_position = wreck.global_position + Vector3(0, 0, 6)
	worker.issue_manual_order(harvest.new(wreck))
	await _frames(2)
	var cargo = worker.resource_a
	_check(
		cargo > 0 and is_instance_valid(wreck),
		"Expiry fixture lost existing cargo or distant wreck"
	)
	if not is_instance_valid(wreck):
		return false
	wreck.salvage_left = .05
	await _frames(10)
	_check(not is_instance_valid(wreck), "Expired wreck remains collectible")
	_check(
		worker.resource_a == cargo and human.resource_a == funds,
		"Expiry lost cargo or awarded undelivered money"
	)
	for role in ["Infantry", "Drone", "CommandCenter"]:
		var excluded = _spawn_frontier(role, enemy, Vector3(43, 0, 44))
		await _frames(2)
		excluded.hp = 0
	await _frames(3)
	_check(
		get_nodes_in_group("salvage_wrecks").is_empty(),
		"Infantry, air or structures yielded ground-machine salvage"
	)
	worker.issue_manual_order(null)
	# Exercise the bounded pending-death queue at a save boundary, with finite one-material wrecks.
	for index in range(132):
		game.wreck_salvage.pending.append(
			{"role": "Worker", "faction": "frontier", "amount": 1, "position": Vector3(24, 0, 24)}
		)
	game.wreck_salvage.flush()
	await _frames(3)
	var wrecks = get_nodes_in_group("salvage_wrecks")
	_check(wrecks.size() == 128, "Salvage lifetime cap failed")
	var placement = load("res://source/match/utils/UnitPlacementUtils.gd")
	var nav = game.navigation.get_navigation_map_rid_by_domain(
		root.get_node("Constants").Match.Navigation.Domain.TERRAIN
	)
	_check(
		(
			placement.validate_agent_placement_position(Vector3(24, 0, 24), .9, wrecks, nav)
			== placement.VALID
		),
		"Wrecks block rebuilding or produced-unit exits"
	)
	paused = true
	var builder = Snapshot.new()
	var data = builder.capture(game)
	_check(data != null and Restore.new().prepare(data), "Full wreck pool cannot be saved")
	if data == null:
		return false
	var bad = data.duplicate(true)
	var saved = bad.resources.filter(func(entry): return not entry.wreck.is_empty())[0]
	saved.amount = 3
	_check(
		not Restore.new().prepare(bad),
		"Worker wreck can invent more material than its original price"
	)
	var before = wrecks[0].salvage_left
	await _frames(15)
	_check(wrecks[0].salvage_left == before, "Pause advanced wreck expiry")
	for node in wrecks:
		node.salvage_left = .01
	paused = false
	await _frames(5)
	_check(
		get_nodes_in_group("salvage_wrecks").is_empty(), "Expired full wreck pool did not retire"
	)
	return true
