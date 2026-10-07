extends CanvasLayer

signal library_changed

const Parameters = preload("res://source/match/programs/LuaParameters.gd")
const Assistant = preload("res://source/match/hud/LLMAssistant.gd")
const GeneratedDraft = preload("res://source/match/programs/llm/DraftResponse.gd")
const Library = preload("res://source/match/programs/ProgramLibrary.gd")
const ArenaResearch = preload("res://source/match/programs/arena/ArenaResearch.gd")
const Record = preload("res://source/match/programs/ProgramRecord.gd")
const Application = preload("res://source/match/programs/ProgramApplication.gd")
const Runtime = preload("res://source/match/programs/LuaRuntime.gd")
const DraftCheck = preload("res://source/match/programs/LuaDraftCheck.gd")
const STARTERS = ["hold", "guard", "repair"]
const ROLE_TITLES = [
	"All compatible roles",
	"Tank",
	"Advanced tank",
	"Combat robot",
	"Repair robot",
	"Drone",
	"Helicopter"
]
var assistant_settings_path = Assistant.Config.PATH
var selection = []
var library_path = Library.PATH
var initial = {}
var game
var _was_paused = false
var _closing = false
var _library = Library.new()
var _entries = []
var _loaded = {}
var _custom_roles = []
var _name: LineEdit
var _source: CodeEdit
var _roles: OptionButton
var _requirements: OptionButton
var _saved: OptionButton
var _starter: OptionButton
var _summary: Label
var _notice: Label
var _trace: TextEdit
var _apply_button: Button
var _panel: PanelContainer
var _version: Label
var _heading: Label
var _guide_heading: Label
var _guide: Label
var _actions: HBoxContainer
var _arena_bridge
var _arena_button: Button
var _arena_report = {}
var _parameter_schema = {}
var _parameter_button: Button
var _assistant_state = {}
var _modal


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 30
	_was_paused = get_tree().paused
	get_tree().paused = true
	_build_ui()
	_reload_library()
	if not initial.is_empty():
		_show_draft(initial)
	else:
		_use_starter()
	_focus_editor()
	_refresh()


