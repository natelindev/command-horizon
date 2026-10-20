extends RefCounted

# Camp-exclusive contracts.
const ROLES = ["MercenaryWarden", "MercenaryRanger", "MercenaryLancer"]
const UNITS = {
	"MercenaryWarden":
	{
		"title": "Iron Warden",
		"base": "AssaultInfantry",
		"cost": [22, 6],
		"seconds": 14.0,
		"description":
		(
			"Camp exclusive. Heavy shield infantry with sustained close-range fire; "
			+ "slow and vulnerable to armor."
		)
	},
	"MercenaryRanger":
	{
		"title": "Dust Ranger",
		"base": "SniperInfantry",
		"cost": [20, 10],
		"seconds": 15.0,
		"description":
		(
			"Camp exclusive. Fast reconnaissance marksman with 18 m vision; "
			+ "light armor and a deliberate firing cadence."
		)
	},
	"MercenaryLancer":
	{
		"title": "Breach Lancer",
		"base": "RocketInfantry",
		"cost": [26, 12],
		"seconds": 18.0,
		"description":
		(
			"Camp exclusive. Long-range heavy rockets against armor and structures; "
			+ "slow reload and weak against infantry."
		)
	},
}
