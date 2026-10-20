extends SceneTree

var errors = []


func _initialize():
	call_deferred("_run")


func _run():
	var script = load("res://source/match/maps/terrain/WaterFlowField.gd")
	var field = script.new()
	var river = {
		"polygon":
		PackedVector2Array([Vector2(0, 8), Vector2(64, 8), Vector2(64, 24), Vector2(0, 24)]),
		"line": [Vector2(-2, 16), Vector2(66, 16)],
		"level": 0.0
	}
	var ford = {
		"polygon":
		PackedVector2Array([Vector2(8, 6), Vector2(12, 6), Vector2(12, 26), Vector2(8, 26)]),
		"ford": true
	}
	var layout = {
		"size": Vector2(64, 32),
		"players": 1,
		"water": [river, ford],
		"landmarks": [{"position": Vector2(32, 16), "solid": 2.0}]
	}
	field.build(layout)
	_check(field.image.get_width() == 256, "Unbounded flow atlas")
	_check(field.sample(Vector2(10, 4)).a == 0, "Water leaked onto land")
	_check(field.sample(Vector2(10, 7)).a == 0, "Dry ford approach became water")
	_check(field.sample(Vector2(10, 16)).b < .2, "Ford depth missing")
	_check(is_equal_approx(field.level_at(Vector2(10, 16)), -.08), "Ford level not respected")
	_check(field.sample(Vector2(32, 16)).a == 0, "Solid obstacle not masked")
	_check(field.sample(Vector2(29, 18)).g > .1, "Current does not turn around obstacle")
	_check(field.sample(Vector2(29, 14)).g < -.1, "Opposite side of obstacle turns wrong way")
	_check(absf(field.sample(Vector2(20, 8.2)).g) < .01, "Current crosses bank")
	_check(field.sample(Vector2(20, 16)).r > 1.0, "River lost downstream current")
	# All authored fields must be finite and within the solver's speed/depth limits.
	var registry = load("res://source/match/maps/terrain/BattlefieldRegistry.gd")
	var started = Time.get_ticks_msec()
	for name in ["PinebreakValleyMap", "SunkenExchangeMap", "CinderRingMap"]:
		var map_field = script.new()
		map_field.build(registry.layout("res://source/match/maps/battlefields/%s.tscn" % name))
		for y in range(0, 256, 2):
			for x in range(0, 256, 2):
				var value = map_field.image.get_pixel(x, y)
				_check(is_finite(value.r) and is_finite(value.g), "Non-finite velocity")
				_check(
					Vector2(value.r, value.g).length() < 2.501, "Current exceeds advection budget"
				)
				_check(value.b <= 1.201, "Depth exceeds stability bound")
	print("Flow bake: three representative maps in %d ms" % (Time.get_ticks_msec() - started))
	for error in errors:
		push_error(error)
	print("Hybrid water regression: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _check(value, message):
	if not value and message not in errors:
		errors.append(message)