func _build_ui():
	var shade = ColorRect.new()
	shade.color = Color("080e17e8")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	_panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color("19232f")
	style.set_corner_radius_all(10)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	_panel.add_theme_stylebox_override("panel", style)
	margin.add_child(_panel)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_panel.add_child(column)
	var header = _row(column)
	_heading = _label(header, "UNIT PROGRAM / LUA", 22)
	_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if authoring_mode() == "lua":
		_parameter_button = _button(header, "Parameters", _open_parameters)
		_button(header, "AI assistant", _open_assistant)
	_button(header, "Close [Esc]", close_editor)
	_label(column, "Battle paused · Drafts stay separate from unit orders.", 13)
	var library_row = _row(column)
	_saved = OptionButton.new()
	_saved.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_saved.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_saved.item_selected.connect(_load_saved)
	library_row.add_child(_saved)
	_button(library_row, "Refresh library", _reload_library)
	_starter = OptionButton.new()
	for title_text in _starter_titles():
		_starter.add_item(title_text)
	library_row.add_child(_starter)
	_button(library_row, "New from starter", _use_starter)
	var fields = _row(column)
	_name = LineEdit.new()
	_name.placeholder_text = "Program name"
	_name.max_length = 40
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name.text_changed.connect(func(_text): _draft_changed())
	fields.add_child(_name)
	_roles = OptionButton.new()
	for title_text in ROLE_TITLES:
		_roles.add_item(title_text)
	_roles.item_selected.connect(func(_index): _draft_changed())
	fields.add_child(_roles)
	_requirements = OptionButton.new()
	for title_text in ["Needs: movement", "Needs: weapons", "Needs: repair tools"]:
		_requirements.add_item(title_text)
	_requirements.item_selected.connect(func(_index): _draft_changed())
	fields.add_child(_requirements)
	var body = HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	column.add_child(body)
	_source = CodeEdit.new()
	_source.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_source.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_source.custom_minimum_size = Vector2(400, 220)
	_source.gutters_draw_line_numbers = true
	_source.indent_size = 4
	_source.indent_use_spaces = true
	_source.auto_brace_completion_enabled = true
	var code_font = SystemFont.new()
	code_font.font_names = PackedStringArray(["Menlo", "Consolas", "DejaVu Sans Mono", "monospace"])
	_source.add_theme_font_override("font", code_font)
	_source.add_theme_font_size_override("font_size", 14)
	_source.text_changed.connect(_draft_changed)
	var syntax = CodeHighlighter.new()
	for keyword in [
		"return",
		"function",
		"end",
		"local",
		"if",
		"then",
		"else",
		"elseif",
		"for",
		"in",
		"do",
		"while",
		"true",
		"false",
		"nil",
		"and",
		"or",
		"not"
	]:
		syntax.add_keyword_color(keyword, Color("b6a5eb"))
	syntax.symbol_color = Color("c7d4df")
	syntax.function_color = Color("87bddf")
	syntax.member_variable_color = Color("c7d4df")
	syntax.number_color = Color("e8be83")
	syntax.add_color_region("--", "", Color("8d9dad"), true)
	syntax.add_color_region('"', '"', Color("89cbb8"))
	syntax.add_color_region("'", "'", Color("89cbb8"))
	_source.syntax_highlighter = syntax
	body.add_child(_source)
	var side = VBoxContainer.new()
	side.custom_minimum_size.x = 280
	side.add_theme_constant_override("separation", 8)
	body.add_child(side)
	_guide_heading = _label(side, "SCRIPT GUIDE", 14)
	var guide_scroll = ScrollContainer.new()
	guide_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	guide_scroll.size_flags_stretch_ratio = 2.0
	guide_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side.add_child(guide_scroll)
	_guide = _label(
		guide_scroll,
		(
			"Return a function(snapshot, state).\nReturn {intent = {...}, state = state}.\n\n"
			+ "hold · stay and defend\nmove · name a point assignment\n"
			+ "attack / repair · use a contact id\nguard · defend your 6 m area\n"
			+ "escort · follow your chosen ally\n\n"
			+ "Points: anchor, safe, route_a, route_b.\nSet them on the battlefield.\n\n"
			+ "Read self, enemies and allies.\nOnly current observed contacts appear.\n"
			+ "Direct orders always take priority."
		),
		13
	)
	_guide.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_guide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label(side, "CHECK RESULTS", 14)
	_trace = TextEdit.new()
	_trace.editable = false
	_trace.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_trace.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_trace.custom_minimum_size.y = 70
	_trace.add_theme_font_size_override("font_size", 12)
	_trace.add_theme_color_override("font_readonly_color", Color("bdccd9"))
	_trace.text = "Checks eight sample snapshots in isolation. This is not a battle simulation."
	side.add_child(_trace)
	_version = _label(column, "", 12)
	_summary = _label(column, "", 13)
	_notice = _label(column, "", 13)
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notice.max_lines_visible = 2
	_notice.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_actions = _row(column)
	_button(_actions, "Check samples", _check_samples)
	_arena_button = _button(_actions, "Battle arena", _open_arena)
	_button(_actions, "Save version", _save)
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_actions.add_child(spacer)
	_apply_button = _button(_actions, "Apply & run", _apply)


func _row(parent):
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	return row


func _label(parent, text, font_size):
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label


func _button(parent, text, callback):
	var button = Button.new()
	button.text = text
	button.custom_minimum_size.y = 34
	button.add_theme_font_size_override("font_size", 13)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _draft():
	var requirements = ["movement"]
	if _requirements.selected > 0:
		requirements.append("attack" if _requirements.selected == 1 else "repair")
	var roles = Record.ROLES.duplicate()
	if _roles.selected == ROLE_TITLES.size():
		roles = _custom_roles.duplicate()
	elif _roles.selected > 0:
		roles = [Record.ROLES[_roles.selected - 1]]
	if _roles.selected == 0:
		roles = roles.filter(func(role): return Record.meets_requirements(requirements, role))
	var value = Record.lua(_name.text.strip_edges(), 1, _source.text, roles, requirements)
	value.parameter_schema = _parameter_schema.duplicate(true)
	return Record.seal(value)


