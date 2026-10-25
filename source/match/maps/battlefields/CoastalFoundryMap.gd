extends RefCounted

# Coastal Foundry — a working harbour town with a ship foundry. Each start
# holds a cliff town above its fishing quay; between them the old fort hill
# stands over the town, the harbour basin cuts in from the sea, and the
# open water lies beyond a pier and the breakwater mole. The valley is
# crossed three ways: over the fort hill past its garrisoned magazine, by the
# swing bridge across the basin under the quay cranes, or out along the mole
# and over the harbour entrance. Each side keeps a foundry hall and a ship in
# dry dock. Authored for the north start; the south start is its mirror image.
const LONG_SHED = [[Vector2(-15, -7), Vector2(15, -7), Vector2(15, 7), Vector2(-15, 7)]]
# Portal cranes straddle the quay on four legs; units pass beneath them.
const CRANE_LEGS = [
	[Vector2(-3.7, -3.7), Vector2(-2.3, -3.7), Vector2(-2.3, -2.3), Vector2(-3.7, -2.3)],
	[Vector2(2.3, -3.7), Vector2(3.7, -3.7), Vector2(3.7, -2.3), Vector2(2.3, -2.3)],
	[Vector2(2.3, 2.3), Vector2(3.7, 2.3), Vector2(3.7, 3.7), Vector2(2.3, 3.7)],
	[Vector2(-3.7, 2.3), Vector2(-2.3, 2.3), Vector2(-2.3, 3.7), Vector2(-3.7, 3.7)],
]
const QUAY_SHED = [[Vector2(-20, -8), Vector2(20, -8), Vector2(20, 8), Vector2(-20, 8)]]
const DEFINITION = {
	"events":
	[
		{
			"kind": "coastal",
			"position": Vector2(146, 58),
			"candidates": [Vector2(144, 59), Vector2(148, 57), Vector2(145, 54)],
			"route": [Vector2(154, 68), Vector2(150, 62), Vector2(146, 58)]
		}
	],
	"id": "CoastalFoundryMap",
	"name": "Coastal Foundry",
	"revision": 1,
	"players": 2,
	"size": Vector2(192, 160),
	"symmetry": "mirror_y",
	"biome": "coastal",
	"ground": "harbour",
	"texture_preset": "coastal",
	"backdrop": {"rise": 16.0},
	"tiers":
	[
		{
			"name": "Cliff town",
			"height": 3.0,
			"natural": true,
			"polygon":
			[
				Vector2(0, 0),
				Vector2(52, 0),
				Vector2(58, 20),
				Vector2(50, 40),
				Vector2(30, 48),
				Vector2(0, 50)
			]
		},
		{
			"name": "Dry dock",
			"height": -6.0,
			"walkable": false,
			"rock": "retaining",
			"polygon": [Vector2(116, 41), Vector2(148, 41), Vector2(148, 54), Vector2(116, 54)]
		},
	],
	"ramps":
	[
		{
			"name": "Town steps",
			"from": Vector2(63.6, 26),
			"to": Vector2(47.6, 26),
			"width": 10.0,
			"from_height": 0.0,
			"to_height": 3.0
		},
		{
			"name": "Fort road",
			"from": Vector2(22, 57.5),
			"to": Vector2(22, 73.5),
			"width": 9.0,
			"from_height": 0.0,
			"to_height": 3.0
		},
	],
	"sands":
	[
		{
			"name": "Fishing beach",
			"natural": true,
			"roughness": 1.4,
			"polygon": [Vector2(62, 0), Vector2(98, 0), Vector2(96, 6), Vector2(64, 6)]
		},
	],
	"roads":
	[
		{
			"name": "Harbour road",
			"width": 5.0,
			"line":
			[
				Vector2(18, 14),
				Vector2(36, 22),
				Vector2(47.6, 26),
				Vector2(63.6, 26),
				Vector2(84, 30),
				Vector2(106, 36),
				Vector2(106, 54)
			]
		},
		{
			"name": "Fort road",
			"width": 4.0,
			"line": [Vector2(63.6, 26), Vector2(46, 46), Vector2(22, 57.5), Vector2(22, 73.5)]
		},
		{
			"name": "Mole road",
			"width": 4.0,
			"line": [Vector2(106, 36), Vector2(148, 34), Vector2(158, 40), Vector2(158, 68)]
		},
	],
	"landmarks":
	[
		{
			"name": "Foundry hall",
			"asset": "works/MillShedLong",
			# Shorten the west end to open the cliff approach without moving the
			# east wall into the shipyard deposits. Match the solid footprint.
			"position": Vector2(81, 44),
			"scale": Vector3(5.0 / 6.0, 1, 1),
			"heading": 0.0,
			"footprints": LONG_SHED,
			"sight_height": 13.0
		},
		{
			"name": "Quay shed",
			"asset": "harbour/QuayShed",
			"position": Vector2(126, 22),
			"heading": 0.0,
			"footprints": QUAY_SHED,
			"sight_height": 11.0
		},
		{
			"name": "Foundry stack",
			"asset": "works/Chimney",
			"position": Vector2(100, 46),
			"solid": 2.6,
			"sight_height": 28.0
		},
		{
			"name": "Ship in dry dock",
			"asset": "harbour/DryDockShip",
			"position": Vector2(132, 47.5),
			"heading": 0.0,
			"scale": 0.72
		},
		{
			"name": "Dock gate",
			"asset": "harbour/DockGate",
			"position": Vector2(148.5, 47.5),
			"heading": 0.0,
			"scale": 0.68
		},
		{
			"name": "Quay crane",
			"asset": "harbour/QuayCraneRed",
			"position": Vector2(124, 58),
			"heading": 0.0,
			"footprints": CRANE_LEGS,
			"sight_height": 19.0
		},
		{
			"name": "Quay crane",
			"asset": "harbour/QuayCraneBlue",
			"position": Vector2(140, 58),
			"heading": 0.0,
			"footprints": CRANE_LEGS,
			"sight_height": 19.0
		},
		{
			"name": "Coaster",
			"asset": "harbour/CargoShip",
			"position": Vector2(130, 68),
			"heading": 0.0,
			"scale": 0.7,
			"level": -2.7
		},
		{
			"name": "Fishing boat",
			"asset": "harbour/FishingBoat",
			"position": Vector2(84, 2),
			"heading": 170.0,
			"level": 0.0
		},
		{
			"name": "Harbour light",
			"asset": "harbour/Lighthouse",
			"position": Vector2(169, 23),
			"solid": 2.6,
			"sight_height": 20.0
		},
		{
			"name": "Breakwater",
			"asset": "coastal/HarborBreakwater",
			"position": Vector2(168, 52),
			"heading": 90.0
		},
		{
			"name": "Quay bollards",
			"asset": "harbour/Bollards",
			"position": Vector2(126, 61.5),
			"heading": 0.0
		},
	],
	"bases": [{"start": Vector2(18, 14), "field": Vector2(9.5, 10)}],
	"expansions":
	[
		{"name": "Fishing quay", "site": Vector2(76, 14), "field": Vector2(84, 8)},
		{"name": "Shipyard", "site": Vector2(106, 36), "field": Vector2(98, 31)},
		{"name": "Lower town", "site": Vector2(40, 56), "field": Vector2(50, 54)},
		{"name": "Pier head", "site": Vector2(156, 28), "field": Vector2(164, 32.5), "rich": true},
		{"name": "North quay", "site": Vector2(134, 7), "field": Vector2(143, 6), "rich": true},
	],
	"sites":
	[
		{
			"kind": "refinery",
			"position": Vector2(88, 20),
			"names": ["North Oil Terminal", "South Oil Terminal"]
		},
	],
	"shared":
	{
		"tiers":
		[
			{
				"name": "Fort hill",
				"height": 3.0,
				"polygon":
				[
					Vector2(16, 66),
					Vector2(60, 62),
					Vector2(92, 68),
					Vector2(96, 80),
					Vector2(92, 92),
					Vector2(60, 98),
					Vector2(16, 94),
					Vector2(10, 80)
				]
			},
			{
				"name": "Harbour basin",
				"height": -3.0,
				"rock": "retaining",
				"polygon": [Vector2(100, 62), Vector2(150, 62), Vector2(150, 98), Vector2(100, 98)]
			},
			{
				"name": "Outer harbour",
				"height": -3.0,
				"rock": "retaining",
				"polygon":
				[
					Vector2(150, -2),
					Vector2(194, -2),
					Vector2(194, 162),
					Vector2(150, 162),
					Vector2(150, 138),
					Vector2(170, 138),
					Vector2(170, 122),
					Vector2(166, 122),
					Vector2(166, 88),
					Vector2(150, 88),
					Vector2(150, 72),
					Vector2(166, 72),
					Vector2(166, 38),
					Vector2(170, 38),
					Vector2(170, 22),
					Vector2(150, 22)
				]
			},
		],
		"water":
		[
			{
				"name": "Harbour basin",
				"level": -2.4,
				"polygon": [Vector2(100, 62), Vector2(150, 62), Vector2(150, 98), Vector2(100, 98)]
			},
			{
				"name": "Outer harbour",
				"level": -2.4,
				"polygon":
				[
					Vector2(150, -2),
					Vector2(194, -2),
					Vector2(194, 162),
					Vector2(150, 162),
					Vector2(150, 138),
					Vector2(170, 138),
					Vector2(170, 122),
					Vector2(166, 122),
					Vector2(166, 88),
					Vector2(150, 88),
					Vector2(150, 72),
					Vector2(166, 72),
					Vector2(166, 38),
					Vector2(170, 38),
					Vector2(170, 22),
					Vector2(150, 22)
				]
			},
		],
		"bridges":
		[
			{"level": 0.3, "line": [Vector2(106, 58), Vector2(106, 102)], "width": 7.0},
			{"level": 0.3, "line": [Vector2(158, 69), Vector2(158, 91)], "width": 6.0},
		],
		"landmarks":
		[
			{
				"name": "Swing bridge",
				"asset": "works/CanalBridge",
				"position": Vector2(106, 70),
				"heading": 90.0
			},
			{
				"name": "Swing bridge",
				"asset": "works/CanalBridge",
				"position": Vector2(106, 90),
				"heading": 90.0
			},
			{
				"name": "Entrance bridge",
				"asset": "works/CanalBridge",
				"position": Vector2(158, 80),
				"heading": 90.0
			},
			{
				"name": "Harbour office",
				"asset": "harbour/HarbourOffice",
				"position": Vector2(84, 80),
				"heading": 90.0,
				"solid": 6.5,
				"sight_height": 22.0
			},
		],
		"garrisons":
		[{"asset": "DamagedWarehouse", "position": Vector2(44, 80), "scale": 0.75, "radius": 6.0}],
		"sites": [{"kind": "mercenary", "position": Vector2(64, 80), "name": "Fort Barracks"}],
	},
	"ai":
	{
		"expand_order": ["Fishing quay", "Shipyard", "Lower town", "North quay", "Pier head"],
		# Over the fort hill, the swing bridge and the harbour entrance.
		"lanes": [Vector2(22, 80), Vector2(106, 80), Vector2(158, 80)],
	},
}
