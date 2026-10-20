extends "res://tests/headless/ContactApproachRegression.gd"


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	for repetition in 12:
		await _captured_approach(repetition)
	# Harvesters pass through the settled row now. Observe each actual phase
	# instead of assuming the old multi-second detour is still in progress.
	for phase in ["approach", "loading", "waiting"]:
		contact_phase = phase
		await _detour_archive()
		await _manual_replacement()
	for faction in ["bastion", "helix", "frontier"]:
		await _building_contacts(faction)
	for message in errors:
		push_error(message)
	print("Contact recovery regression: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)
