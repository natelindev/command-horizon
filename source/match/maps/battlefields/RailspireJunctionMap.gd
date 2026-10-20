extends RefCounted

# Railspire Junction — a Chicago/Ruhr rail junction. Four track fields run in
# from the map edges between the corners and converge on the junction throat,
# where the garrisoned signal box stands. The track fields are flat and open,
# with long sightlines along the rails; each is crossed by a road overpass
# whose embankment halves are high ground, the tracks passing under its span.
# Each start holds a goods terrace in a corner with its goods yard below, an
# engine depot and a container terminal toward the next start. Authored for
# the start near (0, 0); the others receive 90-degree rotations.
const ENGINE_SHED = [[Vector2(-13, -9), Vector2(13, -9), Vector2(13, 9), Vector2(-13, 9)]]
const CONTAINERS = [[Vector2(-6, -4), Vector2(6, -4), Vector2(6, 4), Vector2(-6, 4)]]
const DEFINITION = {
	"id": "RailspireJunctionMap",
	"name": "Railspire Junction",
	"revision": 1,
	"players": 4,
	"size": Vector2(224, 224),
	"symmetry": "rotate",
	"biome": "urban",
	"ground": "works",
	"texture_preset": "works",
	"backdrop": {"rise": 10.0},
	"tiers":
	[
		{
			"name": "Goods terrace",
			"height": 3.0,
			"rock": "retaining",
			"polygon":
			[
				Vector2(0, 0),
				Vector2(52, 0),
				Vector2(56, 18),
				Vector2(50, 40),
				Vector2(30, 52),
				Vector2(0, 54)
			]
		},
		{
			"name": "Overpass embankment",
			"height": 3.0,
			"rock": "retaining",
			"polygon": [Vector2(60, 36), Vector2(80, 36), Vector2(80, 44), Vector2(60, 44)]
		},
		{
			"name": "Overpass embankment",
			"height": 3.0,
			"rock": "retaining",
			"polygon": [Vector2(90, 36), Vector2(106, 36), Vector2(106, 44), Vector2(90, 44)]
		},
	],
	"ramps":
	[
		{
			"name": "Terrace road",
			"from": Vector2(16, 62),
			"to": Vector2(16, 46),
			"width": 10.0,
			"from_height": 0.0,
			"to_height": 3.0
		},
		{
			"name": "Overpass approach",
			"from": Vector2(50, 40),
			"to": Vector2(66, 40),
			"width": 7.0,
			"from_height": 0.0,
			"to_height": 3.0
		},
		{
			"name": "Overpass approach",
			"from": Vector2(100, 56),
			"to": Vector2(100, 40),
			"width": 7.0,
			"from_height": 0.0,
			"to_height": 3.0
		},
	],
	"forests":
	[
		{
			"name": "Lineside scrub",
			"density": 0.6,
			"natural": true,
			"roughness": 1.6,
			"polygon": [Vector2(56, 98), Vector2(70, 96), Vector2(72, 106), Vector2(58, 108)]
		},
	],
	"sands":
	[
		{
			"name": "Track ballast",
			"polygon": [Vector2(68, -2), Vector2(96, -2), Vector2(96, 68), Vector2(68, 68)]
		},
	],
	"roads":
	[
		{
			"name": "Terrace road",
			"width": 5.0,
			"line":
			[
				Vector2(26, 24),
				Vector2(18, 36),
				Vector2(16, 46),
				Vector2(16, 62),
				Vector2(28, 72),
				Vector2(52, 68),
				Vector2(56, 52),
				Vector2(50, 40),
				Vector2(66, 40),
				Vector2(80, 40)
			]
		},
		{
			"name": "Depot lane",
			"width": 4.0,
			"line": [Vector2(28, 72), Vector2(46, 86), Vector2(66, 88), Vector2(84, 84)]
		},
	],
	"rails":
	[
		{"line": [Vector2(71, -2), Vector2(71, 68), Vector2(80, 84), Vector2(90, 92)]},
		{"line": [Vector2(78, -2), Vector2(78, 66), Vector2(86, 80), Vector2(94, 87)]},
		{"line": [Vector2(85, -2), Vector2(85, 64), Vector2(92, 76), Vector2(98, 82)]},
		{"line": [Vector2(92, -2), Vector2(92, 62), Vector2(97, 72), Vector2(102, 77)]},
		{"line": [Vector2(71, 68), Vector2(58, 84), Vector2(44, 92), Vector2(30, 92)]},
	],
	"landmarks":
	[
		{
			"name": "Overpass span",
			"asset": "works/OverpassSpan",
			"position": Vector2(85, 40),
			"heading": 0.0
		},
		{
			"name": "Engine depot",
			"asset": "works/EngineShed",
			"position": Vector2(30, 100),
			"heading": 0.0,
			"footprints": ENGINE_SHED,
			"sight_height": 12.0
		},
		{
			"name": "Water tower",
			"asset": "works/WaterTower",
			"position": Vector2(54, 74),
			"solid": 3.4,
			"sight_height": 14.0
		},
		{
			"name": "Signal gantry",
			"asset": "works/SignalGantry",
			"position": Vector2(81.5, 20),
			"heading": 0.0
		},
		{
			"name": "Signal gantry",
			"asset": "works/SignalGantry",
			"position": Vector2(81.5, 58),
			"heading": 0.0
		},
		{
			"name": "Container stack",
			"asset": "works/ContainerStack",
			"position": Vector2(64, 4),
			"heading": 90.0,
			"footprints": CONTAINERS,
			"sight_height": 7.8
		},
		{
			"name": "Freight train",
			"asset": "works/Boxcar",
			"position": Vector2(78, 24),
			"heading": 90.0,
			"solid": 1.6,
			"sight_height": 4.2
		},
		{
			"name": "Freight train",
			"asset": "works/Boxcar",
			"position": Vector2(78, 13.2),
			"heading": 90.0,
			"solid": 1.6,
			"sight_height": 4.2
		},
		{
			"name": "Freight train",
			"asset": "works/Locomotive",
			"position": Vector2(78, 3.2),
			"heading": 90.0,
			"solid": 1.6,
			"sight_height": 4.6
		},
		{
			"name": "Tank train",
			"asset": "works/TankWagon",
			"position": Vector2(92, 52),
			"heading": 90.0,
			"solid": 1.6,
			"sight_height": 4.2
		},
		{
			"name": "Buffer stop",
			"asset": "works/BufferStop",
			"position": Vector2(30, 92),
			"heading": 180.0
		},
	],
	"bases": [{"start": Vector2(26, 24), "field": Vector2(19, 18.5)}],
	"expansions":
	[
		{"name": "Goods yard", "site": Vector2(24, 76), "field": Vector2(12, 78)},
		{"name": "Container terminal", "site": Vector2(46, 108), "field": Vector2(54, 112)},
		{"name": "Overpass yard", "site": Vector2(60, 12), "field": Vector2(61, 26), "rich": true},
		{"name": "Coaling stage", "site": Vector2(104, 16), "field": Vector2(104, 26)},
		{
			"name": "Junction throat",
			"site": Vector2(84, 100),
			"field": Vector2(94, 104),
			"rich": true
		},
	],
	"sites":
	[
		{
			"kind": "refinery",
			"position": Vector2(8, 102),
			"names":
			[
				"North-West Fuel Depot",
				"North-East Fuel Depot",
				"South-East Fuel Depot",
				"South-West Fuel Depot"
			]
		},
		{
			"kind": "repair",
			"position": Vector2(42, 58),
			"names":
			[
				"North-West Locomotive Works",
				"North-East Locomotive Works",
				"South-East Locomotive Works",
				"South-West Locomotive Works"
			]
		},
	],
	"shared":
	{
		"garrisons":
		[{"asset": "ServiceOffice", "position": Vector2(112, 112), "scale": 0.8, "radius": 6.5}],
	},
	"ai":
	{
		"expand_order":
		["Goods yard", "Container terminal", "Coaling stage", "Junction throat", "Overpass yard"],
		# Each track field's overpass gap and the junction throat.
		"lanes": [Vector2(85, 40), Vector2(96, 96)],
	},
}
