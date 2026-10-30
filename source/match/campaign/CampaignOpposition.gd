extends Node

# Authored mission pressure uses the same harvest, power and paid queue rules as
# the player. Destroying workers, generators and producers has a real effect.
const Catalog = preload("res://source/match/BastionCatalog.gd")
const Rules = preload("res://source/match/combat/CombatRules.gd")
const Gather = preload("res://source/match/units/actions/CollectingResourcesSequentially.gd")
const AttackMove = preload("res://source/match/units/actions/AttackMoving.gd")
const BLAST_RADIUS = 3.0
const WARNING_SECONDS = 4.0
var active = false
var production_left = 60.0
var admitted = 0
var reinforcements = []
var boss = null
var boss_started = false
var boss_defeated = false
var warning_left = -1.0
var target_point = Vector3.ZERO
var salvo_left = 8.0
var rally = Vector3.ZERO
var _game
var _enemy
var _marker
var _boss_label


func configure(game, enemy, destination, commander = null):
	_game = game
	_enemy = enemy
	rally = destination
	boss = commander
	boss_defeated = commander == null
	_label_boss()
	MatchSignals.unit_production_finished.connect(_produced)


func activate():
	if active:
		return
	active = true
	_game.hud.show_notice(
		tr("Enemy base operational. Raid its workers, power and production to stop reinforcements.")
	)
	_assign_workers()


func step(delta):
	if not active or _game.finished:
		return
	_assign_workers()
	production_left = maxf(0, production_left - delta)
	if production_left == 0:
		_try_produce()
	_step_boss(delta)


func _assign_workers():
	if not _enemy.has_completed_structure("CommandCenter"):
		return
	var deposits = get_tree().get_nodes_in_group("resource_units").filter(
		func(unit):
			return (
				is_instance_valid(unit)
				and not unit.is_queued_for_deletion()
				and unit.position.x > _game.map.size.x * .7
			)
	)
	if deposits.is_empty():
		return
	var workers = _enemy.get_children().filter(
		func(unit): return _alive(unit) and unit.type == "Worker"
	)
	for index in workers.size():
		var worker = workers[index]
		if worker.action is Gather and not worker.action.needs_assignment():
			continue
		var candidates = deposits.filter(
			func(unit): return ("resource_b" in unit) == (index % 3 == 2)
		)
		if candidates.is_empty():
			continue
		candidates.sort_custom(
			func(a, b):
				return (
					worker.position.distance_squared_to(a.position)
					< worker.position.distance_squared_to(b.position)
				)
		)
		worker.issue_manual_order(Gather.new(candidates[0]))


func _try_produce():
	reinforcements = reinforcements.filter(_alive)
	# A small replenishment group preserves mission rhythm; it never becomes an
	# unlimited stream or bypasses the shared population / queue / cost rules.
	var producers = _enemy.get_children().filter(
		func(unit): return _alive(unit) and unit.type in ["Barracks", "VehicleFactory"]
	)
	var pending = 0
	for producer in producers:
		pending += producer.get_node("ProductionQueue").size()
	if reinforcements.size() + pending >= [2, 3, 4][_enemy.difficulty]:
		production_left = 5.0
		return
	var preferred = "Barracks" if admitted % 2 == 0 else "VehicleFactory"
	producers.sort_custom(func(a, b): return a.type == preferred and b.type != preferred)
	for producer in producers:
		var queue = producer.get_node("ProductionQueue")
		if queue.size() != 0:
			continue
		var role = "Infantry" if producer.type == "Barracks" else "Tank"
		if queue.produce(load(Catalog.scene_path(role))) != null:
			admitted += 1
			production_left = [65.0, 50.0, 40.0][_enemy.difficulty]
			_game.hud.show_notice(
				tr("Enemy base queued a paid reinforcement. Destroy its producer to cancel it.")
			)
			return
	production_left = 5.0


func _produced(unit, producer):
	if not active or producer.player != _enemy:
		return
	reinforcements.append(unit)
	unit.issue_manual_order(AttackMove.new(rally))


