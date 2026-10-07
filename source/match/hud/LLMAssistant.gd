# gdlint: disable=max-returns
extends CanvasLayer

signal imported(draft, roles)
signal closed(state)

const Config = preload("res://source/match/programs/llm/ProviderConfig.gd")
const Credentials = preload("res://source/match/programs/llm/Credentials.gd")
const Context = preload("res://source/match/programs/llm/RequestContext.gd")
const Draft = preload("res://source/match/programs/llm/DraftResponse.gd")
const Client = preload("res://source/match/programs/llm/ProviderClient.gd")
static var credentials = Credentials.new()
var settings_path = Config.PATH
var current_draft = {}
var diagnostics = ""
var initial = {}
var _config = Config.new()
var _client
var _tabs: TabContainer
var _mode: OptionButton
var _prompt: TextEdit
var _trace: CheckBox
var _disclosure: Label
var _context_preview: TextEdit
var _summary: TextEdit
var _code: CodeEdit
var _params
var _status: Label
var _generate: Button
var _cancel: Button
var _import: Button
var _provider: OptionButton
var _endpoint: LineEdit
var _model: LineEdit
var _structured: CheckBox
var _limit: SpinBox
var _timeout: SpinBox
var _key: LineEdit
var _remember: CheckBox
var _result = {}
var _request_roles = []
var _pending_roles = []
var _closing = false


func _ready():
	layer = 35
	process_mode = Node.PROCESS_MODE_ALWAYS
	_config.read_settings(settings_path)
	_client = Client.new()
	add_child(_client)
	_client.completed.connect(_received)
	_build()
	_prompt.text = initial.get("prompt", "")
	_mode.select(clampi(initial.get("mode", 0), 0, 2))
	# Diagnostic sharing is opt-in each time the assistant opens.
	_result = initial.get("result", {}).duplicate(true)
	_request_roles = initial.get("roles", current_draft.get("roles", [])).duplicate()
	if not _result.is_empty() and Draft.validate(_result, _result.get("operation", "")).is_empty():
		_show_result()
	else:
		_result = {}
	_sync_context()
	_busy(false)
	_status.text = (
		_config.error
		if not _config.error.is_empty()
		else "Describe a behavior, then review the result before importing."
	)
	_prompt.grab_focus()


func _build():
	var shade = ColorRect.new()
	shade.color = Color("080e17ef")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	add_child(margin)
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color("19232f")
	style.set_corner_radius_all(10)
	for side in ["left", "right", "top", "bottom"]:
		style.set("content_margin_" + side, 16)
	panel.add_theme_stylebox_override("panel", style)
	margin.add_child(panel)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	var heading = _row(column)
	var title = _label(heading, "PROGRAM ASSISTANT", 22)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(heading, "Close [Esc]", close_assistant)
	_label(column, "Optional AI help · Your draft and unit orders stay under your control.", 13)
	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_tabs)
	_build_draft_tab()
	_build_connection_tab()
	_context_preview = TextEdit.new()
	_context_preview.name = "Sent context"
	_context_preview.editable = false
	_context_preview.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_context_preview.add_theme_font_size_override("font_size", 13)
	_context_preview.add_theme_color_override("font_readonly_color", Color("bdccd9"))
	_tabs.add_child(_context_preview)
	_status = _label(column, "", 13)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.max_lines_visible = 2
	_status.custom_minimum_size.y = 38
	var actions = _row(column)
	_generate = _button(actions, "Generate", _send)
	_cancel = _button(actions, "Cancel request", _cancel_request)
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(spacer)
	_import = _button(actions, "Import as unsaved draft", _import_result)


