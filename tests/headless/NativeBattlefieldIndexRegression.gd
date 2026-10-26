extends "res://tests/headless/NativeVisibilityRegression.gd"


func _compare_queries():
	_check(game.battlefield.native_battlefield_index, "Requires --native-battlefield-index")
	await super._compare_queries()
	_check(game.unit_state_store != null, "Requires --native-unit-state")
	if game.unit_state_store == null:
		return
	var probe = load("res://tests/fixtures/NativeSightProbe.gd").new()
	game._get_human_player().add_child(probe)
	probe.add_to_group("vision_sources")
	game.invalidate_vision_registry()
	_check(
		not bool(probe._native_state.metadata()[0] & 4096),
		"Custom sight was treated as base behavior"
	)
	probe.sight_range = 37.0
	var field = game.battlefield
	for step in 64:
		probe.sight_factor = .5 + (step % 7) * .25
		probe.force_plateau = step % 2 == 0
		probe.global_position = Vector3(30 + step, 3, 30)
		field.native_battlefield_index = false
		field._native_index = false
		field.invalidate()
		field._refresh()
		var expected = [field._max_sight, field._max_unit_radius, field._max_body_step]
		field.native_battlefield_index = true
		field.invalidate()
		field._refresh()
		_check(
			expected == [field._max_sight, field._max_unit_radius, field._max_body_step],
			"Live custom sight bounds differ"
		)
	var statistics: Array = _native.index_statistics()
	_check(
		statistics[0] == 1 and statistics[3] > 0 and statistics[8] > 0,
		"Resident index/native sight never executed"
	)
	print("Resident battlefield: 64 custom-bound comparisons; statistics=", statistics)
	probe.queue_free()
