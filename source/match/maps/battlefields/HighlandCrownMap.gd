extends RefCounted

# Highland Crown — three forested logging ridges converge on a central
# river-ringed island watchtower. Rolling wooded knolls, log bridges and
# gravel fords shape three-way skirmishes. Authored for the north sector;
# 120-degree rotations keep every start symmetric.
const DEFINITION = {
	"id": "HighlandCrownMap",
	"name": "Highland Crown",
	"revision": 1,
	"players": 3,
	"size": Vector2(224, 224),
	"symmetry": "rotate",
	"biome": "temperate",
	"ground": "forest",
	"backdrop": {"rise": 20.0},
	"tiers":
	[
		{
			"name": "Logging bluff",
			"height": 3.0,
			"natural": true,
			"polygon":
			[
				Vector2(80, 2),
				Vector2(144, 2),
				Vector2(146, 36),
				Vector2(132, 48),
				Vector2(92, 48),
				Vector2(78, 36)
			]
		},
		{
			"name": "West timber hill",
			"height": 1.8,
			"falloff": 4.5,
			"natural": true,
			"polygon": [Vector2(68, 70), Vector2(80, 70), Vector2(82, 80), Vector2(68, 82)]
		},
		{
			"name": "Flank fir hill",
			"height": 1.8,
			"falloff": 5.0,
			"natural": true,
			"polygon": [Vector2(146, 36), Vector2(160, 38), Vector2(158, 50), Vector2(144, 48)]
		},
	],
	"ramps":
	[
		{
			"name": "Bluff ramp",
			"from": Vector2(112, 56),
			"to": Vector2(112, 40),
			"width": 12.0,
			"from_height": 0.0,
			"to_height": 3.0
		},
	],
	"water":
	[
		{
			"name": "Highland stream",
			"level": 0.0,
			"line": [Vector2(106, 94), Vector2(128, 90), Vector2(146, 82), Vector2(162, 70)],
			"width": 8.0
		},
		{
			"name": "Gravel ford",
			"level": 0.0,
			"ford": true,
			"polygon": [Vector2(140, 72), Vector2(152, 72), Vector2(152, 86), Vector2(140, 86)]
		},
	],
	"bridges": [{"level": 0.3, "line": [Vector2(112, 80), Vector2(112, 96)], "width": 7.0}],
	"forests":
	[
		{
			"name": "West pine stand",
			"density": 0.65,
			"natural": true,
			"roughness": 1.8,
			"polygon": [Vector2(66, 68), Vector2(86, 68), Vector2(88, 86), Vector2(68, 86)]
		},
		{
			"name": "Flank firs",
			"density": 0.6,
			"natural": true,
			"roughness": 1.8,
			"polygon": [Vector2(144, 34), Vector2(160, 36), Vector2(160, 52), Vector2(142, 50)]
		},
		{
			"name": "Stream willows",
			"flora": "riparian",
			"density": 0.5,
			"natural": true,
			"polygon": [Vector2(118, 76), Vector2(132, 74), Vector2(134, 83), Vector2(120, 85)]
		},
	],
	"sands":
	[
		{
			"name": "Logging gravel",
			"natural": true,
			"roughness": 1.8,
			"polygon": [Vector2(98, 56), Vector2(126, 56), Vector2(124, 72), Vector2(100, 72)]
		},
	],
	"roads":
	[
		{
			"name": "Crown road",
			"width": 5.0,
			"line":
			[
				Vector2(112, 20),
				Vector2(112, 56),
				Vector2(112, 80),
				Vector2(112, 96),
				Vector2(112, 112)
			]
		},
		{
			"name": "Mill track",
			"width": 3.8,
			"line": [Vector2(112, 56), Vector2(84, 60), Vector2(64, 68)]
		},
	],
	"landmarks":
	[
		{
			"name": "Valley sawmill",
			"asset": "temperate/Sawmill",
			"position": Vector2(130, 58),
			"heading": -20.0,
			"solid": 5.5,
			"sight_height": 6.0
		},
		{
			"name": "River mill",
			"asset": "temperate/WaterMill",
			"position": Vector2(126, 94),
			"heading": 40.0,
			"solid": 4.8,
			"sight_height": 6.0
		},
	],
	"bases": [{"start": Vector2(112, 20), "field": Vector2(112, 11.2)}],
	"expansions":
	[
		{"name": "West mill", "site": Vector2(84, 58), "field": Vector2(75.5, 55)},
		{"name": "East clearing", "site": Vector2(140, 58), "field": Vector2(148.5, 55)},
		{"name": "Bridgehead", "site": Vector2(98, 76), "field": Vector2(92, 69), "rich": true},
		{"name": "Outer glen", "site": Vector2(62, 68), "field": Vector2(54, 65)},
	],
	"sites":
	[
		{
			"kind": "refinery",
			"position": Vector2(96, 90),
			"names": ["North Timber Derrick", "South-East Timber Derrick", "South-West Timber Derrick"]
		},
		{
			"kind": "mercenary",
			"position": Vector2(128, 70),
			"names": ["North Ranger Post", "South-East Ranger Post", "South-West Ranger Post"]
		},
	],
	"shared":
	{
		"tiers":
		[
			{
				"name": "Crown island",
				"height": 2.0,
				"falloff": 6.0,
				"natural": true,
				"polygon":
				[
					Vector2(104, 104),
					Vector2(120, 104),
					Vector2(122, 116),
					Vector2(112, 122),
					Vector2(102, 116)
				]
			}
		],
		"relays": [{"name": "Crown Relay", "position": Vector2(112, 112)}],
	},
	"ai":
	{
		"expand_order": ["West mill", "East clearing", "Bridgehead", "Outer glen"],
		"lanes": [Vector2(112, 112), Vector2(146, 79)],
	},
}