func _matches_loaded(draft):
	return (
		not _loaded.is_empty()
		and (
			Record._canonical(
				[draft.name, draft.source, draft.roles, draft.requirements, draft.parameter_schema]
			)
			== Record._canonical(
				[
					_loaded.name,
					_loaded.source,
					_loaded.roles,
					_loaded.requirements,
					_loaded.parameter_schema
				]
			)
		)
	)


func _draft_changed():
	if not Parameters.valid(_parameter_schema, _source.text):
		_parameter_schema = {}
	if _trace != null:
		_trace.text = "Draft changed. Run sample checks again."
	if _notice != null:
		_set_notice("Draft changed. Save a version before applying.")
	_refresh()


func _refresh():
	if _apply_button == null:
		return
	var draft = _draft()
	if _parameter_button != null:
		_parameter_button.disabled = _parameter_schema.is_empty()
	var preview = Application.preview(draft, selection, game._get_human_player())
	_summary.text = (
		"%d ready · %d incompatible · %d need chip / technology · %d unavailable"
		% [preview.eligible.size(), preview.incompatible, preview.unready, preview.unavailable]
	)
	var saved = _matches_loaded(draft)
	_version.text = (
		("%s · v%d · Lua API %d" % [_loaded.name, _loaded.version, _loaded.api_version])
		if saved
		else (
			"Unsaved draft · Save a version before applying · %d / 32,768 bytes"
			% _source.text.to_utf8_buffer().size()
		)
	)
	_apply_button.disabled = not saved or preview.eligible.is_empty() or not Runtime.available()


func _show_draft(value):
	_trace.text = "Loaded draft. Check samples or run a battle scenario."
	_loaded = value.duplicate(true) if Record.validate(value) else {}
	_name.text = value.get("name", "Custom Lua")
	_source.text = value.get("source", "")
	_parameter_schema = (
		value.get("parameter_schema", {}).duplicate(true) if value.get("mode") == "lua" else {}
	)
	var roles = value.get("roles", Record.ROLES)
	var requirements = value.get("requirements", ["movement"])
	var all_roles = Record.ROLES.filter(
		func(role): return Record.meets_requirements(requirements, role)
	)
	if _roles.item_count > ROLE_TITLES.size():
		_roles.remove_item(ROLE_TITLES.size())
	if roles.size() == 1:
		_roles.select(Record.ROLES.find(roles[0]) + 1)
	elif roles == all_roles or roles.is_empty():
		_roles.select(0)
	else:
		_custom_roles = roles.duplicate()
		_roles.add_item("Saved role group")
		_roles.set_item_tooltip(ROLE_TITLES.size(), ", ".join(roles))
		_roles.select(ROLE_TITLES.size())
	_requirements.select(2 if "repair" in requirements else (1 if "attack" in requirements else 0))
	_refresh()


func _use_starter():
	_trace.text = "New starter. Check samples or run a battle scenario."
	_parameter_schema = {}
	var kind = STARTERS[_starter.selected]
	_loaded = {}
	_name.text = ["Hold position", "Guard & regroup", "Repair area"][_starter.selected]
	_source.text = FileAccess.get_file_as_string("res://assets/programs/%s.lua" % kind)
	_roles.select(4 if kind == "repair" else 0)
	_requirements.select(2 if kind == "repair" else (1 if kind == "guard" else 0))
	_set_notice("Starter copied into a new draft. Check it, save a version, then apply.")
	_refresh()


func _reload_library():
	_entries.clear()
	_saved.clear()
	_saved.add_item(
		"Load a saved %s version…" % ("rule" if authoring_mode() == "visual" else "Lua")
	)
	if not _library.read_library(library_path):
		_set_notice(_library.error)
		return
	for entry in _library.versions:
		if entry.mode == authoring_mode():
			_entries.append(entry)
			_saved.add_item("%s · v%d" % [entry.name, entry.version])


