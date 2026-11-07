extends RefCounted

# Pinebreak Valley — a Pacific Northwest logging valley. A river winds through
# the middle, crossed by a log bridge at the centre and a gravel ford on each
# side. Each start holds a logging-camp bench above the valley with a timber
# ridge behind it; dense fir and cedar stands carve the floor into ambush
# lanes between clear-cut expansions, a gravel bar and a sawmill by the river.
# Authored for the north-west start; the south-east start receives the
# 180-degree rotation.
const DEFINITION = {
	"id": "PinebreakValleyMap",
	"name": "Pinebreak Valley",
	"revision": 1,
	"players": 2,
	"size": Vector2(192, 160),
	"symmetry": "rotate",
	"biome": "temperate",
	"ground": "forest",
	"backdrop": {"rise": 22.0},
	"tiers":
	[
		{
			"name": "Camp bench",
			"height": 3.0,
			"natural": true,
			"polygon":
			[
				Vector2(0, 0),
				Vector2(60, 0),
				Vector2(66, 14),
				Vector2(58, 34),
				Vector2(42, 46),
				Vector2(18, 50),
				Vector2(0, 48)
			]
		},
		{
			"name": "Timber ridge",
			"height": 6.0,
			"walkable": false,
			"natural": true,
			"roughness": 1.8,
			"polygon":
			[Vector2(72, 0), Vector2(130, 0), Vector2(126, 9), Vector2(102, 14), Vector2(78, 10)]
		},
	],
	"ramps":
	[
		{
			"name": "Camp ramp",
			"from": Vector2(31.4, 56.5),
			"to": Vector2(29.0, 40.0),
			"width": 10.0,
			"from_height": 0.0,
			"to_height": 3.0
		},
	],
	"water":
	[
		{
			"name": "Pinebreak River",
			"level": 0.0,
			"line":
			[Vector2(-4, 106), Vector2(26, 97), Vector2(52, 100), Vector2(76, 88), Vector2(96, 80)],
			"width": 9.0
		},
		{
			"name": "Gravel ford",
			"level": 0.0,
			"ford": true,
			"polygon": [Vector2(34, 89), Vector2(46, 89), Vector2(46, 109), Vector2(34, 109)]
		},
	],
	"forests":
	[
		{
			"name": "East stand",
			"density": 0.7,
			"natural": true,
			"roughness": 2.0,
			"polygon":
			[Vector2(74, 24), Vector2(94, 22), Vector2(100, 40), Vector2(86, 50), Vector2(72, 42)]
		},
		{
			"name": "West stand",
			"density": 0.7,
			"natural": true,
			"roughness": 2.0,
			"polygon":
			[Vector2(4, 58), Vector2(26, 60), Vector2(30, 76), Vector2(16, 88), Vector2(2, 84)]
		},
		{
			"name": "Ridge stand",
			"density": 0.65,
			"natural": true,
			"roughness": 2.0,
			"polygon":
			[
				Vector2(118, 18),
				Vector2(150, 16),
				Vector2(156, 34),
				Vector2(136, 44),
				Vector2(116, 36)
			]
		},
		{
			"name": "Ridge timber",
			"density": 0.6,
			"natural": true,
			"polygon": [Vector2(76, 1), Vector2(126, 1), Vector2(124, 8), Vector2(80, 9)]
		},
		{
			"name": "Riverside alders",
			"flora": "riparian",
			"density": 0.55,
			"natural": true,
			"polygon": [Vector2(54, 88), Vector2(70, 82), Vector2(74, 86), Vector2(58, 94)]
		},
	],
	"sands":
	[
		{
			"name": "Gravel bar",
			"natural": true,
			"roughness": 1.6,
			"polygon": [Vector2(56, 70), Vector2(76, 70), Vector2(80, 80), Vector2(60, 84)]
		},
	],
	"roads":
	[
		{
			"name": "Logging road",
			"width": 5.0,
			"line":
			[
				Vector2(24, 24),
				Vector2(29.0, 40.0),
				Vector2(31.4, 56.5),
				Vector2(52, 64),
				Vector2(78, 66),
				Vector2(92.4, 71.9)
			]
		},
		{
			"name": "Ford track",
			"width": 3.5,
			"line": [Vector2(31.4, 56.5), Vector2(40, 72), Vector2(40, 89)]
		},
		{
			"name": "Ridge haul",
			"width": 4.0,
			"line": [Vector2(78, 66), Vector2(104, 52), Vector2(110, 26), Vector2(142, 12)]
		},
	],
	"landmarks":
	[
		{
			"name": "Sawmill",
			"asset": "temperate/Sawmill",
			"position": Vector2(98, 60),
			"heading": 30.0,
			"solid": 6.0,
			"sight_height": 4.2
		},
		{
			"name": "Log deck",
			"asset": "temperate/LogPile",
			"position": Vector2(86, 56),
			"heading": 30.0,
			"solid": 3.4,
			"sight_height": 2.2
		},
		{
			"name": "Log deck",
			"asset": "temperate/LogPile",
			"position": Vector2(56, 48),
			"heading": -20.0,
			"solid": 3.4,
			"sight_height": 2.2
		},
	],
	"bases": [{"start": Vector2(24, 24), "field": Vector2(17.6, 17.6)}],
	"expansions":
	[
		{"name": "Mill flat", "site": Vector2(52, 64), "field": Vector2(60.5, 61)},
		{"name": "Gravel bar", "site": Vector2(68, 74), "field": Vector2(68, 82.5), "rich": true},
		{"name": "Ridge cut", "site": Vector2(106, 28), "field": Vector2(114.5, 25)},
		{"name": "West ford", "site": Vector2(14, 98), "field": Vector2(6, 94)},
		{"name": "Timber landing", "site": Vector2(146, 46), "field": Vector2(154, 42)},
	],
	"sites":
	[
		{
			"kind": "refinery",
			"position": Vector2(112, 46),
			"names": ["North Valley Refinery", "South Valley Refinery"]
		},
		{
			"kind": "mercenary",
			"position": Vector2(128, 62),
			"names": ["North Logging Camp", "South Logging Camp"]
		},
	],
	"shared":
	{
		"bridges":
		[{"level": 0.3, "line": [Vector2(92.4, 71.9), Vector2(99.6, 88.1)], "width": 6.0}],
		"landmarks":
		[
			{
				"name": "Log bridge",
				"asset": "temperate/LogBridge",
				"position": Vector2(96, 80),
				"heading": 66.0
			},
		],
	},
	"ai":
	{
		"expand_order": ["Mill flat", "Gravel bar", "Ridge cut", "West ford", "Timber landing"],
		# The log bridge and the west gravel ford.
		"lanes": [Vector2(96, 80), Vector2(40, 99)],
	},
}
