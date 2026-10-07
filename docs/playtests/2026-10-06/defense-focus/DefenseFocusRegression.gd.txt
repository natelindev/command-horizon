extends "res://tests/headless/AirDefenseAdviceRegression.gd"

var endangered
var focus_checks = 0


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	plan_rules = load("res://source/match/SkirmishPlan.gd")
	tactics = load("res://source/match/SkirmishTactics.gd")
	combat_rules = load("res://source/match/combat/CombatRules.gd")
	factions = load("res://source/match/FactionCatalog.gd")
	for faction in factions.IDS:
		await _focus_fixture(faction)
		await _assert_focus("visible-" + faction, endangered.position)
		await _focus_cases()
		paused = false
		game.queue_free()
		await _frames(5)
	await _earned_focus()
	for message in errors:
		push_error(message)
	print("Defense focus: %d failures; %d focus checks" % [errors.size(), focus_checks])
	quit(0 if errors.is_empty() else 1)


func _focus_fixture(faction):
	await _fixture(faction)
	raider.queue_free()
	await _frames(2)
	endangered = _units(human, "Worker")[0]
	endangered.position = Vector3(58, 0, 50)
	raider = _actor("Infantry", enemy, endangered.position + Vector3(3, 0, 0))
	game.battlefield.invalidate()
	_check(game.battlefield.is_observed(human, raider), "Distant raid fixture is hidden")
	_check(
		plan_rules.next_step(human).action == "Select defenders",
		"Distant raid lacks defender selection"
	)


func _assert_focus(label, expected):
	var panel = game.hud.battle_plan
	var camera = game.get_node("IsometricCamera3D")
	camera.set_physics_process(false)
	camera.set_position_safely(expected)
	var expected_camera = camera.position
	camera.set_position_safely(Vector3(10, 0, 10))
	var advice = plan_rules.next_step(human)
	var before = _authority()
	panel.refresh()
	var untouched_camera = camera.position
	game.hud._overlay = Control.new()
	panel._select_step()
	_check(
		camera.position == untouched_camera and _authority() == before,
		"Defense selection bypassed modal ownership"
	)
	game.hud._overlay.free()
	game.hud._overlay = null
	await _activate_defense(panel)
	await _frames(8)
	var after = _authority()
	# Selection is intentional; simulation, funds, health, queues and orders are not.
	before[4] = after[4]
	_check(before == after, "Defense selection changed gameplay: " + label)
	_check(
		camera.position.distance_to(expected_camera) < .001,
		"Defense selection left the raid offscreen: " + label
	)
	_check(
		advice.get("focus_position") == expected,
		"Defense advice omitted its known asset focus: " + label
	)
	_check(
		advice.units.all(func(unit): return unit in get_nodes_in_group("selected_units")),
		"Defense focus changed recommended selection"
	)
	_check(
		get_nodes_in_group("selected_units").size() == advice.units.size(),
		"Defense focus selected extra units"
	)
	_check(
		"threatened area" in panel._action.tooltip_text, "Defender focus missing action explanation"
	)
	_check(
		panel._action.accessibility_description == panel._action.tooltip_text,
		"Focus action explanation is inaccessible"
	)
	await _review_focus(label)
	focus_checks += 1


func _focus_cases():
	# A real unseen hit can reveal the owned victim, never the hidden attacker's position.
	raider.position = Vector3(105, 0, 85)
	game.battlefield.invalidate()
	_check(
		not game.battlefield.is_observed(human, raider), "Hidden attacker fixture remained visible"
	)
	endangered.receive_weapon_hit(raider)
	await _assert_focus("unseen-hit-" + human.faction, endangered.position)
	endangered.last_enemy_damage_time = game.simulation_time - 7
	_check(
		not plan_rules.next_step(human).has("focus_position"),
		"Expired damage retained danger focus"
	)
	# A newer hit takes precedence over an older victim and nearby visible pressure.
	var recent = _units(human, "Worker")[1]
	recent.position = Vector3(66, 0, 45)
	endangered.last_enemy_damage_time = game.simulation_time - 2
	recent.receive_weapon_hit(raider)
	await _assert_focus("newest-hit-" + human.faction, recent.position)
	recent.last_enemy_damage_time = -1000
	endangered.last_enemy_damage_time = -1000
	# Air-production guidance must still locate its engineer/factory, not jump to the raid.
	raider.queue_free()
	await _frames(2)
	raider = _actor("Helicopter", enemy, endangered.position + Vector3(3, 3, 0))
	game.battlefield.invalidate()
	_check(
		not plan_rules.next_step(human).has("focus_position"),
		"Production advice acquired mobile-defender focus"
	)
	var counter = _actor("Helicopter", human, hq_point + Vector3(-3, 3, 0))
	await _assert_focus("air-" + human.faction, endangered.position)
	counter.queue_free()
	await _frames(2)


func _earned_focus():
	var archive = (
		"res://docs/playtests/2026-10-06/reinforcement-pacing/"
		+ "control6-earned-case6-10-infantry_ready.json"
	)
	var restore = Restore.new()
	var result = await restore.restore(self, FileStore.new().read_file(archive))
	_check(result.ok, "Earned Industrial raid failed to restore")
	if not result.ok:
		return
	game = result.game
	human = game._get_human_player()
	enemy = get_nodes_in_group("players").filter(func(side): return side != human)[0]
	var advice = plan_rules.next_step(human)
	print(
		"EARNED DEFENSE ", advice.title, " ", advice.action, " focus=", advice.get("focus_position")
	)
	_check(advice.id == "defend_economy", "Earned under-fire archive lost economic threat")
	if advice.has("focus_position"):
		await _assert_focus("earned-industrial", advice.focus_position)
		var point = advice.focus_position
		var builder = Snapshot.new()
		var data = builder.capture(game)
		var path = "user://defense-focus-%d.json" % OS.get_process_id()
		_check(FileStore.new().write_file(path, data), "Defense focus archive failed")
		var loaded = await Restore.new().restore(self, FileStore.new().read_file(path))
		DirAccess.remove_absolute(path)
		_check(loaded.ok, "Defense focus archive failed to reload")
		if loaded.ok:
			game = loaded.game
			human = game._get_human_player()
			await _assert_focus("earned-reloaded", point)
	else:
		_check(false, "Earned defense lacks focus")
	paused = false
	game.queue_free()
	await _frames(5)


func _review_focus(_label):
	pass


func _activate_defense(panel):
	panel._select_step()
