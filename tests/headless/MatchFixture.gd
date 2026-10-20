extends SceneTree

# Shared helpers for headless regressions that build their own skirmish fixture.
const Catalog = preload("res://source/match/BastionCatalog.gd")
var _game
var _human
var _enemy
var _errors = []
var _fixtures = []


func _initialize():
	call_deferred("_run")


func _run():
	push_error("MatchFixture is a base script; run a regression that extends it.")
	quit(1)


func _spawn(role, player, point):
	var unit = load(Catalog.scene_path(role)).instantiate()
	_game._setup_and_spawn_unit(unit, Transform3D(Basis(), point), player, false)
	unit.process_mode = Node.PROCESS_MODE_DISABLED
	_fixtures.append(unit)
	return unit


func _clear():
	for unit in _fixtures:
		if is_instance_valid(unit):
			unit.queue_free()
	_fixtures.clear()
	await _frames(5)


func _frames(count):
	for frame in range(count):
		await process_frame


func _check(condition, message):
	if not condition and message not in _errors:
		_errors.append(message)
