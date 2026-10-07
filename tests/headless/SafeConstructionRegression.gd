extends "res://tests/playtest/SafeConstructionMatches.gd"


func _process(_delta):
	return false


func _load_policy():
	plan_rules = load("res://source/match/SkirmishPlan.gd")
	factions = load("res://source/match/FactionCatalog.gd")
	constants = root.get_node("Constants")
	economy_policy = load("res://source/match/players/skirmish-ai/SkirmishEconomy.gd")
	root.get_node("SaveManager").autosaves_enabled = false


func _run():
	_load_policy()
	for faction in factions.IDS:
		await _placement_case(faction)
		paused = false
		if is_instance_valid(game):
			game.queue_free()
			await _frames(5)
	for message in _errors:
		push_error(message)
	print("Safe construction: %d failures" % _errors.size())
	quit(0 if _errors.is_empty() else 1)


func _placement_case(faction):
	var settings = _settings(faction, "frontier" if faction != "frontier" else "helix", false)
	settings.map_path = "res://source/match/maps/IndustrialCrossroads.tscn"
	game = await _start(settings)
	human = game._get_human_player()
	opponent = get_nodes_in_group("players").filter(func(side): return side != human)[0]
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	paused = true
	metrics = {}
	var builder = _unit(human, "Worker")
	builder.position = Vector3(12, 0, 54)
	var enemy = load(Catalog.scene_path("Tank")).instantiate()
	game._setup_and_spawn_unit(enemy, Transform3D(Basis(), Vector3(30, 0, 50)), opponent, false)
	var sights = {}
	for unit in plan_rules.owned_units(human):
		sights[unit] = unit.sight_range
		unit.sight_range = 60.0
	game.battlefield.invalidate()
	_check(game.battlefield.is_observed(human, enemy), "Fixture threat is not observed")
	var price = factions.cost(human, "Barracks", true)
	human.resource_a = price.resource_a
	human.resource_b = price.resource_b
	safe_construction = false
	_place("Barracks", builder)
	var exposed = _unit(human, "Barracks")
	_check(exposed != null, "Original policy did not buy a foundation")
	if exposed == null:
		return
	var original_point = exposed.position
	_check(
		economy_policy.danger(original_point, builder, construction_observed),
		"Original site is not exposed"
	)
	exposed.queue_free()
	await _frames(2)
	builder.issue_manual_order(null)
	human.resource_a = price.resource_a
	human.resource_b = price.resource_b
	safe_construction = true
	_place("Barracks", builder)
	var protected = _unit(human, "Barracks")
	_check(protected != null, "Safe policy did not find an alternative")
	if protected == null:
		return
	_check(
		protected.position.distance_to(original_point) > 1.0, "Safe policy retained exposed site"
	)
	_check(
		not economy_policy.danger(protected.position, builder, construction_observed),
		"Alternative site remains exposed"
	)
	_check(
		human.resource_a == 0 and human.resource_b == 0, "Foundation cost differs from exact price"
	)
	var across = Vector3(50, 0, 50)
	_check(
		not economy_policy.danger(across, builder, construction_observed),
		"Approach fixture endpoint remains threatened"
	)
	_check(
		not _placement_candidate_allowed(across, builder),
		"Safe endpoint allowed a threatened builder approach"
	)
	# Hidden positions cannot reject the same candidate. Visibility is staged,
	# not a claimed complete-match observation.
	for unit in sights:
		unit.sight_range = .1
	var foundation_sight = protected.sight_range
	protected.sight_range = .1
	game.battlefield.invalidate()
	construction_observed = economy_policy.contacts(game, human)
	_check(enemy not in construction_observed, "Hidden fixture enemy remains observed")
	_check(
		_placement_candidate_allowed(original_point, builder),
		"Unseen enemy altered placement choice"
	)
	for unit in sights:
		unit.sight_range = sights[unit]
	protected.sight_range = foundation_sight
	# An observed attacker on the builder's approach must defer every site.
	enemy.position = builder.position + Vector3(1, 0, 0)
	game.battlefield.invalidate()
	human.resource_a = 200
	human.resource_b = 100
	var before = plan_rules.owned_units(human)
	var action = builder.action
	var pending = builder.manual_orders.pending.duplicate(true)
	var started = game.simulation_time
	_place("PowerPlant", builder)
	_check(plan_rules.owned_units(human) == before, "Blocked placement spawned a foundation")
	_check(human.resource_a == 200 and human.resource_b == 100, "Blocked placement spent resources")
	_check(
		builder.action == action and builder.manual_orders.pending == pending,
		"Blocked placement replaced builder orders"
	)
	_check(
		not human.get_node("StructurePlacementHandler")._structure_placement_started(),
		"Deferred blueprint was not cancelled"
	)
	_check(game.simulation_time == started, "Paused placement advanced simulation")
	var safe_point = protected.position
	var saved_funds = Vector2i(human.resource_a, human.resource_b)
	var saved_progress = protected._construction_progress
	enemy.queue_free()
	await _frames(2)
	var snapshot = load("res://source/match/saves/MatchSnapshot.gd").new().capture(game)
	var path = "user://safe-construction-%d.json" % OS.get_process_id()
	var files = load("res://source/match/saves/SaveFile.gd").new()
	_check(files.write_file(path, snapshot), "Construction archive failed")
	var restored = await load("res://source/match/saves/MatchRestore.gd").new().restore(
		self, files.read_file(path)
	)
	DirAccess.remove_absolute(path)
	_check(restored.ok, "Construction archive did not reload")
	if not restored.ok:
		return
	game = restored.game
	human = game._get_human_player()
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	protected = _unit(human, "Barracks")
	await _frames(20)
	_check(
		(
			protected != null
			and protected.position == safe_point
			and protected._construction_progress == saved_progress
			and not protected.is_constructed()
		),
		"Paused reload changed the foundation"
	)
	_check(
		Vector2i(human.resource_a, human.resource_b) == saved_funds,
		"Reload changed paid foundation funds"
	)
	paused = false
	for frame in 3600:
		await physics_frame
		if protected.is_constructed():
			break
	_check(protected.is_constructed(), "Paid safe foundation never completed after reload")
	print(
		"SAFE CONSTRUCTION ",
		faction,
		" original=",
		original_point,
		" safe=",
		safe_point,
		" completed=",
		protected.is_constructed()
	)
