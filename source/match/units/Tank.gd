extends "res://source/match/units/Unit.gd"

const WaitingForTargets = preload("res://source/match/units/actions/WaitingForTargets.gd")


func ability_definitions() -> Array:
	if type != "Tank":
		return []
	return [
		{
			"id": "smoke_screen",
			"name": "Smoke Screen",
			"description": "Deploy a smoke screen in a 6 m radius for 7 seconds.",
			"key": "Q",
			"target_type": "instant",
			"cooldown": 20.0,
			"radius": 6.0,
			"duration": 7.0,
		}
	]


func _ready():
	await super()
	action_changed.connect(_on_action_changed)
	action = WaitingForTargets.new()


func _on_action_changed(new_action):
	if new_action == null:
		action = WaitingForTargets.new()
