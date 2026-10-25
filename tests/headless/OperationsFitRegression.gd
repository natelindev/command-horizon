extends "res://tests/headless/SaveRestoreEdges.gd"

var _cases = 0


func _run():
	var preferences = root.get_node("Globals").options
	var original = preferences.capture()
	root.get_node("SaveManager").autosaves_enabled = false
	var catalog = load("res://source/match/BastionCatalog.gd")
	for faction in ["bastion", "helix", "frontier"]:
		await _skirmish(faction, "res://source/match/maps/DesertFrontier.tscn")
		for player in get_nodes_in_group("players"):
			player.set_process(false)
		paused = true
		var human = game._get_human_player()
		human.resource_a = 10000
		human.resource_b = 10000
		human.coordination_unlocked = true
		for role in catalog.NAMES:
			if _units(human, role).is_empty():
				var unit = load("res://source/match/units/%s.tscn" % role).instantiate()
				game._setup_and_spawn_unit(
					unit, Transform3D(Basis(), Vector3(35, 0, 25)), human, false
				)
		var lab = _units(human, "CommandLab")[0]
		for id in [
			"weapons_1", "weapons_2", "armor_1", "armor_2", "service", "doctrine", "dual_purpose_aa"
		]:
			human.technology.enqueue(id, lab)
		var producers = []
		for role in ["CommandCenter", "Barracks", "VehicleFactory", "AircraftFactory"]:
			var producer = _units(human, role)[0]
			producers.append(producer)
			for index in 5:
				producer.production_queue.produce(
					load("res://source/match/units/%s.tscn" % catalog.PRODUCES[role][0])
				)
		var groups = [
			[_units(human, "Worker")[0]],
			[_units(human, "Tank")[0]],
			[_units(human, "CombatRobot")[0]],
			[_units(human, "Infantry")[0]],
			[lab],
			[
				_units(human, "Worker")[0],
				_units(human, "Infantry")[0],
				_units(human, "CombatRobot")[0]
			],
			producers,
			human.get_children().filter(func(unit): return unit.is_in_group("units"))
		]
		for language in ["en", "zh_CN"]:
			for scale_value in [1.0, 1.5]:
				preferences.restore(
					{"screen": 1, "interface_scale": scale_value, "language": language}
				)
				root.size = Vector2i(1280, 720)
				root.content_scale_size = Vector2i(1920, 1080)
				root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
				for index in groups.size():
					root.get_node("MatchSignals").deselect_all_units.emit()
					for unit in groups[index]:
						unit.get_node("Selection").select()
					await _frames(10)
					var menus = game.find_child("UnitMenus")
					for page in menus._pages.get_tab_count():
						menus._pages.current_tab = page
						await _frames(10)
						var label = (
							"%s %s scale=%s group=%d page=%d"
							% [faction, language, scale_value, index, page]
						)
						_check(menus.size.y <= 246.5, label + ": deck too tall " + str(menus.size))
						_check(
							root.get_visible_rect().grow(1).encloses(menus.get_global_rect()),
							label + ": deck offscreen"
						)
						_bounds(menus, menus.get_global_rect().grow(1), label)
						_check(
							not menus.get_global_rect().intersects(
								game.find_child("Minimap").get_global_rect()
							),
							label + ": menu covers minimap"
						)
						var queue = game.find_child("ProductionQueue")
						if queue.is_visible_in_tree():
							_bounds(queue, root.get_visible_rect().grow(1), label)
							var jobs = queue.find_child("QueueElements").get_children()
							var hidden = jobs.filter(func(job): return not job.visible).size()
							var overflow = queue.find_child("Overflow")
							_check(
								overflow.visible == (hidden > 0),
								label + ": missing queue overflow count"
							)
							if hidden > 0:
								_check(
									overflow.text == "+%d" % hidden,
									label + ": wrong overflow count"
								)

						_cases += 1
		paused = false
		game.queue_free()
		await _frames(5)
	preferences.restore(original)
	_check(_cases >= 96, "Operations cases did not finish")
	for message in errors:
		push_error(message)
	print("Operations fit: %d failures over %d cases" % [errors.size(), _cases])
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)


func _bounds(node, rect, label):
	_check(not node is ScrollContainer, label + ": scroll container " + str(node.get_path()))
	if node is Control and node.is_visible_in_tree():
		_check(
			rect.encloses(node.get_global_rect()),
			label + ": outside deck " + str(node.get_path()) + " " + str(node.get_global_rect())
		)
	for child in node.get_children():
		_bounds(child, rect, label)
