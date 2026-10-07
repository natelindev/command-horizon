extends CanvasLayer

const Research = preload("res://source/match/programs/arena/ArenaResearch.gd")
const Scenarios = preload("res://source/match/programs/arena/ArenaScenarios.gd")
const Record = preload("res://source/match/programs/ProgramRecord.gd")
var request_path = ""
var request = {}
var session
var results = []
var _research: OptionButton
var _research_summary: Label
var _scenario: OptionButton
var _role: OptionButton
var _expected: Label
var _status: Label
var _trace: TextEdit
var _run_button: Button
var _pause_button: Button
var _paused = false
var _returning = false


func _ready():
	layer = 40
	Globals.options.request_display(DisplayServer.WINDOW_MODE_WINDOWED)
	get_window().mode = Window.MODE_WINDOWED
	get_window().min_size = Vector2i(1280, 720)
	get_window().size = Vector2i(1280, 720)
	get_window().content_scale_size = Vector2i(1920, 1080)
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	get_tree().auto_accept_quit = false
	DisplayServer.window_set_title("Program test arena")
	var file = FileAccess.open(request_path, FileAccess.READ)
	if file != null and file.get_length() <= 256 * 1024:
		var value = JSON.parse_string(file.get_as_text())
		if value is Dictionary:
			request = value
	if (
		not Record.validate(request.get("record"))
		or not Record.is_script(request.record)
		or request.get("faction") not in load("res://source/match/FactionCatalog.gd").IDS
		or not request.get("token") is String
		or request.token.length() != 32
		or not Research.valid(request.get("research", Research.baseline()))
	):
		get_tree().quit(1)
		return
	request.research = request.get("research", Research.baseline()).duplicate(true)
	session = load("res://source/match/programs/arena/ArenaSession.gd").new()
	session.record = request.record
	session.faction = request.faction
	add_child(session)
	session.updated.connect(_refresh_trace)
	session.completed.connect(_completed)
	_build_ui()
	_choose_default()
	_update_case()
	var ready_file = FileAccess.open(
		request_path.get_base_dir().path_join("ready"), FileAccess.WRITE
	)
	if ready_file != null:
		ready_file.store_string("ready")
		ready_file.close()


func _build_ui():
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)
	var column = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(column)
	var header = HBoxContainer.new()
	column.add_child(header)
	var title = _label(header, "PROGRAM TEST ARENA", 22)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(header, "Return to editor [Esc]", _return_to_editor)
	var body = HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(body)
	var panel = PanelContainer.new()
	panel.custom_minimum_size.x = 390
	var style = StyleBoxFlat.new()
	style.bg_color = Color("19232ff5")
	style.set_corner_radius_all(8)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", style)
	body.add_child(panel)
	var controls = VBoxContainer.new()
	controls.add_theme_constant_override("separation", 10)
	panel.add_child(controls)
	var program = _label(controls, request.record.name + " · " + request.faction.capitalize(), 16)
	program.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	program.custom_minimum_size.x = 350
	_role = OptionButton.new()
	for role in request.record.roles:
		_role.add_item(role)
	_role.item_selected.connect(func(_index): _update_case())
	controls.add_child(_role)
	_research = OptionButton.new()
	_research.add_item("Completed battle research")
	_research.add_item("Unupgraded baseline")
	_research.item_selected.connect(func(_index): _update_case())
	controls.add_child(_research)
	_research_summary = _label(controls, "", 12)
	_research_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_research_summary.custom_minimum_size.x = 350
	_scenario = OptionButton.new()
	for entry in Scenarios.CASES:
		_scenario.add_item(entry.title)
	_scenario.item_selected.connect(func(_index): _update_case())
	controls.add_child(_scenario)
	_label(controls, "EXPECTED OUTCOME", 13)
	_expected = _label(controls, "", 14)
	_expected.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_expected.custom_minimum_size = Vector2(350, 120)
	var actions = HBoxContainer.new()
	controls.add_child(actions)
	_run_button = _button(actions, "Run scenario", _run)
	_pause_button = _button(actions, "Pause", _toggle_pause)
	_pause_button.disabled = true
	_status = _label(controls, "Choose a scenario and run this draft.", 14)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size.y = 50
	_trace = TextEdit.new()
	_trace.editable = false
	_trace.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_trace.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_trace.custom_minimum_size.y = 120
	_trace.add_theme_font_size_override("font_size", 13)
	_trace.add_theme_color_override("font_readonly_color", Color("c5d4df"))
	_trace.text = "Actual intents, positions and scenario events appear here."
	controls.add_child(_trace)
	var note = _label(
		column,
		"Your battle is paused. These test units and results stay separate from live orders.",
		13
	)
	note.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _label(parent, text, size):
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	parent.add_child(label)
	return label


