extends "res://source/match/units/Structure.gd"

## Bastion Industrial Smelter & Forward Drop-Off.
## Preserves fractional smelting yield on Raw deliveries and runs upfront
## Risk-the-Batch smelting through its RefiningComponent trait.
const RefiningComponent = preload("res://source/match/units/traits/RefiningComponent.gd")

var smelting_remainder: float = 0.0
var refining = null


func _ready():
	await super()
	refining = RefiningComponent.new("bastion")
	add_child(refining)


func refine_materials(amount: int) -> int:
	if refining != null:
		refining.record_delivery()
	var refined = (
		amount * (1.0 + load("res://source/match/economy/HarvestingProfile.gd").SMELTING_BONUS)
	)
	refined += smelting_remainder
	var whole = floori(refined + 0.000001)
	smelting_remainder = maxf(0.0, refined - whole)
	return whole
