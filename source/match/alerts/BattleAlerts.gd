extends Node

signal changed

const LIMIT = 24
const Harvest = preload("res://source/match/units/actions/CollectingResourcesSequentially.gd")
const Factions = preload("res://source/match/FactionCatalog.gd")
var entries = []
var _pending = {}
var _serial = 0
var _entry_serial = 0
var _elapsed = 0.0
var _dirty = false
var _game
var _human


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_game = get_parent()
	_human = _game._get_human_player()
	MatchSignals.unit_destroying.connect(_lost)
	MatchSignals.unit_weapon_hit.connect(_hit)


func _process(delta):
	if not _enabled():
		return
	# Paused orders can resolve a condition; its debounce/expiry still uses simulation time.
	_elapsed += delta / maxf(Engine.time_scale, 0.001)
	if _elapsed >= 0.5:
		_elapsed = 0.0
		scan()


func _enabled():
	return (
		is_instance_valid(_human)
		and not _game.restoring
		and not _game.is_queued_for_deletion()
		and not _game.finished
	)


func _owned(unit):
	return is_instance_valid(unit) and unit.player == _human and _enabled()


func unread_count():
	return entries.filter(func(entry): return entry.unread).size()


func mark_read():
	for entry in entries:
		entry.unread = false
	changed.emit()


func clear_history():
	entries = entries.filter(func(entry): return entry.active)
	changed.emit()


func entry_by_id(id):
	for entry in entries:
		if entry.id == id:
			return entry
	return null


func live_units(entry):
	var result = []
	for reference in entry.units:
		var unit = reference.get_ref()
		if (
			is_instance_valid(unit)
			and not unit.is_queued_for_deletion()
			and unit.is_inside_tree()
			and unit.player == _human
		):
			result.append(unit)
	return result


func _new_key(kind):
	_serial += 1
	return "%s:%d" % [kind, _serial]


func _find(key):
	for entry in entries:
		if entry.key == key:
			return entry
	return null


func _draft(kind, key, point):
	return {
		"kind": kind,
		"key": key,
		"point": point,
		"units": [],
		"count": 0,
		"title": "",
		"detail": "",
		"priority": 0,
		"delay": 0.0,
		"active": true,
		"condition": true,
		"group": "",
		"expires": 0.0
	}


func _publish(draft):
	var entry = _find(draft.key)
	var now = _game.simulation_time
	if entry == null:
		if entries.size() >= LIMIT:
			var replace = null
			for candidate in entries:
				if not candidate.active:
					replace = candidate
					break
				if replace == null or candidate.priority < replace.priority:
					replace = candidate
			if replace.active and replace.priority >= draft.priority:
				return null
			entries.erase(replace)
		entry = draft.duplicate()
		_entry_serial += 1
		entry.id = _entry_serial
		entry.first = now
		entry.last = now
		entry.unread = true
		entries.append(entry)
		_dirty = true
	else:
		var significant = (
			entry.title != draft.title
			or entry.detail != draft.detail
			or entry.count != draft.count
			or entry.active != draft.active
		)
		if not entry.active and draft.active:
			entry.unread = true
		for key in draft:
			entry[key] = draft[key]
		if significant or not draft.condition:
			entry.last = now
			_dirty = true
	return entry


func _notify():
	if _dirty:
		_dirty = false
		changed.emit()


func _event(unit, kind):
	var squad = unit.program_squad
	var group = ""
	if is_instance_valid(squad):
		group = "squad:%d" % squad.id
	var now = _game.simulation_time
	var window = 6.0 if kind == "loss" else 8.0
	var existing = null
	for entry in entries:
		if entry.kind != kind or now - entry.last > window:
			continue
		if group != "" and entry.group == group:
			existing = entry
		elif (
			group == ""
			and entry.group == ""
			and entry.point.distance_to(unit.global_position) <= 10
		):
			existing = entry
	var key = existing.key if existing != null else _new_key(kind)
	var draft = (
		existing.duplicate() if existing != null else _draft(kind, key, unit.global_position)
	)
	draft.group = group
	draft.condition = false
	draft.point = unit.global_position
	draft.active = kind != "loss"
	draft.expires = now + window
	draft.priority = 100 if kind != "loss" else 90
	var members = squad.active_members() if is_instance_valid(squad) else [unit]
	for member in members:
		var present = draft.units.any(func(reference): return reference.get_ref() == member)
		if not present:
			draft.units.append(weakref(member))
	var prefix = squad.title + " · " if is_instance_valid(squad) else ""
	if kind == "loss":
		draft.count += 1
		draft.unread = true
		draft.title = prefix + ("Unit lost" if draft.count == 1 else "%d units lost" % draft.count)
		draft.detail = "Latest loss · %s" % Factions.title(_human.faction, unit.type)
	else:
		draft.title = (
			prefix + ("Base under attack" if kind == "base_attack" else "Units under attack")
		)
		draft.detail = "Incoming fire · inspect your units"
	_publish(draft)
	_notify()


