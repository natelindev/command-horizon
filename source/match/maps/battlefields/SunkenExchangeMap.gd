extends RefCounted

# Sunken Exchange — a port city half lost to the sea. The old exchange stands
# on a raised piazza at the heart of the city, ringed by a flooded quay where
# drowned house fronts stand in the shallows, and beyond that by the ring
# canal. Four canals run from the ring to the city edge between the corner
# districts; each district keeps a palazzo terrace, warehouses, an arsenal
# and a campanile. Bridges are the only ways across the water: one over each
# radial canal, one over the ring canal toward each corner, and steps up to
# the piazza. Authored for the start near (0, 0); the others receive
# 90-degree rotations.
const WAREHOUSE = [[Vector2(-12, -7), Vector2(12, -7), Vector2(12, 7), Vector2(-12, 7)]]
const CANAL_ROW = [[Vector2(-12, -5), Vector2(12, -5), Vector2(12, 5), Vector2(-12, 5)]]
const SHORT_ROW = [[Vector2(-9, -5), Vector2(9, -5), Vector2(9, 5), Vector2(-9, 5)]]
const EXCHANGE = [[Vector2(-9.5, -6.5), Vector2(9.5, -6.5), Vector2(9.5, 6.5), Vector2(-9.5, 6.5)]]
const DEFINITION = {
	"id": "SunkenExchangeMap",
	"name": "Sunken Exchange",
	"revision": 1,
	"players": 4,
	"size": Vector2(224, 224),
	"symmetry": "rotate",
	"biome": "coastal",
	"ground": "canalcity",
	"texture_preset": "urban",
	"backdrop": {"rise": 8.0},
	"tiers":
	[
		{
			"name": "Palazzo terrace",
			"height": 3.0,
			"rock": "retaining",
			"polygon":
			[
				Vector2(0, 0),
				Vector2(54, 0),
				Vector2(58, 22),
				Vector2(48, 44),
				Vector2(24, 52),
				Vector2(0, 54)
			]
		},
		{
			"name": "Grand canal",
			"height": -3.0,
			"rock": "retaining",
			"polygon": [Vector2(100, -2), Vector2(108, -2), Vector2(108, 74), Vector2(100, 74)]
		},
		{
			"name": "Ring canal",
			"height": -3.0,
			"rock": "retaining",
			"polygon":
			[
				Vector2(72.0, 112.0),
				Vector2(72.41, 106.31),
				Vector2(73.62, 100.73),
				Vector2(75.61, 95.38),
				Vector2(78.35, 90.37),
				Vector2(81.77, 85.81),
				Vector2(85.81, 81.77),
				Vector2(90.37, 78.35),
				Vector2(95.38, 75.61),
				Vector2(100.73, 73.62),
				Vector2(106.31, 72.41),
				Vector2(112.0, 72.0),
				Vector2(112.0, 80.0),
				Vector2(107.45, 80.33),
				Vector2(102.98, 81.3),
				Vector2(98.71, 82.89),
				Vector2(94.7, 85.08),
				Vector2(91.04, 87.82),
				Vector2(87.82, 91.04),
				Vector2(85.08, 94.7),
				Vector2(82.89, 98.71),
				Vector2(81.3, 102.98),
				Vector2(80.33, 107.45),
				Vector2(80.0, 112.0)
			]
		},
	],
	"ramps":
	[
		{
			"name": "Palazzo steps",
			"from": Vector2(38.7, 56.1),
			"to": Vector2(33.5, 40.4),
			"width": 10.0,
			"from_height": 0.0,
			"to_height": 3.0
		},
		{
			"name": "Exchange steps",
			"from": Vector2(92.2, 92.2),
			"to": Vector2(103.5, 103.5),
			"width": 8.0,
			"from_height": 0.0,
			"to_height": 3.0
		},
	],
	"water":
	[
		{
			"name": "Grand canal",
			"level": -2.4,
			"polygon": [Vector2(100, -2), Vector2(108, -2), Vector2(108, 74), Vector2(100, 74)]
		},
		{
			"name": "Ring canal",
			"level": -2.4,
			"polygon":
			[
				Vector2(72.0, 112.0),
				Vector2(72.41, 106.31),
				Vector2(73.62, 100.73),
				Vector2(75.61, 95.38),
				Vector2(78.35, 90.37),
				Vector2(81.77, 85.81),
				Vector2(85.81, 81.77),
				Vector2(90.37, 78.35),
				Vector2(95.38, 75.61),
				Vector2(100.73, 73.62),
				Vector2(106.31, 72.41),
				Vector2(112.0, 72.0),
				Vector2(112.0, 80.0),
				Vector2(107.45, 80.33),
				Vector2(102.98, 81.3),
				Vector2(98.71, 82.89),
				Vector2(94.7, 85.08),
				Vector2(91.04, 87.82),
				Vector2(87.82, 91.04),
				Vector2(85.08, 94.7),
				Vector2(82.89, 98.71),
				Vector2(81.3, 102.98),
				Vector2(80.33, 107.45),
				Vector2(80.0, 112.0)
			]
		},
		{
			"name": "Flooded quay",
			"level": 0.0,
			"ford": true,
			"polygon":
			[
				Vector2(81.0, 112.0),
				Vector2(81.3, 107.69),
				Vector2(82.2, 103.46),
				Vector2(83.68, 99.39),
				Vector2(85.71, 95.57),
				Vector2(94.62, 101.14),
				Vector2(93.27, 103.66),
				Vector2(92.29, 106.35),
				Vector2(91.7, 109.15),
				Vector2(91.5, 112.0)
			]
		},
		{
			"name": "Flooded quay",
			"level": 0.0,
			"ford": true,
			"polygon":
			[
				Vector2(95.57, 85.71),
				Vector2(99.39, 83.68),
				Vector2(103.46, 82.2),
				Vector2(107.69, 81.3),
				Vector2(112.0, 81.0),
				Vector2(112.0, 91.5),
				Vector2(109.15, 91.7),
				Vector2(106.35, 92.29),
				Vector2(103.66, 93.27),
				Vector2(101.14, 94.62)
			]
		},
	],
	"bridges":
	[
		{"level": 0.3, "line": [Vector2(94, 36), Vector2(114, 36)], "width": 7.0},
		{"level": 0.3, "line": [Vector2(90.8, 90.8), Vector2(82.3, 82.3)], "width": 7.0},
	],
	"forests":
	[
		{
			"name": "Palazzo garden",
			"density": 0.55,
			"natural": true,
			"roughness": 1.0,
			"polygon": [Vector2(4, 4), Vector2(14, 4), Vector2(14, 12), Vector2(4, 12)]
		},
		{
			"name": "Campo trees",
			"density": 0.45,
			"polygon": [Vector2(46, 80), Vector2(54, 80), Vector2(54, 88), Vector2(46, 88)]
		},
	],
	"sands":
	[
		{
			"name": "Brick campo",
			"polygon": [Vector2(44, 76), Vector2(70, 76), Vector2(70, 96), Vector2(44, 96)]
		},
	],
	"roads":
	[
		{
			"name": "Fondamenta",
			"width": 4.5,
			"line":
			[
				Vector2(24, 22),
				Vector2(30, 32),
				Vector2(33.5, 40.4),
				Vector2(38.7, 56.1),
				Vector2(56, 64),
				Vector2(76, 60),
				Vector2(94, 36)
			]
		},
		{
			"name": "Calle",
			"width": 3.5,
			"line": [Vector2(56, 64), Vector2(70, 76), Vector2(82.3, 82.3)]
		},
	],
	"landmarks":
	[
		{
			"name": "Warehouse",
			"asset": "harbour/PortWarehouse",
			"position": Vector2(86, 14),
			"heading": 90.0,
			"footprints": WAREHOUSE,
			"sight_height": 18.0
		},
		{
			"name": "Canal houses",
			"asset": "harbour/CanalRowA",
			"position": Vector2(70, 48),
			"heading": 0.0,
			"footprints": CANAL_ROW,
			"sight_height": 16.0
		},
		{
			"name": "Canal houses",
			"asset": "harbour/CanalRowShort",
			"position": Vector2(76, 70),
			"heading": 45.0,
			"footprints": SHORT_ROW,
			"sight_height": 16.0
		},
		{
			"name": "Campanile",
			"asset": "harbour/Campanile",
			"position": Vector2(44, 70),
			"solid": 3.4,
			"sight_height": 30.0
		},
		{
			"name": "Campo fountain",
			"asset": "harbour/Fountain",
			"position": Vector2(50, 92),
			"solid": 3.2,
			"sight_height": 3.0
		},
		{
			"name": "Grand canal bridge",
			"asset": "temperate/StoneBridge",
			"position": Vector2(104, 36),
			"heading": 0.0
		},
		{
			"name": "Ring bridge",
			"asset": "temperate/StoneBridge",
			"position": Vector2(86.5, 86.5),
			"heading": 45.0
		},
		{
			"name": "Mooring poles",
			"asset": "harbour/MooringPoles",
			"position": Vector2(98.5, 56),
			"heading": 90.0,
			"level": -2.4
		},
		{
			"name": "Canal boat",
			"asset": "harbour/CanalBoat",
			"position": Vector2(104, 60),
			"heading": 90.0,
			"level": -2.7
		},
		{
			"name": "Canal boat",
			"asset": "harbour/CanalBoat",
			"position": Vector2(104, 14),
			"heading": -90.0,
			"level": -2.7
		},
		{
			"name": "Drowned house",
			"asset": "harbour/SubmergedFacade",
			"position": Vector2(87.4, 103.0),
			"heading": 20.0,
			"solid": 3.6,
			"sight_height": 8.0
		},
		{
			"name": "Drowned house",
			"asset": "harbour/SubmergedFacade",
			"position": Vector2(103.0, 87.4),
			"heading": 70.0,
			"solid": 3.6,
			"sight_height": 8.0
		},
	],
	"bases": [{"start": Vector2(24, 22), "field": Vector2(17, 16.5)}],
	"expansions":
	[
		{"name": "Fondaco", "site": Vector2(24, 70), "field": Vector2(14, 76)},
		{"name": "Arsenal", "site": Vector2(72, 30), "field": Vector2(64, 24)},
		{"name": "Glass works", "site": Vector2(36, 98), "field": Vector2(28, 104)},
		{"name": "Fish market", "site": Vector2(72, 86), "field": Vector2(64, 92), "rich": true},
		{"name": "Customs house", "site": Vector2(90, 60), "field": Vector2(94, 51), "rich": true},
	],
	"sites":
	[
		{
			"kind": "refinery",
			"position": Vector2(54, 106),
			"names":
			[
				"North-West Gas Works",
				"North-East Gas Works",
				"South-East Gas Works",
				"South-West Gas Works"
			]
		},
		{
			"kind": "repair",
			"position": Vector2(8, 92),
			"names":
			[
				"North-West Boatyard",
				"North-East Boatyard",
				"South-East Boatyard",
				"South-West Boatyard"
			]
		},
	],
	"shared":
	{
		"tiers":
		[
			{
				"name": "Exchange piazza",
				"height": 3.0,
				"rock": "retaining",
				"polygon":
				[
					Vector2(132.0, 112.0),
					Vector2(131.32, 117.18),
					Vector2(129.32, 122.0),
					Vector2(126.14, 126.14),
					Vector2(122.0, 129.32),
					Vector2(117.18, 131.32),
					Vector2(112.0, 132.0),
					Vector2(106.82, 131.32),
					Vector2(102.0, 129.32),
					Vector2(97.86, 126.14),
					Vector2(94.68, 122.0),
					Vector2(92.68, 117.18),
					Vector2(92.0, 112.0),
					Vector2(92.68, 106.82),
					Vector2(94.68, 102.0),
					Vector2(97.86, 97.86),
					Vector2(102.0, 94.68),
					Vector2(106.82, 92.68),
					Vector2(112.0, 92.0),
					Vector2(117.18, 92.68),
					Vector2(122.0, 94.68),
					Vector2(126.14, 97.86),
					Vector2(129.32, 102.0),
					Vector2(131.32, 106.82)
				]
			},
		],
		"landmarks":
		[
			{
				"name": "Exchange",
				"asset": "harbour/ExchangeHall",
				"position": Vector2(112, 112),
				"heading": 0.0,
				"scale": 0.62,
				"footprints": EXCHANGE,
				"sight_height": 18.0
			},
		],
	},
	"ai":
	{
		"expand_order": ["Fondaco", "Arsenal", "Glass works", "Customs house", "Fish market"],
		# The grand canal bridges and the ring bridges.
		"lanes": [Vector2(104, 36), Vector2(86.5, 86.5)],
	},
}
