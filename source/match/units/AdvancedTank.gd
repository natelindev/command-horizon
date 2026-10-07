extends "res://source/match/units/Tank.gd"

const DEPLOY_SECONDS = 1.5
var deployment_left = DEPLOY_SECONDS
var deployment_position = Vector3.ZERO


func _ready():
	await super()
	deployment_position = global_position
	if weapon_charge_progress < 0:
		get_node("WeaponPreparationVisual").refresh()
	if player.faction != "helix":
		set_physics_process(false)


func _physics_process(delta):
	var movement = get_node("Movement")
	if (
		movement._has_destination
		or global_position.distance_squared_to(deployment_position) > 0.0004
	):
		deployment_left = DEPLOY_SECONDS
	else:
		deployment_left = maxf(0, deployment_left - delta)
	deployment_position = global_position
	if weapon_charge_progress < 0:
		get_node("WeaponPreparationVisual").refresh()


func weapon_delay():
	return deployment_left if player.faction == "helix" else 0.0


func deployment_status():
	return "Deploying · %.1f s" % deployment_left if deployment_left > 0 else "Deployed · 10 m"
