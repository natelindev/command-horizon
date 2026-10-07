# gdlint: disable=max-returns
extends Node

const MEMBER_LIMIT = 24
const STATE_BYTES = 8192
const CLAIM_SECONDS = 0.8
const POLICIES = ["spread", "focus", "independent"]
const Rules = preload("res://source/match/combat/CombatRules.gd")
var id = 0
var title = ""
var members = []
var policy = "spread"
var _state = {}
var _claims = {}


func active_members():
	return members.filter(
		func(unit): return is_instance_valid(unit) and not unit.is_queued_for_deletion()
	)


func ready_members():
	return active_members().filter(
		func(unit): return unit.program != null and unit.program.ready_to_run()
	)


func can_share(unit):
	return (
		unit in members
		and unit.player.coordination_unlocked
		and unit.program != null
		and unit.program.ready_to_run()
		and unit.program.mode == "Running"
	)


func release(unit):
	_claims.erase(unit.get_instance_id())


func claim(unit, target, channel = "fire"):
	if not can_share(unit) or policy == "independent":
		release(unit)
		return
	_claims[unit.get_instance_id()] = {
		"unit": weakref(unit),
		"target": weakref(target),
		"channel": channel,
		"expires": unit._match.simulation_time + CLAIM_SECONDS,
		"damage": Rules.damage(unit, target) if channel == "fire" else 0.0,
	}


func _live_claims(unit, channel):
	var result = []
	var now = unit._match.simulation_time
	for key in _claims.keys():
		var entry = _claims[key]
		var owner = entry.unit.get_ref()
		var target = entry.target.get_ref()
		if (
			not is_instance_valid(owner)
			or not is_instance_valid(target)
			or owner.is_queued_for_deletion()
			or target.is_queued_for_deletion()
			or entry.expires <= now
			or not can_share(owner)
		):
			_claims.erase(key)
			continue
		if owner != unit and entry.channel == channel:
			result.append(entry)
	return result


func claim_snapshot(unit, channel = "fire"):
	var totals = {}
	if not can_share(unit) or policy == "independent":
		return totals
	for entry in _live_claims(unit, channel):
		var target_id = entry.target.get_ref().get_instance_id()
		if not totals.has(target_id):
			totals[target_id] = {"count": 0, "damage": 0.0}
		totals[target_id].count += 1
		totals[target_id].damage += entry.damage
	return totals


func target_bias(unit, target, channel = "fire", snapshot = null):
	if not can_share(unit) or policy == "independent":
		return 0.0
	var totals = claim_snapshot(unit, channel) if snapshot == null else snapshot
	var entry = totals.get(target.get_instance_id(), {"count": 0, "damage": 0.0})
	if channel == "repair":
		return float(entry.count) * 1000.0
	if policy == "focus":
		return -1000.0 if entry.count > 0 else 0.0
	# Prefer an unclaimed target, especially when another shot already covers its HP.
	return entry.count * 10.0 + (1000.0 if entry.count > 0 and entry.damage >= target.hp else 0.0)


func set_policy(value):
	if value not in POLICIES:
		return false
	policy = value
	_claims.clear()
	return true


func write_state(unit, key, value):
	if not can_share(unit):
		return false
	if (
		not key is String
		or key.is_empty()
		or key.length() > 48
		or not _valid_value(value, 0, [STATE_BYTES])
	):
		return false
	var next = _state.duplicate(true)
	next[key] = value
	if next.size() > 64 or JSON.stringify(next).to_utf8_buffer().size() > STATE_BYTES:
		return false
	_state = next.duplicate(true)
	return true


func erase_state(unit, key):
	if can_share(unit):
		_state.erase(key)


func state_snapshot(unit):
	return _state.duplicate(true) if can_share(unit) else {}


func _valid_value(value, depth, budget):
	budget[0] -= 1
	if depth > 4 or budget[0] < 0:
		return false
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT:
			return true
		TYPE_STRING:
			if value.length() > STATE_BYTES:
				return false
			budget[0] -= value.to_utf8_buffer().size()
			return budget[0] >= 0
		TYPE_FLOAT:
			return is_finite(value)
		TYPE_ARRAY:
			if value.size() > 64:
				return false
			for item in value:
				if not _valid_value(item, depth + 1, budget):
					return false
			return true
		TYPE_DICTIONARY:
			if value.size() > 64:
				return false
			for key in value:
				if (
					not key is String
					or not _valid_value(key, depth + 1, budget)
					or not _valid_value(value[key], depth + 1, budget)
				):
					return false
			return true
	return false
