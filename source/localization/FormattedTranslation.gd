# gdlint: disable=max-returns
extends Translation

# Native Controls also receive text already formatted by older HUD code.
# Match authored format strings without translating simulation IDs or saved data.
var catalog: Translation
var _patterns = {}
var _prefixes = []
var _cache = {}
var _shortcut = RegEx.new()
var _format = RegEx.new()


func _init(source: Translation):
	locale = "zh_CN"
	catalog = source
	_format.compile("%[-+0-9.]*[sdf]|%%")
	_shortcut.compile("^(.*?)( \\[[^\\]]+\\])$")
	var keys = Array(catalog.get_message_list())
	keys.sort_custom(func(a, b): return str(a).length() > str(b).length())
	for key in keys:
		var original = str(key)
		var tokens = _format.search_all(original)
		if not tokens.is_empty():
			_compile_pattern(original, tokens)
		elif original.ends_with(" ") and original.length() > 5:
			_prefixes.append(original)


func _compile_pattern(original, tokens):
	var pattern = "^"
	var offset = 0
	var pieces = []
	var plurals = []
	var literal_length = 0
	for token in tokens:
		var literal = original.substr(offset, token.get_start() - offset)
		literal_length += literal.length()
		pattern += _escape(literal)
		var marker = token.get_string()
		if marker == "%%":
			pattern += "%"
		else:
			pattern += "(.*?)" if marker.ends_with("s") else "(-?[0-9]+(?:\\.[0-9]+)?)"
			pieces.append(marker)
			plurals.append(
				(
					marker == "%s"
					and token.get_start() > 0
					and original[token.get_start() - 1].to_lower() in "abcdefghijklmnopqrstuvwxyz"
				)
			)
		offset = token.get_end()
	pattern += _escape(original.substr(offset)) + "$"
	literal_length += original.length() - offset
	if pieces.is_empty() or literal_length < 3:
		return
	var expression = RegEx.new()
	if expression.compile(pattern) != OK:
		return
	var prefix = _bucket(original)
	if not _patterns.has(prefix):
		_patterns[prefix] = []
	_patterns[prefix].append(
		{"expression": expression, "original": original, "tokens": pieces, "plurals": plurals}
	)


func _escape(value):
	var result = ""
	for character in value:
		if character in "\\.^$|?*+()[]{}":
			result += "\\"
		result += character
	return result


func _bucket(value):
	if value.is_empty() or not value.left(1).to_lower() in "abcdefghijklmnopqrstuvwxyz":
		return ""
	return value.left(2).to_lower()


func _get_message(src_message: StringName, _context: StringName) -> StringName:
	var source = str(src_message)
	var direct = catalog.get_message(src_message)
	if not direct.is_empty():
		return direct
	if _cache.has(source):
		return _cache[source]
	var translated = _translate(source, 0)
	if _cache.size() >= 4096:
		_cache.clear()
	_cache[source] = translated if translated != source else ""
	return _cache[source]


func _translate(source, depth):
	var direct = catalog.get_message(source)
	if not direct.is_empty():
		return str(direct)
	if depth > 5 or source.is_empty():
		return source
	var trimmed = source.strip_edges()
	if trimmed != source:
		var start = source.find(trimmed)
		return (
			source.left(start)
			+ _translate(trimmed, depth + 1)
			+ source.substr(start + trimmed.length())
		)
	var candidates = _patterns.get(_bucket(source), []).duplicate()
	if _bucket(source) != "":
		candidates += _patterns.get("", [])
	for entry in candidates:
		var found = entry.expression.search(source)
		if found == null:
			continue
		var output = str(catalog.get_message(entry.original))
		var position = 0
		# Use placeholders as strings: %02d and %.1f are already formatted by the caller.
		for token in _format.search_all(output):
			if token.get_string() == "%%":
				continue
			position += 1
		var captures = []
		for index in entry.tokens.size():
			var captured = found.get_string(index + 1)
			captures.append(
				"" if entry.plurals[index] and captured == "s" else _translate(captured, depth + 1)
			)
		if position != captures.size():
			continue
		var result = ""
		var end = 0
		var index = 0
		for token in _format.search_all(output):
			result += output.substr(end, token.get_start() - end)
			if token.get_string() == "%%":
				result += "%"
			else:
				result += captures[index]
				index += 1
			end = token.get_end()
		return result + output.substr(end)
	var shortcut = _shortcut.search(source)
	if shortcut != null:
		return _translate(shortcut.get_string(1), depth + 1) + shortcut.get_string(2)
	for separator in ["\n", " · ", " • ", " / ", ": "]:
		if separator in source:
			var parts = source.split(separator)
			for index in parts.size():
				parts[index] = _translate(parts[index], depth + 1)
			return separator.join(parts)
	for prefix in _prefixes:
		if source.begins_with(prefix):
			return (
				str(catalog.get_message(prefix))
				+ _translate(source.substr(prefix.length()), depth + 1)
			)
	return source
