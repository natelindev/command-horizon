# gdlint: disable=max-returns
extends RefCounted

const Config = preload("res://source/match/programs/llm/ProviderConfig.gd")
const Draft = preload("res://source/match/programs/llm/DraftResponse.gd")
const REQUEST_BYTES = 98304
const RESPONSE_BYTES = 262144


static func encode(config, context):
	var issue = Config.validate(config)
	if not issue.is_empty():
		return _fail(issue)
	if (
		not context is Dictionary
		or not context.get("ok", false)
		or not context.get("system") is String
		or not context.get("user") is String
		or context.get("operation") not in Draft.OPERATIONS
	):
		return _fail("Invalid generation context.")
	var body = {"model": config.model, "store": false, "stream": false}
	var instructions = (
		context.system + "\nRequired JSON schema:\n" + JSON.stringify(Draft.response_schema())
	)
	var format = {"type": "json_object"}
	if config.structured:
		format = {
			"type": "json_schema",
			"name": "rts_program_draft",
			"strict": true,
			"schema": Draft.response_schema()
		}
	if config.provider == "responses":
		body.instructions = instructions
		body.input = context.user
		body.max_output_tokens = int(config.output_limit)
		body.text = {"format": format}
	else:
		body.messages = [
			{"role": "system", "content": instructions}, {"role": "user", "content": context.user}
		]
		body.max_tokens = int(config.output_limit)
		if config.structured:
			format = {
				"type": "json_schema",
				"json_schema":
				{"name": "rts_program_draft", "strict": true, "schema": Draft.response_schema()}
			}
		body.response_format = format
	var encoded = JSON.stringify(body)
	if encoded.to_utf8_buffer().size() > REQUEST_BYTES:
		return _fail("Request exceeds the size budget. Shorten the draft or diagnostics.")
	return {"ok": true, "error": "", "body": encoded}


static func decode(provider, operation, status, bytes):
	if bytes.size() > RESPONSE_BYTES:
		return _fail("Provider response exceeds the size limit. Shorten the requested program.")
	if status != 200:
		return _fail(http_error(status))
	var parser = JSON.new()
	if parser.parse(bytes.get_string_from_utf8()) != OK or not parser.data is Dictionary:
		return _fail("Provider returned invalid JSON. Draft retained.")
	var envelope = parser.data
	var extracted = _responses(envelope) if provider == "responses" else _chat(envelope)
	if not extracted.ok:
		return extracted
	if parser.parse(extracted.text) != OK:
		return _fail("Generated content is not a JSON draft. Draft retained.")
	var issue = Draft.validate(parser.data, operation)
	if not issue.is_empty():
		return _fail(issue)
	return {"ok": true, "error": "", "draft": parser.data, "usage": _usage(envelope.get("usage"))}


static func http_error(status):
	match status:
		400, 422:
			return "Provider rejected the request. Check model, output limit and structured-output support."
		401, 403:
			return "Provider denied access. Check the API key and model permissions."
		404:
			return "Provider endpoint or model was not found. Check provider settings."
		408, 504:
			return "Provider timed out. Retry explicitly when ready."
		413:
			return "Provider rejected the request size. Shorten the draft or diagnostics."
		429:
			return "Provider rate or usage limit reached. Check your provider account before retrying."
	if status >= 300 and status < 400:
		return "Request redirected. Set the final endpoint explicitly; redirects are disabled."
	return "Provider request failed (HTTP %d). Draft retained; no automatic retry." % status


static func _responses(value):
	if value.get("status") == "incomplete":
		return _fail("Generation was incomplete. Shorten the request or raise the output limit.")
	if value.get("status") != "completed" or not value.get("output") is Array:
		return _fail("Provider did not complete generation. Draft retained.")
	var output = ""
	for item in value.output:
		if not item is Dictionary:
			return _fail("Invalid provider output.")
		if item.get("type") != "message":
			continue
		if item.get("role") != "assistant" or not item.get("content") is Array:
			return _fail("Invalid provider message.")
		for part in item.content:
			if not part is Dictionary:
				return _fail("Invalid provider content.")
			if part.get("type") == "refusal":
				return _fail("The provider declined this request. Rephrase the behavior you want.")
			if part.get("type") == "output_text" and part.get("text") is String:
				output += part.text
	return {"ok": true, "text": output}


static func _chat(value):
	var choices = value.get("choices")
	if not choices is Array or choices.size() != 1 or not choices[0] is Dictionary:
		return _fail("Provider returned an unsupported response.")
	var choice = choices[0]
	var message = choice.get("message")
	if not message is Dictionary:
		return _fail("Invalid provider message.")
	if message.get("refusal") != null and message.get("refusal") != "":
		return _fail("The provider declined this request. Rephrase the behavior you want.")
	if choice.get("finish_reason") != "stop":
		return _fail("Generation did not finish. Shorten the request or check the output limit.")
	if not message.get("content") is String:
		return _fail("Provider returned no draft text.")
	return {"ok": true, "text": message.content}


static func _usage(value):
	var usage = {}
	if value is Dictionary:
		for key in [
			"input_tokens", "output_tokens", "total_tokens", "prompt_tokens", "completion_tokens"
		]:
			var number = value.get(key)
			if Config._integer(number, 0, 100000000):
				usage[key] = int(number)
	return usage


static func _fail(message):
	return {"ok": false, "error": message}
