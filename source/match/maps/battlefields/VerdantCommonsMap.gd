extends RefCounted

# Verdant Commons — an English village on a broad common. A church stands on
# the green at the centre, ringed by cottages and four rich fields; groves
# close the diagonal approaches so armies reach the green by lanes at the four
# compass points. Each start holds a chalk down with one ramp; walled and
# hedged fields, a barn and a water meadow fill its quadrant. Authored for the
# start near (0, 0); the others receive 90-degree rotations.
const DEFINITION = {
	"id": "VerdantCommonsMap",
	"name": "Verdant Commons",
	"revision": 1,
	"players": 4,
	"size": Vector2(224, 224),
	"symmetry": "rotate",
	"biome": "temperate",
	"ground": "village",
	"backdrop": {"rise": 10.0},
	"tiers":
	[
		{
			"name": "Chalk down",
			"height": 3.0,
			"natural": true,
			"polygon":
			[
				Vector2(0, 0),
				Vector2(64, 0),
				Vector2(66, 18),
				Vector2(54, 40),
				Vector2(40, 54),
				Vector2(18, 66),
				Vector2(0, 62)
			]
		},
	],
	"ramps":
	[
		{
			"name": "Down lane",
			"from": Vector2(53.4, 53.4),
			"to": Vector2(40.6, 40.6),
			"width": 10.0,
			"from_height": 0.0,
			"to_height": 3.0
		},
	],
	"water":
	[
		{
			"name": "Meadow pond",
			"level": 0.0,
			"natural": true,
			"roughness": 0.7,
			"polygon":
			[
				Vector2(8, 98),
				Vector2(14, 95),
				Vector2(20, 98),
				Vector2(20, 105),
				Vector2(13, 108),
				Vector2(7, 104)
			]
		},
	],
	"forests":
	[
		{
			"name": "Common grove",
			"density": 0.6,
			"natural": true,
			"roughness": 1.8,
			"polygon":
			[
				Vector2(69.92, 99.14),
				Vector2(61.33, 100.30),
				Vector2(55.62, 91.48),
				Vector2(62.65, 76.15),
				Vector2(75.68, 65.51),
				Vector2(90.02, 64.87),
				Vector2(90.67, 73.52),
				Vector2(76.76, 82.43)
			]
		},
		{
			"name": "Lane hedgerow",
			"flora": "hedges",
			"density": 1.0,
			"line": [Vector2(60, 60), Vector2(66, 94)],
			"width": 3.0
		},
		{
			"name": "Lane hedgerow",
			"flora": "hedges",
			"density": 1.0,
			"line": [Vector2(60, 60), Vector2(94, 66)],
			"width": 3.0
		},
		{
			"name": "Pond willows",
			"flora": "riparian",
			"density": 0.5,
			"natural": true,
			"polygon": [Vector2(2, 108), Vector2(14, 110), Vector2(16, 118), Vector2(4, 120)]
		},
	],
	"sands":
	[
		{
			"name": "Strip field",
			"polygon": [Vector2(70, 8), Vector2(92, 8), Vector2(92, 22), Vector2(70, 22)]
		},
		{
			"name": "Strip field",
			"polygon": [Vector2(8, 72), Vector2(22, 72), Vector2(22, 92), Vector2(8, 92)]
		},
		{
			"name": "Allotments",
			"polygon": [Vector2(68, 66), Vector2(84, 66), Vector2(84, 82), Vector2(68, 82)]
		},
	],
	"roads":
	[
		{
			"name": "Village road",
			"width": 4.5,
			"line":
			[
				Vector2(26, 26),
				Vector2(40.6, 40.6),
				Vector2(53.4, 53.4),
				Vector2(62.50, 62.50),
				Vector2(78.00, 112.00),
				Vector2(112, 112)
			]
		},
		{
			"name": "Back lane",
			"width": 3.5,
			"line": [Vector2(53.4, 53.4), Vector2(96, 44), Vector2(112, 50)]
		},
	],
	"landmarks":
	[
		{
			"name": "Cottage",
			"asset": "temperate/CottageA",
			"position": Vector2(79.67, 90.19),
			"heading": -56.0,
			"solid": 3.6,
			"sight_height": 3.2
		},
		{
			"name": "Cottage",
			"asset": "temperate/CottageB",
			"position": Vector2(86.30, 85.38),
			"heading": -44.0,
			"solid": 3.6,
			"sight_height": 3.2
		},
		{
			"name": "Cottage",
			"asset": "temperate/CottageB",
			"position": Vector2(90.80, 78.08),
			"heading": -32.0,
			"solid": 3.6,
			"sight_height": 3.2
		},
		{
			"name": "Field wall",
			"asset": "temperate/StoneWall",
			"position": Vector2(70.00, 70.00),
			"heading": 45.0,
			"footprints":
			[[Vector2(-3, -0.35), Vector2(3, -0.35), Vector2(3, 0.35), Vector2(-3, 0.35)]],
			"sight_height": 1.2
		},
		{
			"name": "Field wall",
			"asset": "temperate/StoneWall",
			"position": Vector2(58.00, 82.00),
			"heading": 45.0,
			"footprints":
			[[Vector2(-3, -0.35), Vector2(3, -0.35), Vector2(3, 0.35), Vector2(-3, 0.35)]],
			"sight_height": 1.2
		},
		{
			"name": "Field wall",
			"asset": "temperate/StoneWall",
			"position": Vector2(82.00, 58.00),
			"heading": 45.0,
			"footprints":
			[[Vector2(-3, -0.35), Vector2(3, -0.35), Vector2(3, 0.35), Vector2(-3, 0.35)]],
			"sight_height": 1.2
		},
		{
			"name": "Paddock fence",
			"asset": "temperate/PicketFence",
			"position": Vector2(90, 6),
			"heading": 10.0
		},
		{
			"name": "Hay",
			"asset": "temperate/HayBales",
			"position": Vector2(46, 88),
			"heading": -15.0
		},
		{
			"name": "Village barn",
			"asset": "temperate/Barn",
			"position": Vector2(98, 30),
			"heading": 0.0,
			"solid": 5.6,
			"sight_height": 4.2
		},
	],
	"bases": [{"start": Vector2(26, 26), "field": Vector2(19.6, 19.6)}],
	"expansions":
	[
		{"name": "Home farm", "site": Vector2(74, 30), "field": Vector2(82.5, 26.5)},
		{"name": "Water meadow", "site": Vector2(26, 84), "field": Vector2(17.5, 87.5)},
		{
			"name": "Common pasture",
			"site": Vector2(88.44, 101.01),
			"field": Vector2(93.78, 93.46),
			"rich": true
		},
	],
	"sites":
	[
		{
			"kind": "refinery",
			"position": Vector2(46, 104),
			"names":
			[
				"North-West Fuel Depot",
				"North-East Fuel Depot",
				"South-East Fuel Depot",
				"South-West Fuel Depot"
			]
		},
		{
			"kind": "mercenary",
			"position": Vector2(104, 44),
			"names":
			[
				"North-West Militia Hall",
				"North-East Militia Hall",
				"South-East Militia Hall",
				"South-West Militia Hall"
			]
		},
	],
	"shared":
	{
		"landmarks":
		[
			{
				"name": "Parish church",
				"asset": "temperate/VillageChurch",
				"position": Vector2(112, 112),
				"heading": 0.0,
				"solid": 8.0,
				"sight_height": 4.5
			},
		],
	},
	"ai":
	{
		"expand_order": ["Home farm", "Water meadow", "Common pasture"],
		# The lanes onto the green west and north of this start.
		"lanes": [Vector2(62.00, 112.00), Vector2(112.00, 62.00)],
	},
}
