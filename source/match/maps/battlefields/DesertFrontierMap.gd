extends RefCounted

# Desert Frontier — a Mojave freight outpost. Each start holds a 3 m bajada
# bench with one ramp; its natural sits behind a sheltering rock wall. Two long
# sandstone escarpments, each broken by a pass, split the field into south,
# central and north routes. A water-stop town on the main line holds the
# contested camp; Joshua-tree flats, a cottonwood spring and oil leases fill
# the back country. Authored for the south-west start; the north-east start
# receives the 180-degree rotation.
const DEFINITION = {
	"events":
	[
		{
			"kind": "desert",
			"position": Vector2(76, 63),
			"candidates": [Vector2(80, 62), Vector2(73, 63), Vector2(84, 64)],
			"route": [Vector2(0, 60), Vector2(76, 63), Vector2(192, 65)]
		}
	],
	"id": "DesertFrontierMap",
	"name": "Desert Frontier",
	"revision": 1,
	"players": 2,
	"size": Vector2(192, 144),
	"symmetry": "rotate",
	"biome": "desert",
	"ground": "mojave",
	"backdrop": {"rise": 13.0},
	"tiers":
	[
		{
			"name": "Bajada bench",
			"height": 3.0,
			"natural": true,
			"polygon":
			[
				Vector2(0, 0),
				Vector2(56, 0),
				Vector2(60, 14),
				Vector2(52, 40),
				Vector2(30, 48),
				Vector2(0, 46)
			]
		},
		{
			"name": "South dune swell",
			"height": 1.6,
			"falloff": 9.0,
			"natural": true,
			"polygon":
			[Vector2(34, 96), Vector2(44, 95), Vector2(46, 103), Vector2(35, 104)]
		},
		{
			"name": "Pass ridge",
			"height": 1.4,
			"falloff": 8.0,
			"natural": true,
			"polygon":
			[Vector2(86, 46), Vector2(97, 47), Vector2(96, 54), Vector2(85, 53)]
		},
	],
	"ramps":
	[
		{
			"name": "Bench ramp",
			"from": Vector2(15.6, 56.0),
			"to": Vector2(14.6, 40.0),
			"width": 10.0,
			"from_height": 0.0,
			"to_height": 3.0
		},
	],
	"water":
	[
		{
			"name": "Cottonwood spring",
			"level": 0.0,
			"natural": true,
			"roughness": 0.6,
			"polygon":
			[
				Vector2(70, 126),
				Vector2(74, 123),
				Vector2(78, 125),
				Vector2(78, 130),
				Vector2(73, 132),
				Vector2(69, 130)
			]
		},
	],
	"blockers":
	[
		{
			"name": "South escarpment",
			"height": 6.0,
			"natural": true,
			"roughness": 1.8,
			"polygon": [Vector2(74, 16), Vector2(110, 32), Vector2(106, 41), Vector2(70, 25)]
		},
		{
			"name": "South escarpment",
			"height": 6.0,
			"natural": true,
			"roughness": 1.8,
			"polygon": [Vector2(122, 38), Vector2(152, 52), Vector2(148, 61), Vector2(118, 47)]
		},
		{
			"name": "Shelter wall",
			"height": 5.0,
			"natural": true,
			"roughness": 1.5,
			"polygon":
			[Vector2(46, 64), Vector2(55, 66), Vector2(57, 88), Vector2(48, 93), Vector2(43, 80)]
		},
	],
	"forests":
	[
		{
			"name": "Joshua flats",
			"density": 0.45,
			"natural": true,
			"polygon": [Vector2(28, 124), Vector2(50, 118), Vector2(56, 134), Vector2(34, 141)]
		},
		{
			"name": "Joshua stand",
			"density": 0.45,
			"natural": true,
			"polygon": [Vector2(60, 94), Vector2(76, 90), Vector2(80, 103), Vector2(64, 107)]
		},
		{
			"name": "Spring cottonwoods",
			"flora": "riparian",
			"density": 0.5,
			"natural": true,
			"polygon": [Vector2(64, 120), Vector2(84, 118), Vector2(86, 135), Vector2(66, 138)]
		},
	],
	"sands":
	[
		{
			"name": "Dry wash",
			"natural": true,
			"roughness": 2.5,
			"polygon":
			[Vector2(0, 84), Vector2(36, 80), Vector2(60, 86), Vector2(30, 94), Vector2(0, 92)]
		},
	],
	"roads":
	[
		{
			"name": "Outpost road",
			"width": 5.0,
			"line":
			[
				Vector2(24, 22),
				Vector2(14.6, 40.0),
				Vector2(15.6, 56.0),
				Vector2(34, 66),
				Vector2(66, 64),
				Vector2(96, 66)
			]
		},
		{
			"name": "Lease track",
			"width": 3.5,
			"line": [Vector2(60, 58), Vector2(68, 40), Vector2(80, 8), Vector2(124, 10)]
		},
		{
			"name": "Spring track",
			"width": 3.0,
			"line": [Vector2(28, 62), Vector2(24, 96), Vector2(40, 112), Vector2(60, 118)]
		},
	],
	"landmarks":
	[
		{
			"name": "Water stop",
			"asset": "drylands/RailWaterTower",
			"position": Vector2(84, 80),
			"heading": 0.0,
			"solid": 2.4,
			"sight_height": 9.0
		},
		{
			"name": "Freight depot",
			"asset": "desert/AbandonedFreightBay",
			"position": Vector2(70, 82),
			"heading": 0.0,
			"solid": 4.0,
			"sight_height": 4.0
		},
		{
			"name": "Siding boxcar",
			"asset": "drylands/DerelictBoxcar",
			"position": Vector2(58, 77),
			"heading": 0.0,
			"solid": 3.4,
			"sight_height": 3.6
		},
		{
			"name": "Signal",
			"asset": "drylands/SignalPost",
			"position": Vector2(46, 69),
			"heading": 0.0
		},
		{"name": "Line wire", "asset": "canyon/TelegraphPole", "position": Vector2(30, 76)},
		{"name": "Line wire", "asset": "canyon/TelegraphPole", "position": Vector2(10, 76)},
		{
			"name": "Lease fence",
			"asset": "canyon/FenceRun",
			"position": Vector2(76, 46),
			"heading": 20.0
		},
		{
			"name": "Main line",
			"asset": "drylands/RailSection",
			"position": Vector2(4, 72),
			"heading": 0.0
		},
		{
			"name": "Main line",
			"asset": "drylands/RailSection",
			"position": Vector2(12, 72),
			"heading": 0.0
		},
		{
			"name": "Main line",
			"asset": "drylands/RailSection",
			"position": Vector2(20, 72),
			"heading": 0.0
		},
		{
			"name": "Main line",
			"asset": "drylands/RailSection",
			"position": Vector2(28, 72),
			"heading": 0.0
		},
		{
			"name": "Main line",
			"asset": "drylands/RailSection",
			"position": Vector2(36, 72),
			"heading": 0.0
		},
		{
			"name": "Main line",
			"asset": "drylands/RailSection",
			"position": Vector2(44, 72),
			"heading": 0.0
		},
		{
			"name": "Main line",
			"asset": "drylands/RailSection",
			"position": Vector2(52, 72),
			"heading": 0.0
		},
		{
			"name": "Main line",
			"asset": "drylands/RailSection",
			"position": Vector2(60, 72),
			"heading": 0.0
		},
		{
			"name": "Main line",
			"asset": "drylands/RailSection",
			"position": Vector2(68, 72),
			"heading": 0.0
		},
		{
			"name": "Main line",
			"asset": "drylands/RailSection",
			"position": Vector2(76, 72),
			"heading": 0.0
		},
		{
			"name": "Main line",
			"asset": "drylands/RailSection",
			"position": Vector2(84, 72),
			"heading": 0.0
		},
		{
			"name": "Main line",
			"asset": "drylands/RailSection",
			"position": Vector2(92, 72),
			"heading": 0.0
		},
	],
	"bases": [{"start": Vector2(24, 22), "field": Vector2(17.6, 15.6)}],
	"expansions":
	[
		{"name": "Junction well", "site": Vector2(28, 64), "field": Vector2(19.2, 66)},
		{"name": "Joshua flats", "site": Vector2(20, 108), "field": Vector2(11.5, 110)},
		{
			"name": "Freight yard",
			"site": Vector2(80, 64),
			"field": Vector2(72.5, 59.5),
			"rich": true
		},
		{"name": "South siding", "site": Vector2(124, 16), "field": Vector2(132.5, 13)},
		{"name": "Wash spring", "site": Vector2(54, 116), "field": Vector2(46, 120)},
	],
	"sites":
	[
		{
			"kind": "refinery",
			"position": Vector2(66, 32),
			"names": ["North Oil Lease", "South Oil Lease"]
		},
		{
			"kind": "repair",
			"position": Vector2(36, 128),
			"names": ["West Ranch Garage", "East Ranch Garage"]
		},
	],
	"shared":
	{
		"sites": [{"kind": "mercenary", "position": Vector2(96, 72), "name": "Water Stop Camp"}],
	},
	"ai":
	{
		"expand_order":
		["Junction well", "Joshua flats", "Freight yard", "South siding", "Wash spring"],
		# The town on the main line and the south route past the escarpments.
		"lanes": [Vector2(96, 72), Vector2(116, 10)],
	},
}
