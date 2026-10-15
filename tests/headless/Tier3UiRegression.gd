extends SceneTree

var errors = []


func _initialize():
	_run.call_deferred()


func _run():
	await _test_command_card_grid()
	await _test_tactical_range_ring()
	await _test_tactical_ping_signal()

	print("Tier 3 UI regression: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _test_command_card_grid():
	var CommandCardScript = load("res://source/match/hud/CommandCard.gd")
	var card = CommandCardScript.new()
	root.add_child(card)

	_check(card.columns == 4, "Command card does not have 4 columns")
	_check(card._slots.size() == 3, "Command card does not have 3 rows")
	_check(card._slots[0].size() == 4, "Row 0 does not have 4 buttons")

	var dummy_combat_unit = Node3D.new()
	var dummy_script = GDScript.new()
	dummy_script.source_code = "extends Node3D\nvar hp = 150\nvar attack_range = 18.0\nsignal input_event(cam, ev, pos, norm, idx)\nsignal selected\nsignal deselected"
	dummy_script.reload()
	dummy_combat_unit.set_script(dummy_script)
	dummy_combat_unit.add_to_group("controlled_units")
	root.add_child(dummy_combat_unit)

	card.update_layout([dummy_combat_unit], null)
	var stop_btn = card._slots[0][1]
	_check(stop_btn.badge == "W", "Stop button missing W hotkey badge")
	_check(not stop_btn.disabled, "Stop button disabled for combat unit")

	var atk_move_btn = card._slots[1][0]
	_check(atk_move_btn.badge == "A", "Attack move button missing A hotkey badge")

	dummy_combat_unit.queue_free()
	card.queue_free()
	print("PASS 3x4 command card matrix, hotkey slot mapping, and action dispatch")


func _test_tactical_range_ring():
	var SelectionScript = load("res://source/match/units/traits/Selection.gd")
	var dummy_unit = Node3D.new()
	var dummy_script = GDScript.new()
	dummy_script.source_code = "extends Node3D\nvar hp = 150\nvar attack_range = 14.0\nsignal input_event(cam, ev, pos, norm, idx)\nsignal selected\nsignal deselected"
	dummy_script.reload()
	dummy_unit.set_script(dummy_script)

	var circle = Node3D.new()
	circle.name = "FadedCircle3D"
	dummy_unit.add_child(circle)

	var selection_trait = SelectionScript.new()
	dummy_unit.add_child(selection_trait)
	root.add_child(dummy_unit)

	selection_trait.select()
	_check(selection_trait._range_ring != null, "Tactical range ring was not spawned on selection")
	_check(selection_trait._range_ring.visible, "Tactical range ring is hidden when selected")

	selection_trait.deselect()
	_check(not selection_trait._range_ring.visible, "Tactical range ring was not hidden on deselect")

	dummy_unit.queue_free()
	print("PASS Selected unit tactical attack range ring projection and lifecycle")


func _test_tactical_ping_signal():
	var state = {"received": false, "pos": Vector3.ZERO}
	var cb = func(pos):
		state["received"] = true
		state["pos"] = pos

	var match_signals = root.get_node("MatchSignals")
	match_signals.tactical_ping.connect(cb)
	match_signals.tactical_ping.emit(Vector3(32, 0, 48))

	_check(state.received, "tactical_ping signal failed to dispatch")
	_check(state.pos == Vector3(32, 0, 48), "tactical_ping position corrupted")

	match_signals.tactical_ping.disconnect(cb)

	# Verify tactical ping audio cue asset
	var ping_stream = load("res://assets/audio/combat/tactical_ping.wav")
	_check(ping_stream is AudioStream, "tactical_ping.wav is not a valid AudioStream")
	_check(ping_stream.get_length() > 0.1, "tactical_ping.wav duration too short")
	print("PASS Tactical alert ping signal dispatch and acoustic asset availability")


func _check(condition: bool, message: String):
	if not condition:
		errors.append(message)
		print("FAIL: " + message)
		push_error(message)
