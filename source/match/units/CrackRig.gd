extends "res://source/match/units/Unit.gd"

## Frontier Mobile Crack-Rig.
## Drives freely while mobile, then deploys anywhere to distill Raw into Refined
## (accelerated near Hot Zones: wrecks, Raw fields, or Catalyst POIs).
const RefiningComponent = preload("res://source/match/units/traits/RefiningComponent.gd")

var refining = null


func _ready():
	await super()
	refining = RefiningComponent.new("frontier")
	add_child(refining)


func _adapt_action(action_node):
	if action_node != null and refining != null and refining.is_immobilized():
		action_node.queue_free()
		return null
	return action_node
