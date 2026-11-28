extends "res://source/match/units/Structure.gd"

## Helix Harmonic Phase Condenser.
## Continuously siphons Raw into escalating resonance tiers while Power Grid
## remains stable; links with a nearby partner when Harmonic Lattice is unlocked.
const RefiningComponent = preload("res://source/match/units/traits/RefiningComponent.gd")

var refining = null


func _ready():
	await super()
	refining = RefiningComponent.new("helix")
	add_child(refining)
	update_shields()
