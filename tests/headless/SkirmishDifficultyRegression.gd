extends "res://tests/headless/Skirmish.gd"

# Plays the same opening at each AI difficulty against a stationary commander
# and compares measurable commander quality. Every level pays identical prices
# and gathers at identical rates, so the ordering comes from decisions alone.
const Difficulty = preload("res://source/match/players/skirmish-ai/SkirmishDifficulty.gd")
const Snapshot = preload("res://source/match/saves/MatchSnapshot.gd")
const Restore = preload("res://source/match/saves/MatchRestore.gd")
const Schema = preload("res://source/match/saves/SnapshotSchema.gd")
const SECONDS = 600
const CHECKPOINTS = [180, 300, 420, 600]


func _run():
	factions = load("res://source/match/FactionCatalog.gd")
	constants = root.get_node("Constants")
	var saves = root.get_node("SaveManager")
	var autosaves = saves.autosaves_enabled
	saves.autosaves_enabled = false
	_profiles()
	await _setup_screen()
	# Each opponent takes three ten-minute battles; add -- --helix / --frontier for more.
	var selected = []
	for faction in factions.IDS:
		if "--" + faction in OS.get_cmdline_user_args():
			selected.append(faction)
	if selected.is_empty():
		selected = ["bastion"]
	for opponent in selected:
		var results = []
		for difficulty in 3:
			results.append(await _measure(opponent, difficulty))
		_compare(opponent, results)
	await _archive()
	saves.autosaves_enabled = autosaves
	for message in _errors:
		push_error(message)
	print("Skirmish difficulty: %d failures" % _errors.size())
	quit(0 if _errors.is_empty() else 1)


func _profiles():
	# Normal is the reference commander; existing balance and regressions rely on it.
	var normal = Difficulty.PROFILES[Difficulty.NORMAL]
	_check(normal.decision_interval == 1.5, "Normal decision interval changed")
	_check(normal.first_wave == 120.0 and normal.wave_interval == 65.0, "Normal waves changed")
	_check(normal.task_groups == 2, "Normal task budget changed")
	_check(normal.workers == 6, "Normal engineer target changed")
	_check(normal.retreat_health == 0.3, "Normal retreat threshold changed")
	_check(normal.timing_scale == 1.0, "Normal build timings changed")
	_check(normal.assault_limit == 0 and normal.army_limit == 0, "Normal gained army caps")
	_check(normal.extra_factories == 0, "Normal gained extra production")
	_check(
		normal.research_guards == 6 and normal.research == Difficulty.FULL_RESEARCH,
		"Normal research path changed"
	)
	_check(normal.defense_responders == 6, "Normal raid response changed")
	_check(normal.programs and normal.signatures, "Normal lost programs or abilities")
	for index in 3:
		_check(Difficulty.of(index) == Difficulty.PROFILES[index], "Profile lookup mismatch")
	_check(Difficulty.of(-1) == Difficulty.PROFILES[0], "Negative difficulty not clamped")
	_check(Difficulty.of(7) == Difficulty.PROFILES[2], "Large difficulty not clamped")
	_check(Difficulty.army_cap(Difficulty.NORMAL, 900.0) == 0, "Normal army is capped")
	_check(Difficulty.army_cap(Difficulty.HARD, 900.0) == 0, "Hard army is capped")
	_check(
		(
			Difficulty.army_cap(Difficulty.EASY, 0.0) == 3
			and Difficulty.army_cap(Difficulty.EASY, 180.0) == 9
			and Difficulty.army_cap(Difficulty.EASY, 900.0) == 14
		),
		"Easy army cap does not ramp from 3 to 14 units"
	)
	var easy = Difficulty.PROFILES[Difficulty.EASY]
	var hard = Difficulty.PROFILES[Difficulty.HARD]
	_check(
		(
			easy.decision_interval > normal.decision_interval
			and normal.decision_interval > hard.decision_interval
		),
		"Decision intervals are not ordered"
	)
	_check(
		easy.first_wave > normal.first_wave and normal.first_wave > hard.first_wave,
		"First waves are not ordered"
	)


