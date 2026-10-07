extends SceneTree

const Config = preload("res://source/match/programs/llm/ProviderConfig.gd")
const Credentials = preload("res://source/match/programs/llm/Credentials.gd")
const Draft = preload("res://source/match/programs/llm/DraftResponse.gd")
const Context = preload("res://source/match/programs/llm/RequestContext.gd")
const Protocol = preload("res://source/match/programs/llm/ProviderProtocol.gd")
const Client = preload("res://source/match/programs/llm/ProviderClient.gd")
const Runtime = preload("res://source/match/programs/LuaRuntime.gd")
const HOLD = "return function(s,m) return {intent={kind='hold'},state=m} end"
var _errors = []
var _results = []
var _server = TCPServer.new()
var _client
var _config
var _wire_requests = []


func _initialize():
	call_deferred("_run")


func _run():
	_config_checks()
	_credentials_checks()
	_protocol_checks()
	await _network_checks()
	print("LLM provider regression: %d failures" % _errors.size())
	quit(0 if _errors.is_empty() else 1)


func _draft(operation = "create"):
	return {
		"api_version": 1,
		"operation": operation,
		"name": "Hold position",
		"summary": "Hold until a manual order.",
		"source": HOLD if operation != "explain" else "",
		"parameters": [],
		"assignments": []
	}


func _envelope(draft):
	return {
		"status": "completed",
		"output":
		[
			{"type": "reasoning", "summary": []},
			{
				"type": "message",
				"role": "assistant",
				"content": [{"type": "output_text", "text": JSON.stringify(draft)}]
			}
		],
		"usage": {"input_tokens": 100, "output_tokens": 40, "total_tokens": 140, "private": "omit"}
	}


func _bytes(value):
	return JSON.stringify(value).to_utf8_buffer()


