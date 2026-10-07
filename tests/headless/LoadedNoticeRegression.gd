extends "res://tests/headless/SupplyContestRegression.gd"


func _review_contest():
	_check(paused, "Loaded battle was not paused")
	_check(game.hud._assignment_hint.visible, "Loaded confirmation disappeared")
	_check(
		game.hud._assignment_hint.text == "Battle loaded.",
		"Loaded confirmation makes a transient pause claim"
	)


func _frames(count):
	await super(count)
	if (
		is_instance_valid(game)
		and response != null
		and not paused
		and game.hud._assignment_hint.visible
	):
		_check(
			not "Battle loaded · paused" in game.hud._assignment_hint.text,
			"Live restored combat still claims it is paused"
		)
