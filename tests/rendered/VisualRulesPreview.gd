extends "res://tests/rendered/LuaEditorPreview.gd"


func _run():
	create_timer(45).timeout.connect(
		func():
			push_error("Visual UI test timed out")
			quit(1)
	)
	var original = await _prepare_720p()
	var settings = load("res://source/data-model/MatchSettings.gd").new()
	settings.skirmish = true
	settings.advanced_start = true
	settings.map_path = "res://source/match/maps/BastionDesert.tscn"
	for side in range(2):
		var player = load("res://source/data-model/PlayerSettings.gd").new()
		player.controller = (
			root.get_node("Constants").PlayerType.HUMAN
			if side == 0
			else root.get_node("Constants").PlayerType.SIMPLE_CLAIRVOYANT_AI
		)
		player.faction = "bastion" if side == 0 else "helix"
		player.color = Color("e3ad48") if side == 0 else Color("38c8ce")
		settings.players.append(player)
	_game = load("res://source/match/Skirmish.tscn").instantiate()
	_game.settings = settings
	_game.map = load(settings.map_path).instantiate()
	root.add_child(_game)
	current_scene = _game
	get_nodes_in_group("players")[1].set_process(false)
	_game.get_node("IsometricCamera3D").set_physics_process(false)
	await _frames(50)
	var human = _game._get_human_player()
	var tanks = human.get_children().filter(
		func(unit): return "type" in unit and unit.type == "Tank"
	)
	for tank in tanks:
		tank.get_node("Selection").select()
	await _frames(4)
	var panel = _game.find_child("UnitMenus")._program_panel
	_path = "user://visual-editor-%d.json" % OS.get_process_id()
	panel.library_path = _path
	await _click(_button_named(panel, "Visual rules"))
	var editor = _game.hud.program_editor
	_check(editor != null and editor.authoring_mode() == "visual", "Visual editor button failed")
	var clock_before = _game.simulation_time
	var action_before = tanks[0].action
	editor._starter.select(1)
	await _click(_button_named(editor, "New from starter"))
	_check(editor._cards.document.rules.size() == 2, "Visual guard starter lost cards")
	# Change a real spin control using keyboard input; no Lua editing is needed.
	var input = editor._cards._retreat.get_line_edit()
	await _click(input)
	input.select_all()
	_key(KEY_4, 52)
	_key(KEY_0, 48)
	_key(KEY_ENTER)
	await _frames(3)
	_check(editor._cards.document.parameters.retreat == 40, "Keyboard threshold edit failed")
	await _click(editor._cards.row_controls[1].up)
	_check(editor._cards.document.rules[0].action == "guard", "Rule reorder failed")
	await _click(editor._cards.row_controls[0].down)
	_check(editor._cards.document.rules[0].when == "retreating", "Rule order was not restored")
	await _click(editor._cards._states)
	_check(editor._cards._initial.visible, "Named-state controls missing")
	var row = editor._cards.row_controls[0]
	row.next.select(2)
	row.next.item_selected.emit(2)
	_check(editor._cards.document.rules[0].next_state == "regroup", "State transition edit failed")
	editor._name.text = "Visual perimeter"
	await _click(_button_named(editor, "Check samples"))
	_check(
		"passed" in editor._notice.text, "Generated rules failed samples: " + editor._notice.text
	)
	_check(
		_game.simulation_time == clock_before and tanks[0].action == action_before,
		"Editing/checking changed battle"
	)
	await _click(_button_named(editor, "Save version"))
	_check(editor._loaded.get("mode") == "visual", "Visual Save lost rule document")
	_check(not editor._apply_button.disabled, "Saved visual rules cannot Apply")
	_check(editor._panel.get_global_rect().end.y <= 700, "Rule editor exceeds 720p")
	await _capture("visual-rules-720p")
	editor._tabs.current_tab = 1
	await _frames(3)
	_check(not editor._source.editable, "Generated Lua is editable inside visual mode")
	await _capture("visual-generated-lua-720p")
	editor._tabs.current_tab = 0
	await _click(editor._apply_button)
	_check(
		tanks[0].program.saved_record.mode == "visual" and tanks[0].program.mode == "Ready",
		"Visual Apply failed"
	)
	var deployed = tanks[0].program.lua_source
	# Copy remains an unsaved, separate Lua draft; no automatic execution or reverse conversion.
	await _click(_button_named(editor, "Copy as Lua"))
	await _frames(6)
	var lua = _game.hud.program_editor
	_check(
		lua.authoring_mode() == "lua" and lua._source.text == deployed,
		"Copy as Lua lost generated behavior"
	)
	_check(
		lua._loaded.is_empty() and lua._apply_button.disabled,
		"Lua copy auto-saved or became applicable"
	)
	_check(paused and _game.simulation_time == clock_before, "Editor handoff advanced the battle")
	lua._source.set_caret_line(0)
	lua._source.insert_text_at_caret("-- Custom copy\n")
	await _click(_button_named(lua, "Save version"))
	_check(lua._loaded.get("mode") == "lua", "Custom copy did not save as Lua")
	_key(KEY_ESCAPE)
	await _frames(4)
	_check(not paused, "Copied editor lost original pause owner")
	panel = _game.find_child("UnitMenus")._program_panel
	await _click(_button_named(panel, "Visual rules"))
	editor = _game.hud.program_editor
	_check(
		editor._cards.document.parameters.retreat == 40 and editor._loaded.mode == "visual",
		"Lua copy destroyed visual draft"
	)
	_check(editor._source.text == deployed, "Custom Lua edit contaminated rule source")
	# Reload the actual serialized graph, not just the in-memory draft.
	editor._load_saved(1)
	await _frames(3)
	_check(not editor._apply_button.disabled, "JSON numeric round-trip made saved rules dirty")
	editor._cards._retreat.value = 60
	editor._cards._recover.value = 40
	await _click(_button_named(editor, "Save version"))
	_check(
		"10 points" in editor._notice.text and tanks[0].program.lua_source == deployed,
		"Invalid thresholds replaced live behavior"
	)
	await _capture("visual-rules-validation-720p")
	_key(KEY_ESCAPE)
	await _frames(4)
	# Tactical pause is also retained when copying a visual draft into Lua.
	_game.hud._toggle_pause()
	await _click(_button_named(panel, "Visual rules"))
	editor = _game.hud.program_editor
	_check(editor._cards.document.parameters.recover == 40, "Invalid visual draft was discarded")
	editor._load_saved(1)
	await _click(_button_named(editor, "Copy as Lua"))
	await _frames(5)
	_key(KEY_ESCAPE)
	await _frames(3)
	_check(paused and _game.hud._pause_owned, "Lua copy released existing tactical pause")
	_game.hud._toggle_pause()
	DirAccess.remove_absolute(_path)
	_game.queue_free()
	await _frames(8)
	for message in _errors:
		push_error(message)
	if _errors.is_empty():
		print(
			(
				"PASS: visual rule cards/keyboard thresholds/order/states; generated preview/save/Apply; "
				+ "isolated Lua copy; retained drafts; pause ownership; 720p"
			)
		)
	root.get_node("Globals").options.restore(original)
	quit(0 if _errors.is_empty() else 1)
