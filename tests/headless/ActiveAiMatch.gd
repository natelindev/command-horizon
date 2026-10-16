extends "res://source/match/Skirmish.gd"


# Keep the normal commander's HUD/voice/selection surface while a real AI drives it.
func _create_players_from_settings():
	for index in settings.players.size():
		var config = settings.players[index]
		var scene = (
			"res://source/match/players/human/Human.tscn"
			if index == 0
			else "res://source/match/players/skirmish-ai/SkirmishAI.tscn"
		)
		var side = load(scene).instantiate()
		if index == 0:
			side.set_script(load("res://source/match/players/skirmish-ai/SkirmishAI.gd"))
		side.faction = config.faction
		side.color = config.color
		side.difficulty = config.difficulty
		side.set_meta("skirmish", true)
		_players.add_child(side)


func _get_human_player():
	var players = get_node("Players")
	return players.get_child(0) if players.get_child_count() > 0 else null
