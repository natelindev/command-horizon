extends RefCounted

# Four Rivers — river-confluence farmland. Four rivers run from the edge
# midpoints into a confluence pool, splitting the map into farm quadrants that
# meet at a stone bridge near the pool and a ford near the edge of each river.
# Each start holds a farm bluff with one ramp; crop fields are bounded by
# hedgerows that block sight, around farmsteads, barns and a mill on the pool.
# Authored for the start near (0, 0); the others receive 90-degree rotations.
const DEFINITION = {
	"id": "FourRiversMap",
	"name": "Four Rivers",
	"revision": 1,
	"players": 4,
	"size": Vector2(224, 224),
	"symmetry": "rotate",
	"biome": "temperate",
	"ground": "farmland",
	"backdrop": {"rise": 12.0},
	"tiers":
	[
		{
			"name": "Farm bluff",
			"height": 3.0,
			"natural": true,
			"polygon":
			[
				Vector2(0, 0),
				Vector2(58, 0),
				Vector2(62, 16),
				Vector2(50, 36),
				Vector2(36, 50),
				Vector2(16, 62),
				Vector2(0, 58)
			]
		},
	],
	"ramps":
	[
		{
			"name": "Bluff lane",
			"from": Vector2(49.4, 49.4),
			"to": Vector2(37.3, 37.3),
			"width": 10.0,
			"from_height": 0.0,
			"to_height": 3.0
		},
	],
	"water":
	[
		{
			"name": "West river",
			"level": 0.0,
			"line":
			[
				Vector2(-4, 112),
				Vector2(24, 106),
				Vector2(48, 116),
				Vector2(72, 108),
				Vector2(98, 112),
				Vector2(112, 112)
			],
			"width": 8.0
		},
		{
			"name": "Cattle ford",
			"level": 0.0,
			"ford": true,
			"polygon": [Vector2(25, 98), Vector2(35, 98), Vector2(35, 119), Vector2(25, 119)]
		},
	],
	"bridges": [{"level": 0.3, "line": [Vector2(78.4, 100.2), Vector2(81.2, 118.4)], "width": 5.0}],
	"forests":
	[
		{
			"name": "Field hedgerow",
			"flora": "hedges",
			"density": 1.0,
			"line": [Vector2(36, 56), Vector2(70, 54), Vector2(74, 84)],
			"width": 3.0
		},
		{
			"name": "Field hedgerow",
			"flora": "hedges",
			"density": 1.0,
			"line": [Vector2(4, 68), Vector2(22, 66), Vector2(24, 92)],
			"width": 3.0
		},
		{
			"name": "Oak copse",
			"density": 0.6,
			"natural": true,
			"polygon":
			[Vector2(96, 40), Vector2(102, 46), Vector2(100, 60), Vector2(92, 58), Vector2(90, 46)]
		},
		{
			"name": "Riverside willows",
			"flora": "riparian",
			"density": 0.5,
			"natural": true,
			"polygon": [Vector2(52, 102), Vector2(68, 100), Vector2(70, 104), Vector2(54, 107)]
		},
	],
	"sands":
	[
		{
			"name": "Wheat field",
			"polygon": [Vector2(38, 58), Vector2(68, 56), Vector2(72, 82), Vector2(40, 84)]
		},
		{
			"name": "Barley field",
			"polygon": [Vector2(6, 70), Vector2(21, 69), Vector2(22, 92), Vector2(6, 94)]
		},
		{
			"name": "Pasture strip",
			"polygon": [Vector2(64, 4), Vector2(98, 4), Vector2(98, 14), Vector2(64, 14)]
		},
	],
	"roads":
	[
		{
			"name": "Farm lane",
			"width": 4.5,
			"line":
			[
				Vector2(26, 26),
				Vector2(37.3, 37.3),
				Vector2(49.4, 49.4),
				Vector2(76, 46),
				Vector2(86, 72),
				Vector2(78.4, 100.2)
			]
		},
		{
			"name": "Ford lane",
			"width": 3.5,
			"line": [Vector2(49.4, 49.4), Vector2(30, 70), Vector2(30, 98)]
		},
	],
	"landmarks":
	[
		{
			"name": "Farmhouse",
			"asset": "temperate/Farmhouse",
			"position": Vector2(66, 32),
			"heading": 0.0,
			"solid": 4.6,
			"sight_height": 7.5
		},
		{
			"name": "Barn",
			"asset": "temperate/Barn",
			"position": Vector2(84, 40),
			"heading": 90.0,
			"solid": 5.6,
			"sight_height": 9.0
		},
		{
			"name": "Grain bins",
			"asset": "temperate/MetalSilos",
			"position": Vector2(76, 58),
			"heading": 0.0,
			"solid": 4.2,
			"sight_height": 7.5
		},
		{
			"name": "Hay",
			"asset": "temperate/HayBales",
			"position": Vector2(48, 70),
			"heading": 20.0
		},
		{
			"name": "Stone bridge",
			"asset": "temperate/StoneBridge",
			"position": Vector2(79.8, 109.3),
			"heading": 81.3
		},
		{
			"name": "Pool mill",
			"asset": "temperate/WaterMill",
			"position": Vector2(95.0, 92.0),
			"heading": 45.0,
			"solid": 5.0,
			"sight_height": 8.0
		},
		{
			"name": "Paddock fence",
			"asset": "temperate/PicketFence",
			"position": Vector2(60, 26),
			"heading": 0.0
		},
	],
	"bases": [{"start": Vector2(26, 26), "field": Vector2(19.6, 19.6)}],
	"expansions":
	[
		{"name": "Home farm", "site": Vector2(78, 24), "field": Vector2(86.5, 20.5)},
		{"name": "Mill pasture", "site": Vector2(32, 82), "field": Vector2(23.5, 85.5)},
		{
			"name": "Confluence meadow",
			"site": Vector2(82, 80),
			"field": Vector2(89, 86),
			"rich": true
		},
	],
	"sites":
	[
		{
			"kind": "refinery",
			"position": Vector2(54, 92),
			"names":
			[
				"North-West Biofuel Plant",
				"North-East Biofuel Plant",
				"South-East Biofuel Plant",
				"South-West Biofuel Plant"
			]
		},
		{
			"kind": "mercenary",
			"position": Vector2(106, 22),
			"names":
			[
				"North-West Drovers' Camp",
				"North-East Drovers' Camp",
				"South-East Drovers' Camp",
				"South-West Drovers' Camp"
			]
		},
	],
	"shared":
	{
		"water":
		[
			{
				"name": "Confluence pool",
				"level": 0.0,
				"polygon":
				[
					Vector2(127.88, 112.00),
					Vector2(128.14, 115.21),
					Vector2(126.22, 117.89),
					Vector2(124.00, 120.02),
					Vector2(122.32, 122.32),
					Vector2(120.14, 124.18),
					Vector2(117.41, 125.06),
					Vector2(114.82, 126.18),
					Vector2(112.00, 127.88),
					Vector2(108.79, 128.14),
					Vector2(106.11, 126.22),
					Vector2(103.98, 124.00),
					Vector2(101.68, 122.32),
					Vector2(99.82, 120.14),
					Vector2(98.94, 117.41),
					Vector2(97.82, 114.82),
					Vector2(96.12, 112.00),
					Vector2(95.86, 108.79),
					Vector2(97.78, 106.11),
					Vector2(100.00, 103.98),
					Vector2(101.68, 101.68),
					Vector2(103.86, 99.82),
					Vector2(106.59, 98.94),
					Vector2(109.18, 97.82),
					Vector2(112.00, 96.12),
					Vector2(115.21, 95.86),
					Vector2(117.89, 97.78),
					Vector2(120.02, 100.00),
					Vector2(122.32, 101.68),
					Vector2(124.18, 103.86),
					Vector2(125.06, 106.59),
					Vector2(126.18, 109.18)
				]
			}
		],
	},
	"ai":
	{
		"expand_order": ["Home farm", "Mill pasture", "Confluence meadow"],
		# The west river's stone bridge and cattle ford.
		"lanes": [Vector2(79.8, 109.3), Vector2(30, 109)],
	},
}
