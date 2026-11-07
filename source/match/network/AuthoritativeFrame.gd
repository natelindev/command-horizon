# gdlint: disable=max-returns
extends RefCounted

## A strict battle-state contract is captured synchronously after physics. This
## does not reload the game. Entity IDs survive deaths and later productions.
const Protocol = preload("res://source/match/network/NetworkProtocol.gd")
const Values = preload("res://source/match/saves/SaveValue.gd")
const Native = preload("res://source/match/rendering/NativePosePacker.gd")
const TABLES = ["players", "units", "resources", "obstacles"]
var error = ""
var entities = {}
var _serials = {"unit": 0, "resource": 0, "obstacle": 0}
var _snapshotter
var _schema


class StableSnapshot:
	extends "res://source/match/saves/MatchSnapshot.gd"
	var provider: WeakRef

	func _reference(object):
		var ephemeral = super._reference(object)
		var registry = provider.get_ref()
		return registry._stable_reference(object, ephemeral) if registry != null else ephemeral


func capture(game, strict = true) -> Dictionary:
	error = ""
	if _snapshotter == null:
		_snapshotter = StableSnapshot.new()
		_snapshotter.provider = weakref(self)
	entities.clear()
	var was_finished = game.finished
	var previous_boundary = game.get_meta("network_fixed_boundary", false)
	game.set_meta("network_fixed_boundary", true)
	game.finished = false
	var snapshot = _snapshotter.capture(game, true)
	game.finished = was_finished
	game.set_meta("network_fixed_boundary", previous_boundary)
	if snapshot == null:
		error = _snapshotter.error
		return {}
	for node in _snapshotter._ids:
		_stable_reference(node, _snapshotter._ids[node])
	for table in TABLES:
		if snapshot.has(table):
			snapshot[table].sort_custom(func(a, b): return a.id.naturalnocasecmp_to(b.id) < 0)
	if strict and not validate(snapshot):
		return {}
	return snapshot


func _stable_reference(node, ephemeral: String) -> String:
	if ephemeral.is_empty():
		return ""
	var category = ephemeral.get_slice("-", 0)
	var identifier = ephemeral
	if category in _serials:
		if not node.has_meta("network_id"):
			node.set_meta("network_id", "%s-%d" % [category, _serials[category]])
			_serials[category] += 1
		identifier = node.get_meta("network_id")
		_serials[category] = maxi(_serials[category], identifier.get_slice("-", 1).to_int() + 1)
	entities[identifier] = node
	return identifier


func id_for(node) -> String:
	if not is_instance_valid(node):
		return ""
	if node.has_meta("network_id"):
		return node.get_meta("network_id")
	for id in entities:
		if entities[id] == node:
			return id
	return ""


func prepare_validation(ability_definitions: Dictionary = {}):
	if _schema == null:
		_schema = load("res://source/match/saves/SnapshotSchema.gd").new()
	_schema.prepare_validation(ability_definitions)


func validate(snapshot: Dictionary, ability_definitions: Dictionary = {}) -> bool:
	prepare_validation(ability_definitions)
	if not _schema.validate(snapshot):
		error = _schema.error
		return false
	return true


static func hash_state(snapshot: Dictionary, values = null, native = null) -> String:
	if native == null:
		native = Native.create_state_hasher()
	if native != null:
		var digest: String = native.hash_state(snapshot)
		if not digest.is_empty():
			if values != null:
				values.error = ""
			return digest
	if values == null:
		values = Values.new()
	var encoded = values.encode_canonical(snapshot, "camera")
	return Protocol.canonical_hash(encoded) if values.error.is_empty() else ""


static func delta(previous: Dictionary, current: Dictionary) -> Dictionary:
	var changes = {"set": {}, "upsert": {}, "remove": {}}
	for key in current:
		if key in TABLES:
			continue
		if not previous.has(key) or previous[key] != current[key]:
			changes.set[key] = current[key]
	for table in TABLES:
		var before = _index(previous.get(table, []))
		var after = _index(current.get(table, []))
		var upsert = []
		var removed = []
		for id in after:
			if not before.has(id) or before[id] != after[id]:
				upsert.append(after[id])
		for id in before:
			if not after.has(id):
				removed.append(id)
		changes.upsert[table] = upsert
		changes.remove[table] = removed
	return changes


static func apply_delta(previous: Dictionary, changes: Dictionary) -> Dictionary:
	var result = previous.duplicate(true)
	for key in changes.set:
		result[key] = changes.set[key]
	for table in TABLES:
		var rows = _index(result.get(table, []))
		for id in changes.remove.get(table, []):
			rows.erase(id)
		for row in changes.upsert.get(table, []):
			rows[row.id] = row
		if not rows.is_empty() or table in ["players", "units", "resources"]:
			result[table] = rows.values()
			result[table].sort_custom(func(a, b): return a.id.naturalnocasecmp_to(b.id) < 0)
		elif result.has(table):
			result.erase(table)
	return result


static func _index(rows: Array) -> Dictionary:
	var result = {}
	for row in rows:
		result[row.id] = row
	return result


static func valid_delta(changes: Dictionary) -> bool:
	if (
		changes.keys().size() != 3
		or not changes.get("set") is Dictionary
		or not changes.get("upsert") is Dictionary
		or not changes.get("remove") is Dictionary
	):
		return false
	for key in changes.upsert:
		if key not in TABLES:
			return false
	for key in changes.remove:
		if key not in TABLES:
			return false
	for table in TABLES:
		if not changes.upsert.get(table, []) is Array or not changes.remove.get(table, []) is Array:
			return false
		for row in changes.upsert.get(table, []):
			if not row is Dictionary or not row.get("id") is String:
				return false
		if not changes.remove.get(table, []).all(func(id): return id is String):
			return false
	return true
