extends RefCounted

# Saltwind Basin — Bonneville/Atacama salt flats with a potash works. Each
# start holds a gravel rim terrace with one ramp onto the white pan; the rim
# continues north through a neck (narrowed by a gypsum dome) to a ledge with
# the natural expansion and its own ramp. The pan's centre is open and
# exposed around a contested camp; each side's back flank is a potash works
# whose brine ponds are crossed only on narrow dikes. Authored for the
# south-west start; the north-east start receives the 180-degree rotation.
const DEFINITION = {
	"id": "SaltwindBasinMap",
	"name": "Saltwind Basin",
	"revision": 1,
	"players": 2,
	"size": Vector2(192, 160),
	"symmetry": "rotate",
	"biome": "desert",
	"ground": "salt",
	"backdrop": {"rise": 9.0},
	"tiers":
	[
		{
			"name": "Rim terrace",
			"height": 3.0,
			"natural": true,
			"polygon":
			[
				Vector2(0, 0),
				Vector2(72, 0),
				Vector2(76, 12),
				Vector2(68, 24),
				Vector2(52, 30),
				Vector2(44, 48),
				Vector2(34, 58),
				Vector2(22, 61),
				Vector2(28, 66),
				Vector2(32, 80),
				Vector2(32, 100),
				Vector2(20, 106),
				Vector2(0, 106)
			]
		},
	],
	"ramps":
	[
		{
			"name": "Rim ramp",
			"from": Vector2(78.6, 22.4),
			"to": Vector2(67.0, 14.7),
			"width": 10.0,
			"from_height": 0.0,
			"to_height": 3.0
		},
		{
			"name": "Ledge ramp",
			"from": Vector2(29.6, 110.2),
			"to": Vector2(23.3, 97.6),
			"width": 9.0,
			"from_height": 0.0,
			"to_height": 3.0
		},
	],
	"water":
	[
		{
			"name": "Brine pond",
			"level": 0.0,
			"polygon": [Vector2(36, 116), Vector2(50, 116), Vector2(50, 128), Vector2(36, 128)]
		},
		{
			"name": "Brine pond",
			"level": 0.0,
			"polygon": [Vector2(54, 116), Vector2(68, 116), Vector2(68, 128), Vector2(54, 128)]
		},
		{
			"name": "Brine pond",
			"level": 0.0,
			"polygon": [Vector2(36, 132), Vector2(50, 132), Vector2(50, 146), Vector2(36, 146)]
		},
		{
			"name": "Brine pond",
			"level": 0.0,
			"polygon": [Vector2(54, 132), Vector2(68, 132), Vector2(68, 146), Vector2(54, 146)]
		},
	],
	"blockers":
	[
		{
			"name": "Gypsum dome",
			"height": 5.0,
			"natural": true,
			"roughness": 0.8,
			"polygon":
			[
				Vector2(0, 56),
				Vector2(7, 55),
				Vector2(11, 60),
				Vector2(10, 66),
				Vector2(4, 68),
				Vector2(0, 67)
			]
		},
	],
	"forests":
	[
		{
			"name": "Rim brush",
			"density": 0.6,
			"natural": true,
			"polygon": [Vector2(42, 5), Vector2(56, 4), Vector2(60, 14), Vector2(48, 19)]
		},
		{
			"name": "Ledge brush",
			"density": 0.6,
			"natural": true,
			"polygon": [Vector2(2, 88), Vector2(10, 86), Vector2(12, 96), Vector2(4, 100)]
		},
	],
	"sands":
	[
		{
			"name": "Pond margin mud",
			"natural": true,
			"roughness": 2.0,
			"polygon": [Vector2(32, 112), Vector2(72, 112), Vector2(74, 150), Vector2(32, 150)]
		},
	],
	"roads":
	[
		{
			"name": "Haul road",
			"width": 5.0,
			"line":
			[
				Vector2(24, 26),
				Vector2(46, 20),
				Vector2(67.0, 14.7),
				Vector2(78.6, 22.4),
				Vector2(88, 48),
				Vector2(96, 80)
			]
		},
		{
			"name": "Plant road",
			"width": 4.0,
			"line": [Vector2(23.3, 97.6), Vector2(29.6, 110.2), Vector2(30, 124), Vector2(20, 138)]
		},
		{"name": "Dike track", "width": 3.0, "line": [Vector2(32, 130), Vector2(72, 130)]},
		{"name": "Dike track", "width": 3.0, "line": [Vector2(52, 112), Vector2(52, 150)]},
	],
	"landmarks":
	[
		{
			"name": "Potash plant",
			"asset": "drylands/PotashPlant",
			"position": Vector2(14, 136),
			"heading": 90.0,
			"solid": 6.5,
			"sight_height": 9.0
		},
		{
			"name": "Product conveyor",
			"asset": "drylands/ConveyorRun",
			"position": Vector2(24, 146),
			"heading": 0.0
		},
		{
			"name": "Salt heap",
			"asset": "drylands/SaltHeap",
			"position": Vector2(8, 150),
			"solid": 2.8,
			"sight_height": 2.8
		},
		{
			"name": "Brine pumps",
			"asset": "drylands/BrinePumpHouse",
			"position": Vector2(72, 112),
			"heading": 90.0,
			"solid": 2.2,
			"sight_height": 2.2
		},
		{
			"name": "Plant power",
			"asset": "drylands/PowerPylon",
			"position": Vector2(64, 62),
			"solid": 1.6,
			"sight_height": 13.0
		},
		{
			"name": "Plant power",
			"asset": "drylands/PowerPylon",
			"position": Vector2(46, 92),
			"solid": 1.6,
			"sight_height": 13.0
		},
	],
	"bases": [{"start": Vector2(24, 26), "field": Vector2(17.2, 20.1)}],
	"expansions":
	[
		{"name": "West ledge", "site": Vector2(12, 82), "field": Vector2(3.5, 80)},
		{"name": "South flat", "site": Vector2(92, 14), "field": Vector2(100, 9)},
		{
			"name": "Pond works",
			"site": Vector2(52, 106),
			"field": Vector2(43.5, 103.5),
			"rich": true
		},
		{"name": "Open flat", "site": Vector2(68, 88), "field": Vector2(61, 93)},
		{"name": "Plant yard", "site": Vector2(28, 154), "field": Vector2(19.5, 155)},
	],
	"sites":
	[
		{
			"kind": "refinery",
			"position": Vector2(44, 72),
			"names": ["West Rim Refinery", "East Rim Refinery"]
		},
		{
			"kind": "repair",
			"position": Vector2(112, 26),
			"names": ["North Flat Repair Shop", "South Flat Repair Shop"]
		},
	],
	"shared":
	{
		"sites": [{"kind": "mercenary", "position": Vector2(96, 80), "name": "Salt Pan Camp"}],
	},
	"ai":
	{
		"expand_order": ["West ledge", "South flat", "Pond works", "Open flat", "Plant yard"],
		# The open pan and the dike causeways through each potash works.
		"lanes": [Vector2(96, 80), Vector2(52, 130)],
	},
}
