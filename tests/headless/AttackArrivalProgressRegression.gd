extends "res://tests/headless/AttackCrowdedArrivalRegression.gd"

const LATE_CASES = [
	{
		"path": "res://docs/playtests/2026-10-06/attack-arrival-audit/late-89134-0.json",
		"unit": "unit-16"
	},
	{
		"path": "res://docs/playtests/2026-10-06/attack-arrival-audit/late-89134-5.json",
		"unit": "unit-16"
	},
	{
		"path": "res://docs/playtests/2026-10-06/attack-arrival-audit/late-89135-5.json",
		"unit": "unit-16"
	},
	{
		"path": "res://docs/playtests/2026-10-06/attack-arrival-audit/late-89136-0.json",
		"unit": "unit-16"
	},
	{
		"path": "res://docs/playtests/2026-10-06/attack-arrival-audit/late-89136-3.json",
		"unit": "unit-16"
	},
	{
		"path": "res://docs/playtests/2026-10-06/attack-arrival-audit/late-89136-6.json",
		"unit": "unit-16"
	},
	{
		"path": "res://docs/playtests/2026-10-06/attack-arrival-audit/late-89136-8.json",
		"unit": "unit-16"
	}
]
var current_case = null


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	await _directional_observation()
	for entry in LATE_CASES:
		current_case = entry
		for repetition in 2:
			await _captured_attack(repetition)
	for error in errors:
		push_error(error)
	print("Attack arrival progress: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _open_attack():
	if current_case == null:
		return await super._open_attack()
	var restore = Restore.new()
	var result = await restore.restore(self, FileStore.new().read_file(current_case.path))
	_check(result.ok, "Late attack archive failed to restore")
	if not result.ok:
		return null
	game = result.game
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	print("LATE CASE ", current_case.path)
	return restore.entities[current_case.unit]


func _directional_observation():
	var unit = await _open_attack()
	if unit == null:
		return
	# Synchronize the live navigation path before testing observation geometry.
	paused = false
	await _frames(2)
	paused = true
	var action = unit.action
	var movement = unit.get_node("Movement")
	var helper = load("res://source/match/units/actions/Moving.gd")
	var endpoint = movement.get_current_navigation_path()[-1] * Vector3(1, 0, 1)
	var point = unit.global_position_yless
	var offset = point - endpoint
	_check(movement.has_occupied_endpoint(), "Observation requires an occupied endpoint")
	action._arrival_progress = endpoint + offset.rotated(Vector3.UP, PI / 2)
	_check(point.distance_to(action._arrival_progress) > .2, "Sideways fixture did not travel")
	action._arrival_elapsed = 1.99
	_check(helper.occupied_arrival(action, movement, unit, .02), "Sideways travel reset arrival")
	action._arrival_progress = point + offset.normalized() * .3
	action._arrival_elapsed = 1.99
	_check(
		not helper.occupied_arrival(action, movement, unit, .02), "Approaching endpoint ended early"
	)
	action._arrival_progress = point - offset.normalized() * .3
	action._arrival_elapsed = 1.99
	_check(helper.occupied_arrival(action, movement, unit, .02), "Retreat reset occupied arrival")
	game.queue_free()
	await _frames(5)
