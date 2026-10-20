extends RefCounted

# Glacier Narrows — the head of a Norwegian fjord valley. A glacier snout at
# the north edge stands behind its terminal moraine, which dams a meltwater
# reservoir; a hydro dam closes the reservoir's southern narrows above a
# gorge that opens onto braided outwash flats. Each start holds a valley
# shelf on its own side, so the valley is crossed four ways: over the
# moraine crest (high, past the moraine camp), along the narrow lakeshore
# under it, across the dam crest, or through the outwash ford far to the
# south. Authored for the west start; the east start is its mirror image.
const DEFINITION = {
	"id": "GlacierNarrowsMap",
	"name": "Glacier Narrows",
	"revision": 1,
	"players": 2,
	"size": Vector2(192, 160),
	"symmetry": "mirror_x",
	"biome": "alpine",
	"ground": "fjord",
	"backdrop": {"rise": 26.0},
	"tiers":
	[
		{
			"name": "Valley shelf",
			"height": 3.0,
			"natural": true,
			"polygon":
			[
				Vector2(0, 50),
				Vector2(44, 48),
				Vector2(48, 58),
				Vector2(48, 88),
				Vector2(42, 104),
				Vector2(26, 112),
				Vector2(0, 112)
			]
		},
	],
	"ramps":
	[
		{
			"name": "Shelf road",
			"from": Vector2(34, 41.5),
			"to": Vector2(34, 58),
			"width": 10.0,
			"from_height": 0.0,
			"to_height": 3.0
		},
		{
			"name": "Moraine ramp",
			"from": Vector2(54, 16),
			"to": Vector2(70, 16),
			"width": 8.0,
			"from_height": 0.0,
			"to_height": 3.0
		},
		{
			"name": "Outwash ramp",
			"from": Vector2(38, 140),
			"to": Vector2(54, 140),
			"width": 10.0,
			"from_height": 0.0,
			"to_height": -3.0
		},
	],
	"blockers":
	[
		{
			"name": "Gneiss rib",
			"height": 5.0,
			"natural": true,
			"roughness": 1.0,
			"polygon":
			[
				Vector2(34, 0),
				Vector2(44, 0),
				Vector2(46, 12),
				Vector2(45, 24),
				Vector2(43, 37),
				Vector2(37, 32),
				Vector2(33, 16)
			]
		},
	],
	"forests":
	[
		{
			"name": "Hollow birches",
			"flora": "riparian",
			"density": 0.6,
			"natural": true,
			"polygon":
			[Vector2(2, 2), Vector2(20, 2), Vector2(22, 10), Vector2(8, 14), Vector2(2, 12)]
		},
		{
			"name": "Shelf spruce",
			"density": 0.75,
			"natural": true,
			"roughness": 1.6,
			"polygon":
			[Vector2(0, 56), Vector2(6, 58), Vector2(7, 70), Vector2(4, 96), Vector2(0, 98)]
		},
		{
			"name": "Shore spruce",
			"density": 0.75,
			"natural": true,
			"roughness": 1.8,
			"polygon":
			[Vector2(52, 86), Vector2(62, 84), Vector2(66, 93), Vector2(58, 98), Vector2(52, 95)]
		},
		{
			"name": "Pasture spruce",
			"density": 0.65,
			"natural": true,
			"roughness": 1.6,
			"polygon":
			[Vector2(0, 118), Vector2(4, 116), Vector2(6, 128), Vector2(2, 136), Vector2(0, 136)]
		},
	],
	"sands":
	[
		{
			"name": "Moraine apron",
			"natural": true,
			"roughness": 1.4,
			"polygon": [Vector2(48, 22), Vector2(60, 24), Vector2(62, 33), Vector2(50, 34)]
		},
		{
			"name": "West gravel bar",
			"natural": true,
			"roughness": 1.6,
			"polygon": [Vector2(58, 128), Vector2(78, 126), Vector2(82, 134), Vector2(62, 138)]
		},
	],
	"roads":
	[
		{
			"name": "Shelf road",
			"width": 5.0,
			"line":
			[
				Vector2(22, 86),
				Vector2(30, 68),
				Vector2(34, 58),
				Vector2(34, 41.5),
				Vector2(46, 44),
				Vector2(56, 52),
				Vector2(62, 68),
				Vector2(70, 82),
				Vector2(76, 84.5)
			]
		},
		{
			"name": "Moraine track",
			"width": 3.5,
			"line": [Vector2(46, 44), Vector2(52, 30), Vector2(54, 16), Vector2(70, 16)]
		},
		{
			"name": "Valley road",
			"width": 4.0,
			"line":
			[
				Vector2(62, 68),
				Vector2(58, 100),
				Vector2(44, 120),
				Vector2(24, 134),
				Vector2(38, 140),
				Vector2(54, 140)
			]
		},
	],
	"landmarks":
	[
		{
			"name": "Boathouse",
			"asset": "cold/Boathouse",
			# Keep the solid footprint clear of the lakeshore electronics approach.
			"position": Vector2(63, 56),
			"heading": 0.0,
			"solid": 3.0,
			"sight_height": 4.5
		},
		{
			"name": "Farmhouse",
			"asset": "cold/FjordHouseRed",
			"position": Vector2(10, 122),
			"heading": 90.0,
			"solid": 3.6,
			"sight_height": 7.0
		},
		{
			"name": "Farmhouse",
			"asset": "cold/FjordHouseOchre",
			"position": Vector2(32, 116),
			"heading": 10.0,
			"solid": 3.6,
			"sight_height": 7.0
		},
		{
			"name": "Farmhouse",
			"asset": "cold/FjordHouseRed",
			"position": Vector2(12, 152),
			"heading": 0.0,
			"solid": 3.6,
			"sight_height": 7.0
		},
		{
			"name": "Chapel",
			"asset": "cold/FjordChapel",
			"position": Vector2(36, 152),
			"heading": 90.0,
			"solid": 4.6,
			"sight_height": 12.0
		},
		{
			"name": "Line pylon",
			"asset": "drylands/PowerPylon",
			"position": Vector2(80, 112),
			"solid": 1.6,
			"sight_height": 13.0
		},
		{
			"name": "Line pylon",
			"asset": "drylands/PowerPylon",
			"position": Vector2(54, 118),
			"solid": 1.6,
			"sight_height": 13.0
		},
		{
			"name": "Erratic",
			"asset": "cold/ErraticBoulder",
			"position": Vector2(54, 4),
			"heading": 30.0,
			"solid": 2.6,
			"sight_height": 3.0
		},
		{
			"name": "Erratic",
			"asset": "cold/ErraticBoulder",
			"position": Vector2(8, 104),
			"heading": -40.0,
			"solid": 2.6,
			"sight_height": 3.0
		},
	],
	"bases": [{"start": Vector2(22, 86), "field": Vector2(13, 83)}],
	"expansions":
	[
		{"name": "Birch hollow", "site": Vector2(22, 30), "field": Vector2(14.5, 25)},
		{"name": "Lakeshore flat", "site": Vector2(62, 72), "field": Vector2(55, 66)},
		{"name": "Moraine foot", "site": Vector2(58, 38), "field": Vector2(52, 30), "rich": true},
		{"name": "Gorge rim", "site": Vector2(68, 104), "field": Vector2(64, 112.5)},
		{"name": "Skarvik", "site": Vector2(24, 134), "field": Vector2(15, 139)},
		{"name": "Outwash bar", "site": Vector2(70, 146), "field": Vector2(64, 153), "rich": true},
	],
	"sites":
	[
		{
			"kind": "refinery",
			"position": Vector2(43, 126),
			"names": ["West Fjord Refinery", "East Fjord Refinery"]
		},
		{
			"kind": "repair",
			"position": Vector2(56, 47),
			"names": ["West Shore Repair Shop", "East Shore Repair Shop"]
		},
	],
	"shared":
	{
		"tiers":
		[
			{
				"name": "Terminal moraine",
				"height": 3.0,
				"polygon":
				[
					Vector2(64, 10),
					Vector2(72, 8),
					Vector2(84, 9),
					Vector2(96, 9),
					Vector2(108, 9),
					Vector2(120, 8),
					Vector2(128, 10),
					Vector2(130, 16),
					Vector2(128, 22),
					Vector2(120, 23),
					Vector2(108, 24),
					Vector2(96, 24),
					Vector2(84, 24),
					Vector2(72, 23),
					Vector2(64, 22),
					Vector2(62, 16)
				]
			},
			{
				"name": "Glacier snout",
				"height": 6.0,
				"walkable": false,
				"rock": "ice",
				"natural": true,
				"roughness": 1.5,
				"polygon":
				[
					Vector2(70, 0),
					Vector2(122, 0),
					Vector2(120, 4),
					Vector2(110, 7),
					Vector2(96, 8),
					Vector2(82, 7),
					Vector2(72, 4)
				]
			},
			{
				"name": "Gorge and outwash flats",
				"height": -3.0,
				"polygon":
				[
					Vector2(86, 88),
					Vector2(106, 88),
					Vector2(108, 104),
					Vector2(112, 118),
					Vector2(140, 124),
					Vector2(146, 140),
					Vector2(140, 160),
					Vector2(52, 160),
					Vector2(46, 140),
					Vector2(52, 124),
					Vector2(80, 118),
					Vector2(84, 104)
				]
			},
		],
		"water":
		[
			{
				"name": "Meltwater reservoir",
				"level": 0.0,
				"polygon":
				[
					Vector2(74, 30),
					Vector2(80, 32),
					Vector2(88, 33),
					Vector2(96, 33.5),
					Vector2(104, 33),
					Vector2(112, 32),
					Vector2(118, 30),
					Vector2(123, 35),
					Vector2(126, 44),
					Vector2(125, 54),
					Vector2(122, 62),
					Vector2(117, 70),
					Vector2(112, 76),
					Vector2(108, 82),
					Vector2(84, 82),
					Vector2(80, 76),
					Vector2(75, 70),
					Vector2(70, 62),
					Vector2(67, 54),
					Vector2(66, 44),
					Vector2(69, 35)
				]
			},
			{
				"name": "Glacier river",
				"level": -3.0,
				"line":
				[
					Vector2(96, 103),
					Vector2(95, 112),
					Vector2(98, 122),
					Vector2(94, 132),
					Vector2(96, 142),
					Vector2(97, 152),
					Vector2(96, 164)
				],
				"width": 7.0
			},
			{
				"name": "Braided ford",
				"level": -3.0,
				"ford": true,
				"polygon":
				[Vector2(84, 136), Vector2(108, 136), Vector2(108, 148), Vector2(84, 148)]
			},
		],
		"bridges": [{"level": 0.3, "line": [Vector2(76, 84.5), Vector2(116, 84.5)], "width": 7.0}],
		"landmarks":
		[
			{
				"name": "Narrows dam",
				"asset": "cold/HydroDam",
				"position": Vector2(96, 84.5),
				"heading": 180.0,
				"scale": 1.3
			},
			{
				"name": "Powerhouse",
				"asset": "cold/Powerhouse",
				"position": Vector2(96, 95.5),
				"heading": 180.0,
				"solid": 7.0,
				"sight_height": 10.0
			},
		],
		"sites": [{"kind": "mercenary", "position": Vector2(96, 16), "name": "Moraine Camp"}],
	},
	"ai":
	{
		"expand_order":
		["Birch hollow", "Lakeshore flat", "Moraine foot", "Gorge rim", "Skarvik", "Outwash bar"],
		# The moraine crest, the dam crest and the outwash ford.
		"lanes": [Vector2(96, 16), Vector2(96, 84.5), Vector2(96, 142)],
	},
}
