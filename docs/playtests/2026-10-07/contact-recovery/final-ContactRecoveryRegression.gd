extends "res://tests/headless/ContactApproachRegression.gd"


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	for repetition in 12:
		await _captured_approach(repetition)
	for frames in [75, 150, 240]:
		detour_frames = frames
		await _detour_archive()
		print("CONTACT DISK PHASE ", frames)
	detour_frames = 150
	await _manual_replacement()
	for faction in ["bastion", "helix", "frontier"]:
		await _building_contacts(faction)
	for message in errors:
		push_error(message)
	print("Contact recovery regression: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)
