extends "res://tests/headless/MechanicsRegression.gd"


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	for faction in ["bastion", "helix", "frontier"]:
		await _open_sites(faction)
		await _exercise_sites()
		await _clear()
		paused = false
		_game.queue_free()
		await _frames(5)
		print("SITES faction=", faction, " cumulative_failures=", _errors.size())
	for message in _errors:
		push_error(message)
	print("Capturable facilities: %d failures" % _errors.size())
	quit(0 if _errors.is_empty() else 1)


func _open_sites(faction):
	var settings = load("res://source/data-model/MatchSettings.gd").new()
	settings.skirmish = true
	settings.advanced_start = true
	settings.map_path = "res://source/match/maps/ExpandedDesertFrontier.tscn"
	for index in 2:
		var side = load("res://source/data-model/PlayerSettings.gd").new()
		side.controller = index + 1
		side.faction = faction
		settings.players.append(side)
	_game = load("res://source/match/Skirmish.tscn").instantiate()
	_game.settings = settings
	_game.map = load(settings.map_path).instantiate()
	root.add_child(_game)
	current_scene = _game
	await _frames(60)
	_human = _game._get_human_player()
	_enemy = get_nodes_in_group("players").filter(func(side): return side != _human)[0]
	_enemy.set_process(false)
	_game.get_node("IsometricCamera3D").set_physics_process(false)
	for unit in get_nodes_in_group("units"):
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	for site in _game.map.points_of_interest:
		site.set_physics_process(false)
	_game.repair_service.set_physics_process(false)


func _claim(site, soldier, side):
	var previous_owner = site.captured_by
	soldier.position = site.position + Vector3(3.8, 0, 0)
	_game.battlefield.invalidate()
	site._physics_process(5)
	_check(
		site.captured_by == previous_owner and site.progress == 5,
		"Capture changed ownership before completing"
	)
	site._physics_process(5)
	_check(
		site.captured_by == side and site.progress == 0, "Infantry failed to capture the facility"
	)


