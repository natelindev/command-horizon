extends "res://tests/headless/PointOfInterestRegression.gd"

var _site_orders
var _site_catalog
var _production
var _economy
var _attack


func _run():
	_site_orders = load("res://source/match/players/skirmish-ai/SkirmishSites.gd")
	_site_catalog = load("res://source/match/world/PointOfInterestCatalog.gd")
	_production = load("res://source/match/players/skirmish-ai/SkirmishProduction.gd")
	_economy = load("res://source/match/players/skirmish-ai/SkirmishEconomy.gd")
	_attack = load("res://source/match/units/actions/AttackMoving.gd")
	root.get_node("SaveManager").autosaves_enabled = false
	for faction in ["bastion", "helix", "frontier"]:
		await _open_sites(faction)
		for unit in _enemy._units():
			if unit.get_node_or_null("ProductionQueue") != null:
				unit.production_queue.cancel_all()
		await _capture_detachment()
		await _recruitment_budget()
		_alternate_camp()
		await _clear()
		paused = false
		_game.queue_free()
		await _frames(5)
		print("AI SITES faction=", faction, " cumulative_failures=", _errors.size())
	for message in _errors:
		push_error(message)
	print("Skirmish facilities AI: %d failures" % _errors.size())
	quit(0 if _errors.is_empty() else 1)


func _soldiers():
	return _enemy._units().filter(func(unit): return Catalog.is_infantry(unit.type))


func _capture_detachment():
	var sites = _game.map.points_of_interest
	var target = sites.filter(func(site): return site.kind == "refinery")[0]
	for site in sites:
		site.captured_by = _enemy if site != target else null
	var opening = _soldiers()
	_check(opening.size() == 2, "Opening-screen fixture did not contain two infantry")
	var prior = opening.map(func(unit): return unit.action)
	var commanded = _site_orders.command(_game, _enemy, _enemy._units(), _enemy._units(), [])
	_check(commanded.is_empty(), "Two opening infantry were diverted to capture")
	_check(opening.map(func(unit): return unit.action) == prior, "Opening screen orders changed")
	for index in 2:
		_spawn("Infantry", _enemy, target.position + Vector3(-8, 0, 14 + index * 2))
	await _frames(5)
	var soldiers = _soldiers()
	_check(soldiers.size() == 4, "Four-soldier detachment fixture is invalid")
	var actions = {}
	for unit in soldiers:
		actions[unit] = unit.action
	_game.battlefield.invalidate()
	_check(
		not _production.under_raid(_game, _enemy, _enemy._units()), "Capture fixture is under raid"
	)
	commanded = _site_orders.command(_game, _enemy, _enemy._units(), _enemy._units(), [])
	_check(commanded.size() == 1, "Four healthy infantry did not send exactly one capturer")
	if commanded.size() != 1:
		return
	var capturer = commanded[0]
	_check(
		capturer.action != null and capturer.action.get_script() == _attack,
		"Capturer did not receive a real attack-move order"
	)
	_check(capturer.action.destination == target.position, "Capturer chose the wrong facility")
	_check(
		capturer.get_meta("site_capture").get_ref() == target,
		"Detachment forgot its capture objective"
	)
	var home = soldiers.filter(func(unit): return unit != capturer)
	_check(home.size() == 3, "Capture assignment did not retain three infantry")
	for unit in home:
		_check(unit.action == actions[unit], "A non-detached infantry order was replaced")
	var original_action = capturer.action
	commanded = _site_orders.command(_game, _enemy, _enemy._units(), _enemy._units(), [])
	_check(commanded == [capturer], "Repeated AI tick detached another soldier")
	_check(capturer.action == original_action, "Repeated AI tick restarted an unchanged order")
	_enemy._command_army(_enemy._units())
	_check(
		(
			capturer.action != null
			and capturer.action.get_script() == _attack
			and capturer.action.destination == target.position
		),
		"Army coordination stole the assigned capture detachment"
	)
	var tired = home[0]
	tired.hp = tired.hp_max * .64
	_check(
		_site_orders.command(_game, _enemy, _enemy._units(), _enemy._units(), []).is_empty(),
		"A wounded four-unit screen was treated as four healthy capturers"
	)
	tired.hp = tired.hp_max
	# Put a real observer inside sight range without entering the capture ring.
	soldiers[0].position = target.position + Vector3(-6, 0, 7)
	var defender = _spawn("Tank", _human, target.position + Vector3(0, 0, 4))
	await _frames(5)
	_game.battlefield.invalidate()
	var observed = _economy.contacts(_game, _enemy)
	_check(defender in observed, "Unsafe-site defender is not actually visible")
	_check(
		not _production.under_raid(_game, _enemy, _enemy._units()),
		"Site defender falsely raids home"
	)
	_check(
		_site_orders.command(_game, _enemy, _enemy._units(), _enemy._units(), observed).is_empty(),
		"AI detached infantry to a visibly defended facility"
	)
	defender.position = target.position + Vector3(0, 0, -10)
	_game.battlefield.invalidate()
	observed = _economy.contacts(_game, _enemy)
	_check(defender not in observed, "Hidden-site fixture is still visible")
	commanded = _site_orders.command(_game, _enemy, _enemy._units(), _enemy._units(), observed)
	_check(commanded.size() == 1, "AI inspected hidden defenders before choosing a public facility")
	var hq = _enemy._units().filter(func(unit): return unit.type == "CommandCenter")[0]
	defender.position = hq.position + Vector3(7, 0, 0)
	_game.battlefield.invalidate()
	observed = _economy.contacts(_game, _enemy)
	_check(
		defender in observed and _production.under_raid(_game, _enemy, _enemy._units()),
		"Home-raid fixture is not a visible threat"
	)
	_check(
		_site_orders.command(_game, _enemy, _enemy._units(), _enemy._units(), observed).is_empty(),
		"Facility detachment ignored a visible home raid"
	)
	_enemy.resource_a = 5000
	_enemy.resource_b = 5000
	_site_orders.recruit(_game, _enemy, _enemy._units(), "")
	_check(_contracts() == 0, "AI spent on mercenaries during a home raid")
	defender.queue_free()
	await _frames(5)
	_game.battlefield.invalidate()