func _setup_screen():
	var scene = load("res://source/main-menu/Play.tscn")
	var preferences = "user://difficulty-setup-%d.cfg" % OS.get_process_id()
	var setup = scene.instantiate()
	setup.preferences_path = preferences
	root.add_child(setup)
	await _frames(2)
	_check(setup._difficulty.selected == 1, "Skirmish setup does not default to Normal")
	_check(setup._difficulty.item_count == 3, "Skirmish setup lacks three AI levels")
	for index in 3:
		setup._difficulty.select(index)
		setup._update_summary()
		var settings = setup._create_match_settings()
		_check(settings.players[0].difficulty == 1, "Human side received an AI difficulty")
		_check(settings.players[1].difficulty == index, "Setup lost the selected AI level")
		_check(
			setup._difficulty_note.text == Difficulty.DESCRIPTIONS[index],
			"Setup description does not follow the selected level"
		)
	setup._save_preferences()
	setup.queue_free()
	await _frames(2)
	setup = scene.instantiate()
	setup.preferences_path = preferences
	root.add_child(setup)
	await _frames(2)
	_check(setup._difficulty.selected == 2, "Saved AI level was not restored in setup")
	DirAccess.remove_absolute(preferences)
	setup.queue_free()
	await _frames(2)


func _measure(opponent, difficulty):
	seed(7300 + difficulty)
	var settings = _settings("bastion", opponent, false)
	settings.map_path = "res://source/match/maps/DesertFrontier.tscn"
	settings.players[1].spawn_index_offset = 0
	settings.players[1].difficulty = difficulty
	var game = await _start(settings)
	var human = game._get_human_player()
	var enemy = get_nodes_in_group("players").filter(func(p): return p != human)[0]
	_check(enemy.difficulty == difficulty, "Match did not apply the configured AI level")
	# A stationary, indestructible target isolates the commander's own build-up.
	human.process_mode = Node.PROCESS_MODE_DISABLED
	var hq = _unit(human, "CommandCenter")
	hq.hp = 100000
	var result = {
		"difficulty": Difficulty.NAMES[difficulty],
		"first_attack": -1.0,
		"largest_wave": 0,
		"army": {},
		"army_units": {},
		"workers": {},
		"mined": {},
		"funds": {},
		"structures": 0,
		"research": 0,
		"hq_damage": 0
	}
	var mined = {"materials": 0, "electronics": 0}
	var record = func(worker, kind, amount):
		if worker.player == enemy and mined.has(kind):
			mined[kind] += amount
	var signals = root.get_node("MatchSignals")
	signals.resources_mined.connect(record)
	var checkpoint = 0
	while game.simulation_time < SECONDS and not game.finished:
		await _frames(30)
		if result.first_attack < 0 and enemy.attacks_launched > 0:
			result.first_attack = snappedf(game.simulation_time, 0.1)
		for group in enemy._army_groups:
			if group.kind == "assault":
				result.largest_wave = maxi(result.largest_wave, group.members.size())
		if checkpoint < CHECKPOINTS.size() and game.simulation_time >= CHECKPOINTS[checkpoint]:
			var seconds = CHECKPOINTS[checkpoint]
			result.army[seconds] = _army_value(enemy)
			result.army_units[seconds] = _army_units(enemy)
			result.workers[seconds] = _count(enemy, "Worker")
			result.mined[seconds] = [mined.materials, mined.electronics]
			result.funds[seconds] = [enemy.resource_a, enemy.resource_b]
			checkpoint += 1
	signals.resources_mined.disconnect(record)
	result.structures = enemy.structures_built
	result.research = enemy.technology.completed.size()
	result.hq_damage = 100000 - hq.hp
	var roster = {}
	for unit in enemy.get_children():
		if "type" in unit and not unit.is_queued_for_deletion():
			roster[unit.type] = roster.get(unit.type, 0) + 1
	result.roster = roster
	print("DIFFICULTY ", opponent, " ", JSON.stringify(result))
	game.queue_free()
	paused = false
	await _frames(6)
	return result


func _army_value(player):
	var value = 0
	for unit in player.get_children():
		if (
			not "type" in unit
			or unit.is_queued_for_deletion()
			or unit.hp <= 0
			or unit.type == "Worker"
			or unit.movement_speed <= 0
			or unit.attack_range == null
		):
			continue
		var price = factions.cost(player, unit.type)
		value += price.resource_a + price.resource_b
	return value


