extends SceneTree

var failures := []


class TestField:
	extends RefCounted
	var calls := 0
	var observed := false

	func is_observed(_side, _unit):
		calls += 1
		return observed


class TestMatch:
	extends Node3D
	var battlefield = TestField.new()
	var observers := []
	var observer_reads := 0
	var visible_players:
		get:
			observer_reads += 1
			return observers

	func get_units():
		return get_tree().get_nodes_in_group("units")

	func get_observers():
		return get_units() + get_tree().get_nodes_in_group("vision_sources")


class TestUnit:
	extends Node3D
	var player


func _initialize():
	_run.call_deferred()


func _run():
	var game = TestMatch.new()
	game.name = "Match"
	root.add_child(game)
	var sides = [Node.new(), Node.new(), Node.new(), Node.new()]
	var handler = load("res://source/match/handlers/UnitVisibilityHandler.gd").new()
	game.add_child(handler)
	handler.set_physics_process(false)
	var bodies = []
	for index in 12:
		var body = TestUnit.new()
		body.player = sides[index % 4]
		game.add_child(body)
		body.add_to_group("units")
		bodies.append(body)
	var target = bodies[3]
	game.observers = sides
	target.hide()
	handler._recalculate_unit_visibility(target)
	_check(
		target.visible and game.battlefield.calls == 0,
		"Shared viewing searched sight before its guaranteed owner"
	)
	game.observer_reads = 0
	handler._physics_process(1.0 / 30.0)
	_check(game.observer_reads == 1, "A presentation slice repeatedly fetched the same observers")
	_check(game.battlefield.calls == 0, "Full viewing issued unnecessary sight searches")
	game.observers = [sides[0]]
	handler._recalculate_unit_visibility(target)
	_check(not target.visible and game.battlefield.calls == 1, "Unobserved enemy became visible")
	game.battlefield.observed = true
	handler._recalculate_unit_visibility(target)
	_check(target.visible and game.battlefield.calls == 2, "Current enemy observation was skipped")
	target.add_to_group("revealed_units")
	game.battlefield.observed = false
	handler._recalculate_unit_visibility(target)
	_check(
		target.visible and game.battlefield.calls == 2,
		"Revealed forces lost their visibility shortcut"
	)
	target.remove_from_group("revealed_units")
	handler.hide()
	handler._recalculate_unit_visibility(target)
	_check(
		target.visible and game.battlefield.calls == 2,
		"Disabled visibility filtering still queried sight"
	)
	game.free()
	for side in sides:
		side.free()
	for message in failures:
		push_error(message)
	print("Visibility refresh owner, fog and slice regression: ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)


func _check(condition, message):
	if not condition:
		failures.append(message)