func _exercise_sites():
	var catalog = load("res://source/match/world/PointOfInterestCatalog.gd")
	var sites = _game.map.points_of_interest
	_check(sites.size() == 6, "Expanded map lacks six points of interest")
	var refinery = sites.filter(func(site): return site.kind == "refinery")[0]
	var camp = sites.filter(func(site): return site.kind == "mercenary")[0]
	var shop = sites.filter(func(site): return site.kind == "repair")[0]
	var armor = _spawn("Tank", _human, refinery.position + Vector3(3.8, 0, 0))
	await _frames(5)
	_game.battlefield.invalidate()
	refinery._physics_process(11)
	_check(
		refinery.captured_by == null and refinery.progress == 0,
		"Armor captured an infantry objective"
	)
	armor.position += Vector3(20, 0, 0)
	var soldier = _spawn("Infantry", _human, refinery.position + Vector3(3.8, 0, 0))
	await _frames(5)
	_claim(refinery, soldier, _human)
	var funds = Vector2i(_human.resource_a, _human.resource_b)
	var pump_phase = refinery.machinery.phase
	refinery._physics_process(10)
	_check(refinery.machinery.phase != pump_phase, "Producing refinery pump did not animate")
	_check(
		Vector2i(_human.resource_a, _human.resource_b) == funds + Vector2i(2, 1),
		"Captured refinery failed to pay finite income"
	)
	_check(
		refinery.stock_a == 598 and refinery.stock_b == 299, "Refinery did not consume its stock"
	)
	var resources = _game.find_child("ResourcesBar")
	resources._refresh()
	_check(
		(
			resources._income_labels[1].visible
			and resources._income_labels[1].text == resources.tr("+%d / 10s") % 2
			and resources._income_labels[2].visible
			and resources._income_labels[2].text == resources.tr("+%d / 10s") % 1
		),
		"Refinery trickle missing from resource readouts"
	)
	_check(
		(
			(refinery.tr("+%d M / +%d E every 10 s · next in %ds") % [2, 1, 10])
			in refinery._label.text
		),
		"Refinery payout countdown is missing"
	)
	soldier.position += Vector3(20, 0, 0)
	_game.battlefield.invalidate()
	funds = Vector2i(_human.resource_a, _human.resource_b)
	refinery._physics_process(30)
	_check(
		(
			refinery.captured_by == _human
			and refinery.operational()
			and Vector2i(_human.resource_a, _human.resource_b) == funds + Vector2i(6, 3)
		),
		"Vacant captured refinery lost ownership or stopped paying"
	)
	soldier.position = refinery.position + Vector3(3.8, 0, 0)
	var rival = _spawn("Infantry", _enemy, refinery.position + Vector3(-3.8, 0, 0))
	await _frames(5)
	_game.battlefield.invalidate()
	funds = Vector2i(_human.resource_a, _human.resource_b)
	pump_phase = refinery.machinery.phase
	refinery._physics_process(20)
	_check(refinery.machinery.phase == pump_phase, "Contested refinery kept pumping")
	_check(
		refinery.contested and Vector2i(_human.resource_a, _human.resource_b) == funds,
		"Contested refinery kept paying"
	)
	resources._refresh()
	_check(
		(
			resources._income_labels[1].text == resources.tr("+%d / 10s") % 0
			and refinery.tr("Income paused") in refinery._label.text
		),
		"Contested refinery still advertises active income"
	)
	rival.position += Vector3(20, 0, 0)
	_claim(camp, soldier, _human)
	# Open recruitment from the captured camp, then buy through the displayed UI.
	_check(camp.has_node("RecruitmentArea"), "Captured camp cannot be clicked")
	var click = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	camp.get_node("RecruitmentArea").input_event.emit(null, click, Vector3.ZERO, Vector3.UP, 0)
	await _frames(2)
	var menu = _game.find_child("UnitMenus")
	_check(menu._camp == camp and menu.visible, "Camp did not open standard production console")
	_check(_game.hud._overlay == null and not paused, "Camp recruitment interrupted live play")
	var hire = menu._camp_buttons[0].button
	_check(not hire.disabled, "Owned camp has no enabled recruitment control")
	hire.pressed.emit()
	_check(camp.jobs.size() == 1, "Recruitment button did not queue a mercenary")
	_check(
		menu._queue._queue_elements.get_child_count() == 1,
		"Contract missing from shared queue tray"
	)
	menu._queue._queue_elements.get_child(0).pressed.emit()
	_check(camp.jobs.is_empty(), "Shared queue did not cancel recruitment")

	var cost = catalog.price(_human.faction, "MercenaryLancer")
	funds = Vector2i(_human.resource_a, _human.resource_b)
	_check(camp.hire(_human, "MercenaryLancer"), "Owned camp rejected affordable recruitment")
	_check(
		(
			Vector2i(_human.resource_a, _human.resource_b)
			== funds - Vector2i(cost.resource_a, cost.resource_b)
		),
		"Mercenary recruitment did not debit the displayed price"
	)
	_check(not camp.hire(_enemy, "MercenaryWarden"), "Opponent purchased from a captured camp")
	var before = _human.population(true)
	_check(camp.cancel_hire(_human), "Camp cancellation failed")
	_check(
		(
			_human.population(true) == before - 1
			and Vector2i(_human.resource_a, _human.resource_b) == funds
		),
		"Camp cancellation lost its reservation or refund"
	)
	camp.hire(_human, "MercenaryWarden")
	var infantry_count = (
		_human
		. get_children()
		. filter(func(unit): return "type" in unit and unit.type == "MercenaryWarden")
		. size()
	)
	camp._physics_process(30)
	_check(
		(
			camp.jobs.is_empty()
			and (
				(
					_human
					. get_children()
					. filter(func(unit): return "type" in unit and unit.type == "MercenaryWarden")
					. size()
				)
				== infantry_count + 1
			)
		),
		"Paid mercenary never exited camp"
	)
	# Remove the completed recruit from the capture ring before recapture.
	for unit in _human.get_children():
		if "type" in unit and unit.type == "MercenaryWarden" and unit != soldier:
			unit.position = Vector3(10, 0, 10)
	camp.hire(_human, "MercenaryLancer")
	funds = Vector2i(_human.resource_a, _human.resource_b)
	soldier.position = Vector3(10, 0, 10)
	_claim(camp, rival, _enemy)
	_check(
		(
			camp.jobs.is_empty()
			and (
				Vector2i(_human.resource_a, _human.resource_b)
				== funds + Vector2i(cost.resource_a, cost.resource_b)
			)
		),
		"Capture stole an unfinished mercenary contract"
	)
	rival.position = Vector3(170, 0, 120)
	_claim(shop, soldier, _human)
	_check(
		(
			catalog.services(_human).has(shop)
			and catalog.services(_human).all(
				func(service): return "hp" in service and "type" in service
			)
		),
		"Service discovery included player controllers or omitted a captured repair shop"
	)
	armor.position = shop.position + Vector3(3.8, 0, 1)
	armor.hp = armor.hp_max * .5
	_game.battlefield.invalidate()
	var hp = armor.hp
	_game.repair_service.service(1)
	_check(armor.hp > hp, "Captured repair shop did not service machinery")
	var recover = load("res://source/match/units/actions/RecoveringAtService.gd")
	armor.action = recover.new(shop)
	_claim(camp, soldier, _human)
	await _service_safeguards(camp, refinery)
	await _mercenary_combat(camp, catalog)
	camp.hire(_human, "MercenaryRanger")
	camp._physics_process(20)
	camp.hire(_human, "MercenaryLancer")
	paused = true
	var builder = load("res://source/match/saves/MatchSnapshot.gd").new()
	var data = builder.capture(_game)
	var schema = load("res://source/match/saves/SnapshotSchema.gd").new()
	_check(
		data != null and schema.validate(data),
		"Facility capture/recovery/contract save failed: " + schema.error
	)
	if data == null:
		return
	_check(
		not schema._site_records(1, "res://source/match/maps/DesertFrontier.tscn"),
		"Legacy map accepted malformed facility records"
	)
	var legacy = data.duplicate(true)
	for site in legacy.mission.points_of_interest:
		if not site.jobs.is_empty():
			site.jobs[0] = {
				"role": "Infantry",
				"left": 8.0,
				"paid_cost": catalog.price(_human.faction, "Infantry")
			}
	_check(schema.validate(legacy), "Legacy paid mercenary contract was rejected: " + schema.error)
	var bad = data.duplicate(true)
	bad.mission.points_of_interest = 1
	_check(not schema.validate(bad), "Archive accepted malformed facility records")
	bad = data.duplicate(true)
	bad.mission.points_of_interest[0].stock_a = 601
	_check(not schema.validate(bad), "Archive granted extra refinery stock")
	bad = data.duplicate(true)
	bad.mission.points_of_interest[1].id = bad.mission.points_of_interest[0].id
	_check(not schema.validate(bad), "Archive duplicated a facility identity")
	var restored = await load("res://source/match/saves/MatchRestore.gd").new().restore(self, data)
	_check(restored.ok, "Facility archive restore failed: " + restored.get("error", ""))
	if restored.ok:
		_game = restored.game
		var again = builder.capture(_game)
		_check(
			paused and again.mission == data.mission,
			"Paused restore changed facility ownership, timers or contracts"
		)
		_game.hud.open_sites()
		_check(
			(
				_game.hud._overlay != null
				and _game.hud._overlay.find_child("PointOfInterestOverview", true, false) != null
			),
			"Capturable facilities lack usable controls"
		)
		_game.hud._close_menu()
	paused = false


