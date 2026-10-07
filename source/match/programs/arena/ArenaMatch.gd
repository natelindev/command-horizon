extends "res://source/match/Match.gd"


func _setup_players():
	for index in range(2):
		var player = load("res://source/match/players/Player.tscn").instantiate()
		player.faction = settings.players[index].faction
		player.color = Color("6fbccf") if index == 0 else Color("ed936a")
		player.set_meta("skirmish", true)
		# Test fixtures supply hardware/technology; the live match still owns its gates.
		player._basic_programs = true
		_players.add_child(player)


func _setup_player_units():
	pass


func _get_human_player():
	return _players.get_child(0)


func _move_camera_to_initial_position():
	_camera.size_max = 45
	_camera.set_size_safely(20)
	_camera.set_position_safely(Vector3(25, 0, 25))
	_camera.set_physics_process(false)
	_camera.set_process_unhandled_input(false)


func _unhandled_input(_event):
	pass
