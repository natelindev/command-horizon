extends "res://source/match/Skirmish.gd"

# Every seat is a commander here: a free-for-all runs until one commander
# remains rather than ending with the first seat, and elimination times are
# recorded for pacing reports.
var eliminated_at = {}


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


func _check_outcome(delta):
	var survivors = []
	for player in _defeat_timers:
		if _defeat_timers[player] <= 0:
			continue
		var units = player.get_children().filter(
			func(unit): return "type" in unit and not unit.is_queued_for_deletion()
		)
		if player.has_completed_structure("CommandCenter"):
			_defeat_timers[player] = 60.0
		else:
			_defeat_timers[player] = maxf(0, _defeat_timers[player] - delta)
		if units.is_empty() or _defeat_timers[player] <= 0:
			eliminated_at[player.get_index()] = simulation_time
			_eliminate(player, units)
		else:
			survivors.append(player)
	if survivors.size() <= 1:
		finished = true
		result = (
			"Draw"
			if survivors.is_empty()
			else ("Victory" if _get_human_player() in survivors else "Defeat")
		)
