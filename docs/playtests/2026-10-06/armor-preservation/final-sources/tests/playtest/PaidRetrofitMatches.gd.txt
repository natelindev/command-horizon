extends "res://tests/playtest/ScreenedOpeningMatches.gd"

var retrofit
var retrofit_spent = 0


func _play_case(index):
	retrofit = load("res://tests/playtest/reference/PaidRetrofitPolicy.gd").new()
	retrofit_spent = 0
	await super(index)


func _command():
	retrofit.update(game, human, _retrofit_candidates(), phase != "attack")
	_account_retrofit()
	super()
	if not retrofit.active.is_empty():
		var unit = retrofit.active.unit.get_ref()
		_check(retrofit.protects(unit), "Commander replaced paid installation")
		metrics.retrofit_authority_checks = metrics.get("retrofit_authority_checks", 0) + 1
		if archive_prefix != "":
			_archive_progress("retrofit_installing")
	if (
		archive_prefix != ""
		and retrofit.episodes.any(func(episode): return episode.result == "installed")
	):
		_archive_progress("retrofit_installed")


func _protected_from_command(unit):
	return retrofit.protects(unit)


func _account_retrofit():
	_spent.y += retrofit.spent_e - retrofit_spent
	retrofit_spent = retrofit.spent_e
	metrics.retrofit_episodes = retrofit.episodes
	metrics.retrofit_skipped = retrofit.skipped
	metrics.retrofit_net_e = retrofit_spent


func _measure():
	retrofit.settle(game.simulation_time)
	_account_retrofit()
	super()


func _retrofit_candidates():
	return plan_rules.owned_units(human)
