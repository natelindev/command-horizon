extends "res://tests/headless/AmbientLifeRegression.gd"

const Roster = preload("res://source/match/BastionCatalog.gd")
var Factions
var Combat
var human
var opponent
var barracks
var other_barracks


func _run():
	Factions = load("res://source/match/FactionCatalog.gd")
	Combat = load("res://source/match/combat/CombatRules.gd")
	path = "user://infantry-heroes-%d.json" % OS.get_process_id()
	root.get_node("SaveManager").autosaves_enabled = false
	for faction in Factions.IDS:
		await _fixture(faction)
		await _production_and_identity()
		await _ai_reinforcements()
		await _combat_and_garrison()
		await _close()
	for message in errors:
		push_error(message)
	print("Infantry and heroes: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _fixture(faction):
	var settings = load("res://source/data-model/MatchSettings.gd").new()
	settings.skirmish = true
	settings.map_path = "res://source/match/maps/IndustrialCrossroads.tscn"
	settings.visibility = settings.Visibility.FULL
	for index in 2:
		var side = load("res://source/data-model/PlayerSettings.gd").new()
		side.controller = index + 1
		side.faction = faction
		settings.players.append(side)
	game = load("res://source/match/Skirmish.tscn").instantiate()
	game.settings = settings
	game.map = load(settings.map_path).instantiate()
	root.add_child(game)
	current_scene = game
	await _frames(45)
	_freeze_units()
	human = game._get_human_player()
	opponent = get_nodes_in_group("players").filter(func(side): return side != human)[0]
	human.resource_a = 1000
	human.resource_b = 1000
	opponent.resource_a = 1000
	opponent.resource_b = 1000
	barracks = _soldier("Barracks", human, Vector3(24, 0, 20))
	other_barracks = _soldier("Barracks", human, Vector3(32, 0, 20))
	_soldier("PowerPlant", human, Vector3(20, 0, 10))


func _soldier(role, player, point):
	var unit = load(Roster.scene_path(role)).instantiate()
	game._setup_and_spawn_unit(unit, Transform3D(Basis(), point), player, false)
	unit.process_mode = Node.PROCESS_MODE_DISABLED
	return unit


func _production_and_identity():
	var queue = barracks.production_queue
	var second = other_barracks.production_queue
	var prototype = load(Roster.scene_path("Hero"))
	_check(queue.produce(prototype) == null, "Hero ignores lab requirement")
	var lab = _soldier("CommandLab", human, Vector3(35, 0, 10))
	var funds = Vector2i(human.resource_a, human.resource_b)
	var job = queue.produce(prototype)
	_check(job != null, "Cannot enqueue faction hero")
	_check(queue.blocked_reason() == "", "Hero blocks its own reserved queue")
	_check(second.produce(prototype) == null, "Second barracks reserved duplicate hero")
	_check(queue.produce(prototype, true) == null, "Ignore queue limit bypassed hero uniqueness")
	var info = load("res://source/match/hud/RosterInfo.gd").inspect(other_barracks, "Hero", false)
	_check(not info.allowed and "A hero is already" in info.text, "Hero UI omits uniqueness reason")
	await _archive(false)
	queue = barracks.production_queue
	second = other_barracks.production_queue
	job = queue.get_elements()[0]
	_check(queue.blocked_reason() == "", "Restored reservation blocks hero")
	queue.cancel(job)
	_check(
		Vector2i(human.resource_a, human.resource_b) == funds, "Hero cancellation refund differs"
	)
	job = second.produce(prototype)
	_check(job != null, "Cancellation did not release global reservation")
	other_barracks.hp = 0
	await _frames(2)
	_check(Factions.available(human, "Hero"), "Destroyed producer keeps hero reserved")
	job = queue.produce(prototype)
	lab = _units(human, "CommandLab")[0]
	lab.hp = 0
	await _frames(2)
	var left = job.time_left
	queue._process(5)
	_check(job.time_left == left, "Hero trains without its required lab")
	_soldier("CommandLab", human, Vector3(35, 0, 10))
	queue._process(100)
	await _frames(2)
	var heroes = _units(human, "Hero")
	_check(heroes.size() == 1, "Paid hero did not produce exactly one unit")
	if heroes.is_empty():
		return
	var hero = heroes[0]
	hero.process_mode = Node.PROCESS_MODE_DISABLED
	_check(
		hero.has_node("HeroAura/AuraRing") and hero.has_node("HeroAura/HeroCrown"),
		"Hero visual identity missing"
	)
	_check(queue.produce(prototype) == null, "Living hero allows duplicate production")
	var enemy_barracks = _soldier("Barracks", opponent, Vector3(104, 0, 103))
	_soldier("CommandLab", opponent, Vector3(114, 0, 103))
	_check(
		enemy_barracks.production_queue.produce(prototype) != null,
		"Opponent shares hero reservation"
	)
	enemy_barracks.production_queue.cancel_all()
	await _archive(true)
	hero = _units(human, "Hero")[0]
	_check(hero.has_node("HeroAura"), "Hero aura lost after restore")
	hero.hp = 0
	await _frames(2)
	_check(barracks.production_queue.produce(prototype) != null, "Hero death does not release slot")
	barracks.production_queue.cancel_all()
	for role in Roster.INFANTRY_ROLES:
		var trained = barracks.production_queue.produce(load(Roster.scene_path(role)))
		_check(trained != null, "Barracks refuses " + role)
		barracks.production_queue._process(100)
		await _frames(2)
		_check(not _units(human, role).is_empty(), "Production did not spawn " + role)
		# Keep the doorway free while testing the entire roster with frozen units.
		for trained_unit in _units(human, role):
			trained_unit.position = Vector3(42 + Roster.INFANTRY_ROLES.find(role) * 2, 0, 12)
	_freeze_units()
	# All five actual UI buttons must exist, including the locked unique hero.
	barracks.get_node("Selection").select()
	await _frames(4)
	for role in Roster.INFANTRY_ROLES:
		_check(
			game.find_child("Produce" + role, true, false) != null,
			"Missing production button " + role
		)


func _combat_and_garrison():
	var rifle = _units(human, "Infantry")[0]
	var rocket = _units(human, "RocketInfantry")[0]
	var sniper = _units(human, "SniperInfantry")[0]
	var assault = _units(human, "AssaultInfantry")[0]
	var armor = _soldier("Tank", opponent, Vector3(50, 0, 20))
	var infantry = _soldier("Infantry", opponent, Vector3(50, 0, 22))
	_check(
		Combat.damage(rocket, armor) > Combat.damage(rifle, armor) * 10,
		"Rocket lacks anti-armor role"
	)
	_check(
		Combat.damage(sniper, infantry) > Combat.damage(sniper, armor) * 8,
		"Sniper lacks infantry specialization"
	)
	_check(
		sniper.attack_range > rocket.attack_range and rocket.attack_range > assault.attack_range,
		"Infantry ranges indistinguishable"
	)
	_check(
		assault.hp_max > rifle.hp_max and assault.attack_interval < rifle.attack_interval,
		"Assault role lacks durability or rapid fire"
	)
	for role in Roster.INFANTRY_ROLES:
		var soldier = _units(human, role)[0]
		_check(Combat.armor_for(role) == 0, "New infantry has vehicle armor")
		_check(
			(
				load("res://source/match/combat/RepairService.gd").facility_for_role(role)
				== "Barracks"
			),
			"Infantry recovers at wrong facility"
		)
		_check(
			soldier.get_node("BastionVisuals").death_motion().tilt.length() > 1,
			"Infantry death uses vehicle animation"
		)
		# Exercise the service path with a real barracks and wounded new infantry.
		barracks.process_mode = Node.PROCESS_MODE_INHERIT
		soldier.position = barracks.position + Vector3(3, 0, 0)
		soldier.get_node("Movement").stop()
		soldier.hp = soldier.hp_max * .5
		var wounded = soldier.hp
		game.repair_service.service(1.0)
		_check(soldier.hp > wounded, role + " did not heal at barracks")
		soldier.hp = soldier.hp_max
		barracks.process_mode = Node.PROCESS_MODE_DISABLED
		# Fire actual projectiles, not only the damage formula.
		soldier.position = Vector3(50, 0, 16)
		game.battlefield.invalidate()
		var before = armor.hp
		game.projectile_system.launch(soldier, armor)
		await _frames(50)
		_check(armor.hp < before, role + " projectile failed to deal damage")
		armor.hp = armor.hp_max
	var building = game.get_node("NeutralWorld").buildings[0]
	var troops = []
	for role in Roster.INFANTRY_ROLES:
		troops.append(_units(human, role)[0])
	for index in 4:
		troops.append(_soldier("AssaultInfantry", human, Vector3(4, 0, 4)))
	for index in troops.size():
		var unit = troops[index]
		unit.position = building.position + Vector3(building.radius + .3, 0, 0)
		unit.action = load("res://source/match/units/actions/Garrisoning.gd").new(building)
		if index < 8:
			_check(building.enter(unit), "Mixed infantry garrison refused slot " + str(index))
		else:
			_check(not building.enter(unit), "Ninth infantry entered full building")
	_check(building.occupants.size() == 8, "Mixed garrison capacity differs from eight")
	await _archive(true)
	building = game.get_node("NeutralWorld").buildings[0]
	_check(building.occupants.size() == 8, "Eight-person mixed garrison lost on restore")
	var hero = _units(human, "Hero")[0]
	_check(hero.has_meta("garrison_host"), "Hero lost garrison state")
	_check(not Factions.available(human, "Hero"), "Hidden garrison hero loses unique reservation")
	var aura = hero.get_node("HeroAura")
	aura._physics_process(.1)
	_check(not aura.visible, "Garrisoned hero aura remains outside")
	building.leave(hero)
	aura._physics_process(.1)
	_check(aura.visible, "Hero aura did not return after exiting")
	var relay = load("res://source/match/objectives/CaptureRelay.gd").new()
	game.add_child(relay)
	relay.position = Vector3(70, 0, 14)
	hero.position = relay.position + Vector3(1, 0, 0)
	game.battlefield.invalidate()
	_check(relay._capture_presence().infantry.has(human), "Hero cannot capture relay")
	for role in ["RocketInfantry", "SniperInfantry", "AssaultInfantry"]:
		var soldier = _units(human, role)[0]
		building.leave(soldier)
		soldier.position = relay.position + Vector3(1, 0, 0)
		hero.position = Vector3(4, 0, 4)
		game.battlefield.invalidate()
		_check(relay._capture_presence().infantry.has(human), role + " cannot capture relay")
		soldier.position = Vector3(4, 0, 4)


func _archive(live):
	paused = true
	var snapshot = load("res://source/match/saves/MatchSnapshot.gd").new()
	var data = snapshot.capture(game)
	var schema = load("res://source/match/saves/SnapshotSchema.gd").new()
	_check(schema.validate(data), "Expanded army snapshot invalid: " + schema.error)
	var malformed = data.duplicate(true)
	if live:
		var copy = (
			malformed
			. units
			. filter(func(unit): return unit.role == "Hero" and unit.player == "player-0")[0]
			. duplicate(true)
		)
		copy.id = "unit-9999"
		malformed.units.append(copy)
	else:
		var producer = malformed.units.filter(func(unit): return not unit.production.is_empty() and not unit.production.jobs.is_empty())[0]
		producer.production.jobs.append(producer.production.jobs[0].duplicate(true))
	_check(
		not schema.validate(malformed) and schema.error == "Duplicate hero reservation.",
		"Archive accepted duplicate hero reservations or rejected for wrong reason"
	)
	var loader = load("res://source/match/saves/MatchRestore.gd").new()
	var result = await loader.restore(self, data)
	_check(result.ok, "Expanded army restore failed: " + result.get("error", ""))
	if result.ok:
		game = result.game
		human = game._get_human_player()
		opponent = get_nodes_in_group("players").filter(func(side): return side != human)[0]
		barracks = _units(human, "Barracks")[0]
		if _units(human, "Barracks").size() > 1:
			other_barracks = _units(human, "Barracks")[1]
		_freeze_units()
	paused = false


func _ai_reinforcements():
	while _units(opponent, "Infantry").size() < 4:
		_soldier("Infantry", opponent, Vector3(110, 0, 112))
	_soldier("Barracks", opponent, Vector3(108, 0, 115))
	for cycle in 7:
		opponent._train(opponent._units(), "")
		for producer in opponent._units():
			var queue = producer.get_node_or_null("ProductionQueue")
			if queue != null:
				queue._process(100)
		await _frames(2)
		_freeze_units()
	for role in Roster.INFANTRY_ROLES:
		_check(not _units(opponent, role).is_empty(), "AI failed to train " + role)
	_check(_units(opponent, "Hero").size() == 1, "AI produced duplicate heroes across barracks")
