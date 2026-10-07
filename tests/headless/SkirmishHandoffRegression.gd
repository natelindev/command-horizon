extends "res://tests/headless/SkirmishCoordinationRegression.gd"

var attack_travel
var move_travel
var metrics_probe


func _run():
	attack_travel = load("res://source/match/units/actions/AttackMoving.gd")
	move_travel = load("res://source/match/units/actions/Moving.gd")
	metrics_probe = load("res://tests/headless/SkirmishCoordinationMetrics.gd")
	catalog = load("res://source/match/BastionCatalog.gd")
	coordination = load("res://source/match/players/skirmish-ai/SkirmishCoordination.gd")
	root.get_node("SaveManager").autosaves_enabled = false
	for faction in ["bastion", "helix"]:
		for difficulty in 3:
			await _fixture(faction, difficulty)
			game.simulation_time = 30
			var hq = actors[0]
			var unit = actors[2]
			await _arrival(hq, unit, false)
			await _arrival(hq, unit, true)
			await _archive_handoff(hq, unit)
			paused = false
			game.queue_free()
			await _frames(5)
	for error in errors:
		push_error(error)
	print("Coordination handoff: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _regroup_point(hq, unit):
	return hq.global_position_yless + Vector3(-5 - unit.get_index() % 3 * 2, 0, -5)


func _departing_defense(unit, point, stopped):
	unit.issue_manual_order(attack_travel.new(point))
	if stopped:
		unit.get_node("Movement").stop()
	opponent._army_groups = [coordination._group("defense", point, [unit], 0)]


func _command(hq, unit):
	# The protected threat has left. With no alternative task before the first
	# wave, the coordinator must retire the old defense and regroup its unit.
	coordination.command(game, opponent, [hq, unit], [hq, unit], [])
	_check(opponent._army_groups.is_empty(), "Retired defense kept a task slot")
	_check(
		metrics_probe.inspect(opponent, [hq, unit]).is_empty(), "Unassigned attack order survived"
	)


func _arrival(hq, unit, active):
	var point = _regroup_point(hq, unit)
	unit.position = point + Vector3(.5, 0, 0)
	_departing_defense(unit, point + Vector3(1 if active else 20, 0, 0), not active)
	_command(hq, unit)
	_check(
		not is_instance_of(unit.action, attack_travel),
		"Regroup arrival retained an obsolete attack route"
	)
	_check(not unit.get_node("Movement")._has_destination, "Arrived regroup kept moving")
	var idle = unit.action
	_command(hq, unit)
	_check(unit.action == idle, "Repeated regroup replaced the idle stance")
	# A valid approach already heading home must not be restarted.
	unit.position = point + Vector3(8, 0, 0)
	_departing_defense(unit, point + Vector3(20, 0, 0), false)
	_command(hq, unit)
	_check(is_instance_of(unit.action, move_travel), "Distant retired defender did not head home")
	_check(unit.action._target_position == point, "Regroup changed its destination")
	var moving = unit.action
	_command(hq, unit)
	_check(unit.action == moving, "Repeated regroup restarted its approach")
	# Assigned missions still own their attack-move even when stationary.
	unit.position = point
	unit.issue_manual_order(attack_travel.new(point + Vector3(4, 0, 0)))
	unit.get_node("Movement").stop()
	opponent._army_groups = [
		coordination._group("assault", point + Vector3(4, 0, 0), [unit], game.simulation_time)
	]
	var assigned = unit.action
	coordination.command(game, opponent, [hq, unit], [hq, unit], [])
	_check(unit.action == assigned, "Active mission lost its attack-move on arrival")
	_check(
		metrics_probe.inspect(opponent, [hq, unit]).is_empty(), "Assigned attack lost membership"
	)
	print("HANDOFF ", opponent.faction, " difficulty=", opponent.difficulty, " active=", active)


func _archive_handoff(hq, unit):
	# The intended arrival can overlap an Advanced-start lab. Begin on valid
	# ground so ordinary projection is not mistaken for a resumed old route.
	var desired = _regroup_point(hq, unit) + Vector3(.5, 0, 0)
	unit.position = (
		NavigationServer3D.map_get_closest_point(
			unit.get_node("Movement").get_navigation_map(), desired
		)
		* Vector3(1, 0, 1)
	)
	game.battlefield.invalidate()
	_check(
		unit.position.distance_to(_regroup_point(hq, unit)) < 2.5,
		"Projected arrival exceeds regroup range"
	)
	_departing_defense(unit, unit.position + Vector3(20, 0, 0), true)
	paused = true
	var clock = game.simulation_time
	var builder = Snapshot.new()
	var data = builder.capture(game)
	var ids = [builder._reference(hq), builder._reference(unit)]
	var path = "user://handoff-%d.json" % OS.get_process_id()
	var store = FileStore.new()
	_check(store.write_file(path, data), "Handoff disk write failed")
	var restore = Restore.new()
	var result = await restore.restore(self, store.read_file(path))
	DirAccess.remove_absolute(path)
	_check(result.ok, "Handoff disk restore failed")
	if not result.ok:
		return
	game = result.game
	hq = restore.entities[ids[0]]
	unit = restore.entities[ids[1]]
	opponent = unit.player
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	await _frames(30)
	_check(game.simulation_time == clock, "Paused handoff archive advanced time")
	_check(is_instance_of(unit.action, attack_travel), "Archive discarded the pending old task")
	var position = unit.position
	_command(hq, unit)
	_check(unit.position == position, "Paused task retirement moved its unit")
	await _review_handoff(unit)
	paused = false
	unit.process_mode = Node.PROCESS_MODE_INHERIT
	await _frames(180)
	_check(not is_instance_of(unit.action, attack_travel), "Retired route reappeared after resume")
	_check(unit.position.distance_to(position) < 1, "Retired route resumed travelling")
	print("HANDOFF ARCHIVE ", opponent.faction, " difficulty=", opponent.difficulty)


func _review_handoff(_unit):
	return true
