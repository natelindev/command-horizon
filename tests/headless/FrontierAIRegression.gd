extends "res://tests/headless/Skirmish.gd"


func _run():
	factions = load("res://source/match/FactionCatalog.gd")
	constants = root.get_node("Constants")
	for opponent in factions.IDS:
		await _test_ai(opponent)
	print("Desert opponent economy: %d failures" % _errors.size())
	quit(0 if _errors.is_empty() else 1)


func _settings(faction, opponent, advanced = true):
	var settings = super(faction, opponent, advanced)
	settings.map_path = "res://source/match/maps/DesertFrontier.tscn"
	return settings
