extends "res://tests/headless/Skirmish.gd"

var moving
var attack_move
var recover
var behavior
var game
var human
var opponent
var actors = []


func _run():
	moving = load("res://source/match/units/actions/Moving.gd")
	attack_move = load("res://source/match/units/actions/AttackMoving.gd")
	recover = load("res://source/match/units/actions/RecoveringAtService.gd")
	behavior = load("res://source/match/orders/UnitBehavior.gd")
	factions = load("res://source/match/FactionCatalog.gd")
	constants = root.get_node("Constants")
	root.get_node("SaveManager").autosaves_enabled = false
	var settings = _settings("bastion", "frontier", true)
	settings.map_path = "res://source/match/maps/PlainAndSimple.tscn"
	game = await _start(settings)
	human = game._get_human_player()
	opponent = get_nodes_in_group("players").filter(func(side): return side != human)[0]
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	for unit in get_nodes_in_group("units"):
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	opponent.coordination_unlocked = true
	await _stationary_fire()
	await _clear_actors()
	await _moving_authority(false)
	await _clear_actors()
	await _moving_authority(true)
	await _clear_actors()
	await _recovery()
	await _clear_actors()
	paused = false
	game.queue_free()
	await _frames(5)
	for message in _errors:
		push_error(message)
	print("Frontier maneuver AI: %d failures" % _errors.size())
	quit(0 if _errors.is_empty() else 1)


func _spawn(role, point, player):
	var unit = load(Catalog.scene_path(role)).instantiate()
	game._setup_and_spawn_unit(unit, Transform3D(Basis(), point), player, false)
	actors.append(unit)
	return unit


func _clear_actors():
	paused = false
	for unit in actors:
		unit.queue_free()
	actors.clear()
	await _frames(5)
	game.battlefield.invalidate()


func _stationary_fire():
	var unit = _spawn("CombatRobot", Vector3(25, 0, 25), opponent)
	var target = _spawn("Tank", Vector3(29, 0, 25), human)
	target.process_mode = Node.PROCESS_MODE_DISABLED
	unit.issue_manual_order(attack_move.new(unit.position))
	var hp = target.hp
	await _frames(150)
	paused = true
	_check(target.hp < hp, "Stationary fixture never fired an actual shot")
	_check(not unit.get_node("Movement")._has_destination, "Firing fixture is travelling")
	_check(opponent.signatures.eligible(unit), "Stationary fixture lacks ready Maneuver")
	var order = unit.action
	opponent._use_signatures([unit])
	_check(unit.signature.kind == "", "AI spent Maneuver while stationary firing")
	_check(unit.signature.cooldown == 0, "Stationary firing consumed Maneuver cooldown")
	_check(unit.action == order, "Ability decision replaced stationary firing")
	print("MANEUVER stationary actual shot; cooldown=", unit.signature.cooldown)


func _moving_authority(guarded):
	var unit = _spawn("CombatRobot", Vector3(22, 0, 25), opponent)
	var target = _spawn("Tank", Vector3(3, 0, 45), human)
	target.process_mode = Node.PROCESS_MODE_DISABLED
	if guarded:
		_check(behavior.guard(unit, Vector3(34, 0, 25)), "Moving guard order was rejected")
	else:
		unit.issue_manual_order(moving.new(Vector3(34, 0, 25)))
	var start = unit.position
	await _frames(30)
	paused = true
	game.battlefield.invalidate()
	_check(unit.position.distance_to(start) > .1, "Maneuver fixture never moved")
	_check(unit.get_node("Movement")._has_destination, "Maneuver fixture has no active route")
	_check(not game.battlefield.is_observed(opponent, target), "Hidden contact fixture is visible")
	opponent._use_signatures([unit])
	_check(unit.signature.kind == "", "Hidden enemy triggered Maneuver")
	target.position = unit.position + Vector3(0, 0, 7)
	game.battlefield.invalidate()
	_check(game.battlefield.is_observed(opponent, target), "Moving contact fixture is hidden")
	var order = unit.action
	var stance = unit.stance
	var destination = unit.get_node("Movement").target_position
	var base_speed = unit.movement_speed
	opponent._use_signatures([unit])
	_check(unit.signature.kind == "maneuver", "Visible movement did not trigger Maneuver")
	_check(unit.action == order, "Maneuver replaced moving action")
	_check(unit.stance == stance, "Maneuver changed the unit's stance")
	_check(unit.get_node("Movement").target_position == destination, "Maneuver changed route")
	_check(is_equal_approx(unit.movement_speed, base_speed * 1.35), "Maneuver speed not applied")
	var group = unit.signature.group_id
	opponent._use_signatures([unit])
	_check(unit.signature.group_id == group, "Repeated decision bypassed cohort cooldown")
	target.position = Vector3(3, 0, 45)
	game.battlefield.invalidate()
	start = unit.position
	paused = false
	await _frames(30)
	_check(unit.position.distance_to(start) > .2, "Maneuver unit failed actual continued travel")
	print("MANEUVER moving ", "guard" if guarded else "manual", " authority preserved")


func _recovery():
	var unit = _spawn("CombatRobot", Vector3(23, 0, 25), opponent)
	var service = _spawn("RepairDepot", Vector3(38, 0, 25), opponent)
	var target = _spawn("Infantry", Vector3(19, 0, 25), human)
	target.process_mode = Node.PROCESS_MODE_DISABLED
	unit.hp = unit.hp_max * .25
	game.battlefield.invalidate()
	opponent._command_army([unit, service])
	_check(
		is_instance_of(unit.action, recover), "Wounded unit did not receive ordinary recovery order"
	)
	var order = unit.action
	var start = unit.position
	await _frames(30)
	paused = true
	game.battlefield.invalidate()
	_check(unit.position.distance_to(start) > .1, "Recovery fixture never travelled")
	_check(unit.get_node("Movement")._has_destination, "Recovery fixture has no route")
	_check(game.battlefield.is_observed(opponent, target), "Recovery contact fixture is hidden")
	var destination = unit.get_node("Movement").target_position
	opponent._command_army([unit, service])
	_check(unit.signature.kind == "maneuver", "AI excluded moving recovery from Maneuver")
	_check(
		unit.action == order and is_instance_of(unit.action, recover),
		"Maneuver stole recovery order"
	)
	_check(unit.get_node("Movement").target_position == destination, "Maneuver rerouted recovery")
	if is_instance_of(unit.action, recover):
		_check(unit.action._target == service, "Maneuver changed recovery facility")
	print("MANEUVER recovery retained; boost=", unit.signature.kind)