func _step_boss(delta):
	if boss_defeated:
		return
	if not _alive(boss):
		boss = null
		boss_defeated = true
		warning_left = -1.0
		_clear_marker()
		_game.hud.show_notice(tr("Siege commander destroyed. Precision barrages stopped."))
		_game._checkpoint("Siege commander destroyed")
		return
	if warning_left >= 0:
		warning_left = maxf(0, warning_left - delta)
		if warning_left == 0:
			for unit in _game.battlefield.nearby_units(target_point, BLAST_RADIUS):
				if (
					_alive(unit)
					and Rules.can_target(boss, unit)
					and unit.movement_domain != Constants.Match.Navigation.Domain.AIR
				):
					unit.receive_weapon_hit(boss)
			warning_left = -1.0
			salvo_left = 14.0
			_clear_marker()
		return
	salvo_left = maxf(0, salvo_left - delta)
	if salvo_left > 0:
		return
	var candidates = _game.battlefield.observed_enemies_near(boss, 22.0).filter(
		func(unit):
			return (
				Rules.can_target(boss, unit)
				and unit.player == _game._get_human_player()
				and unit.movement_domain != Constants.Match.Navigation.Domain.AIR
				and unit.global_position_yless.distance_to(boss.global_position_yless) <= 22.0
			)
	)
	if candidates.is_empty():
		return
	candidates.sort_custom(
		func(a, b):
			return (
				boss.position.distance_squared_to(a.position)
				< boss.position.distance_squared_to(b.position)
			)
	)
	target_point = candidates[0].global_position_yless
	boss_started = true
	warning_left = WARNING_SECONDS
	_show_marker()
	_game.hud.show_notice(
		tr(
			(
				"Siege commander locks a barrage in 4 seconds. "
				+ "Move clear of the marked area; attack during cooldown."
			)
		)
	)


func _show_marker():
	_clear_marker()
	_marker = load("res://source/generic-scenes-and-nodes/3d/Circle3D.tscn").instantiate()
	_marker.radius = BLAST_RADIUS
	_marker.width = 5.0
	_marker.color = Color("f5a35b")
	_marker.position = target_point + Vector3.UP * .06
	_marker.render_priority = 10
	_game.add_child(_marker)


func _clear_marker():
	if is_instance_valid(_marker):
		_marker.queue_free()
	_marker = null


func capture_state(reference: Callable):
	# A tactical pause can land after HP reaches zero but before the next
	# mission tick observes death. Persist the terminal encounter state, not
	# a warning whose source has already left the snapshot entity table.
	var commander_alive = _alive(boss)
	return {
		"active": active,
		"production_left": production_left,
		"admitted": admitted,
		"boss_started": boss_started,
		"boss_defeated": boss_defeated or not commander_alive,
		"boss": reference.call(boss) if commander_alive else "",
		"warning_left": warning_left if commander_alive else -1.0,
		"target": [target_point.x, target_point.y, target_point.z],
		"salvo_left": salvo_left,
		"reinforcements": reinforcements.filter(_alive).map(func(unit): return reference.call(unit))
	}


func restore_state(data, entities):
	active = data.active
	production_left = data.production_left
	admitted = data.admitted
	boss_started = data.boss_started
	boss_defeated = data.boss_defeated
	boss = entities.get(data.boss)
	warning_left = data.warning_left
	target_point = Vector3(data.target[0], data.target[1], data.target[2])
	salvo_left = data.salvo_left
	_label_boss()
	reinforcements = data.reinforcements.map(func(id): return entities.get(id)).filter(_alive)
	if warning_left >= 0 and _alive(boss):
		_show_marker()


func _alive(unit):
	return (
		is_instance_valid(unit)
		and not unit.is_queued_for_deletion()
		and "hp" in unit
		and unit.hp != null
		and unit.hp > 0
	)


func _label_boss():
	if is_instance_valid(_boss_label):
		_boss_label.queue_free()
	_boss_label = null
	if not _alive(boss):
		return
	_boss_label = load("res://source/match/debug/UnitInfoLabel.gd").new()
	_boss_label.text = tr("Siege commander")
	_boss_label.font_size = 64
	_boss_label.outline_size = 2
	_boss_label.pixel_size = .011
	_boss_label.position = Vector3(0, 2.0, 0)
	_boss_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	boss.add_child(_boss_label)


func boss_status():
	if boss_defeated:
		return tr("Siege commander · defeated")
	if warning_left >= 0:
		return tr("Barrage locked · move clear · %.1f s") % warning_left
	if _alive(boss) and _game.battlefield.is_observed(_game._get_human_player(), boss):
		return tr("Siege commander · %d / %d HP") % [boss.hp, boss.hp_max]
	return tr("Siege commander · destroy the artillery guarding command")
