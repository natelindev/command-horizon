# gdlint: disable=max-returns
extends Node

signal completed(result)

const Config = preload("res://source/match/programs/llm/ProviderConfig.gd")
const Protocol = preload("res://source/match/programs/llm/ProviderProtocol.gd")
var _request: HTTPRequest
var _epoch = 0


func _init():
	process_mode = Node.PROCESS_MODE_ALWAYS


func busy():
	return is_instance_valid(_request)


func generate(config, context, secret):
	if busy():
		return {
			"ok": false, "error": "A request is already running. Cancel it before generating again."
		}
	if not is_inside_tree():
		return {"ok": false, "error": "Generation is unavailable outside the editor."}
	var encoded = Protocol.encode(config, context)
	if not encoded.ok:
		return encoded
	if (
		not secret is String
		or secret.to_utf8_buffer().size() > 4096
		or secret.contains("\n")
		or secret.contains("\r")
		or secret.to_utf8_buffer().has(0)
	):
		return {"ok": false, "error": "Invalid API key."}
	var host = Config.endpoint_parts(config.endpoint).host
	if secret.is_empty() and host not in ["localhost", "127.0.0.1", "[::1]"]:
		return {"ok": false, "error": "Configure an API key for this provider."}
	_epoch += 1
	_request = HTTPRequest.new()
	_request.timeout = float(config.timeout_seconds)
	_request.max_redirects = 0
	_request.body_size_limit = Protocol.RESPONSE_BYTES
	_request.accept_gzip = false
	# Use the nonblocking poller: threaded requests may block cancellation
	# while waiting for a silent peer in Godot 4.6.
	_request.use_threads = false
	add_child(_request)
	_request.request_completed.connect(
		_on_completed.bind(_epoch, config.provider, context.operation)
	)
	var headers = PackedStringArray(["Content-Type: application/json", "Accept: application/json"])
	if not secret.is_empty():
		headers.append("Authorization: Bearer " + secret)
	var code = _request.request(config.endpoint, headers, HTTPClient.METHOD_POST, encoded.body)
	if code != OK:
		_dispose()
		return {
			"ok": false,
			"error": "Could not start provider request. Check the endpoint and connection."
		}
	return {"ok": true, "error": ""}


func cancel():
	if not busy():
		return
	_epoch += 1
	_dispose()
	completed.emit(
		{"ok": false, "cancelled": true, "error": "Generation cancelled. Draft retained."}
	)


func _exit_tree():
	_epoch += 1
	_dispose()


func _dispose():
	if is_instance_valid(_request):
		_request.cancel_request()
		_request.queue_free()
	_request = null


func _on_completed(result, status, _headers, body, epoch, provider, operation):
	if epoch != _epoch or not busy():
		return
	_dispose()
	if result == HTTPRequest.RESULT_SUCCESS:
		completed.emit(Protocol.decode(provider, operation, status, body))
	elif result == HTTPRequest.RESULT_REDIRECT_LIMIT_REACHED:
		completed.emit({"ok": false, "error": Protocol.http_error(302)})
	elif result == HTTPRequest.RESULT_TIMEOUT:
		completed.emit(
			{"ok": false, "error": "Connection timed out. Draft retained; no automatic retry."}
		)
	elif result == HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED:
		completed.emit(
			{"ok": false, "error": "Provider response exceeds the size limit. Draft retained."}
		)
	else:
		completed.emit(
			{"ok": false, "error": "Provider connection failed. Check connection and TLS settings."}
		)
