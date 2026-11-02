extends "res://source/match/units/Tank.gd"

const DEPLOY_SECONDS = 2.0
var deployment_left = DEPLOY_SECONDS
var deployment_position = Vector3.ZERO
var prism_lock_target = null
var prism_lock_seconds: float = 0.0


func ability_definitions() -> Array:
	if player.faction != "bastion":
		return []
	return [
		{
			"id": "siege_anchor",
			"name": "Siege Anchor",
			"description": "Anchor in place for 35% more attack range and 30% more damage.",
			"key": "E",
			"target_type": "toggle",
			"cooldown": 4.0,
		}
	]


func _ready():
	await super()
	deployment_position = global_position
	if weapon_charge_progress < 0:
		get_node("WeaponPreparationVisual").refresh()


func _physics_process(delta):
	super(delta)
	if player.faction == "helix":
		if is_instance_valid(aim_target) and aim_target == prism_lock_target:
			prism_lock_seconds = minf(4.0, prism_lock_seconds + delta)
		else:
			prism_lock_target = aim_target
			prism_lock_seconds = 0.0
	if player.faction != "bastion":
		return
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
	if player.faction != "bastion":
		return 0.0
	var movement = get_node("Movement")
	return DEPLOY_SECONDS if movement._has_destination else deployment_left


func deployment_status():
	return "Deploying · %.1f s" % deployment_left if deployment_left > 0 else "Deployed · 16 m"
