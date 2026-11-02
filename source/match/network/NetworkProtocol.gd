# gdlint: disable=max-returns
extends RefCounted

## Network and replay values are inert, bounded JSON. Object/Variant decoding,
## resource paths from peers and arbitrary RPC method names are never accepted.
const VERSION = 1
const MAX_BYTES = 4 * 1024 * 1024
const MAX_DEPTH = 96
const MAX_ITEMS = 200000
const MAX_TEXT = 32768
const MAX_GROUP_ENTRIES = 128
const MAX_INTENT_BYTES = 256 * 1024
const ORDER_KINDS = [
	"move",
	"attack_move",
	"attack",
	"force_attack",
	"stop",
	"hold",
	"patrol",
	"follow",
	"guard",
	"reverse",
	"garrison",
	"unload",
	"repair",
	"recover",
	"harvest",
	"gather",
	"approach",
	"collect_tactical",
	"repair_barrier",
	"dismantle",
	"engineering",
	"sweep",
	"scavenge",
	"construct"
]
const KINDS = [
	"batch",
	"order",
	"produce",
	"cancel_production",
	"research",
	"cancel_research",
	"ability",
	"build",
	"exchange",
	"hire_aircraft",
	"commander",
	"stance",
	"formation",
	"cohesion",
	"pause",
	"surrender",
	"signature",
	"rally",
	"revise_order",
	"cancel_build",
	"hire_mercenary",
	"cancel_mercenary"
]
var error = ""
var _remaining = MAX_ITEMS


func encode(value) -> PackedByteArray:
	error = ""
	_remaining = MAX_ITEMS
	if not _valid(value, 0):
		return PackedByteArray()
	var bytes = JSON.stringify(value, "", true, true).to_utf8_buffer()
	if bytes.size() > MAX_BYTES:
		error = "Packet exceeds the 4 MiB limit."
		return PackedByteArray()
	return bytes


func decode(bytes: PackedByteArray):
	error = ""
	if bytes.is_empty() or bytes.size() > MAX_BYTES:
		error = "Invalid packet length."
		return null
	var parser = JSON.new()
	if parser.parse(bytes.get_string_from_utf8()) != OK:
		error = "Packet is not valid JSON."
		return null
	_remaining = MAX_ITEMS
	if not _valid(parser.data, 0):
		return null
	return _integers(parser.data)


func _valid(value, depth) -> bool:
	_remaining -= 1
	if depth > MAX_DEPTH or _remaining < 0:
		error = "Packet exceeds nesting or item limits."
		return false
	match typeof(value):
		TYPE_NIL, TYPE_BOOL:
			return true
		TYPE_INT:
			if absi(value) < 9007199254740992:
				return true
		TYPE_FLOAT:
			if is_finite(value) and absf(value) < 9007199254740992.0:
				return true
		TYPE_STRING:
			if value.to_utf8_buffer().size() <= MAX_TEXT:
				return true
		TYPE_ARRAY:
			for item in value:
				if not _valid(item, depth + 1):
					return false
			return true
		TYPE_DICTIONARY:
			for key in value:
				if (
					not (key is String or key is StringName)
					or key.length() > 96
					or not _valid(value[key], depth + 1)
				):
					return false
			return true
	error = "Packet contains an unsupported value: " + type_string(typeof(value))
	return false


func _integers(value):
	if value is float and value == floor(value):
		return int(value)
	if value is Array:
		return value.map(_integers)
	if value is Dictionary:
		var result = {}
		for key in value:
			result[key] = _integers(value[key])
		return result
	return value


static func quantize(point: Vector3) -> Array:
	return [roundi(point.x * 1000.0), roundi(point.y * 1000.0), roundi(point.z * 1000.0)]


static func vector(point: Array) -> Vector3:
	return Vector3(point[0], point[1], point[2]) / 1000.0


static func valid_point(point) -> bool:
	return (
		point is Array
		and point.size() == 3
		and point.all(func(value): return value is int and absi(value) <= 10000000)
	)


static func identifier(value) -> bool:
	return (
		value is String
		and value.length() > 0
		and value.length() <= 64
		and value.replace("-", "_").is_valid_identifier()
	)


static func digest(bytes: PackedByteArray) -> String:
	var hashing = HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(bytes)
	return hashing.finish().hex_encode()


static func canonical_hash(value) -> String:
	return digest(JSON.stringify(value, "", true, true).to_utf8_buffer())


