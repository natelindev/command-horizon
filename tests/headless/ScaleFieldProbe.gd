# Test-only timing wrapper. Inclusive timings overlap for nested field queries.
extends "res://source/match/combat/Battlefield.gd"

var timings = {}


func _record_timing(label, started):
	if not timings.has(label):
		timings[label] = {"calls": 0, "microseconds": 0}
	timings[label].calls += 1
	timings[label].microseconds += Time.get_ticks_usec() - started


func is_observed(player, target):
	var started = Time.get_ticks_usec()
	var result = super(player, target)
	_record_timing("is_observed", started)
	return result


func can_observe_point(observer, point: Vector3, ignored_target = null) -> bool:
	var started = Time.get_ticks_usec()
	var result = super(observer, point, ignored_target)
	_record_timing("can_observe_point", started)
	return result


func line_clear(origin, end, ignored_source = null, ignored_target = null):
	var started = Time.get_ticks_usec()
	var result = super(origin, end, ignored_source, ignored_target)
	_record_timing("line_clear", started)
	return result


func nearby_units(point: Vector3, radius: float, player_filter = null, excluded_player = null):
	var started = Time.get_ticks_usec()
	var result = super(point, radius, player_filter, excluded_player)
	_record_timing("nearby_units", started)
	return result