func _lost(unit):
	if _owned(unit):
		_event(unit, "loss")


func _hit(unit, _source):
	if _owned(unit) and unit.hp > 0:
		_event(unit, "base_attack" if unit.has_method("is_constructed") else "attack")


func _area_key(kind, point, candidates):
	# Reuse the assignment-area anchor through worker movement and reassignment.
	for candidate in candidates.values():
		if candidate.kind == kind and candidate.point.distance_to(point) <= 10:
			return candidate.key
	for entry in entries:
		if entry.kind == kind and entry.point.distance_to(point) <= 10:
			return entry.key
	for key in _pending:
		var candidate = _pending[key].draft
		if candidate.kind == kind and candidate.point.distance_to(point) <= 10:
			return key
	return _new_key(kind)


func _worker_condition(unit, candidates):
	var action = unit.action
	var kind = "idle"
	var point = unit.global_position
	var title = "Idle engineers"
	var detail = "Select and assign a resource field or construction task."
	var priority = 20
	var delay = 6.0
	if action is Harvest:
		if not action.needs_assignment():
			return
		if action._waiting_reason == Harvest.Wait.DEPLETED:
			kind = "field_materials" if action._kind == 1 else "field_electronics"
			point = action._field_origin
			title = (
				"Materials field depleted" if action._kind == 1 else "Electronics field depleted"
			)
			detail = "Choose a new field for these engineers."
			priority = 60
			delay = 1.0
		elif action._waiting_reason == Harvest.Wait.HQ:
			kind = "drop_off"
			title = "Cargo needs a drop-off"
			detail = "Select engineers and right-click a completed friendly HQ."
			priority = 65
			delay = 1.0
	elif action != null:
		return
	if unit.manual_orders != null and not unit.manual_orders.pending.is_empty():
		return
	var key = _area_key(kind, point, candidates)
	if not candidates.has(key):
		var draft = _draft(kind, key, point)
		draft.title = title
		draft.detail = detail
		draft.priority = priority
		draft.delay = delay
		candidates[key] = draft
	candidates[key].count += 1
	candidates[key].units.append(weakref(unit))


func scan():
	if not _enabled():
		return
	var now = _game.simulation_time
	var candidates = {}
	var own = _human.get_children().filter(
		func(unit): return unit.is_in_group("units") and not unit.is_queued_for_deletion()
	)
	for unit in own:
		if unit.type == "Worker":
			_worker_condition(unit, candidates)
		var queue = unit.get_node_or_null("ProductionQueue")
		if queue == null:
			continue
		var reason = queue.blocked_reason()
		if reason.is_empty():
			continue
		var key = "production:%d" % unit.get_instance_id()
		var draft = _draft("production", key, unit.global_position)
		draft.title = Factions.title(_human.faction, unit.type) + " · production blocked"
		draft.detail = reason
		draft.units = [weakref(unit)]
		draft.count = queue.size()
		draft.priority = 55
		draft.delay = 2.0
		candidates[key] = draft
	var power = _human.power_totals()
	if power.y > power.x:
		var draft = _draft("power", "power", Vector3.ZERO)
		draft.title = "Low power"
		draft.detail = "%d used / %d supply · production at 35%% speed." % [power.y, power.x]
		draft.priority = 70
		draft.delay = 2.0
		for unit in own:
			if unit.type in ["PowerPlant", "CommandCenter"]:
				draft.units.append(weakref(unit))
		if draft.units.is_empty():
			for unit in own:
				if unit.type == "Worker" or unit.has_method("is_constructed"):
					draft.units.append(weakref(unit))
		if not draft.units.is_empty():
			draft.point = draft.units[0].get_ref().global_position
		candidates.power = draft
	for key in candidates:
		var draft = candidates[key]
		if not _pending.has(key):
			_pending[key] = {"since": now, "draft": draft}
		if now - _pending[key].since >= draft.delay:
			_publish(draft)
	for key in _pending.keys():
		if not candidates.has(key):
			_pending.erase(key)
	for entry in entries:
		var recovered = entry.condition and not candidates.has(entry.key)
		var expired = not entry.condition and entry.expires < now
		if entry.active and (recovered or expired):
			entry.active = false
			_dirty = true
	_notify()
