extends "res://tests/headless/SaveRestoreEdges.gd"


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	var preferences = root.get_node("Globals").options
	var saved_bindings = preferences.key_bindings.duplicate(true)
	preferences.key_bindings = load("res://source/input/KeyBindings.gd").defaults()
	preferences.apply()
	for faction in ["bastion", "helix", "frontier"]:
		await _skirmish(faction, "res://source/match/maps/DesertFrontier.tscn")
		for side in get_nodes_in_group("players"):
			side.set_process(false)
		paused = true
		var player = game._get_human_player()
		player.resource_a = 1000
		player.resource_b = 1000
		var worker = _units(player, "Worker")[0]
		root.get_node("MatchSignals").deselect_all_units.emit()
		worker.get_node("Selection").select()
		await _frames(8)
		var menus = game.find_child("UnitMenus")
		_check(
			menus._pages.get_current_tab_control().name == "Build",
			"Worker build choices require another menu"
		)
		_check(menus._pages.tabs_visible, "Direct operation tabs are hidden")
		_check(menus.find_child("MenuNavigation", true, false) == null, "Nested navigation remains")
		var placement = player.get_node("StructurePlacementHandler")
		for entry in menus._buttons:
			_check(entry.button._title.is_visible_in_tree(), "Building choice hides its name")
			_check(entry.button._materials.is_visible_in_tree(), "Building choice hides its price")
			_check(entry.button._portrait.is_visible_in_tree(), "Building choice has no picture")
		var funds = Vector2i(player.resource_a, player.resource_b)
		await _key(KEY_B)
		_check(placement._structure_placement_started(), "One B did not start Barracks placement")
		_check(
			placement._pending_structure_prototype.resource_path.ends_with("Barracks.tscn"),
			"B chose another building"
		)
		_check(
			Vector2i(player.resource_a, player.resource_b) == funds, "Opening placement spent funds"
		)
		await _key(KEY_ESCAPE)
		_check(not placement._structure_placement_started(), "Escape did not cancel placement")
		_check(game.hud._overlay == null, "Escape opened a floating menu")
		_check(
			menus._pages.get_current_tab_control().name == "Build",
			"Placement returned to a parent menu"
		)
		await _tab(menus, "Orders")
		_check(menus._pages.get_current_tab_control().name == "Orders", "Orders tab click failed")
		await _tab(menus, "Build")
		_check(menus._pages.get_current_tab_control().name == "Build", "Build tab click failed")
		var echo_key = InputEventKey.new()
		echo_key.keycode = KEY_B
		echo_key.physical_keycode = KEY_B
		echo_key.pressed = true
		echo_key.echo = true
		root.push_input(echo_key, true)
		await _frames(3)
		_check(not placement._structure_placement_started(), "Held B repeated placement")
		player.resource_a = 0
		player.resource_b = 0
		menus._refresh_buttons()
		await _key(KEY_B)
		_check(
			not placement._structure_placement_started(), "Unaffordable hotkey started placement"
		)
		player.resource_a = funds.x
		player.resource_b = funds.y
		menus._refresh_buttons()
		var barracks = menus._buttons.filter(func(entry): return entry.type == "Barracks")[0]
		await _click(barracks.button)
		_check(placement._structure_placement_started(), "Barracks picture click failed")
		await _key(KEY_ESCAPE)
		for before_paused in [true, false]:
			paused = before_paused
			game.hud.open_technology()
			await _frames(8)
			_check(paused == before_paused, "Opening docked research changed pause state")
			_check(game.hud._overlay == null, "Research created a floating overlay")
			var panel = game.hud.technology_panel
			game.hud._open_menu()
			game.hud._close_menu()
			_check(game.hud.technology_panel == panel, "Battle menu lost docked research reference")
			_check(menus.is_ancestor_of(panel), "Research is outside the bottom HUD")
			_check(get_nodes_in_group("selected_units") == [worker], "Research changed selection")
			_check(
				menus.get_global_rect().grow(1).encloses(panel.get_global_rect()),
				"Research exceeds its dock"
			)
			await _key(KEY_ESCAPE)
			_check(game.hud.technology_panel == null, "Escape did not leave research")
			_check(paused == before_paused, "Closing research changed pause state")
		paused = true
		game.hud.open_technology()
		var panel = game.hud.technology_panel
		panel._branches.weapons.button.pressed.emit()
		panel._start.pressed.emit()
		_check(panel._queue_rows.size() == 1, "Docked research omitted its queued icon")
		panel._queue_rows[0].cancel.pressed.emit()
		panel._cancel.pressed.emit()
		_check(
			Vector2i(player.resource_a, player.resource_b) == funds,
			"Docked research refund differs"
		)
		_units(player, "Tank")[0].get_node("Selection").select()
		await _frames(8)
		_check(game.hud.technology_panel == null, "New selection retained the research view")
		game.hud.open_technology()
		await _frames(5)
		panel = game.hud.technology_panel
		panel._branches.weapons.button.pressed.emit()
		panel._start.pressed.emit()
		panel._branches.armor.button.pressed.emit()
		panel._queue_rows[0].cancel.grab_focus()
		var last = panel._queue_rows[1].cancel
		await _key(KEY_TAB)
		_check(get_nodes_in_group("selected_units").size() == 2, "Research Tab cycled army classes")
		_check(root.gui_get_focus_owner() == last, "Research Tab did not reach next queued project")
		_check(game.hud.technology_panel == panel, "Research Tab rebuilt its bottom panel")
		await _key(KEY_ESCAPE)
		await _commander_controls(player, worker, menus)
		if faction == "bastion":
			await _engineering_controls(player, worker, menus)
		elif faction == "helix":
			await _overdrive_controls(player, menus)
		paused = false
		game.queue_free()
		await _frames(5)
	preferences.key_bindings = saved_bindings
	preferences.apply()
	for message in errors:
		push_error(message)
	print("Flat operation menus: %d failures" % errors.size())
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)


