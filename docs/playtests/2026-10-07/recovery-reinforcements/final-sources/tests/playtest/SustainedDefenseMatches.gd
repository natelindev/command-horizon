extends "res://tests/playtest/ElectronicsHandoffMatches.gd"

var home_response
var response_enabled = false


func _run():
	response_enabled = "--home-response" in OS.get_cmdline_user_args()
	await super()


func _play_case(index):
	home_response = load("res://tests/playtest/reference/HomeDefensePolicy.gd").new()
	await super(index)


func _respond_to_home_threat(unit, threats):
	if not response_enabled:
		return super(unit, threats)
	var before = home_response.decisions
	var handled = home_response.command(unit, threats, game.simulation_time)
	if home_response.decisions != before:
		metrics.home_response_orders = home_response.decisions
		if not metrics.has("first_home_response"):
			metrics.first_home_response = game.simulation_time
			if archive_prefix != "":
				_archive_progress("home_response")
	return handled


func _sample():
	var row = super()
	row.home_response_enabled = response_enabled
	row.electronics_handoff_enabled = handoff_enabled
	return row
