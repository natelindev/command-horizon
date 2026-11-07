extends "res://tests/headless/FactionAsymmetryRegression.gd"

var _cases = 0


func _run():
	var logger = RuntimeErrorLog.new()
	OS.add_logger(logger)
	TranslationServer.set_locale("en")
	root.get_node("SaveManager").autosaves_enabled = false
	factions = load("res://source/match/FactionCatalog.gd")
	for faction in factions.IDS:
		await _fixture(faction)
		await _standalone_health()
		paused = true
		var lab = _units(human, "CommandLab")[0]
		root.get_node("MatchSignals").deselect_all_units.emit()
		lab.get_node("Selection").select()
		await _frames(5)
		var panel = game.find_child("UnitMenus")._research_panel
		_check(is_instance_valid(panel), "Selected lab has no research tiles")
		if is_instance_valid(panel):
			await _exercise(panel, false)
		game.hud.open_technology()
		await _frames(5)
		await _exercise(game.hud.technology_panel, true)
		game.hud._close_menu()
		paused = false
		game.queue_free()
		await _frames(5)
	_check(_cases == 6, "Research tile cases did not all finish")
	OS.remove_logger(logger)
	errors.append_array(logger.messages)
	for message in errors:
		push_error(message)
	print("Research tiles: %d failures over %d cases" % [errors.size(), _cases])
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)


func _standalone_health():
	var tank = _units(human, "Tank")[0]
	var menus = game.find_child("UnitMenus")
	root.get_node("MatchSignals").deselect_all_units.emit()
	tank.get_node("Selection").select()
	await _frames(5)
	var original_hp = tank.hp
	for pause_state in [false, true]:
		paused = pause_state
		game.hud.open_technology()
		await _frames(5)
		_check(not menus._health.visible, "Standalone Technology shows selection health")
		_check(not menus._shields.visible, "Standalone Technology shows selection shields")
		tank.hp = original_hp - 1
		menus._queue_health_refresh()
		await _frames(3)
		_check(not menus._health.visible, "Health refresh leaked into Technology")
		_check(not menus._shields.visible, "Shield refresh leaked into Technology")
		_check(tank in get_nodes_in_group("selected_units"), "Technology cleared selection")
		game.hud._close_menu()
		await _frames(5)
		_check(paused == pause_state, "Technology changed tactical pause")
		_check(menus._health.visible and menus._health.value == tank.hp, "Health did not return")
		_check(menus._shields.visible == (tank.shields_max > 0), "Shields did not return")
		tank.hp = original_hp