func _commander_controls(player, worker, menus):
	game.hud.select_units([worker])
	await _frames(8)
	if player.faction != "bastion":
		_check(
			menus._command_card._slots[2][3].badge.is_empty(),
			"A non-Bastion worker exposes an unusable dismantle shortcut"
		)
	var support = game.commander_support
	support.set_physics_process(false)
	support.state(player).started = true
	support.state(player).left = 0.0
	var commands = game.hud.direct_orders
	for before_paused in [true, false]:
		paused = before_paused
		var funds = Vector2i(player.resource_a, player.resource_b)
		await _key(KEY_F6)
		_check(menus._commander_open, "F6 did not open commander support")
		_check(game.hud._overlay == null, "Commander support created a floating overlay")
		_check(paused == before_paused, "Commander submenu changed pause state")
		_check(get_nodes_in_group("selected_units") == [worker], "Commander submenu lost selection")
		var panel = menus._commander_panel
		_check(is_instance_valid(panel), "Commander submenu has no power control")
		if not is_instance_valid(panel):
			return
		_check(
			menus.get_global_rect().grow(1).encloses(panel.get_global_rect()),
			"Commander support exceeds its bottom dock"
		)
		await _key(KEY_Q)
		_check(commands.kind == "commander", "Commander Q activated a selected unit ability")
		_check(
			is_instance_valid(commands._ability_range), "Commander targeting omitted its preview"
		)
		await _key(KEY_ESCAPE)
		_check(
			commands.kind.is_empty() and menus._commander_open and game.hud._overlay == null,
			"First Escape did not cancel targeting while retaining the commander submenu"
		)
		await _key(KEY_Q)
		await _right_click_world()
		_check(
			commands.kind.is_empty() and menus._commander_open,
			"Right-click did not cancel commander targeting"
		)
		_check(
			(
				Vector2i(player.resource_a, player.resource_b) == funds
				and support.state(player).left == 0.0
				and support.pending.is_empty()
			),
			"Canceled commander targeting spent resources, charge or committed an effect"
		)
		await _key(KEY_ESCAPE)
		_check(
			not menus._commander_open and game.hud._overlay == null,
			"Second Escape failed to return from commander support"
		)
		_check(paused == before_paused, "Commander cancellation changed pause state")
		_check(
			get_nodes_in_group("selected_units") == [worker],
			"Commander cancellation changed selection"
		)
	paused = true
	root.get_node("MatchSignals").deselect_all_units.emit()
	await _frames(5)
	var opener = game.find_child("OpenCommanderSupport", true, false)
	_check(is_instance_valid(opener), "Persistent commander icon is missing")
	if is_instance_valid(opener):
		await _click(opener)
		_check(menus._commander_open, "Commander icon requires a selected unit")
		_check(get_nodes_in_group("selected_units").is_empty(), "Commander icon selected a unit")
		await _key(KEY_ESCAPE)
	game.hud.select_units([worker])
	await _frames(5)