func _build_draft_tab():
	var body = HBoxContainer.new()
	body.name = "Draft"
	body.add_theme_constant_override("separation", 18)
	_tabs.add_child(body)
	var left = VBoxContainer.new()
	left.custom_minimum_size.x = 340
	left.add_theme_constant_override("separation", 10)
	body.add_child(left)
	_mode = OptionButton.new()
	for title in ["Create a program", "Revise current draft", "Explain current draft"]:
		_mode.add_item(title)
	_mode.item_selected.connect(func(_index): _sync_context())
	left.add_child(_mode)
	_prompt = TextEdit.new()
	_prompt.placeholder_text = "E.g. retreat to my safe point below 30% health, then return to guard."
	_prompt.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_prompt.custom_minimum_size.y = 140
	_prompt.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_prompt.text_changed.connect(_sync_context)
	left.add_child(_prompt)
	_trace = CheckBox.new()
	_trace.text = "Include current check diagnostics"
	_trace.toggled.connect(func(_enabled): _sync_context())
	left.add_child(_trace)
	_disclosure = _label(left, "", 13)
	_disclosure.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_disclosure.custom_minimum_size.y = 126
	_disclosure.max_lines_visible = 6
	_disclosure.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var right = VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	body.add_child(right)
	_label(right, "REVIEW", 14)
	_summary = TextEdit.new()
	_summary.editable = false
	_summary.add_theme_color_override("font_readonly_color", Color("bdccd9"))
	_summary.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_summary.custom_minimum_size.y = 90
	_summary.text = "Generated summaries, code and parameters appear here. Nothing runs automatically."
	right.add_child(_summary)
	var review = TabContainer.new()
	review.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(review)
	_code = CodeEdit.new()
	_code.name = "Lua code"
	_code.editable = false
	_code.add_theme_color_override("font_readonly_color", Color("bdccd9"))
	_code.gutters_draw_line_numbers = true
	_code.add_theme_font_size_override("font_size", 13)
	review.add_child(_code)
	var scroll = ScrollContainer.new()
	scroll.name = "Parameters"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	review.add_child(scroll)
	_params = load("res://source/match/hud/NumericParameters.gd").new()
	_params.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_params)
	_params.changed.connect(_parameters_changed)


func _build_connection_tab():
	var scroll = ScrollContainer.new()
	scroll.name = "Connection"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tabs.add_child(scroll)
	var column = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 10)
	scroll.add_child(column)
	_label(column, "Bring your own API key. API usage is billed by your provider.", 14)
	var row = _row(column)
	_provider = OptionButton.new()
	_provider.add_item("OpenAI Responses")
	_provider.add_item("Chat Completions compatible")
	_provider.select(0 if _config.value.provider == "responses" else 1)
	row.add_child(_provider)
	_provider.item_selected.connect(_provider_changed)
	_endpoint = _field(column, "Endpoint", _config.value.endpoint)
	_model = _field(column, "Model ID", _config.value.model)
	_structured = CheckBox.new()
	_structured.text = "Strict structured output (recommended)"
	_structured.button_pressed = _config.value.structured
	column.add_child(_structured)
	row = _row(column)
	_label(row, "Max output tokens", 13)
	_limit = _spin(row, 256, 4096, _config.value.output_limit)
	_label(row, "Timeout (seconds)", 13)
	_timeout = _spin(row, 5, 120, _config.value.timeout_seconds)
	_button(row, "Save connection", _save_connection)
	_label(
		column,
		"Keys belong to the exact saved endpoint. Changing endpoint requires its own key.",
		13
	)
	_key = _field(column, "API key", "")
	_key.secret = true
	_key.max_length = 4096
	_key.placeholder_text = "Paste a key; existing keys are never displayed"
	row = _row(column)
	_remember = CheckBox.new()
	_remember.text = "Remember in platform credential store"
	_remember.disabled = not credentials.available()
	_remember.tooltip_text = "Unchecked: use only until the game exits."
	row.add_child(_remember)
	_button(row, "Use key", _use_key)
	_button(row, "Forget key", _forget_key)
	var note = _label(
		column,
		(
			"Save connection before setting its key. Keys stay out of programs and battle saves.\n"
			+ "Cancel stops waiting; your provider may still bill work already started."
		),
		13
	)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _context():
	var trace = []
	if _trace.button_pressed and not diagnostics.is_empty():
		# Bound UTF-8 bytes without cutting a multi-byte character.
		var reason = diagnostics
		while reason.to_utf8_buffer().size() > 500:
			reason = reason.left(reason.length() - 1)
		trace.append({"reason": reason})
	return Context.build(
		Draft.OPERATIONS[_mode.selected],
		_prompt.text,
		current_draft.get("roles", []),
		current_draft,
		trace
	)


func _sync_context():
	if _disclosure == null or _context_preview == null:
		return
	var context = _context()
	_context_preview.text = context.system + "\n\n" + context.user if context.ok else context.error
	_disclosure.text = (
		(
			"Sends your request, unit roles and API guide%s%s to:\n%s\n\n"
			+ "%d / 4,000 request bytes · up to %d output tokens. No automatic retry."
		)
		% [
			", current Lua" if _mode.selected > 0 else "",
			", first 500 bytes of diagnostics" if _trace.button_pressed else "",
			_config.value.endpoint,
			_prompt.text.to_utf8_buffer().size(),
			_config.value.output_limit
		]
	)

	_disclosure.tooltip_text = _disclosure.text