func _exercise(panel, overlay):
	var catalog = load("res://source/match/research/TechnologyCatalog.gd")
	var branches = catalog.FACTION_TECHNOLOGIES[human.faction]
	var branch = branches[0]
	var choice = panel._branches[branch].button
	var pair = catalog.EXCLUSIVE_PAIRS[factions.IDS.find(human.faction)]
	var research = human.technology
	research.completed.clear()
	human.coordination_unlocked = false
	panel.refresh()
	_check(
		panel._grid.get_child_count() == branches.size() + 1,
		"Not all authored faction research choices are visible"
	)
	_check(
		not panel._branches.has("weapons") and not panel._branches.has("armor"),
		"Mirrored research ladders remain available"
	)
	_check(
		panel._branches.has("plasma_shields") == (human.faction == "helix"),
		"Shield branch ignores faction availability"
	)
	for tile in panel._grid.get_children():
		_check(tile.visible and tile.portrait() != null, "Research tile lacks visible artwork")
		_check(tile.get_global_rect().size.y < 100, "Research tile grew into a text row")
		_check(panel.get_global_rect().encloses(tile.get_global_rect()), "Research tile overflows")
		_check(tile.accessibility_description == tile.tooltip_text, "Research tooltip inaccessible")
		_check(
			tile._materials.is_visible_in_tree() and tile._electronics.is_visible_in_tree(),
			"Research tile hides its price"
		)
		var tooltip = tile._make_custom_tooltip(tile.tooltip_text)
		_check(tooltip.get_meta("roster_tooltip") == tile.tooltip_text, "Missing custom tooltip")
		tooltip.free()
	var item = catalog.ITEMS[branch]
	var lines = choice.tooltip_text.split("\n")
	_check(
		(
			lines[1] == catalog.description(branch, human.faction)
			and lines[2] == "%d M / %d E" % [item.cost.x, item.cost.y]
			and lines[3] == "%d s research at current power." % ceili(item.seconds)
		),
		"Research tooltip lost description/price/timing format"
	)
	_check(
		choice.disabled and choice.tooltip_text.contains("Requires Coordination"),
		"Faction branch bypassed Coordination"
	)
	_check(choice.research_state == "locked", "Missing prerequisite has no distinct state")
	_check(panel._start._marker.text == "Core", "Coordination has no gateway cue")
	var funds = Vector2i(human.resource_a, human.resource_b)
	panel._start.pressed.emit()
	_check(human.coordination_left > 0.0, "Coordination tile did not start")
	_check(not choice.disabled, "Reserved Coordination did not unlock dependent branch")
	choice.pressed.emit()
	panel._branches[pair[0]].button.pressed.emit()
	_check(
		(
			research.queued.size() == 2
			and research.queued[0].id == branch
			and research.queued[1].id == pair[0]
		),
		"Dependent projects did not queue in purchase order"
	)
	_check(
		panel._queue_rows.size() == 2 and panel._branches[pair[1]].button.disabled,
		"Doctrine reservation lacks queue controls or exclusion"
	)
	_check(
		panel._branches[pair[1]].button.tooltip_text.contains("Reserved by"),
		"Excluded doctrine lacks explanation"
	)
	_check(
		panel._branches[pair[1]].button.research_state == "reserved", "Reservation looks permanent"
	)
	_check(choice._marker.text == "Q1", "Queued choice lacks its FIFO position")
	_check(
		panel._queue_rows[1].cancel._marker.text == "Q2", "Queue position disagrees with choices"
	)
	var focused = panel._queue_rows[1].cancel
	focused.grab_focus()
	panel._queue_rows[0].cancel.pressed.emit()
	_check(root.gui_get_focus_owner() == focused, "Earlier cancellation stole project focus")
	_check(focused._marker.text == "Q1", "Surviving project position did not update")
	# Fill the remaining legal projects, exercising the widest paid queue while
	# retaining the opposing-doctrine exclusion.
	for id in branches:
		if research.queue_reason(id, panel.lab) == "":
			panel._branches[id].button.pressed.emit()
	await _frames(5)
	_check(
		panel._queue_rows.size() == research.queued.size(), "Full queue lost a cancellation control"
	)
	for queued in panel._queue_rows:
		_check(
			panel.get_global_rect().encloses(queued.row.get_global_rect()),
			"Full paid queue escapes research panel"
		)
	_check(
		panel._active_title.is_visible_in_tree() and panel._status.is_visible_in_tree(),
		"Active details hidden"
	)
	_check("Paused" in panel._status.text, "Paused research has no visible pause state")
	for tile in panel._grid.get_children():
		for part in [tile._marker, tile._title, tile._materials, tile._electronics]:
			_check(
				tile.get_global_rect().grow(.5).encloses(part.get_global_rect()),
				"Tile content escapes its card"
			)
		_check(
			not tile._marker.get_global_rect().intersects(tile._title.get_global_rect()),
			"State covers title"
		)
	if not overlay:
		var height = game.find_child("UnitMenus").get_global_rect().size.y
		_check(height <= 246.5, "Paid research queue exceeds baseline console height")
	panel._cancel.pressed.emit()
	_check(
		research.queued.is_empty() and human.coordination_left == -1.0,
		"Cancelling Coordination retained blocked projects"
	)
	_check(
		Vector2i(human.resource_a, human.resource_b) == funds,
		"Prerequisite cancellation did not refund every project"
	)
	human.coordination_unlocked = true
	panel.refresh()
	choice.pressed.emit()
	_check(research.active == branch, "Faction branch tile did not start its project")
	_check(
		Vector2i(human.resource_a, human.resource_b) == funds - item.cost,
		"Faction branch charged the wrong price"
	)
	research.left = item.seconds * .5
	panel.refresh()
	var previous_boosts = human.production_boosts.duplicate()
	human.production_boosts.append({"target": weakref(panel.lab), "left": 10.0})
	panel.refresh()
	_check(
		(
			panel._project.seconds == ceili(item.seconds * .5 / 1.5)
			and panel._progress.value == 50
			and panel._project.detail.contains("150%")
		),
		"Boosted research ETA or progress is incorrect"
	)
	human.production_boosts = previous_boosts
	panel.refresh()
	game.hud.research_status.refresh()
	_check(panel._progress.value == 50, "Footer progress is not research completion")
	_check(choice._research_progress.value == 50, "Active tile progress disagrees with footer")
	_check(panel._active_title.text == catalog.title(branch, human.faction), "Active title missing")
	_check(
		panel._status.text in game.hud.research_status._button.text,
		"Top and footer states disagree"
	)
	_check(
		(
			choice.disabled
			and choice._materials.is_visible_in_tree()
			and panel._progress.visible
			and panel._cancel.visible
		),
		"Active research hides its price, progress or cancellation"
	)
	panel._branches[pair[0]].button.pressed.emit()
	_check(research.queued.size() == 1, "Doctrine did not queue behind active research")
	panel._queue_rows[0].cancel.pressed.emit()
	_check(
		research.queued.is_empty() and not panel._branches[pair[1]].button.disabled,
		"Cancelled doctrine kept its rival excluded"
	)
	panel._cancel.pressed.emit()
	_check(
		research.active == "" and Vector2i(human.resource_a, human.resource_b) == funds,
		"Active research cancellation changed its refund"
	)
	research.completed.append(branch)
	panel.refresh()
	_check(
		choice.disabled and choice.visible and choice._marker.text == "✓",
		"Completed branch disappeared or remains purchasable"
	)
	_check(
		choice._materials.is_visible_in_tree() and choice._electronics.is_visible_in_tree(),
		"Completed branch hides its authored price"
	)
	research.completed.clear()
	research.completed.append(pair[0])
	panel.refresh()
	_check(
		panel._branches[pair[1]].button.research_state == "excluded",
		"Completed doctrine looks reversible"
	)
	_check(
		panel._branches[pair[1]].button.tooltip_text.contains("Permanently excluded"),
		"Permanent exclusion unexplained"
	)
	research.completed.clear()
	human.resource_a = 0
	panel.refresh()
	_check(
		choice.disabled and choice.tooltip_text.contains("Need %d M" % item.cost.x),
		"Unaffordable branch lacks its actual price shortage"
	)
	human.resource_a = funds.x
	human.coordination_unlocked = false
	panel.refresh()
	_cases += 1
