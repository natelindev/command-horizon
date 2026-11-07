extends RefCounted

# Alpine Relay — a Swiss alpine communications pass. A 9 m massif runs
# diagonally through the valley; two cols cut it, each holding a capture
# relay that grants local vision, and its ends leave a narrow bypass at each
# far corner. Each start holds a high alp along its side of the valley, with
# a hay meadow below, the cable-car valley station and mountain huts on the
# approaches, and weather stations on the ridge. Authored for the north-west
# start; the south-east start receives the 180-degree rotation.
const DEFINITION = {
	"events":
	[
		{
			"kind": "alpine",
			"position": Vector2(60, 65),
			"candidates": [Vector2(62, 68), Vector2(58, 62), Vector2(60, 61)],
			"route": []
		}
	],
	"id": "AlpineRelayMap",
	"name": "Alpine Relay",
	"revision": 1,
	"players": 2,
	"size": Vector2(192, 160),
	"symmetry": "rotate",
	"biome": "alpine",
	"ground": "alpine",
	"backdrop": {"rise": 30.0},
	"tiers":
	[
		{
			"name": "High alp",
			"height": 3.0,
			"natural": true,
			"polygon":
			[
				Vector2(0, 14),
				Vector2(20, 8),
				Vector2(36, 16),
				Vector2(42, 34),
				Vector2(40, 58),
				Vector2(32, 74),
				Vector2(14, 80),
				Vector2(0, 78)
			]
		},
		# The col first: the massif overwrites its ends, so the saddle meets
		# rock without a seam.
		{
			"name": "Relay col",
			"height": 3.0,
			"polygon":
			[Vector2(108.7, 44.6), Vector2(121.5, 31.9), Vector2(144.1, 54.5), Vector2(131.4, 67.3)]
		},
		{
			"name": "Massif",
			"height": 9.0,
			"walkable": false,
			"natural": true,
			"roughness": 2.0,
			"polygon":
			[
				Vector2(80.4, 75.8),
				Vector2(89.3, 64.8),
				Vector2(100.9, 56.7),
				Vector2(111.2, 44.3),
				Vector2(131.7, 64.8),
				Vector2(119.7, 75.4),
				Vector2(110.8, 86.4),
				Vector2(100.2, 95.6)
			]
		},
		{
			"name": "Massif",
			"height": 9.0,
			"walkable": false,
			"natural": true,
			"roughness": 2.0,
			"polygon":
			[
				Vector2(121.1, 34.4),
				Vector2(132.1, 25.6),
				Vector2(141.6, 18.1),
				Vector2(150.4, 15.7),
				Vector2(158.2, 17.8),
				Vector2(160.3, 25.6),
				Vector2(157.5, 34.0),
				Vector2(150.8, 44.3),
				Vector2(141.6, 54.9)
			]
		},
	],
	"ramps":
	[
		{
			"name": "Alp road",
			"from": Vector2(50, 46),
			"to": Vector2(34, 46),
			"width": 10.0,
			"from_height": 0.0,
			"to_height": 3.0
		},
		{
			"name": "Col switchback",
			"from": Vector2(109.4, 32.6),
			"to": Vector2(120.7, 43.9),
			"width": 9.0,
			"from_height": 0.0,
			"to_height": 3.0
		},
		{
			"name": "Col switchback",
			"from": Vector2(143.4, 66.6),
			"to": Vector2(132.1, 55.3),
			"width": 9.0,
			"from_height": 0.0,
			"to_height": 3.0
		},
	],
	"forests":
	[
		{
			"name": "Pass spruce",
			"density": 0.75,
			"natural": true,
			"roughness": 1.6,
			"polygon": [Vector2(92, 42), Vector2(102, 38), Vector2(106, 44), Vector2(96, 52)]
		},
		{
			"name": "Alp spruce",
			"density": 0.7,
			"natural": true,
			"roughness": 1.6,
			"polygon": [Vector2(12, 84), Vector2(26, 82), Vector2(28, 90), Vector2(14, 94)]
		},
		{
			"name": "Corner spruce",
			"density": 0.7,
			"natural": true,
			"roughness": 1.8,
			"polygon": [Vector2(0, 138), Vector2(10, 136), Vector2(14, 148), Vector2(2, 152)]
		},
	],
	"sands":
	[
		{
			"name": "Scree fan",
			"natural": true,
			"roughness": 1.6,
			"polygon": [Vector2(98, 22), Vector2(110, 22), Vector2(112, 30), Vector2(100, 32)]
		},
	],
	"roads":
	[
		{
			"name": "Pass road",
			"width": 5.0,
			"line":
			[
				Vector2(18, 44),
				Vector2(34, 46),
				Vector2(50, 46),
				Vector2(66, 38),
				Vector2(88, 34),
				Vector2(109.4, 32.6),
				Vector2(120.7, 43.9),
				Vector2(126.4, 49.6)
			]
		},
		{
			"name": "Valley road",
			"width": 4.0,
			"line": [Vector2(50, 46), Vector2(54, 70), Vector2(48.6, 93.4)]
		},
		{
			"name": "Hut track",
			"width": 3.5,
			"line":
			[Vector2(88, 34), Vector2(104, 18), Vector2(120, 14), Vector2(140, 6), Vector2(164, 6)]
		},
	],
	"landmarks":
	[
		{
			"name": "Cable valley station",
			"asset": "alpine/AbandonedCableStation",
			"position": Vector2(44, 84),
			"heading": 30.0,
			"solid": 4.4,
			"sight_height": 4.6
		},
		{
			"name": "Cable pylon",
			"asset": "cold/CablePylon",
			"position": Vector2(62, 84),
			"heading": -15.0,
			"solid": 1.6,
			"sight_height": 14.0
		},
		{
			"name": "Cable pylon",
			"asset": "cold/CablePylon",
			"position": Vector2(80, 76),
			"heading": -15.0,
			"solid": 1.6,
			"sight_height": 14.0
		},
		{
			"name": "Weather station",
			"asset": "alpine/MountainWeatherStation",
			"position": Vector2(100, 74),
			"heading": 45.0
		},
		{
			"name": "Peak",
			"asset": "alpine/AlpineMassifA",
			"position": Vector2(141.3, 34.7),
			"scale": 0.55
		},
		{
			"name": "Peak",
			"asset": "alpine/AlpineMassifB",
			"position": Vector2(108.7, 67.3),
			"heading": 120.0,
			"scale": 0.5
		},
		{
			"name": "Mountain hut",
			"asset": "cold/MountainHut",
			"position": Vector2(104, 8),
			"heading": 0.0,
			"solid": 5.0,
			"sight_height": 4.2
		},
		{
			"name": "Snow fence",
			"asset": "cold/SnowFence",
			"position": Vector2(56, 4),
			"heading": 10.0,
			"solid": 1.2,
			"sight_height": 2.4
		},
		{
			"name": "Snow fence",
			"asset": "cold/SnowFence",
			"position": Vector2(40, 110),
			"heading": -40.0,
			"solid": 1.2,
			"sight_height": 2.4
		},
	],
	"bases": [{"start": Vector2(18, 44), "field": Vector2(9.5, 40)}],
	"expansions":
	[
		{"name": "Hay meadow", "site": Vector2(66, 26), "field": Vector2(72, 17)},
		{"name": "Glacier shelf", "site": Vector2(74, 56), "field": Vector2(80, 48)},
		{"name": "Cable foot", "site": Vector2(34, 96), "field": Vector2(27, 102)},
		{"name": "Hut meadow", "site": Vector2(120, 14), "field": Vector2(128, 8), "rich": true},
		{"name": "Lower alp", "site": Vector2(16, 118), "field": Vector2(8, 126), "rich": true},
	],
	"sites":
	[
		{
			"kind": "refinery",
			"position": Vector2(84, 28),
			"names": ["North Pass Refinery", "South Pass Refinery"]
		},
		{
			"kind": "repair",
			"position": Vector2(54, 70),
			"names": ["North Alp Repair Shop", "South Alp Repair Shop"]
		},
	],
	"relays": [{"position": Vector2(126.4, 49.6), "names": ["North Relay", "South Relay"]}],
	"ai":
	{
		"expand_order": ["Hay meadow", "Glacier shelf", "Cable foot", "Hut meadow", "Lower alp"],
		# The relay col and the bypass past the massif's end.
		"lanes": [Vector2(126.4, 49.6), Vector2(152, 6)],
	},
}
