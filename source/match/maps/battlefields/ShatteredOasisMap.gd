extends RefCounted

# Shattered Oasis — a desert oasis among wadis. A turquoise lake lies in a
# sunken palm-grove basin; four dry wadis cut from the basin to the edge
# midpoints, splitting the map into quadrants that meet only at wadi crossings
# and in the basin. Each quadrant holds a base, a mud-brick village by its
# natural, dunes, and a ruined caravanserai whose courtyard hosts a camp.
# Authored for the start near (0, 0); the others receive 90-degree rotations.
const DEFINITION = {
	"id": "ShatteredOasisMap",
	"name": "Shattered Oasis",
	"revision": 1,
	"players": 4,
	"size": Vector2(224, 224),
	"symmetry": "rotate",
	"biome": "desert",
	"ground": "oasis",
	"backdrop": {"rise": 12.0},
	"tiers":
	[
		{
			"name": "Wadi",
			"height": -3.0,
			"natural": true,
			"roughness": 1.4,
			"polygon":
			[
				Vector2(70.00, 116.00),
				Vector2(52.00, 123.00),
				Vector2(36.00, 115.00),
				Vector2(20.00, 121.00),
				Vector2(0.00, 117.00),
				Vector2(0.00, 103.00),
				Vector2(20.00, 107.00),
				Vector2(36.00, 101.00),
				Vector2(52.00, 109.00),
				Vector2(70.00, 100.00)
			]
		},
		{
			"name": "Corner dune",
			"height": 3.0,
			"falloff": 8.0,
			"natural": true,
			"roughness": 2.0,
			"polygon": [Vector2(30, 0), Vector2(58, 0), Vector2(54, 9), Vector2(36, 11)]
		},
		{
			"name": "Edge dune",
			"height": 3.0,
			"falloff": 8.0,
			"natural": true,
			"roughness": 2.0,
			"polygon": [Vector2(0, 32), Vector2(9, 36), Vector2(11, 56), Vector2(0, 60)]
		},
	],
	"ramps":
	[
		{
			"name": "Basin track",
			"from": Vector2(80.45, 66.95),
			"to": Vector2(91.35, 82.51),
			"width": 10.0,
			"from_height": 0.0,
			"to_height": -3.0
		},
		{
			"name": "Wadi crossing south",
			"from": Vector2(44, 90),
			"to": Vector2(44, 105),
			"width": 8.0,
			"from_height": 0.0,
			"to_height": -3.0
		},
		{
			"name": "Wadi crossing north",
			"from": Vector2(44, 134),
			"to": Vector2(44, 119),
			"width": 8.0,
			"from_height": 0.0,
			"to_height": -3.0
		},
	],
	"water": [],
	"blockers": [],
	"forests":
	[
		{
			"name": "Palm grove",
			"flora": "trees",
			"density": 0.55,
			"natural": true,
			"polygon":
			[
				Vector2(86.63, 102.77),
				Vector2(73.96, 99.64),
				Vector2(78.01, 89.07),
				Vector2(87.37, 80.48),
				Vector2(96.90, 89.62)
			]
		},
		{
			"name": "Palm grove",
			"flora": "riparian",
			"density": 0.5,
			"natural": true,
			"polygon":
			[
				Vector2(100.60, 88.63),
				Vector2(96.14, 76.37),
				Vector2(106.43, 72.39),
				Vector2(110.12, 85.07)
			]
		},
	],
	"sands":
	[
		{
			"name": "Dune sand",
			"natural": true,
			"roughness": 3.0,
			"polygon":
			[
				Vector2(0, 0),
				Vector2(70, 0),
				Vector2(60, 14),
				Vector2(14, 16),
				Vector2(16, 64),
				Vector2(0, 70)
			]
		},
		{
			"name": "Wadi bed",
			"natural": true,
			"polygon":
			[
				Vector2(66.00, 113.00),
				Vector2(52.00, 119.00),
				Vector2(36.00, 111.00),
				Vector2(20.00, 117.00),
				Vector2(0.00, 113.00),
				Vector2(0.00, 107.00),
				Vector2(20.00, 111.00),
				Vector2(36.00, 105.00),
				Vector2(52.00, 113.00),
				Vector2(66.00, 105.00)
			]
		},
	],
	"roads":
	[
		{
			"name": "Caravan track",
			"width": 4.0,
			"line":
			[
				Vector2(24, 24),
				Vector2(42, 40),
				Vector2(60, 50),
				Vector2(60, 70),
				Vector2(80.45, 66.95),
				Vector2(91.35, 82.51)
			]
		},
		{
			"name": "Village lane",
			"width": 3.5,
			"line": [Vector2(42, 40), Vector2(76, 30), Vector2(98, 24)]
		},
	],
	"landmarks":
	[
		{
			"name": "Caravanserai tower",
			"asset": "drylands/CaravanseraiTower",
			"position": Vector2(50.00, 50.00),
			"heading": 0.0,
			"solid": 2.4,
			"sight_height": 7.0
		},
		{
			"name": "Caravanserai tower",
			"asset": "drylands/CaravanseraiTower",
			"position": Vector2(70.00, 50.00),
			"heading": 45.0,
			"solid": 2.4,
			"sight_height": 7.0
		},
		{
			"name": "Caravanserai tower",
			"asset": "drylands/CaravanseraiTower",
			"position": Vector2(70.00, 70.00),
			"heading": 45.0,
			"solid": 2.4,
			"sight_height": 7.0
		},
		{
			"name": "Caravanserai tower",
			"asset": "drylands/CaravanseraiTower",
			"position": Vector2(50.00, 70.00),
			"heading": 0.0,
			"solid": 2.4,
			"sight_height": 7.0
		},
		{
			"name": "Caravanserai wall",
			"asset": "drylands/CaravanseraiGate",
			"position": Vector2(60.00, 50.00),
			"heading": 0.0,
			"footprints":
			[
				[Vector2(-9.2, -1.1), Vector2(-1.6, -1.1), Vector2(-1.6, 1.1), Vector2(-9.2, 1.1)],
				[Vector2(1.6, -1.1), Vector2(9.2, -1.1), Vector2(9.2, 1.1), Vector2(1.6, 1.1)]
			],
			"sight_height": 5.0
		},
		{
			"name": "Caravanserai wall",
			"asset": "drylands/CaravanseraiGate",
			"position": Vector2(70.00, 60.00),
			"heading": 90.0,
			"footprints":
			[
				[Vector2(-9.2, -1.1), Vector2(-1.6, -1.1), Vector2(-1.6, 1.1), Vector2(-9.2, 1.1)],
				[Vector2(1.6, -1.1), Vector2(9.2, -1.1), Vector2(9.2, 1.1), Vector2(1.6, 1.1)]
			],
			"sight_height": 5.0
		},
		{
			"name": "Caravanserai wall",
			"asset": "drylands/CaravanseraiGate",
			"position": Vector2(60.00, 70.00),
			"heading": 180.0,
			"footprints":
			[
				[Vector2(-9.2, -1.1), Vector2(-1.6, -1.1), Vector2(-1.6, 1.1), Vector2(-9.2, 1.1)],
				[Vector2(1.6, -1.1), Vector2(9.2, -1.1), Vector2(9.2, 1.1), Vector2(1.6, 1.1)]
			],
			"sight_height": 5.0
		},
		{
			"name": "Caravanserai wall",
			"asset": "drylands/CaravanseraiGate",
			"position": Vector2(50.00, 60.00),
			"heading": 270.0,
			"footprints":
			[
				[Vector2(-9.2, -1.1), Vector2(-1.6, -1.1), Vector2(-1.6, 1.1), Vector2(-9.2, 1.1)],
				[Vector2(1.6, -1.1), Vector2(9.2, -1.1), Vector2(9.2, 1.1), Vector2(1.6, 1.1)]
			],
			"sight_height": 5.0
		},
		{
			"name": "Village house",
			"asset": "drylands/MudHouseA",
			"position": Vector2(64.00, 32.00),
			"heading": 10.0,
			"solid": 2.8,
			"sight_height": 3.0
		},
		{
			"name": "Village house",
			"asset": "drylands/MudHouseB",
			"position": Vector2(90.00, 30.00),
			"heading": -15.0,
			"solid": 3.0,
			"sight_height": 2.6
		},
		{
			"name": "Village house",
			"asset": "drylands/MudHouseA",
			"position": Vector2(84.00, 40.00),
			"heading": 80.0,
			"solid": 2.8,
			"sight_height": 3.0
		},
		{
			"name": "Village well",
			"asset": "drylands/StoneWell",
			"position": Vector2(76.00, 34.00),
			"heading": 0.0,
			"solid": 1.4,
			"sight_height": 2.2
		},
		{
			"name": "Herders' tent",
			"asset": "drylands/BedouinTent",
			"position": Vector2(30.00, 74.00),
			"heading": 30.0,
			"solid": 2.0,
			"sight_height": 2.0
		},
	],
	"bases": [{"start": Vector2(24, 24), "field": Vector2(17.6, 17.6)}],
	"expansions":
	[
		{"name": "Village wells", "site": Vector2(74, 18), "field": Vector2(78.5, 10.2)},
		{"name": "Wadi mouth", "site": Vector2(20, 78), "field": Vector2(11.2, 80)},
		{
			"name": "Palm grove",
			"site": Vector2(84.64, 93.55),
			"field": Vector2(90.61, 86.87),
			"rich": true
		},
	],
	"sites":
	[
		{
			"kind": "mercenary",
			"position": Vector2(60, 60),
			"names":
			[
				"North-West Caravanserai",
				"North-East Caravanserai",
				"South-East Caravanserai",
				"South-West Caravanserai"
			]
		},
		{
			"kind": "refinery",
			"position": Vector2(90, 50),
			"names": ["North Date Press", "East Date Press", "South Date Press", "West Date Press"]
		},
		{
			"kind": "repair",
			"position": Vector2(34, 92),
			"names":
			["West Wadi Smithy", "North Wadi Smithy", "East Wadi Smithy", "South Wadi Smithy"]
		},
	],
	"shared":
	{
		"tiers":
		[
			{
				"name": "Oasis basin",
				"height": -3.0,
				"polygon":
				[
					Vector2(158.27, 112.00),
					Vector2(158.09, 118.07),
					Vector2(155.35, 123.62),
					Vector2(152.59, 128.81),
					Vector2(150.34, 134.14),
					Vector2(147.10, 138.93),
					Vector2(142.69, 142.69),
					Vector2(138.13, 146.05),
					Vector2(133.43, 149.12),
					Vector2(128.22, 151.16),
					Vector2(122.95, 152.87),
					Vector2(117.75, 155.64),
					Vector2(112.00, 158.27),
					Vector2(105.93, 158.09),
					Vector2(100.38, 155.35),
					Vector2(95.19, 152.59),
					Vector2(89.86, 150.34),
					Vector2(85.07, 147.10),
					Vector2(81.31, 142.69),
					Vector2(77.95, 138.13),
					Vector2(74.88, 133.43),
					Vector2(72.84, 128.22),
					Vector2(71.13, 122.95),
					Vector2(68.36, 117.75),
					Vector2(65.73, 112.00),
					Vector2(65.91, 105.93),
					Vector2(68.65, 100.38),
					Vector2(71.41, 95.19),
					Vector2(73.66, 89.86),
					Vector2(76.90, 85.07),
					Vector2(81.31, 81.31),
					Vector2(85.87, 77.95),
					Vector2(90.57, 74.88),
					Vector2(95.78, 72.84),
					Vector2(101.05, 71.13),
					Vector2(106.25, 68.36),
					Vector2(112.00, 65.73),
					Vector2(118.07, 65.91),
					Vector2(123.62, 68.65),
					Vector2(128.81, 71.41),
					Vector2(134.14, 73.66),
					Vector2(138.93, 76.90),
					Vector2(142.69, 81.31),
					Vector2(146.05, 85.87),
					Vector2(149.12, 90.57),
					Vector2(151.16, 95.78),
					Vector2(152.87, 101.05),
					Vector2(155.64, 106.25)
				]
			},
		],
		"water":
		[
			{
				"name": "Oasis lake",
				"level": -3.0,
				"polygon":
				[
					Vector2(134.33, 112.00),
					Vector2(133.22, 114.79),
					Vector2(131.63, 117.26),
					Vector2(130.87, 119.82),
					Vector2(130.29, 122.56),
					Vector2(128.45, 124.62),
					Vector2(125.83, 125.83),
					Vector2(123.81, 127.39),
					Vector2(122.30, 129.83),
					Vector2(120.30, 132.04),
					Vector2(117.72, 133.33),
					Vector2(114.92, 134.15),
					Vector2(112.00, 134.33),
					Vector2(109.21, 133.22),
					Vector2(106.74, 131.63),
					Vector2(104.18, 130.87),
					Vector2(101.44, 130.29),
					Vector2(99.38, 128.45),
					Vector2(98.17, 125.83),
					Vector2(96.61, 123.81),
					Vector2(94.17, 122.30),
					Vector2(91.96, 120.30),
					Vector2(90.67, 117.72),
					Vector2(89.85, 114.92),
					Vector2(89.67, 112.00),
					Vector2(90.78, 109.21),
					Vector2(92.37, 106.74),
					Vector2(93.13, 104.18),
					Vector2(93.71, 101.44),
					Vector2(95.55, 99.38),
					Vector2(98.17, 98.17),
					Vector2(100.19, 96.61),
					Vector2(101.70, 94.17),
					Vector2(103.70, 91.96),
					Vector2(106.28, 90.67),
					Vector2(109.08, 89.85),
					Vector2(112.00, 89.67),
					Vector2(114.79, 90.78),
					Vector2(117.26, 92.37),
					Vector2(119.82, 93.13),
					Vector2(122.56, 93.71),
					Vector2(124.62, 95.55),
					Vector2(125.83, 98.17),
					Vector2(127.39, 100.19),
					Vector2(129.83, 101.70),
					Vector2(132.04, 103.70),
					Vector2(133.33, 106.28),
					Vector2(134.15, 109.08)
				]
			},
		],
	},
	"ai":
	{
		"expand_order": ["Village wells", "Wadi mouth", "Palm grove"],
		# A wadi crossing and the basin track down to the groves.
		"lanes": [Vector2(44, 112), Vector2(86.19, 75.14)],
	},
}
