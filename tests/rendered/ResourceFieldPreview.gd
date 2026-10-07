extends "res://tests/rendered/SkirmishLoopPreview.gd"


func _run():
	var options = root.get_node("Globals").options
	var original = options.capture()
	options.screen = options.Screen.WINDOW
	options.apply()
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	var harvest = load("res://source/match/units/actions/CollectingResourcesSequentially.gd")
	for faction in ["bastion", "helix"]:
		await _start_loop(faction, false)
		var human = _game._get_human_player()
		var workers = human.get_children().filter(
			func(unit): return unit.is_in_group("units") and unit.type == "Worker"
		)
		var camera = _game.get_node("IsometricCamera3D")
		var deposits = get_nodes_in_group("resource_units").filter(
			func(deposit): return "resource_b" in deposit
		)
		deposits.sort_custom(
			func(a, b):
				return (
					a.position.distance_to(workers[0].position)
					< b.position.distance_to(workers[0].position)
				)
		)
		var electronics = deposits[0]
		for worker in workers:
			worker.issue_manual_order(harvest.new(electronics))
			worker.get_node("Selection").select()
		camera.set_position_safely(electronics.global_position)
		await _frames(20)
		var menu = _game.find_child("UnitMenus")
		_check("2 gathering / 2 waiting" in menu._status.text, "Group economy status missing")
		_check(
			menu.get_global_rect().end.x <= 1280 and menu.position.y >= 0,
			"Engineer panel exceeds 720p"
		)
		await _capture("fields-%s-group-720p" % faction)
		for worker in workers:
			worker.get_node("Selection").deselect()
		workers[2].get_node("Selection").select()
		await _frames(20)
		_check("waiting for a work slot" in menu._status.text, "Work-slot wait is invisible")
		await _capture("fields-%s-wait-720p" % faction)
		for deposit in workers[2].action._field_deposits():
			deposit.resource_b = 0
		await _frames(45)
		_check("field depleted" in menu._status.text, "Depletion instruction is invisible")
		await _capture("fields-%s-depleted-720p" % faction)
		var plan = _game.hud.battle_plan
		await _click(plan._idle)
		_check(
			get_nodes_in_group("selected_units").has(workers[2]),
			"Idle shortcut missed depleted engineer"
		)
		var materials = get_nodes_in_group("resource_units").filter(
			func(deposit): return "resource_a" in deposit
		)
		var target = materials[0]
		camera.set_position_safely(target.global_position)
		await _frames(5)
		await _right_click(camera.unproject_position(target.global_position + Vector3.UP * 0.5))
		_check(
			workers[2].action != null and workers[2].action._kind == 1,
			"Right-click did not reassign resource type"
		)
		_game.queue_free()
		await _frames(6)
	options.restore(original)
	for error in _errors:
		push_error(error)
	print("Resource field UI: %d failures" % _errors.size())
	quit(0 if _errors.is_empty() else 1)
