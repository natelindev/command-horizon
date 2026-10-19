extends RefCounted

# Hidden engine-verification battlefield: two tiers, an overlook, ramps, a
# pond, a stream with a ford, forest, a solid formation, roads and fields.
# Authored for the first start; the second receives the 180-degree rotation.
const DEFINITION = {
	"id": "TerrainTestMap",
	"name": "Terrain Test",
	"revision": 1,
	"players": 2,
	"size": Vector2(192, 160),
	"symmetry": "rotate",
	"biome": "canyon",
	"tiers":
	[
		{
			"height": 3.0,
			"polygon":
			[Vector2(0, 0), Vector2(56, 0), Vector2(56, 36), Vector2(40, 52), Vector2(0, 52)]
		},
		{
			"height": 6.0,
			"polygon": [Vector2(6, 64), Vector2(32, 64), Vector2(32, 84), Vector2(6, 84)]
		},
	],
	"ramps":
	[
		{
			"from": Vector2(55, 51),
			"to": Vector2(43, 39),
			"width": 8.0,
			"from_height": 0.0,
			"to_height": 3.0
		},
		{
			"from": Vector2(19, 104),
			"to": Vector2(19, 80),
			"width": 8.0,
			"from_height": 0.0,
			"to_height": 6.0
		},
		{
			"from": Vector2(96, 104),
			"to": Vector2(96, 90),
			"width": 8.0,
			"from_height": 0.0,
			"to_height": 3.0
		},
	],
	"water":
	[
		{
			"level": 0.0,
			"polygon":
			[
				Vector2(112, 22),
				Vector2(122, 18),
				Vector2(130, 24),
				Vector2(128, 34),
				Vector2(116, 34)
			]
		},
		{"level": 0.0, "line": [Vector2(140, 0), Vector2(146, 30), Vector2(160, 52)], "width": 6.0},
		{
			"level": 0.0,
			"ford": true,
			"polygon": [Vector2(158, 46), Vector2(166, 50), Vector2(162, 58), Vector2(154, 54)]
		},
	],
	"blockers":
	[
		{
			"height": 5.0,
			"polygon": [Vector2(110, 60), Vector2(118, 58), Vector2(121, 68), Vector2(112, 72)]
		},
	],
	"forests":
	[
		{
			"density": 0.6,
			"polygon": [Vector2(64, 100), Vector2(86, 96), Vector2(90, 118), Vector2(68, 124)]
		},
	],
	"roads":
	[
		{
			"width": 5.0,
			"line":
			[Vector2(24, 28), Vector2(43, 39), Vector2(55, 51), Vector2(80, 70), Vector2(88, 76)]
		},
	],
	"bases": [{"start": Vector2(24, 28), "field": Vector2(17.6, 21.6)}],
	"expansions": [{"site": Vector2(74, 18), "field": Vector2(82, 14)}],
	"sites":
	[
		{
			"kind": "refinery",
			"position": Vector2(70, 40),
			"names": ["West Refinery", "East Refinery"]
		},
	],
	"shared":
	{
		"tiers":
		[
			{
				"height": 3.0,
				"polygon":
				[
					Vector2(84, 74),
					Vector2(96, 66),
					Vector2(108, 74),
					Vector2(108, 86),
					Vector2(96, 94),
					Vector2(84, 86)
				]
			},
		],
	},
}
