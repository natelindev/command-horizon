extends SceneTree

var failures := []


func _initialize():
	_run.call_deferred()


func _check(condition: bool, message: String):
	if not condition:
		failures.append(message)


func _run():
	var probe = load("res://tests/fixtures/AutoAttackPhaseProbe.gd")
	var actions := []
	var owners := []
	for index in 200:
		var owner := Node3D.new()
		owner.add_to_group("units")
		owner.set_meta("visual_seed", index + 1)
		root.add_child(owner)
		var action = probe.new(null)
		owner.add_child(action)
		action.set_physics_process(false)
		_check(action.refreshes == 1, "New attack did not respond immediately")
		actions.append(action)
		owners.append(owner)
	var counts := []
	var last_tick := PackedInt32Array()
	last_tick.resize(actions.size())
	last_tick.fill(-1)
	for tick in 15:
		var count := 0
		for index in actions.size():
			var action = actions[index]
			var before: int = action.refreshes
			action._physics_process(1.0 / 30.0)
			if action.refreshes == before:
				continue
			count += 1
			if last_tick[index] >= 0:
				_check(tick - last_tick[index] == 5, "Recurring perception cadence changed")
			else:
				_check(tick < 5, "First refresh exceeded the existing interval")
			last_tick[index] = tick
		counts.append(count)
	_check(counts.max() < 70, "Army perception still converges on one physics tick")
	_check(counts.min() > 0, "Perception phases left an empty tick")
	for action in actions:
		_check(action.refreshes == 4, "Phasing changed the recurring work count")
	var restored = probe.new(null)
	restored.restoring = true
	restored._elapsed = .12
	owners[0].add_child(restored)
	restored.set_physics_process(false)
	_check(restored.refreshes == 0 and restored._elapsed == .12, "Restore replaced the saved phase")
	restored._physics_process(1.0 / 30.0)
	_check(restored.refreshes == 1, "Restored phase did not resume on its saved deadline")
	for owner in owners:
		owner.free()
	for message in failures:
		push_error(message)
	print("Attack phases: %d failures; checks per tick %s" % [failures.size(), counts])
	await root.get_node("Globals").quit_game(0 if failures.is_empty() else 1)
