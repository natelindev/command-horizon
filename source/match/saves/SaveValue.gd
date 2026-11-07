# gdlint: disable=max-returns
extends RefCounted

# Every value is tagged, including records: saved keys can never masquerade as types.
const MAX_DEPTH = 32
const MAX_NODES = 750000
const MAX_STRING_BYTES = 2 * 1024 * 1024
var error = ""
var _left = MAX_NODES


func encode(value):
	error = ""
	_left = MAX_NODES
	return _encode(value, 0)


## Sort record keys while tagging values, avoiding a second recursive copy.
## Only the root exclusion is omitted; nested camera fields remain authoritative.
func encode_canonical(value, excluded_root_key = ""):
	error = ""
	_left = MAX_NODES
	return _encode(value, 0, true, excluded_root_key)


func decode(value):
	error = ""
	_left = MAX_NODES
	return _decode(value, 0)


func _visit(depth):
	_left -= 1
	if not error.is_empty():
		return false
	if depth > MAX_DEPTH or _left < 0:
		error = "Save data exceeds the nesting or item limit."
		return false
	return true


func _fail():
	error = "Save contains an unsupported or invalid value."
	return null


func _encode(value, depth, canonical = false, excluded_root_key = ""):
	if not _visit(depth):
		return null
	match typeof(value):
		TYPE_NIL:
			return ["null"]
		TYPE_BOOL:
			return ["bool", value]
		TYPE_INT:
			return ["int", str(value)]  # JSON numbers cannot preserve all 64-bit integers.
		TYPE_FLOAT:
			return ["float", _number_bits(value)] if is_finite(value) else _fail()
		TYPE_STRING:
			return ["text", value] if value.to_utf8_buffer().size() <= MAX_STRING_BYTES else _fail()
		TYPE_VECTOR3:
			return (
				["vec3", [value.x, value.y, value.z].map(_number_bits)]
				if value.is_finite()
				else _fail()
			)
		TYPE_COLOR:
			var parts = [value.r, value.g, value.b, value.a]
			return (
				["color", parts.map(_number_bits)]
				if parts.all(func(n): return is_finite(n))
				else _fail()
			)
		TYPE_ARRAY:
			var result = []
			for item in value:
				result.append(_encode(item, depth + 1, canonical))
				if not error.is_empty():
					return null
			return ["list", result]
		TYPE_DICTIONARY:
			var result = []
			var keys = value.keys() if canonical else value
			if canonical:
				for key in keys:
					if not (key is String or key is StringName):
						return _fail()
				keys = keys.map(func(key): return str(key))
				keys.sort()
			for key in keys:
				if depth == 0 and not excluded_root_key.is_empty() and key == excluded_root_key:
					continue
				if not (key is String or key is StringName):
					return _fail()
				var text_key = str(key)
				if text_key.to_utf8_buffer().size() > MAX_STRING_BYTES:
					return _fail()
				result.append([text_key, _encode(value[key], depth + 1, canonical)])
				if not error.is_empty():
					error = "%s: %s" % [text_key.left(48), error]
					return null
			return ["record", result]
	return _fail()


func _decode(value, depth):
	if not _visit(depth):
		return null
	if not value is Array or value.is_empty() or not value[0] is String:
		return _fail()
	if value == ["null"]:
		return null
	if value.size() != 2:
		return _fail()
	var data = value[1]
	match value[0]:
		"bool":
			return data if data is bool else _fail()
		"int":
			if not data is String or data.length() > 20 or not data.is_valid_int():
				return _fail()
			var number = data.to_int()
			return number if str(number) == data else _fail()
		"float":
			return _read_number(data)
		"text":
			if data is String and data.to_utf8_buffer().size() <= MAX_STRING_BYTES:
				return data
		"vec3", "color":
			var count = 3 if value[0] == "vec3" else 4
			if not data is Array or data.size() != count:
				return _fail()
			data = data.map(_read_number)
			if not error.is_empty():
				return _fail()
			return (
				Vector3(data[0], data[1], data[2])
				if count == 3
				else Color(data[0], data[1], data[2], data[3])
			)
		"list":
			if not data is Array:
				return _fail()
			var result = []
			for item in data:
				result.append(_decode(item, depth + 1))
				if not error.is_empty():
					return null
			return result
		"record":
			if not data is Array:
				return _fail()
			var result = {}
			for pair in data:
				if not pair is Array or pair.size() != 2 or not pair[0] is String:
					return _fail()
				if result.has(pair[0]) or pair[0].to_utf8_buffer().size() > MAX_STRING_BYTES:
					return _fail()
				result[pair[0]] = _decode(pair[1], depth + 1)
				if not error.is_empty():
					return null
			return result
	return _fail()


func _number_bits(value):
	# Preserve IEEE-754 bits: decimal JSON can round simulation durations on parse.
	return PackedFloat64Array([value]).to_byte_array().hex_encode()


func _read_number(value):
	if not value is String or value.length() != 16 or not value.is_valid_hex_number():
		return _fail()
	var number = value.hex_decode().decode_double(0)
	return number if is_finite(number) else _fail()
