extends "res://tests/rendered/LLMAssistantPreview.gd"


func _adverse_flows(tank, draft_value):
	var original = _editor._source.text
	var order = tank.action
	var review = _assistant._result.duplicate(true)
	var errors = [
		{"status": 200, "body": "{broken"}, {"status": 429, "body": "private provider text"}
	]
	var incomplete = _envelope(draft_value)
	incomplete.status = "incomplete"
	errors.append({"status": 200, "body": JSON.stringify(incomplete)})
	var refusal = _envelope(draft_value)
	refusal.output[1].content = [{"type": "refusal", "refusal": "private provider text"}]
	errors.append({"status": 200, "body": JSON.stringify(refusal)})
	for change in ["operation", "parameters", "source"]:
		var invalid = draft_value.duplicate(true)
		match change:
			"operation":
				invalid.operation = "explain"
			"parameters":
				invalid.parameters[0].value = INF
			"source":
				invalid.source = "x".repeat(32769)
		errors.append({"status": 200, "body": JSON.stringify(_envelope(invalid))})
	for entry in errors:
		await _click(_assistant._generate)
		var peer = await _accept_request()
		_check(peer != null, "Adverse request did not connect")
		if peer == null:
			return
		_reply(peer, entry.status, entry.body)
		await _wait_idle()
		peer.disconnect_from_host()
		_check(_assistant._result == review, "Rejected response replaced the prior review")
		_check(
			_editor._source.text == original and tank.action == order,
			"Rejected response changed source/orders"
		)
		_check(
			not _assistant._status.text.contains("private provider text"),
			"Raw provider text leaked"
		)
		_check(
			not _assistant._generate.disabled and not _assistant._import.disabled,
			"Error stranded controls"
		)
		_check(not _server.is_connection_available(), "Error triggered an automatic paid retry")
	# Explicit trace opt-in is bounded and resets on reopen.
	_assistant.diagnostics = "Diagnostic " + "测".repeat(800)
	await _click(_assistant._trace)
	await _click(_assistant._generate)
	var peer = await _accept_request()
	var sent = JSON.parse_string(_wire_requests.back().input)
	_check(
		sent.diagnostics.size() == 1 and sent.diagnostics[0].reason.to_utf8_buffer().size() <= 500,
		"Opt-in trace missing or oversized"
	)
	var time_before = _game.simulation_time
	await _frames(20)
	_check(
		_assistant._client.busy() and _game.simulation_time == time_before,
		"Pending request changed tactical pause"
	)
	await _key(KEY_ESCAPE)
	_check(_editor._modal == null and paused, "Closing a pending request changed pause/ownership")
	peer.poll()
	_check(
		peer.get_status() != StreamPeerTCP.STATUS_CONNECTED,
		"Closing assistant retained the request socket"
	)
	peer.disconnect_from_host()
	await _click(_button_named(_editor, "AI assistant"))
	_assistant = _editor._modal
	_check(not _assistant._trace.button_pressed, "Reopen silently enabled diagnostics")
	_check(
		_assistant._result == review and not _assistant._client.busy(),
		"Reopen accepted stale response or request"
	)
	# A complete editor close also retains the assistant review in transient HUD memory.
	var prompt = _assistant._prompt.text
	await _key(KEY_ESCAPE)
	await _key(KEY_ESCAPE)
	_check(not paused, "Editor with cancelled request failed to resume")
	_game.hud.open_lua_editor([tank], _path)
	_editor = _game.hud.program_editor
	_editor.assistant_settings_path = _settings_path
	await _click(_button_named(_editor, "AI assistant"))
	_assistant = _editor._modal
	_check(
		_assistant._prompt.text == prompt and _assistant._result == review,
		"Editor reopen lost prompt/review"
	)
	# Invalid Lua is inert on arrival/import; explicit checking reports its bounded failure.
	await _click(_assistant._generate)
	peer = await _accept_request()
	var hostile = draft_value.duplicate(true)
	hostile.source = "while true do end"
	_reply(peer, 200, JSON.stringify(_envelope(hostile)))
	await _wait_idle()
	peer.disconnect_from_host()
	_check(_editor._source.text == original and tank.action == order, "Hostile arrival executed")
	await _click(_assistant._import)
	_check(_editor._loaded.is_empty() and tank.action == order, "Hostile import applied")
	await _click(_button_named(_editor, "Check samples"))
	_check(
		_editor._notice.text.contains("failed") and tank.action == order,
		"Hostile sample check changed orders"
	)
	await _capture("llm-invalid-lua-720p")
	# Restore the starting draft explicitly, then continue the normal authoring flow.
	_editor._source.text = original
	_editor._parameter_schema = {}
	_editor._draft_changed()
	await _click(_button_named(_editor, "AI assistant"))
	_assistant = _editor._modal
	await _click(_assistant._generate)
	peer = await _accept_request()
	_reply(peer, 200, JSON.stringify(_envelope(draft_value)))
	await _wait_idle()
	peer.disconnect_from_host()
	print(
		(
			"PASS: malformed/refused/incomplete/oversized/rate-limit UI; "
			+ "trace opt-in; pending close/reopen; inert hostile Lua"
		)
	)
