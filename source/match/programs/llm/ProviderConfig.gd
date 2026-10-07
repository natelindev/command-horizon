# gdlint: disable=max-returns
extends RefCounted

const PATH = "user://llm-provider.json"
const DEFAULTS = {
	"schema": 1,
	"provider": "responses",
	"endpoint": "https://api.openai.com/v1/responses",
	"model": "gpt-4.1-mini-2025-04-14",
	"structured": true,
	"output_limit": 2048,
	"timeout_seconds": 45
}
var value = DEFAULTS.duplicate(true)
var error = ""


static func validate(data):
	if not data is Dictionary or data.size() != DEFAULTS.size():
		return "Provider settings have unsupported fields."
	for key in DEFAULTS:
		if not data.has(key):
			return "Provider settings are incomplete."
	if (
		not _integer(data.schema, 1, 1)
		or not data.provider is String
		or data.provider not in ["responses", "chat"]
	):
		return "Unsupported provider configuration."
	if not data.endpoint is String or not data.model is String or not data.structured is bool:
		return "Invalid endpoint/model settings."
	if data.endpoint.length() > 512 or data.model.length() > 120:
		return "Endpoint/model setting is too long."
	var model_pattern = RegEx.new()
	model_pattern.compile("^[A-Za-z0-9._:/-]+\\z")
	if model_pattern.search(data.model) == null:
		return "Enter a valid model ID."
	var endpoint = endpoint_parts(data.endpoint)
	if endpoint.is_empty():
		return "Use HTTPS, or HTTP on localhost. Do not include credentials, query strings or fragments."
	var suffix = "/responses" if data.provider == "responses" else "/chat/completions"
	if not endpoint.path.ends_with(suffix):
		return "Endpoint must end in " + suffix + "."
	if not _integer(data.output_limit, 256, 4096) or not _integer(data.timeout_seconds, 5, 120):
		return "Output limit must be 256–4,096 tokens; timeout must be 5–120 seconds."
	return ""


static func endpoint_parts(url):
	var regex = RegEx.new()
	(
		regex
		. compile(
			"^(https?)://([A-Za-z0-9.-]+|\\[::1\\])(?::([0-9]{1,5}))?(/[A-Za-z0-9._~!$&'()*+,;=:@%/-]*)\\z"
		)
	)
	var parsed = regex.search(url)
	if parsed == null or url.to_utf8_buffer().has(0):
		return {}
	var host = parsed.get_string(2).to_lower()
	if parsed.get_string(1) == "http" and host not in ["localhost", "127.0.0.1", "[::1]"]:
		return {}
	var port = parsed.get_string(3)
	if not port.is_empty() and (int(port) < 1 or int(port) > 65535):
		return {}
	return {"scheme": parsed.get_string(1), "host": host, "path": parsed.get_string(4)}


static func account(data):
	return (data.provider + "\n" + data.endpoint).sha256_text()


static func _integer(number, lower, upper):
	return (
		(number is int or number is float)
		and is_finite(number)
		and number >= lower
		and number <= upper
		and number == int(number)
	)


func read_settings(path = PATH):
	error = ""
	if not FileAccess.file_exists(path):
		return true
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 8192:
		error = "Provider settings could not be read. Current settings retained."
		return false
	var parser = JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		error = "Provider settings are damaged. Current settings retained."
		return false
	error = validate(parser.data)
	if not error.is_empty():
		return false
	value = parser.data.duplicate(true)
	return true


func write_settings(data, path = PATH):
	error = validate(data)
	if not error.is_empty():
		return false
	var file = FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		error = "Could not save provider settings."
		return false
	file.store_string(JSON.stringify(data))
	file.flush()
	var code = file.get_error()
	file.close()
	if code != OK or DirAccess.rename_absolute(path + ".tmp", path) != OK:
		DirAccess.remove_absolute(path + ".tmp")
		error = "Could not replace provider settings. Previous settings retained."
		return false
	value = data.duplicate(true)
	return true