func _button(parent, text, callback):
	var button = Button.new()
	button.text = text
	button.custom_minimum_size.y = 36
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _choose_default():
	if "RepairRobot" == request.record.roles[0]:
		_scenario.select(6)
	elif request.record.mode == "visual":
		var actions = request.record.rules.rules.map(func(rule): return rule.action)
		if "escort" in actions:
			_scenario.select(1)


func _update_case():
	_research_summary.text = Research.summary(_selected_research())
	_research_summary.tooltip_text = (
		"Completed upgrades only. The enemy uses baseline stats. "
		+ "Basic chip access is supplied by the arena."
	)
	var role = _role.get_item_text(_role.selected)
	for index in range(Scenarios.CASES.size()):
		_scenario.set_item_disabled(index, not Scenarios.available(index, role))
	if not Scenarios.available(_scenario.selected, role):
		_scenario.select(4)
	var entry = Scenarios.CASES[_scenario.selected]
	_expected.text = entry.expected + "\n\n" + entry.hint
	_status.text = "Ready · %d seconds · %s" % [entry.duration, role]
	_run_button.text = "Run scenario"


func _selected_research():
	return request.research if _research.selected == 0 else Research.baseline()


func _run():
	if session.starting:
		return
	_paused = false
	session.set_physics_process(true)
	_pause_button.text = "Pause"
	_role.disabled = true
	_scenario.disabled = true
	_research.disabled = true
	_run_button.disabled = true
	_pause_button.disabled = true
	_status.text = "Preparing real units and navigation…"
	session.research = _selected_research().duplicate(true)
	session.role = _role.get_item_text(_role.selected)
	session.case_index = _scenario.selected
	await session.start()
	if is_instance_valid(session.game):
		session.game.get_node("IsometricCamera3D").h_offset = -6.0
	_run_button.disabled = false
	_run_button.text = "Restart scenario"
	_pause_button.disabled = not session.running


func _toggle_pause():
	if not session.running:
		return
	_paused = not _paused
	session.set_physics_process(not _paused)
	session.game.process_mode = Node.PROCESS_MODE_DISABLED if _paused else Node.PROCESS_MODE_INHERIT
	_pause_button.text = "Resume" if _paused else "Pause"
	_status.text = "Test paused" if _paused else "Test resumed"


func _refresh_trace():
	if session.starting:
		return
	if session.running:
		_status.text = (
			"%0.1f / %d s · %d evaluations"
			% [session.elapsed, Scenarios.CASES[session.case_index].duration, session.evaluations]
		)
	var lines = []
	if not session.outcome.is_empty():
		lines.append(
			"Research: " + Research.summary(session.outcome.get("research", Research.baseline()))
		)
		for check in session.outcome.checks:
			lines.append(("PASS · " if check.passed else "FAIL · ") + check.text)
		if not session.outcome.get("error", "").is_empty():
			lines.append(session.outcome.error)

		lines.append("\nACTUAL TRACE")
	for entry in session.trace:
		lines.append("%04.1fs · (%0.1f, %0.1f) · %s" % [entry.time, entry.x, entry.z, entry.text])
	_trace.text = "\n".join(lines)
	if session.running:
		_trace.scroll_vertical = _trace.get_line_count()


func _completed(result):
	results.append(result.duplicate(true))
	if results.size() > 32:
		results.pop_front()
	_status.text = (
		"Expected behavior observed for this scenario"
		if result.passed
		else "Expected behavior not met — inspect the trace"
	)
	_role.disabled = false
	_scenario.disabled = false
	_research.disabled = false
	_pause_button.disabled = true
	_run_button.disabled = false
	_run_button.text = "Restart scenario"
	_trace.scroll_vertical = 0


func _return_to_editor():
	if _returning:
		return
	_returning = true
	var directory = request_path.get_base_dir()
	var file = FileAccess.open(directory.path_join("report.tmp"), FileAccess.WRITE)
	if file != null:
		file.store_string(
			JSON.stringify(
				{
					"token": request.token,
					"content_hash": request.record.content_hash,
					"research": request.research,
					"results": results
				}
			)
		)
		file.close()
		DirAccess.rename_absolute(
			directory.path_join("report.tmp"), directory.path_join("report.json")
		)
	get_tree().quit()


func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_return_to_editor()


func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST and not request.is_empty():
		_return_to_editor()
