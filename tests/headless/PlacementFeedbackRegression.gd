extends "res://tests/headless/SaveRestoreEdges.gd"


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	await _skirmish("bastion", "res://source/match/maps/DesertFrontier.tscn")
	paused = true
	var human = game._get_human_player()
	human.resource_a = 1000
	human.resource_b = 1000
	var handler = human.get_node("StructurePlacementHandler")
	var camera = game.get_node("IsometricCamera3D")
	var hq = _units(human, "CommandCenter")[0]
	camera.set_physics_process(false)
	camera.set_position_safely(hq.global_position)
	handler._start_structure_placement(load("res://source/match/units/PowerPlant.tscn"))
	var point = camera.unproject_position(hq.global_position)
	handler._set_blueprint_position(point)
	var validity = handler._calculate_blueprint_position_validity()
	_check(validity != handler.BlueprintPositionValidity.VALID, "Overlap fixture is valid")
	handler._update_feedback_label(validity)
	await _frames(5)
	var feedback = handler._feedback
	_check(feedback is Control, "Placement reason is still world-space text")
	_check(not feedback._label.text.is_empty(), "Invalid placement has no reason")
	_check(feedback._label.get_theme_font_size("font_size") >= 16, "Reason text is too small")
	_check(feedback.size.y < 100, "Placement reason panel did not shrink after text wrapping")
	_check(feedback.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Reason intercepts placement")
	feedback._place_at(Vector2(100000, 100000))
	_check(
		root.get_visible_rect().encloses(feedback.get_rect()),
		"Placement explanation extends outside the viewport"
	)
	var funds = Vector2(human.resource_a, human.resource_b)
	var event = InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	handler._handle_lmb_down_event(event)
	event.pressed = false
	handler._handle_lmb_up_event(event)
	_check(handler._structure_placement_started(), "Rejected placement canceled its blueprint")
	_check(Vector2(human.resource_a, human.resource_b) == funds, "Rejected placement spent funds")
	var original_language = TranslationServer.get_locale()
	TranslationServer.set_locale("zh_CN")
	handler._update_feedback_label(handler.BlueprintPositionValidity.COLLIDES_WITH_OBJECT)
	_check(feedback._label.text == "该位置已被占用。", "Chinese placement reason is untranslated")
	TranslationServer.set_locale(original_language)
	handler._update_feedback_label(handler.BlueprintPositionValidity.VALID)
	_check(not feedback.visible and not feedback.is_processing(), "Valid placement kept a warning")
	handler._update_feedback_label(validity)
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = true
	handler._handle_rmb_event(event)
	_check(not handler._structure_placement_started(), "Right click did not cancel placement")
	_check(not feedback.visible and not feedback.is_processing(), "Cancel retained its explanation")
	_check(Vector2(human.resource_a, human.resource_b) == funds, "Cancel spent construction funds")
	paused = false
	game.queue_free()
	await _frames(5)
	for message in errors:
		push_error(message)
	print("Placement feedback: %d failures" % errors.size())
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)
