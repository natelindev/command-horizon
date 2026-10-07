extends RefCounted

const CASES = [
	{
		"id": "retreat",
		"title": "Retreat & recovery",
		"duration": 12.0,
		"needs": "movement",
		"expected":
		"At 20% HP reach the safe point; stay there at 50%; return to the area after full recovery.",
		"hint": "Try Guard & regroup with retreat 30% / recovery 80%."
	},
	{
		"id": "escort",
		"title": "Escort a moving ally",
		"duration": 9.0,
		"needs": "movement",
		"expected": "Approach the assigned ally, then follow its move and finish within 3.8 m.",
		"hint": "Try Escort. The ally receives a real move order at 3 seconds."
	},
	{
		"id": "hidden",
		"title": "Lost enemy contact",
		"duration": 7.0,
		"needs": "attack",
		"expected":
		"Engage the visible target, then stop requesting attacks after it leaves sight at 3 seconds.",
		"hint":
		"Try Guard & regroup. A stale target request fails even if the engine safely rejects it."
	},
	{
		"id": "assignments",
		"title": "Missing assignment",
		"duration": 9.0,
		"needs": "movement",
		"expected": "Wait for an area without moving; after it is assigned at 3 seconds, reach it.",
		"hint": "Try a move-to-area rule. Waiting is a valid result while the point is absent."
	},
	{
		"id": "manual",
		"title": "Manual override",
		"duration": 8.0,
		"needs": "movement",
		"expected":
		"Run the program; at 2 seconds accept a direct move, reach it and stop all script evaluations.",
		"hint": "Any working program can run this authority check."
	},
	{
		"id": "blocked",
		"title": "Unreachable destination",
		"duration": 13.0,
		"needs": "ground",
		"expected":
		"Try to enter the sealed pen, report Blocked after no progress, then accept a manual move away.",
		"hint":
		"Try a move-to-area rule. The pen is real navigation geometry. Aircraft skip this ground test."
	},
	{
		"id": "repair",
		"title": "Destroyed repair target",
		"duration": 7.0,
		"needs": "repair",
		"expected":
		"Heal the damaged ally, then stop requesting its repair after destruction at 3 seconds.",
		"hint": "Try Repair area on a repair robot."
	},
]


static func available(index, role):
	var needs = CASES[index].needs
	if needs == "ground":
		return role not in ["Drone", "Helicopter"]
	return load("res://source/match/programs/ProgramRecord.gd").meets_requirements([needs], role)
