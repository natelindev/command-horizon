extends RefCounted

const Draft = preload("res://source/match/programs/llm/DraftResponse.gd")


static func schema(values):
	return {} if values.is_empty() else {"version": 1, "values": values.duplicate(true)}


static func valid(metadata, source):
	if metadata == {}:
		return true
	return (
		metadata is Dictionary
		and metadata.size() == 2
		and (metadata.get("version") is int or metadata.get("version") is float)
		and metadata.get("version") == 1
		and Draft.validate_parameters(metadata.get("values")).is_empty()
		and not metadata.values.is_empty()
		and source.begins_with(Draft.parameter_prefix(metadata.values))
	)


static func replace(source, metadata, values):
	if (
		not valid(metadata, source)
		or metadata.is_empty()
		or not Draft.validate_parameters(values).is_empty()
	):
		return {}
	var body = source.substr(Draft.parameter_prefix(metadata.values).length())
	var result = Draft.parameter_prefix(values) + body
	if result.to_utf8_buffer().size() > 32768:
		return {}
	return {"source": result, "parameter_schema": schema(values)}