func _load_saved(index):
	if index > 0 and index <= _entries.size():
		_show_draft(_entries[index - 1])
		_set_notice("Loaded a saved version. Unit orders are unchanged until Apply & run.")


func _check_samples():
	var draft = _draft()
	if not Record.validate(draft):
		_set_notice("Use a name, compatible role requirements and 1–32,768 bytes of Lua source.")
		return
	var traces = []
	for role in draft.roles:
		var result = DraftCheck.check(draft.source, role)
		if not result.ok:
			_trace.text = "%s: %s" % [role, result.error]
			_set_notice("Sample check failed. Current unit orders are unchanged.")
			return
		traces.append(role + "\n" + result.trace)
	_trace.text = "\n\n".join(traces)
	_set_notice(
		(
			"Eight samples passed for each of %d roles. Battle behavior is not simulated."
			% draft.roles.size()
		)
	)


func _open_arena():
	if is_instance_valid(_arena_bridge) and _arena_bridge.pid > 0:
		_set_notice("The arena is open in its own window. Return there to run or finish a test.")
		return
	var draft = _draft()
	if not Record.validate(draft):
		_set_notice("Correct the draft before opening the battle arena.")
		return
	var runtime = Runtime.new()
	var compiled = runtime.compile_source(draft.source)
	if not compiled.ok:
		_set_notice(compiled.error)
		return
	if not is_instance_valid(_arena_bridge):
		_arena_bridge = load("res://source/match/programs/arena/ArenaBridge.gd").new()
		add_child(_arena_bridge)
		_arena_bridge.finished.connect(_arena_finished)
	var human = game._get_human_player()
	var result = _arena_bridge.launch(draft, human.faction, ArenaResearch.capture(human))
	_set_notice(
		(
			"Arena opened in a separate window. Your battle stays paused; this draft can be unsaved."
			if result.ok
			else result.error
		)
	)


func _arena_finished(report):
	if not report.ok:
		_set_notice(report.error)
		return
	if report.content_hash != _draft().content_hash:
		_set_notice("Arena finished for an earlier draft. Run the changed program again.")
		return
	_arena_report = report.duplicate(true)
	var lines = []
	for result in report.results:
		if not result is Dictionary:
			continue
		lines.append(
			(
				"%s · %s · %s"
				% [
					result.get("scenario", "Test"),
					result.get("role", ""),
					"Passed" if result.get("passed", false) else "Expected behavior not met"
				]
			)
		)
		lines.append(
			"Research: " + ArenaResearch.summary(result.get("research", ArenaResearch.baseline()))
		)
		for check in result.get("checks", []):
			lines.append(("PASS · " if check.passed else "FAIL · ") + check.text)
		if not result.get("error", "").is_empty():
			lines.append(result.error)
	_trace.text = "\n".join(lines) if not lines.is_empty() else "No scenario completed."
	_set_notice("Arena results returned. Save and Apply remain separate choices.")


func _save():
	_refresh()
	var draft = _draft()
	if not Record.validate(draft):
		_set_notice("Use a name, compatible role requirements and 1–32,768 bytes of Lua source.")
		return
	var runtime = Runtime.new()
	var compiled = runtime.compile_source(draft.source)
	if not compiled.ok:
		_set_notice(compiled.error)
		return
	draft.test_notes = "Initialization checked. Battlefield behavior not verified."
	if _arena_report.get("content_hash") == draft.content_hash:
		var notes = []
		for result in _arena_report.results:
			notes.append(
				(
					"%s / %s / %s: %s"
					% [
						result.get("faction", ""),
						result.get("role", ""),
						result.get("scenario", "Test"),
						(
							"expected behavior observed"
							if result.get("passed", false)
							else "expected behavior not met"
						)
					]
				)
			)
			notes.append(
				(
					"Research: "
					+ ArenaResearch.summary(result.get("research", ArenaResearch.baseline()))
				)
			)
		if not notes.is_empty():
			draft.test_notes = (
				("Initialization checked. Scenario evidence only. " + "; ".join(notes)).left(1000)
			)
	Record.seal(draft)
	var saved = _library.save_record(draft, library_path)
	if saved == null:
		_set_notice(_library.error)
		return
	_loaded = saved
	library_changed.emit()
	_reload_library()
	_set_notice(
		(
			"Saved %s · v%d. Existing units and factory jobs keep their programs."
			% [saved.name, saved.version]
		)
	)
	_refresh()


