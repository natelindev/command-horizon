extends RefCounted

# Copper Badlands — a Chilean open-pit copper mine. Four benches step 12 m down
# to the pit floor and its contested camp; each start's haul road spirals down
# one bench at a time, and a rich ore face lies on its upper bench. Bases hold
# the corners; each natural sits along an edge under a neighbour's waste dump,
# a 6 m mesa whose ramp faces the corridor between the dumps and the pit rim.
# Bench outlines carry a four-fold ripple so every start sees the same pit.
# Authored for the start near (0, 0); the others receive 90-degree rotations.
const DEFINITION = {
	"id": "CopperBadlandsMap",
	"name": "Copper Badlands",
	"revision": 1,
	"players": 4,
	"size": Vector2(224, 224),
	"symmetry": "rotate",
	"biome": "desert",
	"ground": "copper",
	"backdrop": {"rise": 16.0},
	"tiers":
	[
		{
			"name": "Waste dump",
			"height": 6.0,
			"natural": true,
			"roughness": 1.5,
			"polygon":
			[
				Vector2(0, 94),
				Vector2(14, 90),
				Vector2(26, 96),
				Vector2(30, 112),
				Vector2(26, 128),
				Vector2(14, 134),
				Vector2(0, 130)
			]
		},
	],
	"ramps":
	[
		{
			"name": "Haul ramp 1",
			"from": Vector2(67.37, 59.19),
			"to": Vector2(68.94, 77.13),
			"width": 9.0,
			"from_height": 0.0,
			"to_height": -3.0
		},
		{
			"name": "Haul ramp 2",
			"from": Vector2(97.73, 58.68),
			"to": Vector2(91.87, 75.70),
			"width": 9.0,
			"from_height": -3.0,
			"to_height": -6.0
		},
		{
			"name": "Haul ramp 3",
			"from": Vector2(119.92, 71.46),
			"to": Vector2(107.64, 84.63),
			"width": 9.0,
			"from_height": -6.0,
			"to_height": -9.0
		},
		{
			"name": "Haul ramp 4",
			"from": Vector2(129.36, 90.66),
			"to": Vector2(112.80, 97.70),
			"width": 9.0,
			"from_height": -9.0,
			"to_height": -12.0
		},
		{
			"name": "Dump ramp",
			"from": Vector2(45, 104),
			"to": Vector2(25, 106),
			"width": 8.0,
			"from_height": 0.0,
			"to_height": 6.0
		},
	],
	"water":
	[
		{
			"name": "Tailings pond",
			"level": 0.0,
			"natural": true,
			"polygon":
			[Vector2(4, 42), Vector2(14, 38), Vector2(20, 46), Vector2(16, 56), Vector2(6, 56)]
		},
	],
	"blockers": [],
	"forests": [],
	"sands":
	[
		{
			"name": "Haul yard",
			"natural": true,
			"roughness": 2.0,
			"polygon":
			[Vector2(50, 40), Vector2(70, 46), Vector2(74, 64), Vector2(56, 66), Vector2(46, 56)]
		},
	],
	"roads":
	[
		{
			"name": "Pit road",
			"width": 6.0,
			"line": [Vector2(24, 24), Vector2(50, 48), Vector2(67.37, 59.47)]
		},
	],
	"landmarks":
	[
		{
			"name": "Primary crusher",
			"asset": "drylands/PrimaryCrusher",
			"position": Vector2(62, 30),
			"heading": 45.0,
			"solid": 6.5,
			"sight_height": 8.4
		},
		{
			# Park heavy equipment in the haul yard, clear of the bench ramp mouths.
			"name": "Rope shovel",
			"asset": "drylands/ElectricShovel",
			"position": Vector2(80, 40),
			"heading": 236.0,
			"solid": 4.0,
			"sight_height": 9.0
		},
		{
			"name": "Haul truck",
			"asset": "drylands/HaulTruck",
			"position": Vector2(90, 35),
			"heading": 140.0,
			"solid": 3.2,
			"sight_height": 4.0
		},
		{
			"name": "Haul truck",
			"asset": "drylands/HaulTruck",
			"position": Vector2(110, 36),
			"heading": 170.0,
			"solid": 3.2,
			"sight_height": 4.0
		},
		{
			"name": "Light plant",
			"asset": "drylands/LightTower",
			"position": Vector2(59.13, 96.84),
			"heading": 20.0
		},
		{
			"name": "Mine offices",
			"asset": "drylands/MineOffice",
			"position": Vector2(44, 8),
			"heading": 90.0,
			"solid": 4.5,
			"sight_height": 3.0
		},
	],
	"bases": [{"start": Vector2(24, 24), "field": Vector2(17.6, 17.6)}],
	"expansions":
	[
		{"name": "Edge workings", "site": Vector2(74, 22), "field": Vector2(78, 13.9)},
		{"name": "West spoil", "site": Vector2(20, 72), "field": Vector2(11.2, 74)},
		{
			"name": "Upper ore face",
			"site": Vector2(61.37, 90.51),
			"field": Vector2(65.61, 82.45),
			"rich": true
		},
	],
	"sites":
	[
		{
			"kind": "refinery",
			"position": Vector2(50, 70),
			"names":
			["North-West Smelter", "North-East Smelter", "South-East Smelter", "South-West Smelter"]
		},
		{
			"kind": "repair",
			"position": Vector2(12, 112),
			"names":
			[
				"West Dump Workshop",
				"North Dump Workshop",
				"East Dump Workshop",
				"South Dump Workshop"
			]
		},
	],
	"shared":
	{
		"tiers":
		[
			{
				"name": "Upper bench",
				"height": -3.0,
				"polygon":
				[
					Vector2(175.34, 112.00),
					Vector2(175.08, 120.30),
					Vector2(172.66, 128.25),
					Vector2(169.65, 135.88),
					Vector2(166.09, 143.23),
					Vector2(161.28, 149.81),
					Vector2(155.59, 155.59),
					Vector2(149.52, 160.90),
					Vector2(142.73, 165.23),
					Vector2(135.20, 168.00),
					Vector2(127.60, 170.23),
					Vector2(120.04, 173.08),
					Vector2(112.00, 175.34),
					Vector2(103.70, 175.08),
					Vector2(95.75, 172.66),
					Vector2(88.12, 169.65),
					Vector2(80.77, 166.09),
					Vector2(74.19, 161.28),
					Vector2(68.41, 155.59),
					Vector2(63.10, 149.52),
					Vector2(58.77, 142.73),
					Vector2(56.00, 135.20),
					Vector2(53.77, 127.60),
					Vector2(50.92, 120.04),
					Vector2(48.66, 112.00),
					Vector2(48.92, 103.70),
					Vector2(51.34, 95.75),
					Vector2(54.35, 88.12),
					Vector2(57.91, 80.77),
					Vector2(62.72, 74.19),
					Vector2(68.41, 68.41),
					Vector2(74.48, 63.10),
					Vector2(81.27, 58.77),
					Vector2(88.80, 56.00),
					Vector2(96.40, 53.77),
					Vector2(103.96, 50.92),
					Vector2(112.00, 48.66),
					Vector2(120.30, 48.92),
					Vector2(128.25, 51.34),
					Vector2(135.88, 54.35),
					Vector2(143.23, 57.91),
					Vector2(149.81, 62.72),
					Vector2(155.59, 68.41),
					Vector2(160.90, 74.48),
					Vector2(165.23, 81.27),
					Vector2(168.00, 88.80),
					Vector2(170.23, 96.40),
					Vector2(173.08, 103.96)
				]
			},
			{
				"name": "Middle bench",
				"height": -6.0,
				"polygon":
				[
					Vector2(161.55, 112.00),
					Vector2(160.46, 118.38),
					Vector2(158.26, 124.40),
					Vector2(156.27, 130.34),
					Vector2(153.93, 136.21),
					Vector2(150.18, 141.29),
					Vector2(145.41, 145.41),
					Vector2(140.54, 149.20),
					Vector2(135.54, 152.77),
					Vector2(130.10, 155.69),
					Vector2(124.38, 158.19),
					Vector2(118.38, 160.49),
					Vector2(112.00, 161.55),
					Vector2(105.62, 160.46),
					Vector2(99.60, 158.26),
					Vector2(93.66, 156.27),
					Vector2(87.79, 153.93),
					Vector2(82.71, 150.18),
					Vector2(78.59, 145.41),
					Vector2(74.80, 140.54),
					Vector2(71.23, 135.54),
					Vector2(68.31, 130.10),
					Vector2(65.81, 124.38),
					Vector2(63.51, 118.38),
					Vector2(62.45, 112.00),
					Vector2(63.54, 105.62),
					Vector2(65.74, 99.60),
					Vector2(67.73, 93.66),
					Vector2(70.07, 87.79),
					Vector2(73.82, 82.71),
					Vector2(78.59, 78.59),
					Vector2(83.46, 74.80),
					Vector2(88.46, 71.23),
					Vector2(93.90, 68.31),
					Vector2(99.62, 65.81),
					Vector2(105.62, 63.51),
					Vector2(112.00, 62.45),
					Vector2(118.38, 63.54),
					Vector2(124.40, 65.74),
					Vector2(130.34, 67.73),
					Vector2(136.21, 70.07),
					Vector2(141.29, 73.82),
					Vector2(145.41, 78.59),
					Vector2(149.20, 83.46),
					Vector2(152.77, 88.46),
					Vector2(155.69, 93.90),
					Vector2(158.19, 99.62),
					Vector2(160.49, 105.62)
				]
			},
			{
				"name": "Lower bench",
				"height": -9.0,
				"polygon":
				[
					Vector2(146.58, 112.00),
					Vector2(145.84, 116.45),
					Vector2(144.64, 120.74),
					Vector2(143.41, 125.01),
					Vector2(141.50, 129.03),
					Vector2(138.44, 132.29),
					Vector2(135.08, 135.08),
					Vector2(132.15, 138.26),
					Vector2(129.11, 141.64),
					Vector2(125.31, 144.14),
					Vector2(120.98, 145.53),
					Vector2(116.52, 146.36),
					Vector2(112.00, 146.58),
					Vector2(107.55, 145.84),
					Vector2(103.26, 144.64),
					Vector2(98.99, 143.41),
					Vector2(94.97, 141.50),
					Vector2(91.71, 138.44),
					Vector2(88.92, 135.08),
					Vector2(85.74, 132.15),
					Vector2(82.36, 129.11),
					Vector2(79.86, 125.31),
					Vector2(78.47, 120.98),
					Vector2(77.64, 116.52),
					Vector2(77.42, 112.00),
					Vector2(78.16, 107.55),
					Vector2(79.36, 103.26),
					Vector2(80.59, 98.99),
					Vector2(82.50, 94.97),
					Vector2(85.56, 91.71),
					Vector2(88.92, 88.92),
					Vector2(91.85, 85.74),
					Vector2(94.89, 82.36),
					Vector2(98.69, 79.86),
					Vector2(103.02, 78.47),
					Vector2(107.48, 77.64),
					Vector2(112.00, 77.42),
					Vector2(116.45, 78.16),
					Vector2(120.74, 79.36),
					Vector2(125.01, 80.59),
					Vector2(129.03, 82.50),
					Vector2(132.29, 85.56),
					Vector2(135.08, 88.92),
					Vector2(138.26, 91.85),
					Vector2(141.64, 94.89),
					Vector2(144.14, 98.69),
					Vector2(145.53, 103.02),
					Vector2(146.36, 107.48)
				]
			},
			{
				"name": "Pit floor",
				"height": -12.0,
				"polygon":
				[
					Vector2(132.23, 112.00),
					Vector2(131.97, 114.63),
					Vector2(131.15, 117.13),
					Vector2(130.17, 119.53),
					Vector2(128.95, 121.78),
					Vector2(127.35, 123.78),
					Vector2(125.73, 125.73),
					Vector2(124.24, 127.96),
					Vector2(122.39, 129.99),
					Vector2(119.91, 131.10),
					Vector2(117.22, 131.49),
					Vector2(114.62, 131.89),
					Vector2(112.00, 132.23),
					Vector2(109.37, 131.97),
					Vector2(106.87, 131.15),
					Vector2(104.47, 130.17),
					Vector2(102.22, 128.95),
					Vector2(100.22, 127.35),
					Vector2(98.27, 125.73),
					Vector2(96.04, 124.24),
					Vector2(94.01, 122.39),
					Vector2(92.90, 119.91),
					Vector2(92.51, 117.22),
					Vector2(92.11, 114.62),
					Vector2(91.77, 112.00),
					Vector2(92.03, 109.37),
					Vector2(92.85, 106.87),
					Vector2(93.83, 104.47),
					Vector2(95.05, 102.22),
					Vector2(96.65, 100.22),
					Vector2(98.27, 98.27),
					Vector2(99.76, 96.04),
					Vector2(101.61, 94.01),
					Vector2(104.09, 92.90),
					Vector2(106.78, 92.51),
					Vector2(109.38, 92.11),
					Vector2(112.00, 91.77),
					Vector2(114.63, 92.03),
					Vector2(117.13, 92.85),
					Vector2(119.53, 93.83),
					Vector2(121.78, 95.05),
					Vector2(123.78, 96.65),
					Vector2(125.73, 98.27),
					Vector2(127.96, 99.76),
					Vector2(129.99, 101.61),
					Vector2(131.10, 104.09),
					Vector2(131.49, 106.78),
					Vector2(131.89, 109.38)
				]
			},
		],
		"sites": [{"kind": "mercenary", "position": Vector2(112, 112), "name": "Pit Floor Camp"}],
	},
	"ai":
	{
		"expand_order": ["Edge workings", "West spoil", "Upper ore face"],
		# The dump corridors on either side and the pit floor.
		"lanes": [Vector2(40, 112), Vector2(112, 112)],
	},
}
