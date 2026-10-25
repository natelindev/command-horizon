extends "res://tests/headless/SkirmishLaborRegression.gd"

var economy
var ai
var engineer
var hq
var material
var electronics


func _run():
	factions = load("res://source/match/FactionCatalog.gd")
	catalog = load("res://source/match/BastionCatalog.gd")
	harvest = load("res://source/match/units/actions/CollectingResourcesSequentially.gd")
	labor = load("res://source/match/players/skirmish-ai/SkirmishLabor.gd")
	economy = load("res://source/match/players/skirmish-ai/SkirmishEconomy.gd")
	root.get_node("SaveManager").autosaves_enabled = false
	await _fixture()
	_guards()
	paused = false
	game.queue_free()
	await _frames(5)
	await _fixture()
	_check(await _opportunity() == true, "Salvage opportunity did not complete")
	paused = false
	game.queue_free()
	await _frames(5)
	for message in errors:
		push_error(message)
	print("Frontier AI salvage: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _fixture():
	var settings = load("res://source/data-model/MatchSettings.gd").new()
	settings.skirmish = true
	settings.advanced_start = true
	settings.map_path = "res://source/match/maps/DesertFrontier.tscn"
	for index in 2:
		var side = load("res://source/data-model/PlayerSettings.gd").new()
		side.controller = index + 1
		side.faction = "bastion" if index == 0 else "frontier"
		settings.players.append(side)
	game = load("res://source/match/Skirmish.tscn").instantiate()
	game.settings = settings
	game.map = load(settings.map_path).instantiate()
	root.add_child(game)
	current_scene = game
	ai = get_nodes_in_group("players").filter(func(p): return p != game._get_human_player())[0]
	_freeze(ai)
	# Park the frozen military clear of the live workers' drop-off approaches.
	var parked = 0
	for unit in ai._units():
		if unit.movement_speed > 0 and unit.attack_range != null:
			unit.position = Vector3(88 + parked * 2, 0, 84)
			parked += 1
	var workers = _units(ai, "Worker")
	engineer = workers[0]
	hq = _units(ai, "CommandCenter")[0]
	material = _deposit(hq, "resource_a")
	electronics = _deposit(hq, "resource_b")
	ai.resource_a = 1000
	ai.resource_b = 1000
	for index in workers.size():
		workers[index].issue_manual_order(harvest.new(material if index == 0 else electronics))
	for frame in 3000:
		if labor.handoff_ready(engineer):
			break
		await physics_frame
	_check(labor.handoff_ready(engineer), "Did not reach a real loaded delivery boundary")
	paused = true


func _wreck(point):
	game.wreck_salvage.pending.append(
		{"role": "Tank", "faction": "bastion", "amount": 4, "position": point}
	)
	game.wreck_salvage.flush()
	return get_nodes_in_group("salvage_wrecks")[-1]


func _choice():
	return economy.deposit(game, engineer, hq, 1, economy.contacts(game, ai))


func _static_stock():
	var total = 0
	for resource in get_nodes_in_group("resource_units"):
		if "resource_a" in resource and not resource.is_in_group("salvage_wrecks"):
			total += resource.resource_a
	return total


func _unchanged(action, label):
	ai._harvest(ai._units())
	_check(engineer.action == action, label + ": interrupted the delivery")
	_check(engineer.resource_a == 4, label + ": changed undelivered cargo")
	_check(engineer.manual_orders.pending.is_empty(), label + ": queued a diversion")


func _guards():
	var action = engineer.action
	_check(labor.plan(game, ai, ai._units())[engineer] == 1, "Fixture must retain materials labor")
	var local = _wreck(material.global_position_yless + Vector3(0, 0, 1))
	_check(_choice() == local, "Local wreck fixture is not preferred")
	_unchanged(action, "Wreck already within current field")
	local.free()
	var hidden = _wreck(Vector3(60, 0, 20))
	_check(not hidden.known_to(ai), "Hidden wreck fixture was observed")
	_unchanged(action, "Hidden wreck")
	hidden.free()
	var wreck = _wreck(hq.global_position_yless + Vector3(5, 0, 2))
	_check(wreck.known_to(ai) and _choice() == wreck, "Safe nearby wreck was not preferred")
	_check(
		material.position.distance_to(wreck.position) > harvest.FIELD_RADIUS,
		"Opportunity must lie outside the engineer's current field"
	)
	var attacker = _spawn("Tank", game._get_human_player(), wreck.global_position_yless)
	_check(
		not economy.safe_approach(wreck, engineer, hq, economy.contacts(game, ai)),
		"Danger fixture did not threaten the salvage route"
	)
	_unchanged(action, "Threatened wreck")
	attacker.free()
	var open_position = wreck.position
	# Placement permits a later building over a nonblocking wreck. Move the
	# already aligned wreck underneath an existing factory to model that state.
	wreck.global_position = _units(ai, "VehicleFactory")[0].global_position
	_check(wreck.known_to(ai), "Covered wreck fixture was not observed")
	_check(_choice() != wreck, "AI chose a wreck without a reachable collection face")
	_unchanged(action, "Wreck covered by factory")
	wreck.position = open_position
	var movement = engineer.get_node("Movement")
	movement._synchronized = false
	_check(_choice() != wreck, "Unsynchronized navigation accepted a wreck")
	_unchanged(action, "Unsynchronized salvage navigation")
	movement._synchronized = true
	# Make a distant observed wreck the best remaining material target, while
	# preserving all stock and the current loaded delivery for the decision.
	var positions = {}
	for resource in get_nodes_in_group("resource_units"):
		if "resource_a" in resource and resource != wreck:
			positions[resource] = resource.position
			resource.position = Vector3(20, 0, 20)
	wreck.position = hq.position + Vector3(-31, 0, 0)
	var observer = _units(ai, "Tank")[0]
	var observer_position = observer.position
	observer.position = wreck.position
	# Observation uses a per-frame spatial index; refresh it after teleporting.
	game.battlefield.invalidate()
	_check(wreck.known_to(ai) and _choice() == wreck, "Far wreck fixture is not observed/preferred")
	_unchanged(action, "Distant wreck")
	observer.position = observer_position
	for resource in positions:
		resource.position = positions[resource]


func _opportunity():
	var action = engineer.action
	var funds = ai.resource_a
	var workers = _units(ai, "Worker")
	var electronic_actions = workers.slice(1).map(func(worker): return worker.action)
	var wreck = _wreck(_home_opportunity_point())
	_check(wreck.known_to(ai) and _choice() == wreck, "Safe nearby wreck was not preferred")
	for structure in ai._units().filter(func(unit): return unit.movement_speed == 0):
		_check(
			(
				wreck.position.distance_to(structure.position)
				> structure.radius + engineer.radius + 1.0
			),
			(
				"Wreck %s overlaps %s at %s (r=%s, engineer r=%s)"
				% [
					wreck.position,
					structure.type,
					structure.position,
					structure.radius,
					engineer.radius
				]
			)
		)
	var nav = game.navigation.get_navigation_map_rid_by_domain(engineer.movement_domain)
	_check(
		(
			NavigationServer3D.map_get_closest_point(nav, wreck.position).distance_to(
				wreck.position
			)
			< .1
		),
		"Wreck fixture is outside reachable navigation ground"
	)
	ai._harvest(ai._units())
	_check(
		labor.queued_target(engineer) == wreck, "Productive materials worker ignored nearby wreck"
	)
	_check(
		engineer.action == action and engineer.resource_a == 4, "Salvage handoff interrupted cargo"
	)
	_check(ai.resource_a == funds, "Queuing salvage awarded undelivered materials")
	for repeat in 5:
		ai._harvest(ai._units())
	_check(
		engineer.manual_orders.pending.size() == 1 and labor.queued_target(engineer) == wreck,
		"Repeated decisions duplicated or replaced the queued wreck"
	)
	for index in range(1, workers.size()):
		_check(
			(
				workers[index].action == electronic_actions[index - 1]
				and workers[index].manual_orders.pending.is_empty()
			),
			"Salvage diverted electronics labor"
		)
	var initial_delivery = false
	var salvaged = false
	var electronic_funds = ai.resource_b
	var static_stock = _static_stock()
	paused = false
	for frame in 2400:
		if frame % 90 == 0:
			ai._harvest(ai._units())
		if engineer.action != action and not initial_delivery:
			initial_delivery = true
			_check(ai.resource_a == funds + 4, "Initial load was not delivered exactly once")
			_check(engineer.resource_a == 0, "Initial cargo was retained after HQ delivery")
		if not is_instance_valid(wreck) or wreck.resource_a < 4:
			salvaged = true
		if salvaged and ai.resource_a >= funds + 8:
			break
		await physics_frame
	_check(
		initial_delivery and salvaged, "Engineer never delivered old cargo then dismantled salvage"
	)
	_check(
		ai.resource_a == funds + 8,
		"HQ delivery plus on-site dismantle did not award exactly eight materials"
	)
	_check(engineer.resource_a == 0, "Delivered salvage remained in cargo")
	_check(not is_instance_valid(wreck), "Depleted wreck remained collectible")
	_check(_static_stock() == static_stock, "Salvage opportunity kept mining the static field")
	# Depletion hands the same engineer back to a productive ordinary field.
	for frame in 1800:
		if frame % 90 == 0:
			ai._harvest(ai._units())
		if ai.resource_a >= funds + 12:
			break
		await physics_frame
	_check(ai.resource_a == funds + 12, "Engineer failed to resume normal materials income")
	_check(
		_static_stock() == static_stock - 4, "Resumed materials income did not use the live field"
	)
	_check(ai.resource_b > electronic_funds, "Electronics economy stopped during salvage")
	print(
		"Salvage deliveries: materials +",
		ai.resource_a - funds,
		" / electronics +",
		ai.resource_b - electronic_funds,
		"; initial delivery=",
		initial_delivery,
		" salvage collected=",
		salvaged
	)
	return true


# Starting resources form compact arcs 18 m from HQ and a field spans 13 m, so
# a fixed offset can fall inside the engineer's current field. Pick an open,
# reachable home point outside that field and clear of every structure.
func _home_opportunity_point():
	var origin = engineer.action._field_origin
	var nav = game.navigation.get_navigation_map_rid_by_domain(engineer.movement_domain)
	var structures = ai._units().filter(func(unit): return unit.movement_speed == 0)
	for distance in [6.0, 8.0, 10.0, 12.0, 14.0]:
		for index in 16:
			var angle = index * TAU / 16
			var point = hq.global_position_yless + Vector3(cos(angle), 0, sin(angle)) * distance
			if point.distance_to(origin) <= harvest.FIELD_RADIUS + 1.0:
				continue
			if structures.any(
				func(structure):
					return (
						point.distance_to(structure.global_position_yless)
						<= structure.radius + engineer.radius + 1.5
					)
			):
				continue
			var ground = NavigationServer3D.map_get_closest_point(nav, point) * Vector3(1, 0, 1)
			if ground.distance_to(point) < .1:
				return point
	_check(false, "No open home salvage point outside the current field")
	return hq.global_position_yless
