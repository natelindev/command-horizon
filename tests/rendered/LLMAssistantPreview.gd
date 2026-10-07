extends "res://tests/headless/LLMProviderRegression.gd"

const Record = preload("res://source/match/programs/ProgramRecord.gd")
const Library = preload("res://source/match/programs/ProgramLibrary.gd")
const Parameters = preload("res://source/match/programs/LuaParameters.gd")
var _game
var _editor
var _assistant
var _path = "user://llm-ui-library-%d.json" % OS.get_process_id()
var _settings_path = "user://llm-ui-settings-%d.json" % OS.get_process_id()


func _run():
	root.mode = Window.MODE_WINDOWED
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	var numeric = load("res://source/match/hud/NumericParameters.gd").new()
	root.add_child(numeric)
	numeric.set_values(
		[{"name": "fraction", "label": "Fraction", "value": 0.35, "min": 0, "max": 1, "step": 0.2}]
	)
	_check(
		is_equal_approx(numeric.get_child(0).get_child(1).value, 0.35),
		"Parameter control rounded the default to an unrelated step"
	)
	numeric.free()
	_server.listen(0, "127.0.0.1")
	_config = Config.DEFAULTS.duplicate(true)
	_config.endpoint = "http://127.0.0.1:%d/v1/responses" % _server.get_local_port()
	Config.new().write_settings(_config, _settings_path)
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
		player.faction = "helix" if side == 0 else "bastion"
		settings.players.append(player)
	_game = load("res://source/match/Skirmish.tscn").instantiate()
	_game.settings = settings
	_game.map = load(settings.map_path).instantiate()
	root.add_child(_game)
	current_scene = _game
	get_nodes_in_group("players")[1].set_process(false)
	await _frames(50)
	var human = _game._get_human_player()
	var tanks = human.get_children().filter(
		func(unit): return "type" in unit and unit.type == "Tank"
	)
	var tank = tanks[0]
	_game.hud.open_lua_editor([tank], _path)
	_editor = _game.hud.program_editor
	_editor.assistant_settings_path = _settings_path
	_editor._roles.select(1)
	_editor._refresh()
	var original = _editor._source.text
	var order = tank.action
	await _click(_button_named(_editor, "AI assistant"))
	_assistant = _editor._modal
	_check(is_instance_valid(_assistant), "Assistant button did not open")
	_assistant._prompt.text = "Hold position with an adjustable health threshold."
	_assistant._sync_context()
	await _capture("llm-draft-720p")
	_check(
		not _assistant._context_preview.text.contains("diagnostics"),
		"Diagnostics sent without opt-in"
	)
	await _click(_assistant._generate)
	var peer = await _accept_request()
	if peer == null:
		print("UI generation failure: ", _assistant._status.text)
		await _capture("llm-debug-720p")
		quit(1)
		return
	var draft = _draft()
	draft.source = """return function(s,m)
    if s.self.hp / s.self.hp_max * 100 < params.health and s.assignments.safe then
        return {intent={kind='move',assignment='safe'},state=m}
    end
    return {intent={kind='hold'},state=m}
end"""
	draft.summary = "Retreat to the assigned safe point below the health threshold. Otherwise hold."
	draft.assignments = ["safe"]
	draft.parameters = [
		{
			"name": "health",
			"label": "Health threshold (%)",
			"value": 30,
			"min": 1,
			"max": 90,
			"step": 1
		}
	]
	_reply(peer, 200, JSON.stringify(_envelope(draft)))
	await _wait_idle()
	peer.disconnect_from_host()
	_check(
		_editor._source.text == original and tank.action == order,
		"Arrival replaced draft or orders"
	)
	_check(not _assistant._import.disabled, "Valid draft could not be imported")
	await _capture("llm-review-720p")
	await _adverse_flows(tank, draft)
	# Failed revision preserves the reviewed result and underlying draft.
	_assistant._mode.select(1)
	_assistant._sync_context()
	await _click(_assistant._generate)
	peer = await _accept_request()
	_reply(peer, 401, '{"error":"DO_NOT_ECHO"}')
	await _wait_idle()
	peer.disconnect_from_host()
	_check(
		_assistant._result.source == draft.source and not _assistant._import.disabled,
		"Failure lost prior review"
	)
	_check(not _assistant._status.text.contains("DO_NOT_ECHO"), "Provider error echoed in UI")
	await _capture("llm-error-720p")
	# Escape closes only the assistant; reopening retains prompt and result.
	await _key(KEY_ESCAPE)
	_check(
		is_instance_valid(_editor) and paused, "Assistant Escape closed editor or resumed battle"
	)
	await _click(_button_named(_editor, "AI assistant"))
	_assistant = _editor._modal
	_check(
		not _assistant._prompt.text.is_empty() and not _assistant._result.is_empty(),
		"Reopen lost review"
	)
	await _click(_assistant._import)
	_check(_editor._loaded.is_empty() and _editor._apply_button.disabled, "Import bypassed Save")
	_check(_editor._draft().parameter_schema.values[0].value == 30, "Imported parameters lost")
	_check(tank.action == order, "Import changed actual unit orders")
	await _click(_editor._parameter_button)
	var dialog = _editor._modal
	dialog._fields.get_child(0).get_child(1).value = 45
	await _capture("llm-parameters-720p")
	await _click(_button_named(dialog, "Update draft"))
	_check(_editor._source.text.contains("= 45,"), "Offline parameter edit did not change Lua")
	await _click(_button_named(_editor, "Check samples"))
	_check(
		_editor._notice.text.contains("passed"), "Generated parameter draft failed sample checks"
	)
	await _click(_button_named(_editor, "Save version"))
	_check(not _editor._apply_button.disabled, "Saved generated program cannot apply")
	var saved = _editor._loaded.duplicate(true)
	_check(Record.validate(saved), "Parameterized record invalid")
	var runtime = Runtime.new()
	_check(runtime.compile_source(saved.source).ok, "Saved parameter Lua did not compile")
	var sample = {"self": {"hp": 40, "hp_max": 100}, "assignments": {"safe": {"x": 0, "z": 0}}}
	_check(
		runtime.step(sample).intent.kind == "move",
		"45% parameter did not trigger retreat at 40% health"
	)
	var lower = saved.parameter_schema.values.duplicate(true)
	lower[0].value = 30
	var lower_source = Parameters.replace(saved.source, saved.parameter_schema, lower).source
	runtime.compile_source(lower_source)
	_check(
		runtime.step(sample).intent.kind == "hold",
		"30% parameter did not retain position at 40% health"
	)
	var library = Library.new()
	_check(
		(
			library.read_library(_path)
			and (
				Record._canonical(library.versions[0].parameter_schema)
				== Record._canonical(saved.parameter_schema)
			)
		),
		"Parameter metadata did not survive library roundtrip"
	)
	var altered = saved.duplicate(true)
	altered.parameter_schema.values[0].value = 60
	Record.seal(altered)
	_check(not Record.validate(altered), "Mismatched parameter/source accepted")
	await _click(_editor._apply_button)
	_check(tank.program.mode != "Manual" and paused, "Explicit Apply failed")
	_editor._source.text = _editor._source.text.replace("= 45,", "= 46,")
	_editor._draft_changed()
	_check(
		_editor._parameter_schema.is_empty() and _editor._parameter_button.disabled,
		"Freeform prefix edit left stale parameter controls"
	)
	# Explain remains read-only even when the provider returns valid text.
	await _click(_button_named(_editor, "AI assistant"))
	_assistant = _editor._modal
	_assistant._mode.select(2)
	_assistant._sync_context()
	await _click(_assistant._generate)
	peer = await _accept_request()
	_reply(peer, 200, JSON.stringify(_envelope(_draft("explain"))))
	await _wait_idle()
	peer.disconnect_from_host()
	_check(_assistant._import.disabled, "Explanation offered replacement import")
	# Cancel a silent provider using the actual button, then review connection UI.
	await _click(_assistant._generate)
	peer = await _accept_request()
	if peer == null:
		print(
			"Silent fixture status: ", _assistant._status.text, " busy=", _assistant._client.busy()
		)
		await _capture("llm-debug-720p")
		quit(1)
		return
	await _click(_assistant._cancel)
	_check(
		not _assistant._client.busy() and _assistant._status.text.contains("cancelled"),
		"Cancel UI failed"
	)
	peer.disconnect_from_host()
	_assistant._tabs.current_tab = 1
	await _frames(3)
	await _capture("llm-connection-720p")
	_check(_assistant._key.secret and _assistant._key.text.is_empty(), "API key visible on open")
	_assistant._key.text = "ui-fixture-only-dummy"
	await _click(_button_named(_assistant, "Use key"))
	_check(_assistant._key.text.is_empty(), "Key remains in field after use")
	await _click(_button_named(_assistant, "Forget key"))
	_check(not _assistant.credentials.read_key(_config).found, "Forget key UI failed")
	_assistant._limit.value = 1536
	await _click(_button_named(_assistant, "Save connection"))
	var stored_config = Config.new()
	_check(
		stored_config.read_settings(_settings_path) and stored_config.value.output_limit == 1536,
		"Connection controls did not persist"
	)
	await _key(KEY_ESCAPE)
	await _key(KEY_ESCAPE)
	_check(not paused, "Editor close did not restore simulation")
	_server.stop()
	DirAccess.remove_absolute(_path)
	DirAccess.remove_absolute(_settings_path)
	_game.queue_free()
	await _frames(8)
	print("LLM assistant UI: %d failures" % _errors.size())
	quit(0 if _errors.is_empty() else 1)


