extends "res://tests/headless/MechanicsRegression.gd"


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	harvest = load("res://source/match/units/actions/CollectingResourcesSequentially.gd")
	for faction in ["bastion", "helix", "frontier"]:
		await _open(faction)
		# This shared fixture places the nearer service/HQ across an actual
		# disconnected navigation region and requires the reachable alternative.
		await _service_routes()
		_game.queue_free()
		await _frames(5)
	for message in _errors:
		push_error(message)
	print("HUD recovery reachability: %d failures" % _errors.size())
	await root.get_node("Globals").quit_game(0 if _errors.is_empty() else 1)
