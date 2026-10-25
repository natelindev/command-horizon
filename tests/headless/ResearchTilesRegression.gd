extends "res://tests/headless/SaveRestoreEdges.gd"

var _cases = 0


func _run():
	TranslationServer.set_locale("en")
	root.get_node("SaveManager").autosaves_enabled = false
	for faction in ["bastion", "helix", "frontier"]:
		await _skirmish(faction, "res://source/match/maps/DesertFrontier.tscn")
		for side in get_nodes_in_group("players"):
			side.set_process(false)
		paused = true
		var human = game._get_human_player()
		human.resource_a = 1000
		human.resource_b = 1000
		var lab = _units(human, "CommandLab")[0]
		root.get_node("MatchSignals").deselect_all_units.emit()
		lab.get_node("Selection").select()
		await _frames(5)
		var panel = game.find_child("UnitMenus")._research_panel
		_check(is_instance_valid(panel), "Selected lab has no research tiles")
		if is_instance_valid(panel):
			await _exercise(panel, human)
		game.hud.open_technology()
		await _frames(5)
		await _exercise(game.hud.technology_panel, human)
		game.hud._close_menu()
		paused = false
		game.queue_free()
		await _frames(5)
	_check(_cases == 6, "Research tile cases did not all finish")
	for message in errors:
		push_error(message)
	print("Research tiles: %d failures over %d cases" % [errors.size(), _cases])
	quit(0 if errors.is_empty() else 1)


func _exercise(panel, human):
	var catalog = load("res://source/match/research/TechnologyCatalog.gd")
	var weapons = panel._branches.weapons.button
	var available = catalog.BRANCHES.filter(func(id): return catalog.available(id, human.faction))
	_check(
		panel._grid.get_child_count() == available.size() + 1,
		"Not all research choices are visible"
	)
	_check(
		panel._branches.has("plasma_shields") == (human.faction == "helix"),
		"Plasma shield research ignores faction availability"
	)
	var dual_aa = panel._branches.dual_purpose_aa.button
	_check(dual_aa.disabled, "Dual-purpose AA bypassed Weapon systems I")
	_check(
		dual_aa.tooltip_text.contains(catalog.description("dual_purpose_aa", human.faction)),
		"Dual-purpose AA tooltip does not explain the affected units and turret priority"
	)
	for tile in panel._grid.get_children():
		_check(tile.visible and tile.portrait() != null, "Research tile lacks visible artwork")
		_check(tile.get_global_rect().size.y < 100, "Research tile grew into a text row")
		_check(panel.get_global_rect().encloses(tile.get_global_rect()), "Research tile overflows")
		_check(tile.accessibility_description == tile.tooltip_text, "Tooltip inaccessible")
		var tooltip = tile._make_custom_tooltip(tile.tooltip_text)
		_check(tooltip.get_meta("roster_tooltip") == tile.tooltip_text, "Missing custom tooltip")
		tooltip.free()
	_check(
		weapons.tooltip_text.contains(catalog.description("weapons_1", human.faction)),
		"Weapon tooltip does not explain its effect"
	)
	var tooltip_lines = weapons.tooltip_text.split("\n")
	_check(
		(
			tooltip_lines[1] == catalog.description("weapons_1", human.faction)
			and tooltip_lines[2] == "30 M / 20 E"
			and tooltip_lines[3] == "35 s research at current power."
		),
		"Research tooltip does not follow the production description/price/timing format"
	)
	_check(panel._branches.doctrine.button.disabled, "Locked doctrine can be purchased")
	_check(
		panel._branches.doctrine.button.tooltip_text.contains("Requires Coordination"),
		"Locked doctrine tooltip lacks its prerequisite"
	)
	var funds = Vector2i(human.resource_a, human.resource_b)
	weapons.pressed.emit()
	_check(human.technology.active == "weapons_1", "Research tile did not start its project")
	_check(
		Vector2i(human.resource_a, human.resource_b) == funds - Vector2i(30, 20),
		"Research tile charged the wrong price"
	)
	_check(panel._progress.visible and panel._cancel.visible, "Active research lacks controls")
	_check(not panel._start.disabled and weapons.disabled, "Queue choices ignore prerequisites")
	panel._start.pressed.emit()
	_check(
		human.technology.queued.size() == 1 and human.technology.queued[0].id == "coordination",
		"Busy Coordination tile did not queue its project"
	)
	_check(not weapons.disabled, "Queued Coordination did not unlock the next weapon purchase")
	weapons.pressed.emit()
	_check(
		human.technology.queued.size() == 2 and human.technology.queued[1].id == "weapons_2",
		"Dependent upgrade did not queue behind its prerequisites"
	)
	_check(panel._queue_rows.size() == 2, "Queued research lacks visible cancellation controls")
	panel._queue_rows[0].cancel.pressed.emit()
	_check(
		human.technology.queued.is_empty(), "Cancelling a prerequisite retained a blocked upgrade"
	)
	_check(
		Vector2i(human.resource_a, human.resource_b) == funds - Vector2i(30, 20),
		"Queued cancellation did not refund both projects"
	)
	panel._cancel.pressed.emit()
	_check(human.technology.active == "", "Research cancel failed")
	_check(Vector2i(human.resource_a, human.resource_b) == funds, "Research refund differs")
	panel._start.pressed.emit()
	_check(human.coordination_left > 0, "Coordination tile did not start")
	panel._cancel.pressed.emit()
	human.technology.completed = ["weapons_1"]
	panel.refresh()
	_check(not dual_aa.disabled, "Weapon systems I did not unlock Dual-purpose AA")
	dual_aa.pressed.emit()
	_check(human.technology.active == "dual_purpose_aa", "Dual-purpose AA button failed")
	_check(
		Vector2i(human.resource_a, human.resource_b) == funds - Vector2i(40, 30),
		"Dual-purpose AA tile charged the wrong price"
	)
	panel._cancel.pressed.emit()
	_check(Vector2i(human.resource_a, human.resource_b) == funds, "Dual-purpose AA refund differs")
	_check(weapons.title() == "Weapon systems II" and weapons.disabled, "Tier II ignores gate")
	human.coordination_unlocked = true
	panel.refresh()
	_check(not weapons.disabled, "Coordination did not unlock Tier II")
	human.technology.completed = ["weapons_1", "weapons_2"]
	panel.refresh()
	_check(
		weapons.disabled and weapons.visible and weapons._state.text == "Completed",
		"Completed branch disappeared or can be repurchased"
	)
	human.technology.completed.append("dual_purpose_aa")
	panel.refresh()
	_check(
		dual_aa.disabled and dual_aa._state.text == "Completed",
		"Completed Dual-purpose AA remains purchasable"
	)
	human.technology.completed = []
	human.coordination_unlocked = false
	human.resource_a = 0
	panel.refresh()
	_check(
		weapons.disabled and weapons.tooltip_text.contains("Need 30 M"),
		"Unaffordable tile lacks price shortage"
	)
	human.resource_a = funds.x
	panel.refresh()
	_cases += 1