func valid_intent(intent) -> bool:
	error = "Invalid command shape."
	if not intent is Dictionary or intent.get("kind") not in KINDS or intent.size() > 13:
		return false
	if intent.kind == "batch":
		return _valid_batch(intent)
	var allowed = [
		"kind",
		"units",
		"unit",
		"target",
		"point",
		"role",
		"id",
		"append",
		"angle",
		"index",
		"value",
		"direction",
		"order",
		"waypoints",
		"token",
		"members"
	]
	for key in intent:
		if key not in allowed:
			return false
		if key in ["unit", "target"] and not identifier(intent[key]):
			return false
		if (
			key in ["role", "id", "direction", "order"]
			and not (intent[key] is String and intent[key].length() <= 64)
		):
			return false
	if intent.has("point") and not valid_point(intent.point):
		return false
	if (
		intent.has("units")
		and not (
			intent.units is Array
			and intent.units.size() in range(1, 129)
			and intent.units.all(identifier)
		)
	):
		return false
	if (
		intent.has("waypoints")
		and not (
			intent.waypoints is Array
			and intent.waypoints.size() <= 32
			and intent.waypoints.all(valid_point)
		)
	):
		return false
	if (
		intent.has("token")
		and not (intent.token is int and intent.token > 0 and intent.token <= 1000000000)
	):
		return false
	if (
		intent.has("members")
		and not (
			intent.members is Array
			and intent.members.size() <= 128
			and intent.members.all(identifier)
		)
	):
		return false
	if intent.has("append") and not intent.append is bool:
		return false
	if (
		intent.has("index")
		and not (intent.index is int and intent.index >= -1 and intent.index < 16)
	):
		return false
	if intent.has("angle") and not (intent.angle is int and absi(intent.angle) <= 360000):
		return false
	match intent.kind:
		"order":
			if (
				not intent.has("units")
				or intent.get("order") not in ORDER_KINDS
				or not intent.has("point")
			):
				return false
		"rally", "revise_order":
			if (
				not intent.has("unit")
				or not intent.has("point")
				or (intent.kind == "revise_order" and not intent.has("token"))
			):
				return false
		"cancel_build":
			if not intent.has("unit"):
				return false
		"hire_mercenary", "cancel_mercenary":
			if (
				not intent.has("target")
				or (intent.kind == "hire_mercenary" and not intent.has("role"))
				or (intent.kind == "cancel_mercenary" and not intent.has("index"))
			):
				return false
		"produce", "build", "hire_aircraft":
			if (
				not intent.has("role")
				or (intent.kind == "produce" and not intent.has("unit"))
				or (intent.kind == "build" and not intent.has("point"))
			):
				return false
		"ability", "research":
			if not intent.has("unit") or not intent.has("id"):
				return false
		"cancel_production", "cancel_research":
			if (
				not intent.has("index")
				or (intent.kind == "cancel_production" and not intent.has("unit"))
			):
				return false
		"exchange":
			if intent.get("direction") not in ["buy_materials", "buy_electronics"]:
				return false
		"commander", "signature":
			if not intent.has("point") or (intent.kind == "signature" and not intent.has("units")):
				return false
		"pause":
			if not intent.get("value") is bool:
				return false
		"stance", "formation", "cohesion":
			if not intent.has("units") or not intent.has("value"):
				return false
	if intent.kind == "stance" and not (intent.value is int and intent.value in range(4)):
		return false
	if intent.kind == "formation" and intent.value not in ["line", "box", "flank", "staggered"]:
		return false
	if intent.kind == "cohesion" and not intent.value is bool:
		return false
	var schemas = {
		"order":
		[
			"kind",
			"units",
			"order",
			"point",
			"target",
			"append",
			"angle",
			"id",
			"waypoints",
			"token",
			"members"
		],
		"produce": ["kind", "unit", "role"],
		"cancel_production": ["kind", "unit", "index"],
		"research": ["kind", "unit", "id"],
		"cancel_research": ["kind", "index"],
		"ability": ["kind", "unit", "id", "point", "target"],
		"build": ["kind", "role", "point", "angle"],
		"exchange": ["kind", "direction"],
		"hire_aircraft": ["kind", "role"],
		"commander": ["kind", "point"],
		"signature": ["kind", "units", "point"],
		"stance": ["kind", "units", "value"],
		"formation": ["kind", "units", "value"],
		"cohesion": ["kind", "units", "value"],
		"pause": ["kind", "value"],
		"surrender": ["kind"],
		"rally": ["kind", "unit", "point", "target"],
		"revise_order": ["kind", "unit", "token", "point", "waypoints"],
		"cancel_build": ["kind", "unit"],
		"hire_mercenary": ["kind", "target", "role"],
		"cancel_mercenary": ["kind", "target", "index"]
	}
	if not intent.keys().all(func(key): return key in schemas[intent.kind]):
		return false
	error = ""
	return true


static func pack_batch(intents: Array) -> Dictionary:
	var result = {"kind": "batch", "intents": [], "cohorts": []}
	for original in intents:
		var entry = original.duplicate(true)
		if entry.has("members"):
			var index = result.cohorts.find(entry.members)
			if index < 0:
				index = result.cohorts.size()
				result.cohorts.append(entry.members)
			entry.erase("members")
			entry.cohort = index
		result.intents.append(entry)
	return result


static func unpack_batch(batch: Dictionary) -> Array:
	var result = []
	for original in batch.intents:
		var entry = original.duplicate()
		if entry.has("cohort"):
			entry.members = batch.cohorts[entry.cohort]
			entry.erase("cohort")
		result.append(entry)
	return result


func _valid_batch(batch: Dictionary) -> bool:
	if not batch.keys().all(func(key): return key in ["kind", "intents", "cohorts"]):
		return false
	if (
		not batch.get("intents") is Array
		or batch.intents.is_empty()
		or batch.intents.size() > MAX_GROUP_ENTRIES
		or not batch.get("cohorts") is Array
		or batch.cohorts.size() > MAX_GROUP_ENTRIES
	):
		return false
	for members in batch.cohorts:
		if not members is Array or members.size() > 128 or not members.all(identifier):
			return false
	for original in batch.intents:
		if not original is Dictionary or original.get("kind") in ["batch", "pause", "surrender"]:
			return false
		var entry = original.duplicate()
		if entry.has("cohort"):
			if (
				entry.kind != "order"
				or not entry.cohort is int
				or entry.cohort < 0
				or entry.cohort >= batch.cohorts.size()
				or entry.has("members")
			):
				return false
			entry.members = batch.cohorts[entry.cohort]
			entry.erase("cohort")
		if not valid_intent(entry):
			return false
	error = ""
	return true


static func work_cost(intent: Dictionary) -> int:
	if intent.get("kind") == "batch":
		var total = 0
		for entry in intent.intents:
			total += maxi(1, entry.get("units", []).size())
		return total
	return maxi(1, intent.get("units", []).size())