func _engineering_controls(player, worker, menus):
	paused = true
	game.hud.select_units([worker])
	await _frames(5)
	var funds = Vector2i(player.resource_a, player.resource_b)
	var commands = game.hud.direct_orders
	menus.open_page("Build")
	await _frames(3)
	var button = menus._engineering_buttons[0].button
	player.resource_a = 9
	menus._refresh_buttons()
	_check(
		button.disabled and button.tooltip_text.contains(tr("Not enough Materials.")),
		"Unaffordable barricade build button does not explain its cost"
	)
	await _key(KEY_Q)
	_check(commands.kind.is_empty(), "Unaffordable Build Q armed a barricade")
	player.resource_a = funds.x
	menus._refresh_buttons()
	await _key(KEY_Q)
	_check(
		commands.kind == "ability" and commands.ability_id == "field_barricade",
		"Build Q did not target a field barricade"
	)
	var preview = commands._ability_range
	_check(is_instance_valid(preview), "Barricade targeting has no placement preview")
	await _key(KEY_R)
	_check(
		(
			commands.ability_id == "field_barricade"
			and is_equal_approx(commands.engineering_angle, PI / 4)
		),
		"Rotate activated dismantling instead of rotating the barricade"
	)
	await _key(KEY_ESCAPE)
	_check(
		commands.kind.is_empty() and game.hud._overlay == null, "Escape did not cancel barricade"
	)
	_check(
		(
			Vector2i(player.resource_a, player.resource_b) == funds
			and game.engineering.cooldown_left(worker) == 0.0
			and game.engineering.count_for(player, "barricade") == 0
		),
		"Canceled barricade targeting spent resources or reserved a deployment"
	)
	_check(
		paused and get_nodes_in_group("selected_units") == [worker],
		"Barricade targeting lost context"
	)


