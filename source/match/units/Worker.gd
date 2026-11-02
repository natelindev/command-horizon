extends "res://source/match/units/Unit.gd"

var resource_a = 0:
	set(value):
		resource_a = value
		_refresh_cargo()
var resource_b = 0:
	set(value):
		resource_b = value
		_refresh_cargo()
var resources_max = null
var harvesting_profile = null
var _cargo = null


func _ready():
	await super()
	harvesting_profile = load("res://source/match/economy/HarvestingProfile.gd").new(player.faction)
	resources_max = harvesting_profile.cargo_capacity
	get_node("Movement").speed *= harvesting_profile.travel_multiplier
	if player.faction == "frontier":
		attack_damage = 3.0
		attack_interval = .55
		attack_range = 7.0
		attack_domains = [
			Constants.Match.Navigation.Domain.TERRAIN, Constants.Match.Navigation.Domain.AIR
		]
		add_child(load("res://source/match/units/traits/HarvesterDefense.gd").new())
	_cargo = load("res://source/match/units/traits/WorkerCargo.gd").new(self)
	get_node("Geometry").add_child(_cargo)


func _refresh_cargo():
	if is_instance_valid(_cargo) and _cargo.is_node_ready():
		_cargo.refresh()


func is_full():
	assert(resource_a + resource_b <= resources_max, "worker capacity was exceeded somehow")
	return resource_a + resource_b == resources_max


func is_flux_skimmer() -> bool:
	return player != null and player.faction == "helix"


func _physics_process(delta):
	super(delta)
	if (
		player != null
		and player.faction == "bastion"
		and hp != null
		and hp > 0
		and hp < hp_max
		and _match != null
		and _match.simulation_time - last_enemy_damage_time >= 5.0
	):
		hp = minf(hp_max, hp + 1.5 * delta)
