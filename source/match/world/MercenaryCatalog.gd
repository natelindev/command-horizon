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
			"Camp exclusive. Heavy ballistic shield breacher with a close-range combat shotgun. "
			+ "Activate Shield Wall for 40% damage resistance and suppression immunity."
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
			"Camp exclusive. Reconnaissance marksman with 18 m vision and heavy sniper rifle. "
			+ "Launch Spotter Flare to illuminate fog and mark targets "
			+ "for 20% increased damage."
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
			"Camp exclusive. Long-range heavy breach rockets against armor and structures. "
			+ "Launch Disruptor Rocket to damage, drain shields, and slow hostile vehicles."
		)
	},
}