func _overdrive_controls(player, menus):
	paused = true
	var generator = _units(player, "PowerPlant")[0]
	game.hud.select_units([generator])
	await _frames(8)
	var card = menus._command_card
	_check(is_instance_valid(card), "A selected generator omitted its support ability card")
	if not is_instance_valid(card):
		return
	var buttons = card.get_children().filter(
		func(button): return button is BaseButton and button.is_visible_in_tree()
	)
	_check(buttons.size() == 1, "Generator card exposes blank or movement command rows")
	if buttons.size() != 1:
		return
	var overdrive = buttons[0]
	_check(overdrive.badge == "E", "Generator support ability has the wrong shortcut")
	_check(
		(
			overdrive.disabled
			and overdrive.tooltip_text.contains(tr("Requires Plasma Shields research."))
		),
		"Unavailable Overdrive does not explain its research prerequisite"
	)
	player.technology.completed.append("plasma_shields")
	card._refresh_abilities()
	_check(not overdrive.disabled, "Exactly 3 spare power did not enable researched Overdrive")
	var consumer = load("res://source/match/units/AntiGroundTurret.tscn").instantiate()
	game._setup_and_spawn_unit(
		consumer,
		Transform3D(Basis.IDENTITY, generator.global_position + Vector3(12, 0, 12)),
		player,
		false
	)
	consumer.process_mode = Node.PROCESS_MODE_DISABLED
	card._refresh_abilities()
	_check(
		overdrive.disabled and overdrive.tooltip_text.contains(tr("Requires 3 spare power.")),
		"Overdrive does not explain its power requirement below 3 spare power"
	)
	var reserve = load("res://source/match/units/PowerPlant.tscn").instantiate()
	game._setup_and_spawn_unit(
		reserve,
		Transform3D(Basis.IDENTITY, generator.global_position + Vector3(0, 0, 12)),
		player,
		false
	)
	card._refresh_abilities()
	_check(not overdrive.disabled, "Additional power did not enable researched Overdrive")
	_check(
		card.size.y < overdrive.size.y * 1.5,
		"The support-only ability occupies a full command-card grid"
	)
	await _key(KEY_E)
	_check(not game.helix_support.requested(generator), "Paused E activated Overdrive")
	_check(paused, "Overdrive hotkey resumed a paused battle")
	var power = player.power_totals()
	paused = false
	await _key(KEY_E)
	card._refresh_abilities()
	_check(
		game.helix_support.requested(generator) and player.power_totals().y == power.y + 3,
		"Generator E did not enable Overdrive with its power demand"
	)
	_check(overdrive.button_pressed, "Active Overdrive is not represented on its button")
	var support = game.helix_support
	support._refresh_generator_visuals(generator)
	var cores = support._cores.get(generator, {}).get("surfaces", [])
	_check(not cores.is_empty(), "Operating Overdrive did not find authored generator cores")
	var original_overrides = cores.map(func(core): return core.override)
	var operating_energy = cores.map(func(core): return core.material.emission_energy_multiplier)
	var core_meshes = cores.map(func(core): return core.mesh)
	var core_surfaces = cores.map(func(core): return core.surface)
	reserve._construction_progress = 0.0
	card._refresh_abilities()
	menus._refresh_buttons()
	support._refresh_generator_visuals(generator)
	_check(support.overdrive_status(generator) == "suspended", "Fixture did not suspend Overdrive")
	_check(
		(
			overdrive.tooltip_text.contains(tr("Suspended: low power"))
			and not overdrive.tooltip_text.ends_with("\n" + tr("Active"))
		),
		"Suspended Overdrive tooltip still claims to be active"
	)
	_check(
		menus._status.text.contains(tr("Overdrive suspended · low power")),
		"Selected generator does not explain its suspended Overdrive"
	)
	for index in cores.size():
		_check(
			cores[index].material.emission_energy_multiplier < operating_energy[index],
			"Low power left the generator cores at operating brightness"
		)
	reserve._construction_progress = 1.0
	card._refresh_abilities()
	menus._refresh_buttons()
	support._refresh_generator_visuals(generator)
	_check(support.operating(generator), "Restored power did not resume the Overdrive presentation")
	_check(
		not overdrive.tooltip_text.contains(tr("Suspended: low power")),
		"Overdrive retained its suspended tooltip after power returned"
	)
	for index in cores.size():
		_check(
			cores[index].material.emission_energy_multiplier == operating_energy[index],
			"Restored power did not restore generator core brightness"
		)
	await _click(overdrive)
	support._refresh_generator_visuals(generator)
	_check(
		not game.helix_support.requested(generator) and player.power_totals().y == power.y,
		"Clicking active Overdrive did not disable it and release power"
	)
	_check(not support._cores.has(generator), "Disabled Overdrive retained a presentation override")
	for index in core_meshes.size():
		_check(
			(
				core_meshes[index].get_surface_override_material(core_surfaces[index])
				== original_overrides[index]
			),
			"Disabled Overdrive did not restore the authored generator material"
		)
	_check(
		get_nodes_in_group("selected_units") == [generator] and not paused,
		"Overdrive controls changed selection or pause state"
	)
	consumer.queue_free()
	reserve.queue_free()


func _right_click_world():
	var point = Vector2(root.size) * Vector2(.5, .25)
	for down in [true, false]:
		var event = InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_RIGHT
		event.pressed = down
		root.push_input(event, true)
		await _frames(4)


func _key(code):
	for down in [true, false]:
		var event = InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		root.push_input(event, true)
		await _frames(3)


func _click(control):
	await _frames(2)
	var point = control.get_global_rect().get_center()
	for down in [true, false]:
		var event = InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		root.push_input(event, true)
		await _frames(4)


func _tab(menus, title):
	var bar = menus._pages.get_tab_bar()
	for index in menus._pages.get_tab_count():
		if menus._pages.get_child(index).name != title:
			continue
		var point = bar.global_position + bar.get_tab_rect(index).get_center()
		for down in [true, false]:
			var event = InputEventMouseButton.new()
			event.position = point
			event.global_position = point
			event.button_index = MOUSE_BUTTON_LEFT
			event.pressed = down
			root.push_input(event, true)
			await _frames(4)
		return