func _send():
	if not _connection_matches():
		_notice("Save the changed connection before generating.")
		_tabs.current_tab = 1
		return
	var context = _context()
	if not context.ok:
		_notice(context.error)
		return
	var key = credentials.read_key(_config.value)
	if not key.ok:
		_notice(key.error)
		return
	var started = _client.generate(_config.value, context, key.secret)
	if not started.ok:
		_notice(started.error)
		return
	_pending_roles = current_draft.roles.duplicate()
	_tabs.current_tab = 0
	_busy(true)
	_notice("Generating with %s… You can cancel. Existing draft retained." % _config.value.model)


func _received(result):
	if _closing:
		return
	_busy(false)
	if not result.ok:
		_notice(result.error)
		return
	_request_roles = _pending_roles.duplicate()
	_result = result.draft.duplicate(true)
	_show_result()
	_busy(false)
	_notice("Review the result. Import changes the draft only; check, save and apply separately.")


func _show_result():
	_summary.text = _result.summary
	if not _result.assignments.is_empty():
		_summary.text += "\nAssignments: " + ", ".join(_result.assignments)
	_code.text = Draft.source(_result)
	_params.set_values(_result.parameters)


func _parameters_changed(values):
	_result.parameters = values.duplicate(true)
	_code.text = Draft.source(_result)


func _import_result():
	if _client.busy() or _result.is_empty() or _result.operation == "explain":
		return
	var issue = Draft.validate(_result, _result.operation)
	if not issue.is_empty():
		_notice(issue)
		return
	imported.emit(_result.duplicate(true), _request_roles.duplicate())
	close_assistant()


func _busy(active):
	_generate.disabled = active
	_cancel.disabled = not active
	_import.disabled = active or _result.is_empty() or _result.get("operation") == "explain"
	_prompt.editable = not active
	_mode.disabled = active
	_trace.disabled = active
	_tabs.set_tab_disabled(1, active)


func _cancel_request():
	_client.cancel()


func _connection():
	return {
		"schema": 1,
		"provider": "responses" if _provider.selected == 0 else "chat",
		"endpoint": _endpoint.text.strip_edges(),
		"model": _model.text.strip_edges(),
		"structured": _structured.button_pressed,
		"output_limit": int(_limit.value),
		"timeout_seconds": int(_timeout.value)
	}


func _provider_changed(index):
	var old_suffix = "/responses" if index == 1 else "/chat/completions"
	var new_suffix = "/chat/completions" if index == 1 else "/responses"
	if _endpoint.text.ends_with(old_suffix):
		_endpoint.text = _endpoint.text.trim_suffix(old_suffix) + new_suffix


func _save_connection():
	if _config.write_settings(_connection(), settings_path):
		_key.clear()
		_sync_context()
		_notice("Connection saved. No request sent. Set a key for this endpoint if needed.")
	else:
		_notice(_config.error)


func _use_key():
	if not _connection_matches():
		_notice("Save the connection before setting its key.")
		return
	var result = credentials.set_key(_config.value, _key.text, _remember.button_pressed)
	if result.ok:
		_key.clear()
		_notice(
			(
				"Key stored in platform credentials."
				if _remember.button_pressed
				else "Key set for this game session."
			)
		)
	else:
		_notice(result.error)


func _forget_key():
	if not _connection_matches():
		_notice("Save the connection before forgetting its key.")
		return
	var result = credentials.forget(_config.value)
	_key.clear()
	_notice("Key forgotten for this endpoint." if result.ok else result.error)


func _notice(text):
	_status.text = text
	_status.tooltip_text = text


func close_assistant():
	if _closing:
		return
	_closing = true
	_client.cancel()
	_key.clear()
	closed.emit(
		{
			"prompt": _prompt.text,
			"mode": _mode.selected,
			"result": _result.duplicate(true),
			"roles": _request_roles.duplicate()
		}
	)
	queue_free()


func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close_assistant()


func _unhandled_input(_event):
	get_viewport().set_input_as_handled()


func _row(parent):
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	return row


func _label(parent, text, size):
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	parent.add_child(label)
	return label


func _button(parent, text, callback):
	var button = Button.new()
	button.text = text
	button.custom_minimum_size.y = 34
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _field(parent, title, value):
	_label(parent, title, 13)
	var field = LineEdit.new()
	field.text = value
	parent.add_child(field)
	return field


func _spin(parent, lower, upper, value):
	var field = SpinBox.new()
	field.min_value = lower
	field.max_value = upper
	field.value = value
	field.custom_minimum_size.x = 120
	parent.add_child(field)
	return field


func _connection_matches():
	var draft = _connection()
	for key in draft:
		if draft[key] != _config.value[key]:
			return false
	return true