func _service_safeguards(camp, refinery):
	# The actual service clock, not just tree scheduling, must obey pause.
	camp.hire(_human, "MercenaryWarden")
	var job_clock = camp.jobs[0].left
	var stock = Vector2i(refinery.stock_a, refinery.stock_b)
	var income_clock = refinery.income_left
	var pump_phase = refinery.machinery.phase
	paused = true
	camp._physics_process(60)
	refinery._physics_process(60)
	_check(
		(
			camp.jobs[0].left == job_clock
			and Vector2i(refinery.stock_a, refinery.stock_b) == stock
			and refinery.income_left == income_clock
			and refinery.machinery.phase == pump_phase
		),
		"Paused facility advanced recruitment or refinery income"
	)
	paused = false
	camp.cancel_hire(_human)
	# Depleted facilities remain visibly stopped even while still owned.
	refinery.stock_a = 0
	refinery.stock_b = 0
	refinery._physics_process(3)
	_check(refinery.machinery.phase == pump_phase, "Depleted refinery kept pumping")
	refinery.stock_a = stock.x
	refinery.stock_b = stock.y
	# An occupied exit keeps the paid contract rather than dropping or overlapping it.
	var blockers = []
	for ring in [4.5, 5.5, 6.5]:
		for index in 12:
			var angle = index * TAU / 12
			blockers.append(
				_spawn("Tank", _human, camp.position + Vector3(sin(angle), 0, cos(angle)) * ring)
			)
	await _frames(3)
	camp.hire(_human, "MercenaryWarden")
	var population = _human.population(false)
	camp._physics_process(60)
	_check(
		camp.jobs.size() == 1 and camp.jobs[0].left == 0 and _human.population(false) == population,
		"Blocked camp exit lost a paid recruit or spawned overlapping units"
	)
	for blocker in blockers:
		blocker.queue_free()
	await _frames(3)
	camp._physics_process(1)
	_check(
		camp.jobs.is_empty() and _human.population(false) == population + 1 - blockers.size(),
		"Cleared camp exit did not release its waiting recruit"
	)
	# Camp reservations share the ordinary global mobile population limit.
	var filler = []
	while _human.population(true) < 99:
		filler.append(_spawn("Worker", _human, Vector3(12, 0, 10)))
	_check(camp.hire(_human, "MercenaryWarden"), "Camp rejected the last legal population slot")
	var funds = Vector2i(_human.resource_a, _human.resource_b)
	_check(
		(
			_human.population(true) == 100
			and not camp.hire(_human, "MercenaryWarden")
			and Vector2i(_human.resource_a, _human.resource_b) == funds
		),
		"Camp ignored its reserved population slot or charged a rejected contract"
	)
	camp._physics_process(60)
	_check(
		camp.jobs.is_empty() and _human.population(false) == 100,
		"A reserved camp contract could not complete at the population limit"
	)
	for unit in filler:
		unit.queue_free()
	await _frames(3)


