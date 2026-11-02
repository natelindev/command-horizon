extends "res://source/match/units/Structure.gd"

## Preserve fractional smelting yield across trips (and saves): eight materials
## yield nine immediately and the remaining fifth accumulates toward the next.
var smelting_remainder: float = 0.0


func refine_materials(amount: int) -> int:
	var refined = (
		amount * (1.0 + load("res://source/match/economy/HarvestingProfile.gd").SMELTING_BONUS)
	)
	refined += smelting_remainder
	var whole = floori(refined + 0.000001)
	smelting_remainder = maxf(0.0, refined - whole)
	return whole
