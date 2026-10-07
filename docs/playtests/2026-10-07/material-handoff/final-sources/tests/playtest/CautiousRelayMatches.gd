extends "res://tests/playtest/RelayContestMatches.gd"


func _new_expedition():
	return load("res://tests/playtest/reference/CautiousRelayPolicy.gd").new()


func _command():
	super()
	metrics.relay_withdrawals = expedition.withdrawals