func _wait_idle():
	var deadline = Time.get_ticks_msec() + 10000
	while _assistant._client.busy() and Time.get_ticks_msec() < deadline:
		await process_frame
	_check(not _assistant._client.busy(), "Provider fixture did not finish within 10 seconds")
	await _frames(3)


func _button_named(node, title):
	if node is Button and node.text == title:
		return node
	for child in node.get_children():
		var found = _button_named(child, title)
		if found != null:
			return found
	return null


func _click(control):
	_check(is_instance_valid(control), "Missing UI control")
	if not is_instance_valid(control):
		return
	await _frames(2)
	var rect = control.get_global_rect()
	_check(
		Rect2(Vector2.ZERO, Vector2(1280, 720)).encloses(rect),
		"Control outside 720p: " + str(control)
	)
	var motion = InputEventMouseMotion.new()
	motion.position = rect.get_center()
	root.push_input(motion, true)
	for pressed in [true, false]:
		var event = InputEventMouseButton.new()
		event.position = rect.get_center()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
		await _frames(2)


func _key(code):
	for pressed in [true, false]:
		var event = InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		root.push_input(event, true)
		await _frames(2)


func _capture(title):
	await _frames(3)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://art/skirmish/%s.png" % title)


func _frames(count):
	for frame in count:
		await process_frame


func _adverse_flows(_tank, _draft_value):
	pass
