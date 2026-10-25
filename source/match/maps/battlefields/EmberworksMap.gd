extends RefCounted

# Emberworks — a Ruhr steelworks on its last shift, split by the works canal.
# Each start holds the workers' terraces on a hill above its colliery; the
# canal runs through the valley between them with a lock at its middle and
# only two crossings, a truss bridge at each end of the works. A blast furnace
# and a rolling mill wall each bank into alleys toward the bridges, a slag
# heap stands over each bridge as high ground, and garrisoned works offices
# face each other across the lock. Authored for the west start; the east
# start receives the 180-degree rotation.
const FURNACE_FOOTPRINTS = [
	[
		Vector2(6, 0),
		Vector2(4.2, 4.2),
		Vector2(0, 6),
		Vector2(-4.2, 4.2),
		Vector2(-6, 0),
		Vector2(-4.2, -4.2),
		Vector2(0, -6),
		Vector2(4.2, -4.2)
	],
	[Vector2(-7.8, 6.8), Vector2(7.8, 6.8), Vector2(7.8, 12.2), Vector2(-7.8, 12.2)],
	[Vector2(7, -2.5), Vector2(12, -2.5), Vector2(12, 2.5), Vector2(7, 2.5)],
	[Vector2(-14, -8.5), Vector2(-4, -8.5), Vector2(-4, 0.5), Vector2(-14, 0.5)],
]
const LONG_SHED = [[Vector2(-18, -7), Vector2(18, -7), Vector2(18, 7), Vector2(-18, 7)]]
const HEADFRAME = [
	[Vector2(-4, -3.5), Vector2(4, -3.5), Vector2(4, 3.5), Vector2(-4, 3.5)],
	[Vector2(-16, -4.5), Vector2(-9, -4.5), Vector2(-9, 4.5), Vector2(-16, 4.5)],
]
const DEFINITION = {
	"events":
	[
		{
			"kind": "industrial",
			"position": Vector2(85, 46),
			"candidates": [Vector2(86, 43), Vector2(85, 49), Vector2(86, 51)],
			"route": [Vector2(86, 18), Vector2(86, 47)]
		}
	],
	"id": "EmberworksMap",
	"name": "Emberworks",
	"revision": 1,
	"players": 2,
	"size": Vector2(192, 160),
	"symmetry": "rotate",
	"biome": "urban",
	"ground": "works",
	"texture_preset": "works",
	"backdrop": {"rise": 14.0},
	"tiers":
	[
		{
			"name": "Workers' terraces",
			"height": 3.0,
			"natural": true,
			"polygon":
			[
				Vector2(0, 52),
				Vector2(28, 50),
				Vector2(40, 62),
				Vector2(42, 96),
				Vector2(32, 108),
				Vector2(0, 110)
			]
		},
		{
			"name": "Slag heap",
			"height": 6.0,
			# Wide enough flanks for every slope cell to stay walkable.
			"falloff": 11.0,
			"polygon":
			[
				Vector2(64, 3),
				Vector2(78, 2),
				Vector2(81, 10),
				Vector2(78, 18),
				Vector2(65, 19),
				Vector2(61, 11)
			]
		},
	],
	"ramps":
	[
		{
			"name": "Terrace road",
			"from": Vector2(40, 50),
			"to": Vector2(28.3, 61.7),
			"width": 10.0,
			"from_height": 0.0,
			"to_height": 3.0
		},
	],
	"bridges": [{"level": 0.3, "line": [Vector2(82, 130), Vector2(110, 130)], "width": 8.0}],
	"forests":
	[
		{
			"name": "Colliery scrub",
			"density": 0.6,
			"natural": true,
			"roughness": 1.6,
			"polygon": [Vector2(0, 10), Vector2(12, 8), Vector2(14, 20), Vector2(2, 22)]
		},
		{
			"name": "Siding scrub",
			"density": 0.55,
			"natural": true,
			"roughness": 1.6,
			"polygon": [Vector2(60, 114), Vector2(72, 113), Vector2(74, 120), Vector2(62, 122)]
		},
	],
	"sands":
	[
		{
			"name": "Coal yard",
			"natural": true,
			"roughness": 1.2,
			"polygon": [Vector2(34, 6), Vector2(54, 4), Vector2(56, 20), Vector2(36, 22)]
		},
		{
			"name": "Slag tip",
			"natural": true,
			"roughness": 1.6,
			"polygon": [Vector2(62, 1), Vector2(80, 0), Vector2(83, 19), Vector2(63, 21)]
		},
	],
	"roads":
	[
		{
			"name": "Works road",
			"width": 5.0,
			"line":
			[
				Vector2(20, 80),
				Vector2(24, 68),
				Vector2(28.3, 61.7),
				Vector2(40, 50),
				Vector2(56, 38),
				Vector2(76, 30),
				Vector2(86, 30)
			]
		},
		{
			"name": "Pit lane",
			"width": 4.0,
			"line": [Vector2(40, 50), Vector2(34, 38), Vector2(30, 32)]
		},
		{
			"name": "Canal road",
			"width": 5.0,
			"line":
			[
				Vector2(40, 50),
				Vector2(46, 64),
				Vector2(46, 112),
				Vector2(60, 126),
				Vector2(82, 130),
				Vector2(110, 130)
			]
		},
		{"name": "Estate lane", "width": 3.5, "line": [Vector2(46, 112), Vector2(26, 126)]},
	],
	"rails":
	[
		# Dedicated delivery siding avoids the parked locomotives and ladle car.
		{"line": [Vector2(86, 12), Vector2(86, 48)]},
		{"line": [Vector2(4, 46), Vector2(36, 45), Vector2(48, 47), Vector2(54, 52)]},
		{"line": [Vector2(48, 47), Vector2(60, 40), Vector2(88, 40)]},
	],
	"landmarks":
	[
		{
			"name": "Colliery headframe",
			"asset": "works/Headframe",
			"position": Vector2(8, 40),
			"heading": 90.0,
			"footprints": HEADFRAME,
			"sight_height": 18.0
		},
		{
			"name": "Blast furnace",
			"asset": "works/BlastFurnace",
			"position": Vector2(66, 58),
			"heading": 0.0,
			"footprints": FURNACE_FOOTPRINTS,
			"sight_height": 22.0
		},
		{
			"name": "Rolling mill",
			"asset": "works/MillShedLong",
			"position": Vector2(68, 104),
			"heading": 0.0,
			"footprints": LONG_SHED,
			"sight_height": 13.0
		},
		{
			"name": "Gas holder",
			"asset": "works/Gasometer",
			"position": Vector2(52, 152),
			"solid": 8.8,
			"sight_height": 15.0
		},
		{
			"name": "Mill stack",
			"asset": "works/Chimney",
			"position": Vector2(80, 120),
			"solid": 2.6,
			"sight_height": 28.0
		},
		{
			"name": "Pipe bridge",
			"asset": "works/PipeRack",
			"position": Vector2(72, 92),
			"heading": 0.0
		},
		{
			"name": "Cooling tower",
			"asset": "works/CoolingTower",
			"position": Vector2(8, 152),
			"solid": 9.5,
			"sight_height": 21.0
		},
		{
			"name": "Coke pile",
			"asset": "works/CokePile",
			"position": Vector2(30, 12),
			"solid": 4.0,
			"sight_height": 3.0
		},
		{
			"name": "Ore train",
			"asset": "works/HopperWagon",
			"position": Vector2(24, 45.3),
			"heading": -1.8,
			"solid": 2.4,
			"sight_height": 4.0
		},
		{
			"name": "Ore train",
			"asset": "works/HopperWagon",
			"position": Vector2(14, 45.6),
			"heading": -1.8,
			"solid": 2.4,
			"sight_height": 4.0
		},
		{
			"name": "Ladle car",
			"asset": "works/TorpedoCar",
			"position": Vector2(76, 40),
			"heading": 0.0,
			"solid": 2.6,
			"sight_height": 4.5
		},
		{
			"name": "Canal barge",
			"asset": "coastal/CargoBarge",
			"position": Vector2(96, 104),
			"heading": 90.0
		},
		{
			"name": "Canal bridge",
			"asset": "works/CanalBridge",
			"position": Vector2(96, 130),
			"heading": 0.0
		},
	],
	"garrisons":
	[
		{"asset": "DamagedWarehouse", "position": Vector2(20, 142), "scale": 0.7, "radius": 5.6},
		{"asset": "ServiceOffice", "position": Vector2(82, 84), "scale": 0.75, "radius": 6.0},
	],
	"bases": [{"start": Vector2(20, 80), "field": Vector2(11, 77)}],
	"expansions":
	[
		{"name": "Colliery", "site": Vector2(30, 32), "field": Vector2(22, 26)},
		{"name": "Coal yard", "site": Vector2(46, 22), "field": Vector2(42, 13.5)},
		{"name": "Furnace yard", "site": Vector2(62, 84), "field": Vector2(54, 88), "rich": true},
		{"name": "Estate", "site": Vector2(26, 124), "field": Vector2(17, 128)},
		{"name": "Slag terrace", "site": Vector2(67, 10), "field": Vector2(75.5, 12)},
		{"name": "Canal wharf", "site": Vector2(66, 141), "field": Vector2(75, 145), "rich": true},
	],
	"sites":
	[
		{
			"kind": "refinery",
			"position": Vector2(30, 152),
			"names": ["West Coke Works", "East Coke Works"]
		},
		{
			"kind": "repair",
			"position": Vector2(8, 120),
			"names": ["West Works Repair Shop", "East Works Repair Shop"]
		},
	],
	"shared":
	{
		# The canal runs in a walled cut, its water well below the quays.
		"tiers":
		[
			{
				"name": "Canal cut",
				"height": -3.0,
				"rock": "retaining",
				"polygon": [Vector2(91, -2), Vector2(101, -2), Vector2(101, 162), Vector2(91, 162)]
			},
		],
		"water":
		[
			{
				"name": "Works canal",
				"level": -2.4,
				"polygon": [Vector2(91, -2), Vector2(101, -2), Vector2(101, 162), Vector2(91, 162)]
			},
		],
		"landmarks":
		[
			{
				"name": "Canal lock",
				"asset": "works/CanalLock",
				"position": Vector2(96, 80),
				"heading": 0.0
			},
		],
	},
	"ai":
	{
		"expand_order":
		["Colliery", "Coal yard", "Furnace yard", "Estate", "Slag terrace", "Canal wharf"],
		# The two canal bridges.
		"lanes": [Vector2(96, 130)],
	},
}
