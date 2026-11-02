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
		panel._branches[pair[1]].button.tooltip_text.contains("Permanently excluded"),
		"Excluded doctrine lacks explanation"
	)
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