func _contracts():
	var count = 0
	for site in _game.map.points_of_interest:
		count += site.jobs.size()
	return count


func _recruitment_budget():
	var camps = _game.map.points_of_interest.filter(func(site): return site.kind == "mercenary")
	# Use the real ten-second infantry capture before testing paid recruitment.
	camps[0].captured_by = null
	var soldier = _soldiers()[0]
	_claim(camps[0], soldier, _enemy)
	var units = _enemy._units()
	var desired = "AircraftFactory"
	var building = _production.reserve(_enemy, units, desired)
	var urgent = Vector2i.ZERO
	var priority_jobs = []
	for job in _production.requests(_game, _enemy, units):
		if job.priority <= 2:
			urgent += Vector2i(job.cost.resource_a, job.cost.resource_b)
			priority_jobs.append(job)
	_check(
		building.x > 0 and urgent.x > 0, "Recruitment fixture has no real building/urgent reserve"
	)
	var reserve = building + urgent
	# The commander hires the camp's anti-armor Breach Lancer at its fixed contract price.
	var price = _site_catalog.price("MercenaryLancer")
	var contract = load("res://source/match/world/MercenaryCatalog.gd").UNITS.MercenaryLancer.cost
	_check(
		price.resource_a == contract[0] and price.resource_b == contract[1],
		"Camp price differs from the Breach Lancer contract"
	)
	var cost = Vector2i(price.resource_a, price.resource_b)
	_enemy.resource_a = reserve.x + cost.x - 1
	_enemy.resource_b = reserve.y + cost.y
	var funds = Vector2i(_enemy.resource_a, _enemy.resource_b)
	_site_orders.recruit(_game, _enemy, units, desired)
	_check(
		_contracts() == 0 and Vector2i(_enemy.resource_a, _enemy.resource_b) == funds,
		"Mercenary hire spent protected production materials"
	)
	if cost.y > 0:
		_enemy.resource_a = reserve.x + cost.x
		_enemy.resource_b = reserve.y + cost.y - 1
		funds = Vector2i(_enemy.resource_a, _enemy.resource_b)
		_site_orders.recruit(_game, _enemy, units, desired)
		_check(
			_contracts() == 0 and Vector2i(_enemy.resource_a, _enemy.resource_b) == funds,
			"Mercenary hire spent protected production electronics"
		)
	_enemy.resource_a = reserve.x + cost.x
	_enemy.resource_b = reserve.y + cost.y
	_site_orders.recruit(_game, _enemy, units, desired)
	_check(_contracts() == 1, "Recruitment tick queued zero or multiple camp contracts")
	_check(
		Vector2i(_enemy.resource_a, _enemy.resource_b) == reserve,
		"Camp did not debit its contract price exactly once"
	)
	var busy = camps.filter(func(site): return not site.jobs.is_empty())
	_check(
		busy.size() == 1 and busy[0].jobs[0].role == "MercenaryLancer",
		"AI camp queued the wrong paid role"
	)
	_site_orders.recruit(_game, _enemy, units, desired)
	_check(
		_contracts() == 1 and Vector2i(_enemy.resource_a, _enemy.resource_b) == reserve,
		"Next recruitment tick consumed protected funds or duplicated a contract"
	)
	_enemy._train(units, desired)
	for job in priority_jobs:
		_check(
			job.producer.production_queue.size() > 0,
			"Camp reserve prevented normal urgent production"
		)
	_check(
		_enemy.resource_a >= building.x and _enemy.resource_b >= building.y,
		"Paid production lost its building reserve after mercenary hire"
	)
	for camp in camps:
		while not camp.jobs.is_empty():
			camp.cancel_hire(_enemy)


func _alternate_camp():
	var camps = _game.map.points_of_interest.filter(func(site): return site.kind == "mercenary")
	camps[0].contested = true
	camps[1].contested = false
	_enemy.resource_a = 5000
	_enemy.resource_b = 5000
	_site_orders.recruit(_game, _enemy, _enemy._units(), "")
	_check(
		camps[0].jobs.is_empty() and camps[1].jobs.size() == 1,
		"A contested first camp prevented recruitment from the other operational camp"
	)
	camps[0].contested = false
	for camp in camps:
		while not camp.jobs.is_empty():
			camp.cancel_hire(_enemy)
