extends "res://tests/headless/ExpandedMapRegression.gd"

const Snapshot = preload("res://source/match/saves/MatchSnapshot.gd")
const Restore = preload("res://source/match/saves/MatchRestore.gd")


func _run():
	factions = load("res://source/match/FactionCatalog.gd")
	constants = root.get_node("Constants")
	harvest = load("res://source/match/units/actions/CollectingResourcesSequentially.gd")
	root.get_node("SaveManager").autosaves_enabled = false
	for map_name in EXPANDED_MAPS:
		if not "--advanced-only" in OS.get_cmdline_user_args():
			for faction in factions.IDS:
				await _create(map_name, faction)
				await _geometry(map_name)
				await _harvest_home_fields()
				await _archive_positions()
				await _close()
		await _advanced_base(map_name)
	for message in _errors:
		push_error(message)
	print("Starting resources: %d failures" % _errors.size())
	quit(0 if _errors.is_empty() else 1)


func _advanced_base(map_name):
	var settings = _settings("bastion", "helix", true)
	settings.map_path = "res://source/match/maps/%s.tscn" % map_name
	game = await _start(settings)
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	await _frames(120)
	await _geometry(map_name)
	await _archive_positions()
	await _close()


func _harvest_home_fields():
	var targets = []
	var workers = []
	var deposits = game.map.get_node("Resources").get_children()
	var sides = get_nodes_in_group("players")
	for side in sides:
		var hq = side.get_children().filter(func(unit): return "type" in unit and unit.type == "CommandCenter")[0]
		var balances = Vector2(side.resource_a, side.resource_b)
		targets.append({"side": side, "balances": balances})
		for kind in ["resource_a", "resource_b"]:
			var choices = deposits.filter(
				func(deposit):
					return (
						kind in deposit
						and deposit.get(kind) == (400 if kind == "resource_a" else 720)
					)
			)
			choices.sort_custom(
				func(a, b):
					return a.position.distance_to(hq.position) < b.position.distance_to(hq.position)
			)
			var direction = (choices[0].position - hq.position).normalized()
			var worker = load(Catalog.scene_path("Worker")).instantiate()
			var origin = (
				hq.position + direction * 5 + Vector3(1 if kind == "resource_a" else -1, 0, 0)
			)
			game._setup_and_spawn_unit(worker, Transform3D(Basis.IDENTITY, origin), side, false)
			workers.append({"unit": worker, "deposit": choices[0]})
	await _frames(60)
	for entry in workers:
		entry.unit.issue_manual_order(harvest.new(entry.deposit))
	var began = game.simulation_time
	var delivered = false
	for frame in range(3600):
		await physics_frame
		delivered = targets.all(
			func(entry):
				return (
					entry.side.resource_a >= entry.balances.x + 4
					and entry.side.resource_b >= entry.balances.y + 4
				)
		)
		if delivered:
			break
	_check(delivered, "Home materials/electronics failed to return on " + game.settings.map_path)
	print(
		"HOME HARVEST ",
		game.settings.map_path.get_file(),
		" ",
		game._get_human_player().faction,
		" both_players=",
		delivered,
		" seconds=",
		game.simulation_time - began
	)


func _archive_positions():
	paused = true
	var builder = Snapshot.new()
	var snapshot = builder.capture(game)
	_check(snapshot != null, "Starting-field snapshot failed: " + builder.error)
	if snapshot == null:
		return
	# Archives retain their recorded coordinates, including a pre-layout position.
	snapshot.resources[0].position += Vector3(.25, 0, 0)
	var loaded = await Restore.new().restore(self, snapshot)
	_check(loaded.ok, "Starting-field restore failed: " + loaded.get("error", ""))
	if not loaded.ok:
		return
	game = loaded.game
	var again = Snapshot.new().capture(game)
	_check(again != null, "Restored starting-field capture failed")
	if again == null:
		return
	_check(
		again.resources.size() == snapshot.resources.size(), "Restore duplicated resource fields"
	)
	for index in snapshot.resources.size():
		_check(
			again.resources[index].position.is_equal_approx(snapshot.resources[index].position),
			"Restore normalized an archived resource position"
		)
		_check(
			again.resources[index].amount == snapshot.resources[index].amount,
			"Restore changed resource stock"
		)
	paused = false
