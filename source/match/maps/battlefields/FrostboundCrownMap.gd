extends RefCounted

# Frostbound Crown — a polar plateau research station. Each start holds an
# ice shelf in a corner with its depot flat below it, closed by a nunatak
# spine and a crevasse line crossed on two ice bridges. Crevasse fields
# break up the open ice between the corners; at the centre a raised ice crown
# carries the radar station on its summit, overlooking the whole plateau and
# reached by a ramp from each corner. Authored for the start near (0, 0); the
# others receive 90-degree rotations.
const DEFINITION = {
	"id": "FrostboundCrownMap",
	"name": "Frostbound Crown",
	"revision": 1,
	"players": 4,
	"size": Vector2(224, 224),
	"symmetry": "rotate",
	"biome": "alpine",
	"ground": "polar",
	"texture_preset": "polar",
	"backdrop": {"rise": 9.0},
	"tiers":
	[
		{
			"name": "Station shelf",
			"height": 3.0,
			"rock": "ice",
			"natural": true,
			"roughness": 1.2,
			"polygon":
			[
				Vector2(0, 0),
				Vector2(60, 0),
				Vector2(60, 34),
				Vector2(46, 48),
				Vector2(28, 58),
				Vector2(0, 60)
			]
		},
		{
			"name": "Depot crevasse",
			"height": -3.0,
			"walkable": false,
			"rock": "ice",
			"natural": true,
			"roughness": 1.0,
			"line": [Vector2(70, 44), Vector2(78, 41), Vector2(85, 41)],
			"width": 5.0
		},
		{
			"name": "Depot crevasse",
			"height": -3.0,
			"walkable": false,
			"rock": "ice",
			"natural": true,
			"roughness": 1.0,
			"line": [Vector2(97, 40), Vector2(101, 35), Vector2(103, 29)],
			"width": 5.0
		},
		{
			"name": "Plateau crevasse",
			"height": -3.0,
			"walkable": false,
			"rock": "ice",
			"natural": true,
			"roughness": 1.0,
			"line": [Vector2(36, 72), Vector2(44, 76), Vector2(50, 84)],
			"width": 4.5
		},
		{
			"name": "Plateau crevasse",
			"height": -3.0,
			"walkable": false,
			"rock": "ice",
			"natural": true,
			"roughness": 1.0,
			"line": [Vector2(70, 100), Vector2(66, 108)],
			"width": 4.0
		},
	],
	"ramps":
	[
		{
			"name": "Shelf road",
			"from": Vector2(68, 18),
			"to": Vector2(52, 18),
			"width": 10.0,
			"from_height": 0.0,
			"to_height": 3.0
		},
		{
			"name": "Crown ramp",
			"from": Vector2(83, 83),
			"to": Vector2(94.3, 94.3),
			"width": 10.0,
			"from_height": 0.0,
			"to_height": 3.0
		},
		{
			"name": "Summit ramp",
			"from": Vector2(97.4, 97.4),
			"to": Vector2(106.3, 106.3),
			"width": 7.0,
			"from_height": 3.0,
			"to_height": 6.0
		},
	],
	"blockers":
	[
		{
			"name": "Nunatak",
			"height": 7.0,
			"natural": true,
			"roughness": 1.2,
			"polygon":
			[
				Vector2(100, 0),
				Vector2(110, 0),
				Vector2(111, 12),
				Vector2(108, 24),
				Vector2(104, 29),
				Vector2(99, 22),
				Vector2(98, 10)
			]
		},
	],
	"sands":
	[
		{
			"name": "Blue ice",
			"natural": true,
			"roughness": 2.0,
			"polygon": [Vector2(18, 64), Vector2(38, 62), Vector2(34, 70), Vector2(20, 74)]
		},
		{
			"name": "Blue ice",
			"natural": true,
			"roughness": 2.0,
			"polygon": [Vector2(78, 50), Vector2(96, 48), Vector2(98, 56), Vector2(82, 60)]
		},
	],
	"roads":
	[
		{
			"name": "Station track",
			"width": 5.0,
			"line":
			[
				Vector2(28, 28),
				Vector2(42, 20),
				Vector2(52, 18),
				Vector2(68, 18),
				Vector2(84, 22),
				Vector2(91, 40),
				Vector2(100, 62)
			]
		},
		{
			"name": "Crown track",
			"width": 4.5,
			"line":
			[
				Vector2(68, 18),
				Vector2(63, 40),
				Vector2(64, 66),
				Vector2(83, 83),
				Vector2(94.3, 94.3),
				Vector2(97.4, 97.4),
				Vector2(106.3, 106.3)
			]
		},
		{
			"name": "Sledge track",
			"width": 3.5,
			"line": [Vector2(63, 40), Vector2(46, 60), Vector2(34, 80), Vector2(30, 90)]
		},
	],
	"landmarks":
	[
		{
			"name": "Fuel depot",
			"asset": "cold/FuelTanks",
			"position": Vector2(74, 6),
			"heading": 0.0,
			"solid": 3.4,
			"sight_height": 2.6
		},
		{
			"name": "Supply cache",
			"asset": "cold/SupplyCrates",
			"position": Vector2(76, 30),
			"heading": 20.0,
			"solid": 2.2,
			"sight_height": 2.0
		},
		{
			"name": "Old station",
			"asset": "cold/ResearchStation",
			"position": Vector2(14, 78),
			"heading": 90.0,
			"solid": 6.0,
			"sight_height": 8.0
		},
		{
			"name": "Field shelter",
			"asset": "cold/Weatherhaven",
			"position": Vector2(44, 90),
			"heading": 30.0,
			"solid": 2.6,
			"sight_height": 2.2
		},
		{
			"name": "Field shelter",
			"asset": "cold/Weatherhaven",
			"position": Vector2(88, 66),
			"heading": -20.0,
			"solid": 2.6,
			"sight_height": 2.2
		},
		{
			"name": "Relay mast",
			"asset": "cold/AntennaMast",
			"position": Vector2(54, 72),
			"solid": 1.2,
			"sight_height": 18.0
		},
		{
			"name": "Snowcat",
			"asset": "cold/Snowcat",
			"position": Vector2(104, 46),
			"heading": 60.0,
			"solid": 2.2,
			"sight_height": 3.0
		},
	],
	"bases": [{"start": Vector2(28, 28), "field": Vector2(21.5, 21.5)}],
	"expansions":
	[
		{"name": "Depot flat", "site": Vector2(84, 22), "field": Vector2(90, 14)},
		{"name": "Sledge depot", "site": Vector2(30, 90), "field": Vector2(21, 96)},
		{"name": "Crown foot", "site": Vector2(66, 80), "field": Vector2(58, 88), "rich": true},
		{"name": "Radar road", "site": Vector2(100, 62), "field": Vector2(108, 68)},
		{
			"name": "Crown terrace",
			"site": Vector2(90, 104),
			"field": Vector2(85, 114),
			"rich": true
		},
	],
	"sites":
	[
		{
			"kind": "refinery",
			"position": Vector2(48, 108),
			"names":
			[
				"Ross Shelf Refinery",
				"Weddell Shelf Refinery",
				"Amery Shelf Refinery",
				"Ronne Shelf Refinery"
			]
		},
		{
			"kind": "repair",
			"position": Vector2(84, 56),
			"names":
			[
				"Ross Field Workshop",
				"Weddell Field Workshop",
				"Amery Field Workshop",
				"Ronne Field Workshop"
			]
		},
	],
	"shared":
	{
		"tiers":
		[
			{
				"name": "Ice crown",
				"height": 3.0,
				"rock": "ice",
				"polygon":
				[
					Vector2(147.00, 112.00),
					Vector2(147.00, 116.61),
					Vector2(145.13, 120.88),
					Vector2(143.41, 125.01),
					Vector2(141.19, 128.85),
					Vector2(137.94, 131.91),
					Vector2(135.33, 135.33),
					Vector2(133.49, 140.00),
					Vector2(130.15, 143.44),
					Vector2(125.01, 143.41),
					Vector2(120.20, 142.62),
					Vector2(116.27, 144.42),
					Vector2(112.00, 147.00),
					Vector2(107.39, 147.00),
					Vector2(103.12, 145.13),
					Vector2(98.99, 143.41),
					Vector2(95.15, 141.19),
					Vector2(92.09, 137.94),
					Vector2(88.67, 135.33),
					Vector2(84.00, 133.49),
					Vector2(80.56, 130.15),
					Vector2(80.59, 125.01),
					Vector2(81.38, 120.20),
					Vector2(79.58, 116.27),
					Vector2(77.00, 112.00),
					Vector2(77.00, 107.39),
					Vector2(78.87, 103.12),
					Vector2(80.59, 98.99),
					Vector2(82.81, 95.15),
					Vector2(86.06, 92.09),
					Vector2(88.67, 88.67),
					Vector2(90.51, 84.00),
					Vector2(93.85, 80.56),
					Vector2(98.99, 80.59),
					Vector2(103.80, 81.38),
					Vector2(107.73, 79.58),
					Vector2(112.00, 77.00),
					Vector2(116.61, 77.00),
					Vector2(120.88, 78.87),
					Vector2(125.01, 80.59),
					Vector2(128.85, 82.81),
					Vector2(131.91, 86.06),
					Vector2(135.33, 88.67),
					Vector2(140.00, 90.51),
					Vector2(143.44, 93.85),
					Vector2(143.41, 98.99),
					Vector2(142.62, 103.80),
					Vector2(144.42, 107.73)
				]
			},
			{
				"name": "Radar summit",
				"height": 6.0,
				"rock": "ice",
				"polygon":
				[
					Vector2(126.40, 112.00),
					Vector2(126.04, 114.79),
					Vector2(124.93, 117.36),
					Vector2(123.38, 119.60),
					Vector2(121.62, 121.62),
					Vector2(120.27, 124.37),
					Vector2(117.36, 124.93),
					Vector2(114.56, 124.87),
					Vector2(112.00, 126.40),
					Vector2(109.21, 126.04),
					Vector2(106.64, 124.93),
					Vector2(104.40, 123.38),
					Vector2(102.38, 121.62),
					Vector2(99.63, 120.27),
					Vector2(99.07, 117.36),
					Vector2(99.13, 114.56),
					Vector2(97.60, 112.00),
					Vector2(97.96, 109.21),
					Vector2(99.07, 106.64),
					Vector2(100.62, 104.40),
					Vector2(102.38, 102.38),
					Vector2(103.73, 99.63),
					Vector2(106.64, 99.07),
					Vector2(109.44, 99.13),
					Vector2(112.00, 97.60),
					Vector2(114.79, 97.96),
					Vector2(117.36, 99.07),
					Vector2(119.60, 100.62),
					Vector2(121.62, 102.38),
					Vector2(124.37, 103.73),
					Vector2(124.93, 106.64),
					Vector2(124.87, 109.44)
				]
			},
		],
		"landmarks":
		[
			{
				"name": "Crown radar",
				"asset": "cold/RadarDome",
				"position": Vector2(112, 112),
				"heading": 45.0,
				"solid": 6.0,
				"sight_height": 13.0
			},
		],
	},
	"ai":
	{
		"expand_order": ["Depot flat", "Sledge depot", "Crown foot", "Radar road", "Crown terrace"],
		# The depot ice bridge toward the next shelf, and the crown ramp.
		"lanes": [Vector2(91, 41), Vector2(83, 83)],
	},
}
