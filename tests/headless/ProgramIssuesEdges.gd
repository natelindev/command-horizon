extends "res://tests/headless/ProgramIssuesRegression.gd"


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	plan_rules = load("res://source/match/SkirmishPlan.gd")
	library = load("res://source/match/programs/ProgramLibrary.gd")
	await _fixture("frontier")
	var panel = game.hud.battle_plan
	var queued = _spawn_for_plan("Tank", human, Vector3(50, 0, 30))
	queued.program.set_status("Error", "Queued unit fixture")
	queued.queue_free()
	_check(queued not in plan_rules.program_issues(human), "Queued unit remained in program issues")
	await _frames(2)
	var before = _authority()
	var selected = get_nodes_in_group("selected_units")
	var camera = game.get_node("IsometricCamera3D").position
	game.hud.program_editor = Control.new()
	await panel._select_program_issues()
	_check(
		get_nodes_in_group("selected_units") == selected, "Issue shortcut bypassed program editor"
	)
	game.hud.program_editor.free()
	game.hud.program_editor = null
	game.finished = true
	await panel._select_program_issues()
	game.finished = false
	_check(get_nodes_in_group("selected_units") == selected, "Issue shortcut acted after match end")
	_check(
		game.get_node("IsometricCamera3D").position == camera and _authority() == before,
		"Blocked issue activation changed state"
	)
	# A later selection must own its scroll position when the earlier shortcut's
	# deferred layout continuation wakes up.
	panel._select_program_issues()
	panel._select([faulted])
	await _frames(8)
	var menus = game.find_child("UnitMenus")
	_check(
		get_nodes_in_group("selected_units") == [faulted],
		"Late issue continuation replaced selection"
	)
	_check(
		menus._scroll.scroll_vertical == 0,
		"Late issue continuation scrolled a different unit's panel"
	)
	_check(_authority() == before, "Selection race altered program state")
	blocked.issue_manual_order(null)
	faulted.issue_manual_order(null)
	panel.refresh()
	_check(
		not panel._programs.visible and panel._programs.disabled,
		"Empty issue control stayed active"
	)
	selected = get_nodes_in_group("selected_units")
	await panel._select_program_issues()
	_check(
		get_nodes_in_group("selected_units") == selected,
		"Empty issue selection cleared existing selection"
	)
	paused = false
	game.queue_free()
	await _frames(5)
	for message in errors:
		push_error(message)
	print("Program issue edges: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)
