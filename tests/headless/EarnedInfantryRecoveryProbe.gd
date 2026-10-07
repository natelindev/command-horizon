extends "res://tests/headless/SaveRestoreEdges.gd"

const ARCHIVE = "res://docs/playtests/2026-10-06/engineer-reassignment/reassigned-2-unresolved.json"


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	for assign in [false, true]:
		var restore = Restore.new()
		var loaded = await restore.restore(self, FileStore.new().read_file(ARCHIVE))
		_check(loaded.ok, "Unresolved army archive failed to restore")
		if not loaded.ok:
			break
		game = loaded.game
		# Isolate the existing soldiers' service handoff. Other actors remain
		# live; neither faction receives new strategic orders during this probe.
		for player in get_nodes_in_group("players"):
			player.set_process(false)
		var owner = game._get_human_player()
		var wounded = _units(owner, "Infantry").filter(
			func(unit): return unit.hp < unit.hp_max * .8
		)
		_check(wounded.size() == 4, "Unresolved archive no longer contains four wounded infantry")
		var before = wounded.map(func(unit): return unit.hp / unit.hp_max)
		var barracks = _units(owner, "Barracks")[0]
		if assign:
			for unit in wounded:
				unit.issue_manual_order(
					load("res://source/match/units/actions/RecoveringAtService.gd").new(barracks)
				)
		paused = false
		await _frames(3600)
		var after = wounded.map(
			func(unit): return unit.hp / unit.hp_max if is_instance_valid(unit) else 0
		)
		if assign:
			_check(
				after.all(func(value): return value >= .8),
				"Assigned infantry did not complete real treatment"
			)
		print("EARNED INFANTRY assigned=", assign, " before=", before, " after=", after)
		paused = false
		game.queue_free()
		await _frames(5)
	for error in errors:
		push_error(error)
	print("Earned infantry recovery probe: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)