func _mercenary_combat(camp, sites):
	var factions = load("res://source/match/FactionCatalog.gd")
	var combat = load("res://source/match/combat/CombatRules.gd")
	for role in sites.ROLES:
		_check(
			role not in factions.Bastion.PRODUCES.Barracks, "Camp recruit is available at barracks"
		)
		var origin = camp.position + Vector3(0, 0, 12)
		var recruit = _spawn(role, _human, origin)
		var target = _spawn(
			"Tank" if role == "MercenaryLancer" else "Infantry", _enemy, origin + Vector3(0, 0, 4)
		)
		_check(combat.armor_for(role) == 0, "Mercenary uses structure armor")
		_check(factions.portrait(_human.faction, role) != null, "Mercenary lacks a portrait")
		recruit.process_mode = Node.PROCESS_MODE_INHERIT
		_game.hud.select_units([recruit])
		await _frames(3)
		_check(
			_game.find_child("UnitMenus")._title.text == factions.title(_human.faction, role),
			"Mercenary selection lost its identity"
		)
		var hp = target.hp
		recruit.issue_manual_order(
			load("res://source/match/units/actions/AttackingWhileInRange.gd").new(target)
		)
		await _frames(210)
		_check(
			not is_instance_valid(target) or target.hp < hp,
			"Mercenary weapon did not deal damage: " + role
		)
		recruit.queue_free()
		if is_instance_valid(target):
			target.queue_free()
		await _frames(3)
