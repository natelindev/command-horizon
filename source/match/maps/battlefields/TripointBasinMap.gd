extends RefCounted

# Tripoint Basin — a three-way sandstone canyon basin. Three elevated mesa
# starts look down onto rolling desert dunes, redrock escarpments and a
# central contested oasis spring. Authored for the north sector; 120-degree
# rotations give all three commanders identical terrain, passes and sites.
const DEFINITION = {
	"id": "TripointBasinMap",
	"name": "Tripoint Basin",
	"revision": 1,
	"players": 3,
	"size": Vector2(224, 224),
	"symmetry": "rotate",
	"biome": "desert",
	"ground": "canyon",
	"backdrop": {"rise": 16.0},
	"tiers":
	[
		{
			"name": "Mesa bastion",
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
			"name": "West dune swell",
			"height": 1.6,
			"falloff": 5.5,
			"natural": true,
			"polygon": [Vector2(76, 80), Vector2(86, 78), Vector2(88, 88), Vector2(78, 90)]
		},
		{
			"name": "East dune swell",
			"height": 1.8,
			"falloff": 8.0,
			"natural": true,
			"polygon": [Vector2(138, 72), Vector2(150, 75), Vector2(148, 86), Vector2(136, 84)]
		},
	],
	"ramps":
	[
		{
			"name": "West mesa ramp",
			"from": Vector2(90, 55),
			"to": Vector2(99, 41),
			"width": 10.0,
			"from_height": 0.0,
			"to_height": 3.0
		},
		{
			"name": "East mesa ramp",
			"from": Vector2(134, 55),
			"to": Vector2(125, 41),
			"width": 10.0,
			"from_height": 0.0,
			"to_height": 3.0
		},
	],
	"water":
	[
		{
			"name": "Spring pool",
			"level": 0.0,
			"natural": true,
			"roughness": 0.7,
			"polygon":
			[
				Vector2(149, 44),
				Vector2(156, 42),
				Vector2(160, 47),
				Vector2(158, 53),
				Vector2(151, 54),
				Vector2(147, 49)
			]
		},
	],
	"blockers":
	[
		{
			"name": "Canyon spine",
			"height": 6.0,
			"natural": true,
			"roughness": 1.6,
			"polygon": [Vector2(100, 58), Vector2(124, 58), Vector2(122, 69), Vector2(102, 69)]
		},
	],
	"forests":
	[
		{
			"name": "Juniper ridge",
			"density": 0.55,
			"natural": true,
			"roughness": 1.6,
			"polygon": [Vector2(64, 34), Vector2(76, 36), Vector2(76, 52), Vector2(62, 48)]
		},
		{
			"name": "Oasis cottonwoods",
			"flora": "riparian",
			"density": 0.55,
			"natural": true,
			"polygon": [Vector2(136, 38), Vector2(156, 38), Vector2(158, 58), Vector2(138, 58)]
		},
	],
	"sands":
	[
		{
			"name": "Basin wash",
			"natural": true,
			"roughness": 2.2,
			"polygon": [Vector2(92, 74), Vector2(132, 74), Vector2(128, 92), Vector2(96, 92)]
		},
	],
	"roads":
	[
		{
			"name": "Mesa road",
			"width": 5.0,
			"line":
			[
				Vector2(112, 18),
				Vector2(99, 41),
				Vector2(90, 55),
				Vector2(96, 82),
				Vector2(112, 98)
			]
		},
		{
			"name": "Flank track",
			"width": 4.0,
			"line": [Vector2(112, 18), Vector2(125, 41), Vector2(134, 55), Vector2(132, 84)]
		},
	],
	"landmarks":
	[
		{
			"name": "Stock windmill",
			"asset": "canyon/Windmill",
			"position": Vector2(142, 44),
			"heading": -30.0,
			"solid": 2.2,
			"sight_height": 7.5
		},
		{
			"name": "Ranch ruin",
			"asset": "canyon/RanchRuin",
			"position": Vector2(70, 50),
			"heading": 25.0,
			"solid": 3.4,
			"sight_height": 3.0
		},
	],
	"bases": [{"start": Vector2(112, 18), "field": Vector2(112, 9.2)}],
	"expansions":
	[
		{"name": "West wash", "site": Vector2(84, 62), "field": Vector2(75.5, 60)},
		{"name": "East spring", "site": Vector2(140, 62), "field": Vector2(148.5, 60)},
		{"name": "Canyon heart", "site": Vector2(112, 78), "field": Vector2(112, 70.5), "rich": true},
		{"name": "Rim flat", "site": Vector2(62, 68), "field": Vector2(54, 65)},
	],
	"sites":
	[
		{
			"kind": "refinery",
			"position": Vector2(128, 72),
			"names": ["North Canyon Derrick", "South-East Canyon Derrick", "South-West Canyon Derrick"]
		},
		{
			"kind": "repair",
			"position": Vector2(96, 72),
			"names": ["North Basin Depot", "South-East Basin Depot", "South-West Basin Depot"]
		},
	],
	"shared":
	{
		"tiers":
		[
			{
				"name": "Tripoint crown",
				"height": 2.4,
				"falloff": 7.0,
				"natural": true,
				"polygon":
				[
					Vector2(104, 102),
					Vector2(120, 102),
					Vector2(124, 114),
					Vector2(112, 124),
					Vector2(100, 114)
				]
			}
		],
		"sites":
		[
			{"kind": "mercenary", "position": Vector2(112, 112), "name": "Tripoint Outpost"}
		],
	},
	"ai":
	{
		"expand_order": ["West wash", "East spring", "Canyon heart", "Rim flat"],
		"lanes": [Vector2(112, 112), Vector2(84, 96)],
	},
}
