extends "res://tests/headless/MapResourceBalanceRegression.gd"


class NavigationErrorLog:
	extends Logger

	var messages = []
	var mutex = Mutex.new()

	func _log_error(_function, file, _line, code, rationale, _notify, _type, _backtraces):
		if "navigation_3d" not in file:
			return
		mutex.lock()
		messages.append(file + ": " + code + " " + rationale)
		mutex.unlock()


func _run():
	constants = root.get_node("Constants")
	root.get_node("SaveManager").autosaves_enabled = false
	var logger = NavigationErrorLog.new()
	OS.add_logger(logger)
	# The initial Glacier bake has distinct ford vertices less than 3 cm apart.
	# Server-created maps must inherit the project's finer merge raster so those
	# edges remain distinct before the first obstacle rebake is published.
	await _create("res://source/match/maps/battlefields/GlacierNarrowsMap.tscn")
	# Compare the effective setting: the server clamps small configured values.
	var configured_scale = NavigationServer3D.map_get_merge_rasterizer_cell_scale(
		game.get_world_3d().navigation_map
	)
	for domain in [game.navigation.terrain, game.navigation.air]:
		var actual_scale = NavigationServer3D.map_get_merge_rasterizer_cell_scale(
			domain.navigation_map_rid
		)
		_check(
			is_equal_approx(actual_scale, configured_scale),
			"%s map ignores configured merge raster scale: %s" % [domain.name, actual_scale]
		)
		_check(
			domain._navigation_region.navigation_mesh.get_polygon_count() > 0,
			"%s map has no navigation polygons" % domain.name
		)
	game.queue_free()
	await _frames(5)
	OS.remove_logger(logger)
	for message in logger.messages:
		_check(false, message)
	for message in _errors:
		push_error(message)
	print("Owned navigation maps: %d failures" % _errors.size())
	quit(0 if _errors.is_empty() else 1)
