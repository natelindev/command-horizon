extends "res://tests/headless/SaveRestoreEdges.gd"


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	await _skirmish("bastion")
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	var human = game._get_human_player()
	var enemy = get_nodes_in_group("players").filter(func(side): return side != human)[0]
	var hq = _units(human, "CommandCenter")[0]
	var shooter = _units(human, "Tank")[0]
	var spotter = _units(human, "Tank")[1]
	var target = _units(enemy, "Tank")[0]
	# Shooters must stay processable: incoming damage ignores inactive allies.
	# Every check below runs synchronously, before any unit can move or fire.
	shooter.global_position = hq.global_position + Vector3(-7, 0, 0)
	spotter.global_position = hq.global_position + Vector3(-7, 0, 4)
	target.global_position = hq.global_position + Vector3(7, 0, 0)
	# Hold the round in flight; the checks query it without letting it land.
	var system = game.projectile_system
	system.process_mode = Node.PROCESS_MODE_DISABLED
	system.launch(shooter, target)
	var battlefield = game.battlefield
	battlefield.invalidate()
	_check(not battlefield.has_line_of_fire(shooter, target), "Fixture HQ does not block the shell")
	# The shell re-checks line of fire on impact, so a blocked shot will miss.
	_check(
		battlefield._incoming_damage(spotter, [target]).get(target, 0.0) == 0.0,
		"Blocked in-flight shot counted as incoming damage"
	)
	# Open ground between the two bases gives the shell a clear line.
	var middle = (hq.global_position + _units(enemy, "CommandCenter")[0].global_position) / 2.0
	shooter.global_position = middle
	var clear = false
	for step in 16:
		var offset = Vector3(0, 0, 6).rotated(Vector3.UP, step * TAU / 16.0)
		target.global_position = middle + offset
		if battlefield.has_line_of_fire(shooter, target):
			clear = true
			break
	_check(clear, "Fixture found no clear line of fire")
	_check(
		battlefield._incoming_damage(spotter, [target]).get(target, 0.0) > 0.0,
		"Clear in-flight shot was not counted as incoming damage"
	)
	system.clear()
	game.queue_free()
	await _frames(5)
	for message in errors:
		push_error(message)
	print("Incoming damage: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)