func _apply():
	if not _matches_loaded(_draft()):
		_set_notice("Save this draft as a new version before applying.")
		return
	var result = Application.apply(_loaded, selection, game._get_human_player())
	if not result.ok:
		_set_notice(result.error)
		return
	_set_notice(
		(
			"Applied to %d units; %d keep their orders. Runs when battle resumes."
			% [result.applied, result.skipped]
		)
	)
	_refresh()


func _set_notice(text):
	_notice.text = text
	_notice.tooltip_text = text


func _input(event):
	if is_instance_valid(_modal):
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close_editor()


func _unhandled_input(_event):
	get_viewport().set_input_as_handled()


func close_editor():
	if _closing:
		return
	_closing = true
	var draft_state = {
		"draft": _draft(),
		"loaded": _loaded.duplicate(true),
		"role_index": _roles.selected,
		"requirement_index": _requirements.selected
	}
	_store_draft(draft_state)
	_restore_pause()
	queue_free()


func _restore_pause():
	if is_instance_valid(game) and not game.is_queued_for_deletion() and not game.finished:
		get_tree().paused = _was_paused


func _exit_tree():
	if not _closing:
		_restore_pause()


func authoring_mode():
	return "lua"


func _starter_titles():
	return ["Hold position", "Guard & regroup", "Repair area"]


func _focus_editor():
	_source.grab_focus()


func _store_draft(value):
	value["arena_report"] = _arena_report.duplicate(true)
	value["assistant_state"] = _assistant_state.duplicate(true)
	if authoring_mode() == "visual":
		game.hud.visual_draft = value
	else:
		game.hud.lua_draft = value


func _open_assistant():
	if is_instance_valid(_modal):
		return
	_modal = Assistant.new()
	_modal.current_draft = _draft()
	_modal.settings_path = assistant_settings_path
	_modal.diagnostics = _trace.text
	_modal.initial = _assistant_state.duplicate(true)
	_modal.imported.connect(_import_generated)
	_modal.closed.connect(
		func(state):
			_assistant_state = state
			_modal = null
			_focus_editor()
	)
	add_child(_modal)


func _import_generated(value, roles):
	var draft = Record.lua(
		value.name.strip_edges(), 1, GeneratedDraft.source(value), roles, ["movement"]
	)
	draft.parameter_schema = Parameters.schema(value.parameters)
	Record.seal(draft)
	_show_draft(draft)
	_loaded = {}
	_arena_report = {}
	_trace.text = "Imported AI draft. Check samples and battlefield behavior before applying."
	_set_notice(
		"Imported as an unsaved draft. Check the roles and assignments, then test and save."
	)
	_refresh()


func _open_parameters():
	if is_instance_valid(_modal) or _parameter_schema.is_empty():
		return
	_modal = load("res://source/match/hud/LuaParameterDialog.gd").new()
	_modal.values = _parameter_schema.values.duplicate(true)
	_modal.accepted.connect(_update_parameters)
	_modal.closed.connect(
		func():
			_modal = null
			_focus_editor()
	)
	add_child(_modal)


func _update_parameters(values):
	var updated = Parameters.replace(_source.text, _parameter_schema, values)
	if updated.is_empty():
		_set_notice("Parameter/source mismatch. Current draft retained.")
		return
	_source.text = updated.source
	_parameter_schema = updated.parameter_schema
	_draft_changed()
