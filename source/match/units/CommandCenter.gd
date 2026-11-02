extends "res://source/match/units/Structure.gd"

const ENERGY_CAPACITY = 100.0
const ENERGY_REGENERATION = 0.5
const INITIAL_ENERGY = 50.0
var energy: float = 0.0


func _ready():
	await super()
	energy = INITIAL_ENERGY if player.faction == "helix" else 0.0


func ability_definitions() -> Array:
	return load("res://source/match/economy/MacroEconomy.gd").definitions(player.faction)


func _physics_process(delta):
	super(delta)
	if player != null and player.faction == "helix" and hp != null and hp > 0 and is_constructed():
		energy = minf(ENERGY_CAPACITY, energy + ENERGY_REGENERATION * delta)


func spend_energy(amount: float) -> bool:
	if amount < 0.0 or player.faction != "helix" or energy < amount:
		return false
	energy -= amount
	action_updated.emit()
	return true