func _army_units(player):
	# Matches the commander's own cap: every mobile non-engineer unit, queued or fielded.
	var counts = load("res://source/match/players/skirmish-ai/SkirmishComposition.gd").inventory(
		player.get_children().filter(func(unit): return "type" in unit)
	)
	return load("res://source/match/players/skirmish-ai/SkirmishProduction.gd").army_size(counts)


func _count(player, role):
	var total = 0
	for unit in player.get_children():
		if "type" in unit and unit.type == role and not unit.is_queued_for_deletion():
			total += 1
	return total


func _compare(opponent, results):
	var easy = results[0]
	var normal = results[1]
	var hard = results[2]
	var label = opponent + ": "
	for result in results:
		_check(result.first_attack >= 0, label + result.difficulty + " never attacked")
		_check(result.structures >= 3, label + result.difficulty + " did not build a base")
	_check(
		hard.first_attack < normal.first_attack and normal.first_attack < easy.first_attack,
		label + "first attack is not ordered Hard < Normal < Easy"
	)
	# The stronger economy needs a few minutes to pay for engineers and a second
	# factory; compare once it has, and income across the whole measured period.
	for seconds in [420, 600]:
		_check(
			hard.army[seconds] > normal.army[seconds] and normal.army[seconds] > easy.army[seconds],
			label + "army value at %ds is not ordered Hard > Normal > Easy" % seconds
		)
	_check(
		hard.mined[600][0] > normal.mined[600][0] and normal.mined[600][0] > easy.mined[600][0],
		label + "materials mined are not ordered Hard > Normal > Easy"
	)
	_check(
		hard.workers[600] > normal.workers[600] and normal.workers[600] > easy.workers[600],
		label + "engineer count is not ordered Hard > Normal > Easy"
	)
	# Easy keeps its opening gentle and its waves small.
	_check(easy.army_units[180] < normal.army_units[180], label + "Easy opening army not smaller")
	for seconds in CHECKPOINTS:
		_check(
			easy.army_units[seconds] <= Difficulty.army_cap(Difficulty.EASY, seconds),
			label + "Easy army exceeded its cap at %ds" % seconds
		)
	_check(easy.largest_wave <= Difficulty.PROFILES[0].assault_limit, label + "Easy wave too large")
	_check(hard.largest_wave > easy.largest_wave, label + "Hard waves are not larger than Easy")
	_check(
		easy.hq_damage < normal.hq_damage and easy.hq_damage < hard.hq_damage,
		label + "Easy pressure on the enemy HQ is not the lightest"
	)


func _archive():
	# The chosen level belongs to the battle archive and survives a reload.
	for difficulty in 3:
		var settings = _settings("bastion", "helix", false)
		settings.map_path = "res://source/match/maps/DesertFrontier.tscn"
		settings.players[1].spawn_index_offset = 0
		settings.players[1].difficulty = difficulty
		var game = await _start(settings)
		paused = true
		var snapshot = Snapshot.new()
		var data = snapshot.capture(game)
		_check(data != null, "Difficulty battle could not be captured")
		if data == null:
			paused = false
			game.queue_free()
			await _frames(5)
			continue
		_check(data.settings.players[1].difficulty == difficulty, "Archive lost the AI level")
		var schema = Schema.new()
		for invalid in [-1, 3]:
			var broken = data.duplicate(true)
			broken.settings.players[1].difficulty = invalid
			_check(not schema.validate(broken), "Archive accepted AI level %d" % invalid)
		var summary = load("res://source/match/saves/SaveSlots.gd").summary_for(data)
		_check(
			Difficulty.NAMES[difficulty] in summary, "Save slot summary does not name the AI level"
		)
		var restore = Restore.new()
		var loaded = await restore.restore(self, data)
		_check(loaded.ok, "Difficulty archive restore failed: " + loaded.get("error", ""))
		if loaded.ok:
			game = loaded.game
			var enemy = restore.entities["player-1"]
			_check(enemy.difficulty == difficulty, "Restored AI lost its level")
			_check(
				game.settings.players[1].difficulty == difficulty,
				"Restored settings lost the AI level"
			)
			_check(
				Difficulty.of(enemy.difficulty) == Difficulty.PROFILES[difficulty],
				"Restored AI uses another profile"
			)
		paused = false
		game.queue_free()
		await _frames(5)
