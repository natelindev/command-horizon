# gdlint: disable=max-returns
extends RefCounted

const Config = preload("res://source/match/programs/llm/ProviderConfig.gd")
const OPERATIONS = ["create", "revise", "explain"]
const ASSIGNMENTS = ["anchor", "safe", "route_a", "route_b", "escort"]


static func response_schema():
	var parameter = {
		"type": "object",
		"additionalProperties": false,
		"required": ["name", "label", "value", "min", "max", "step"],
		"properties":
		{
			"name": {"type": "string"},
			"label": {"type": "string"},
			"value": {"type": "number"},
			"min": {"type": "number"},
			"max": {"type": "number"},
			"step": {"type": "number"}
		}
	}
	return {
		"type": "object",
		"additionalProperties": false,
		"required":
		["api_version", "operation", "name", "summary", "source", "parameters", "assignments"],
		"properties":
		{
			"api_version": {"type": "integer", "enum": [1]},
			"operation": {"type": "string", "enum": OPERATIONS},
			"name": {"type": "string"},
			"summary": {"type": "string"},
			"source": {"type": "string"},
			"parameters": {"type": "array", "items": parameter},
			"assignments": {"type": "array", "items": {"type": "string", "enum": ASSIGNMENTS}}
		}
	}


static func validate(value, operation):
	if (
		not value is Dictionary
		or value.size() != 7
		or not Config._integer(value.get("api_version"), 1, 1)
		or value.get("operation") != operation
		or operation not in OPERATIONS
	):
		return "Response does not match the requested operation/API."
	if (
		not _text(value.get("name"), 40)
		or not _text(value.get("summary"), 2000)
		or not _text(value.get("source"), 32768, operation == "explain")
	):
		return "Response has missing or oversized name, summary or source."
	if (
		not value.get("assignments") is Array
		or value.assignments.size() > 5
		or not value.assignments.all(func(item): return item is String and item in ASSIGNMENTS)
	):
		return "Response has unsupported assignments."
	var issue = validate_parameters(value.get("parameters"))
	if not issue.is_empty():
		return issue
	if operation == "explain" and (not value.source.is_empty() or not value.parameters.is_empty()):
		return "Explain returned a replacement program. Current draft retained."
	if operation != "explain" and source(value).to_utf8_buffer().size() > 32768:
		return "Generated program exceeds the source budget."
	return ""


static func validate_parameters(values):
	if not values is Array or values.size() > 8:
		return "At most eight numeric parameters are supported."
	var names = []
	var regex = RegEx.new()
	regex.compile("^[a-z][a-z0-9_]{0,31}\\z")
	for item in values:
		if (
			not item is Dictionary
			or item.size() != 6
			or not _text(item.get("name"), 32)
			or not _text(item.get("label"), 64)
		):
			return "Invalid parameter description."
		if regex.search(item.name) == null or item.name in names:
			return "Parameter names must be unique identifiers."
		names.append(item.name)
		for key in ["value", "min", "max", "step"]:
			var number = item.get(key)
			if (
				not (number is int or number is float)
				or not is_finite(number)
				or absf(number) > 1000000
			):
				return "Parameter values must be finite bounded numbers."
		if (
			item.min >= item.max
			or item.value < item.min
			or item.value > item.max
			or item.step <= 0
			or item.step > item.max - item.min
		):
			return "Parameter value/range/step is invalid."
	return ""


static func parameter_prefix(parameters):
	if parameters.is_empty():
		return ""
	var result = "-- RTS parameters v1\nlocal params = {\n"
	for item in parameters:
		result += (
			'    ["%s"] = %s,\n'
			% [
				item.name,
				JSON.stringify(int(item.value) if item.value == int(item.value) else item.value)
			]
		)
	return result + "}\n"


static func source(value):
	return parameter_prefix(value.parameters) + value.source


static func _text(value, maximum, empty = false):
	return (
		value is String
		and (empty or not value.strip_edges().is_empty())
		and value.to_utf8_buffer().size() <= maximum
		and not value.to_utf8_buffer().has(0)
	)
