extends RefCounted

# Redrock Divide — Utah/Arizona canyon country. A 6 m sandstone mesa (the
# Divide) splits the map; armies cross by a broad dry wash with a collapsed
# rail trestle at its centre or by narrow slot canyons at either end. Each
# start holds a 3 m shelf with one ramp onto sheltered west flats (natural)
# behind a butte-guarded choke; a south canyon under its own cliffs carries a
# rich field and the slot route; an upper bench holds the third and fourth
# fields; a ramp from the canyon climbs onto the Divide, whose exposed top
# overlooks every crossing. Authored for the south-west start; the north-east
# start receives the 180-degree rotation.
const DEFINITION = {
	"events":
	[
		{
			"kind": "desert",
			"position": Vector2(80, 80),
			"candidates": [Vector2(78, 78), Vector2(83, 83), Vector2(80, 86)],
			"route": [Vector2(0, 79), Vector2(80, 80), Vector2(192, 81)]
		}
	],
	"id": "RedrockDivideMap",
	"name": "Redrock Divide",
	"revision": 1,
	"players": 2,
	"size": Vector2(192, 160),
	"symmetry": "rotate",
	"biome": "desert",
	"ground": "canyon",
	"tiers":
	[
		{
			"name": "Home shelf",
			"height": 3.0,
			"natural": true,
			"polygon":
			[
				Vector2(0, 0),
				Vector2(58, 0),
				Vector2(63, 16),
				Vector2(60, 40),
				Vector2(64, 62),
				Vector2(52, 66),
				Vector2(38, 64),
				Vector2(24, 62),
				Vector2(10, 64),
				Vector2(0, 60)
			]
		},
		{
			"name": "Divide south block",
			"height": 6.0,
			"walkable": false,
			"natural": true,
			"polygon":
			[
				Vector2(84, 0),
				Vector2(110, 0),
				Vector2(108, 10),
				Vector2(106, 20),
				Vector2(85, 20),
				Vector2(82, 10)
			]
		},
		{
			"name": "Divide",
			"height": 6.0,
			"natural": true,
			"polygon":
			[
				Vector2(85, 29),
				Vector2(107, 29),
				Vector2(105, 42),
				Vector2(108, 55),
				Vector2(104, 66),
				Vector2(106, 72),
				Vector2(86, 72),
				Vector2(88, 60),
				Vector2(84, 48),
				Vector2(86, 38)
			]
		},
		{
			"name": "Upper bench",
			"height": 3.0,
			"natural": true,
			"polygon":
			[
				Vector2(0, 110),
				Vector2(16, 106),
				Vector2(34, 110),
				Vector2(52, 108),
				Vector2(66, 112),
				Vector2(76, 120),
				Vector2(78, 128),
				Vector2(74, 146),
				Vector2(80, 160),
				Vector2(0, 160)
			]
		},
	],
	"ramps":
	[
		{
			"name": "Home ramp",
			"from": Vector2(37, 72),
			"to": Vector2(36, 57),
			"width": 10.0,
			"from_height": 0.0,
			"to_height": 3.0
		},
		{
			"name": "Divide climb",
			"from": Vector2(68, 50),
			"to": Vector2(91, 52),
			"width": 9.0,
			"from_height": 0.0,
			"to_height": 6.0
		},
		{
			"name": "Bench trail",
			"from": Vector2(26, 99),
			"to": Vector2(26, 117),
			"width": 9.0,
			"from_height": 0.0,
			"to_height": 3.0
		},
		{
			"name": "Slot mouth",
			"from": Vector2(83, 136),
			"to": Vector2(68, 136),
			"width": 9.0,
			"from_height": 0.0,
			"to_height": 3.0
		},
	],
	"water":
	[
		{
			"name": "Tinaja",
			"level": 0.0,
			"natural": true,
			"roughness": 0.6,
			"polygon":
			[
				Vector2(7, 96),
				Vector2(9.5, 93.2),
				Vector2(13, 92.4),
				Vector2(16.5, 94),
				Vector2(18, 97.5),
				Vector2(17, 101),
				Vector2(13.5, 103.4),
				Vector2(9.5, 102.8),
				Vector2(7.2, 100)
			]
		},
	],
	"blockers":
	[
		{
			"name": "Sentinel Butte",
			"height": 10.0,
			"kit": "butte",
			"natural": true,
			"roughness": 2.2,
			"polygon":
			[
				Vector2(55, 80),
				Vector2(61, 77.5),
				Vector2(66, 79),
				Vector2(68.5, 84),
				Vector2(70, 90),
				Vector2(68, 97),
				Vector2(64, 102.5),
				Vector2(58, 104),
				Vector2(53, 100),
				Vector2(50.5, 94),
				Vector2(52, 86)
			]
		},
		{
			"name": "Canyon hoodoos",
			"height": 7.0,
			"kit": "hoodoo",
			"natural": true,
			"roughness": 0.5,
			"polygon": [Vector2(74, 39), Vector2(78, 38), Vector2(79, 43), Vector2(75, 44)]
		},
		{
			"name": "Bench spires",
			"height": 8.0,
			"kit": "hoodoo",
			"natural": true,
			"roughness": 0.6,
			"polygon": [Vector2(44, 131), Vector2(49, 129), Vector2(51, 135), Vector2(46, 138)]
		},
	],
	"forests":
	[
		{
			"name": "Choke junipers",
			"density": 0.55,
			"natural": true,
			"polygon":
			[Vector2(40, 80), Vector2(48, 78), Vector2(50, 86), Vector2(42, 89), Vector2(38, 85)]
		},
		{
			"name": "Flats junipers",
			"density": 0.5,
			"natural": true,
			"polygon":
			[Vector2(4, 72), Vector2(14, 69), Vector2(18, 77), Vector2(10, 83), Vector2(3, 80)]
		},
		{
			"name": "Bench pinyon",
			"density": 0.5,
			"natural": true,
			"polygon":
			[Vector2(6, 124), Vector2(20, 120), Vector2(26, 129), Vector2(16, 137), Vector2(6, 134)]
		},
		{
			"name": "Canyon cottonwoods",
			"flora": "riparian",
			"density": 0.45,
			"natural": true,
			"polygon": [Vector2(64, 22), Vector2(72, 20), Vector2(74, 29), Vector2(66, 31)]
		},
	],
	"roads":
	[
		{
			"name": "Home road",
			"width": 5.0,
			"line":
			[
				Vector2(25, 27),
				Vector2(34, 48),
				Vector2(36, 57),
				Vector2(37, 72),
				Vector2(50, 74),
				Vector2(60, 72),
				Vector2(74, 74),
				Vector2(86, 80),
				Vector2(96, 80)
			]
		},
		{
			"name": "Canyon track",
			"width": 4.0,
			"line":
			[Vector2(64, 68), Vector2(70, 52), Vector2(70, 32), Vector2(78, 25), Vector2(96, 24.5)]
		},
		{
			"name": "Bench trail",
			"width": 3.5,
			"line":
			[
				Vector2(37, 74),
				Vector2(28, 88),
				Vector2(26, 99),
				Vector2(26, 117),
				Vector2(32, 130),
				Vector2(52, 141),
				Vector2(68, 136),
				Vector2(83, 136)
			]
		},
	],
	"sands":
	[
		{
			"name": "Wash floor",
			"natural": true,
			"polygon":
			[
				Vector2(76, 76),
				Vector2(88, 73),
				Vector2(104, 74),
				Vector2(116, 78),
				Vector2(96, 80),
				Vector2(80, 81)
			]
		},
		{
			"name": "Canyon floor sand",
			"natural": true,
			"roughness": 2.0,
			"polygon":
			[Vector2(64, 4), Vector2(80, 2), Vector2(82, 30), Vector2(72, 46), Vector2(65, 30)]
		},
		{
			"name": "Slot sand",
			"natural": true,
			"polygon": [Vector2(78, 22), Vector2(110, 21), Vector2(114, 28), Vector2(80, 28)]
		},
	],
	"landmarks":
	[
		{
			"name": "Collapsed trestle bent",
			"asset": "canyon/TrestleBent",
			"position": Vector2(96, 75),
			"heading": 0.0,
			"solid": 1.6,
			"sight_height": 6.5
		},
		{
			"name": "Trestle debris",
			"asset": "canyon/TrestleDebris",
			"position": Vector2(99, 79.5),
			"heading": 20.0
		},
		{
			"name": "Flats windmill",
			"asset": "canyon/Windmill",
			"position": Vector2(5, 87),
			"heading": 90.0,
			"solid": 1.2,
			"sight_height": 7.5
		},
		{
			"name": "Bench homestead",
			"asset": "canyon/RanchRuin",
			"position": Vector2(38, 152),
			"heading": 8.0,
			"solid": 3.3,
			"sight_height": 2.4
		},
		{
			"name": "Flats fence",
			"asset": "canyon/FenceRun",
			"position": Vector2(30, 70),
			"heading": -12.0
		},
		{
			"name": "Flats fence",
			"asset": "canyon/FenceRun",
			"position": Vector2(22, 72),
			"heading": -12.0
		},
		{"name": "Canyon wire", "asset": "canyon/TelegraphPole", "position": Vector2(67, 44)},
		{"name": "Canyon wire", "asset": "canyon/TelegraphPole", "position": Vector2(67, 26)},
		{"name": "Canyon wire", "asset": "canyon/TelegraphPole", "position": Vector2(74, 64)},
	],
	"bases": [{"start": Vector2(25, 27), "field": Vector2(19.6, 19.8)}],
	"expansions":
	[
		{"name": "West flats", "site": Vector2(22, 82), "field": Vector2(13.2, 83.8)},
		{"name": "Canyon floor", "site": Vector2(70, 14), "field": Vector2(78, 10), "rich": true},
		{"name": "Divide top", "site": Vector2(96, 46), "field": Vector2(96, 37), "rich": true},
		{"name": "Bench spring", "site": Vector2(22, 138), "field": Vector2(22, 147)},
		{"name": "Bench rim", "site": Vector2(54, 146), "field": Vector2(54, 155)},
		{"name": "Butte shadow", "site": Vector2(72, 108), "field": Vector2(80, 113)},
	],
	"sites":
	[
		{
			"kind": "refinery",
			"position": Vector2(42, 98),
			"names": ["West Flats Refinery", "East Flats Refinery"]
		},
		{
			"kind": "mercenary",
			"position": Vector2(66, 40),
			"names": ["North Canyon Camp", "South Canyon Camp"]
		},
		{
			"kind": "repair",
			"position": Vector2(40, 122),
			"names": ["West Bench Repair Shop", "East Bench Repair Shop"]
		},
	],
	"ai":
	{
		"expand_order":
		["West flats", "Canyon floor", "Bench spring", "Butte shadow", "Divide top", "Bench rim"],
		# Divide crossings: the central wash and the slot canyons at either end.
		"lanes": [Vector2(96, 80), Vector2(96, 24.5)],
	},
}