func _config_checks():
	_check(Config.validate(Config.DEFAULTS).is_empty(), "Default config invalid")
	for endpoint in [
		"http://example.com/v1/responses",
		"https://key@example.com/v1/responses",
		"https://example.com/v1/responses?key=hidden",
		"https://example.com/v1/responses#key",
		"http://127.0.0.1.evil/v1/responses",
		"https://example.com:0/v1/responses",
		"https://example.com/v1/responses\n"
	]:
		var bad = Config.DEFAULTS.duplicate(true)
		bad.endpoint = endpoint
		_check(not Config.validate(bad).is_empty(), "Unsafe endpoint accepted")
	for endpoint in ["http://127.0.0.1:4321/v1/responses", "http://[::1]:1234/v1/responses"]:
		var local = Config.DEFAULTS.duplicate(true)
		local.endpoint = endpoint
		_check(Config.validate(local).is_empty(), "Loopback endpoint rejected")
	var model_config = Config.DEFAULTS.duplicate(true)
	model_config.model += "\n"
	_check(not Config.validate(model_config).is_empty(), "Model newline accepted")
	var settings = Config.new()
	var path = "user://llm-regression-%d.json" % OS.get_process_id()
	_check(settings.write_settings(Config.DEFAULTS, path), "Config save failed")
	_check(Config.new().read_settings(path), "Config roundtrip failed")
	var before = FileAccess.get_file_as_bytes(path)
	var invalid = Config.DEFAULTS.duplicate(true)
	invalid.api_key = "dummy-not-a-key"
	_check(not settings.write_settings(invalid, path), "Credential field saved to settings")
	_check(FileAccess.get_file_as_bytes(path) == before, "Invalid settings replaced good file")
	var file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{corrupt")
	file.close()
	_check(
		not settings.read_settings(path) and settings.value == Config.DEFAULTS,
		"Corrupt settings replaced active config"
	)
	DirAccess.remove_absolute(path)


func _credentials_checks():
	var credentials = Credentials.new()
	var config = Config.DEFAULTS.duplicate(true)
	config.endpoint = (
		"http://127.0.0.1/%d-%d/responses" % [OS.get_process_id(), Time.get_ticks_usec()]
	)
	var secret = "regression-dummy-" + str(Time.get_ticks_usec())
	_check(credentials.set_key(config, secret).ok, "Session key write failed")
	_check(credentials.read_key(config).secret == secret, "Session key read failed")
	var other = config.duplicate(true)
	other.endpoint += "/responses"
	_check(not credentials.read_key(other).found, "Key crossed endpoint boundary")
	_check(not credentials.set_key(config, "bad\nheader").ok, "Header injection key accepted")
	_check(credentials.read_key(config).secret == secret, "Invalid key replaced valid key")
	credentials.clear_session()
	if credentials.available():
		var stored = credentials.set_key(config, secret, true)
		_check(stored.ok, "Isolated platform credential write failed")
		credentials.clear_session()
		var read = credentials.read_key(config)
		_check(read.ok and read.found and read.secret == secret, "Platform credential read failed")
		_check(
			credentials.set_key(config, secret + "-updated", true).ok, "Credential update failed"
		)
		credentials.clear_session()
		_check(credentials.read_key(config).secret == secret + "-updated", "Credential update lost")
		_check(credentials.forget(config).ok, "Isolated credential cleanup failed")
		_check(not credentials.read_key(config).found, "Deleted credential still present")
		var native = ClassDB.instantiate("RtsCredentialStore")
		_check(
			not native.read_secret("arbitrary-service").ok,
			"Native store accepted unrelated account"
		)
	else:
		_check(
			not credentials.set_key(config, secret, true).ok, "Unavailable store silently persisted"
		)
	_check(credentials.forget(config).ok, "Session cleanup failed")


func _protocol_checks():
	var record = {"name": "Private draft", "source": HOLD, "hidden_world": "DO_NOT_SEND"}
	var context = Context.build(
		"revise",
		"Retreat when damaged",
		["Tank"],
		record,
		[{"reason": "Missing safe assignment", "time": 99, "hidden": "DO_NOT_SEND"}]
	)
	_check(context.ok and not context.user.contains("DO_NOT_SEND"), "Private context leaked")
	_check(not Context.build("revise", "revise", ["Tank"]).ok, "Missing draft accepted")
	_check(not Context.build("create", "x", ["CommandCenter"]).ok, "Unsupported role accepted")
	_check(not Context.build("create", "x".repeat(4001), ["Tank"]).ok, "Oversized prompt accepted")
	for provider in ["responses", "chat"]:
		var config = Config.DEFAULTS.duplicate(true)
		config.provider = provider
		config.endpoint = (
			"https://example.com/v1/"
			+ ("responses" if provider == "responses" else "chat/completions")
		)
		for structured in [true, false]:
			config.structured = structured
			var request = Protocol.encode(config, context)
			_check(request.ok, "Request encode failed")
			var body = JSON.parse_string(request.body)
			_check(body.store == false and body.stream == false, "Privacy/stream settings absent")
			var format = body.text.format if provider == "responses" else body.response_format
			_check(
				format.type == ("json_schema" if structured else "json_object"), "Wrong wire format"
			)
			_check(
				request.body.contains("Required JSON schema"), "JSON mode lacks response contract"
			)
	for malformed in [null, true, [], "wrong", {}, {"api_version": true}, {"api_version": 1e100}]:
		_check(not Draft.validate(malformed, "create").is_empty(), "Malformed draft accepted")
	var draft = _draft()
	var response = Protocol.decode("responses", "create", 200, _bytes(_envelope(draft)))
	_check(response.ok and response.usage.size() == 3, "Responses/usage extraction failed")
	var chat = {
		"choices": [{"finish_reason": "stop", "message": {"content": JSON.stringify(draft)}}]
	}
	_check(Protocol.decode("chat", "create", 200, _bytes(chat)).ok, "Chat extraction failed")
	chat.choices[0].finish_reason = "length"
	_check(not Protocol.decode("chat", "create", 200, _bytes(chat)).ok, "Truncated chat accepted")
	var incomplete = _envelope(draft)
	incomplete.status = "incomplete"
	_check(
		not Protocol.decode("responses", "create", 200, _bytes(incomplete)).ok,
		"Incomplete accepted"
	)
	var refusal = _envelope(draft)
	refusal.output[1].content = [{"type": "refusal", "refusal": "private provider message"}]
	_check(not Protocol.decode("responses", "create", 200, _bytes(refusal)).ok, "Refusal accepted")
	for status in [400, 401, 403, 404, 429, 500, 302]:
		var failure = Protocol.decode(
			"responses", "create", status, _bytes({"error": "DO_NOT_ECHO"})
		)
		_check(
			not failure.ok and not failure.error.contains("DO_NOT_ECHO"), "Provider error echoed"
		)
	_check(
		not Protocol.decode("responses", "create", 200, "bad".to_utf8_buffer()).ok,
		"Malformed JSON accepted"
	)
	_check(not Draft.validate(_draft("revise"), "create").is_empty(), "Wrong operation accepted")
	var oversized = PackedByteArray()
	oversized.resize(Protocol.RESPONSE_BYTES + 1)
	_check(not Protocol.decode("responses", "create", 200, oversized).ok, "Large envelope accepted")
	var explanation = _draft("explain")
	_check(Draft.validate(explanation, "explain").is_empty(), "Explanation rejected")
	explanation.source = HOLD
	_check(not Draft.validate(explanation, "explain").is_empty(), "Explain replaced source")
	draft.parameters = [
		{
			"name": "retreat_hp",
			"label": "Retreat health",
			"value": 30,
			"min": 1,
			"max": 90,
			"step": 1
		}
	]
	_check(Draft.validate(draft, "create").is_empty(), "Valid parameters rejected")
	var runtime = Runtime.new()
	_check(runtime.compile_source(Draft.source(draft)).ok, "Parameter prefix is invalid Lua")
	draft.parameters[0].name = "name\n"
	_check(not Draft.validate(draft, "create").is_empty(), "Parameter newline accepted")
	draft.parameters[0].name = "x']; os.execute('bad')"
	_check(not Draft.validate(draft, "create").is_empty(), "Parameter code injection accepted")
	# Arrival is inert: even invalid Lua is only a reviewable text draft.
	draft = _draft()
	draft.source = "while true do end"
	_check(
		Protocol.decode("responses", "create", 200, _bytes(_envelope(draft))).ok,
		"Protocol executed or compiled untrusted Lua on arrival"
	)


func _network_checks():
	_check(_server.listen(0, "127.0.0.1") == OK, "Local fixture listen failed")
	if not _server.is_listening():
		return
	_config = Config.DEFAULTS.duplicate(true)
	_config.endpoint = "http://127.0.0.1:%d/v1/responses" % _server.get_local_port()
	_config.timeout_seconds = 5
	_client = Client.new()
	root.add_child(_client)
	_client.completed.connect(func(value): _results.append(value))
	# The assistant runs while the authoring editor owns tactical pause.
	paused = true
	var context = Context.build("create", "Hold position", ["Tank"])
	_check(_client.generate(_config, context, "").ok, "Local request did not start")
	_check(not _client.generate(_config, context, "").ok, "Concurrent request accepted")
	var peer = await _accept_request()
	if peer == null:
		_client.free()
		_server.stop()
		return
	_reply(peer, 200, JSON.stringify(_envelope(_draft())))
	await _wait_result(1)
	_check(_results.size() == 1 and _results[0].ok, "Local HTTP roundtrip failed")
	peer.disconnect_from_host()
	# Cancellation followed immediately by a new request must ignore the old result.
	_check(_client.generate(_config, context, "").ok, "Cancellation fixture failed to start")
	peer = await _accept_request()
	var cancel_started = Time.get_ticks_msec()
	_client.cancel()
	_check(Time.get_ticks_msec() - cancel_started < 250, "Cancel blocked the main thread")
	_check(_results.size() == 2 and _results[1].get("cancelled", false), "Cancel not reported")
	_check(_client.generate(_config, context, "").ok, "Restart after cancellation failed")
	if peer != null:
		peer.disconnect_from_host()
	var fresh = await _accept_request()
	_reply(fresh, 200, JSON.stringify(_envelope(_draft())))
	await _wait_result(3)
	_check(_results.size() == 3 and _results[2].ok, "Cancelled generation contaminated retry")
	fresh.disconnect_from_host()
	_check(_client.generate(_config, context, "").ok, "Redirect fixture failed to start")
	peer = await _accept_request()
	_reply(peer, 302, "", "Location: " + _config.endpoint + "\r\n")
	await _wait_result(4)
	_check(_results.size() == 4 and not _results[3].ok, "Redirect accepted")
	_check(not _server.is_connection_available(), "Redirect was followed")
	peer.disconnect_from_host()
	_check(_client.generate(_config, context, "").ok, "Oversize fixture failed to start")
	peer = await _accept_request()
	_reply(peer, 200, "", "", Protocol.RESPONSE_BYTES + 1)
	await _wait_result(5)
	_check(_results.size() == 5 and not _results[4].ok, "Oversize body accepted")
	peer.disconnect_from_host()
	_check(_client.generate(_config, context, "").ok, "Timeout fixture failed to start")
	peer = await _accept_request()
	await _wait_result(6, 7000)
	_check(
		_results.size() == 6 and not _results[5].ok and _results[5].error.contains("timed out"),
		"Silent endpoint did not time out"
	)
	_check(not _server.is_connection_available(), "Timeout automatically retried")
	peer.disconnect_from_host()
	# Explicit Chat-compatible mode traverses the same actual transport.
	_config.provider = "chat"
	_config.endpoint = _config.endpoint.replace("/responses", "/chat/completions")
	_check(
		_client.generate(_config, context, "fixture-only-dummy").ok, "Chat transport did not start"
	)
	peer = await _accept_request()
	_reply(
		peer,
		200,
		JSON.stringify(
			{
				"choices":
				[{"finish_reason": "stop", "message": {"content": JSON.stringify(_draft())}}]
			}
		)
	)
	await _wait_result(7)
	_check(_results.size() == 7 and _results[6].ok, "Chat HTTP roundtrip failed")
	_check(_wire_requests.back().has("messages"), "Chat did not send messages")
	peer.disconnect_from_host()
	# Closing the editor while a request runs emits no late completion.
	_check(_client.generate(_config, context, "").ok, "Close fixture failed to start")
	peer = await _accept_request()
	_client.free()
	await process_frame
	_check(_results.size() == 7, "Closed client emitted a late result")
	_check(paused, "Client changed the editor pause state")
	paused = false
	peer.disconnect_from_host()
	_server.stop()


func _accept_request():
	var deadline = Time.get_ticks_msec() + 3000
	while not _server.is_connection_available() and Time.get_ticks_msec() < deadline:
		await process_frame
	if not _server.is_connection_available():
		_check(
			false,
			(
				"Fixture did not receive a connection: port=%d results=%s"
				% [_server.get_local_port(), str(_results)]
			)
		)
		return null
	var peer = _server.take_connection()
	var data = PackedByteArray()
	while Time.get_ticks_msec() < deadline:
		peer.poll()
		if peer.get_available_bytes() > 0:
			data.append_array(peer.get_data(peer.get_available_bytes())[1])
		var text = data.get_string_from_utf8()
		var separator = text.find("\r\n\r\n")
		if separator >= 0:
			var length = 0
			for line in text.left(separator).split("\r\n"):
				if line.to_lower().begins_with("content-length:"):
					length = int(line.split(":")[1])
			if data.size() >= separator + 4 + length:
				_check(
					text.begins_with(
						(
							"POST /v1/%s HTTP/1.1"
							% (
								"responses"
								if _config.provider == "responses"
								else "chat/completions"
							)
						)
					),
					"Unexpected request target"
				)
				var body = JSON.parse_string(text.substr(separator + 4))
				_check(
					body is Dictionary and body.get("store") == false,
					"Wire request lost privacy option"
				)
				_check(
					not text.substr(separator + 4).contains("fixture-only-dummy"),
					"Key leaked into request body"
				)
				if _config.provider == "chat" and _results.size() == 6:
					_check(
						text.contains("Authorization: Bearer fixture-only-dummy"),
						"Bearer header missing"
					)
				_wire_requests.append(body)
				return peer
		await process_frame
	_check(false, "Fixture received incomplete request")
	return peer


func _reply(peer, status, body, headers = "", declared = -1):
	if peer == null:
		return
	var bytes = body.to_utf8_buffer()
	var response = (
		(
			"HTTP/1.1 %d Fixture\r\nContent-Type: application/json\r\n"
			+ "Content-Length: %d\r\n%sConnection: close\r\n\r\n"
		)
		% [status, bytes.size() if declared < 0 else declared, headers]
	)
	peer.put_data(response.to_utf8_buffer())
	peer.put_data(bytes)


func _wait_result(count, milliseconds = 3000):
	var deadline = Time.get_ticks_msec() + milliseconds
	while _results.size() < count and Time.get_ticks_msec() < deadline:
		await process_frame


func _check(condition, message):
	if not condition:
		_errors.append(message)
		push_error(message)
