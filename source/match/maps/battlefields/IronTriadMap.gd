extends RefCounted

# Iron Triad — a three-way industrial steelworks and rail terminal. Three
# foundry terraces overlook a Y-shaped slag canal, rail spurs and rolling
# cinder heaps around a central exchange yard. Authored for the north sector;
# 120-degree rotations preserve exact fairness across all three commanders.
const SHED = [[Vector2(-10, -5), Vector2(10, -5), Vector2(10, 5), Vector2(-10, 5)]]
const DEFINITION = {
	"id": "IronTriadMap",
	"name": "Iron Triad",
	"revision": 1,
	"players": 3,
	"size": Vector2(224, 224),
	"symmetry": "rotate",
	"biome": "urban",
	"ground": "works",
	"texture_preset": "works",
	"backdrop": {"rise": 14.0},
	"tiers":
	[
		{
			"name": "Foundry terrace",
			"height": 3.0,
			"rock": "retaining",
			"polygon":
			[
				Vector2(80, 2),
				Vector2(144, 2),
				Vector2(146, 36),
				Vector2(132, 48),
				Vector2(92, 48),
				Vector2(78, 36)
			]
		},
		{
			"name": "West slag heap",
			"height": 1.6,
			"falloff": 4.5,
			"natural": true,
			"polygon": [Vector2(70, 78), Vector2(80, 76), Vector2(82, 86), Vector2(72, 88)]
		},
		{
			"name": "East cinder bank",
			"height": 1.8,
			"falloff": 5.0,
			"natural": true,
			"polygon": [Vector2(152, 32), Vector2(166, 34), Vector2(164, 46), Vector2(150, 44)]
		},
	],
	"ramps":
	[
		{
			"name": "West haul ramp",
			"from": Vector2(88, 56),
			"to": Vector2(96, 40),
			"width": 10.0,
			"from_height": 0.0,
			"to_height": 3.0
		},
		{
			"name": "East haul ramp",
			"from": Vector2(136, 56),
			"to": Vector2(128, 40),
			"width": 10.0,
			"from_height": 0.0,
			"to_height": 3.0
		},
	],
	"water":
	[
		{
			"name": "Canal arm",
			"level": 0.0,
			"line": [Vector2(112, 92), Vector2(140, 86), Vector2(162, 74)],
			"width": 7.5
		},
		{
			"name": "Weir ford",
			"level": 0.0,
			"ford": true,
			"polygon": [Vector2(140, 74), Vector2(152, 74), Vector2(152, 88), Vector2(140, 88)]
		},
	],
	"bridges": [{"level": 0.3, "line": [Vector2(112, 82), Vector2(112, 96)], "width": 8.0}],
	"forests":
	[
		{
			"name": "Yard scrub",
			"density": 0.5,
			"natural": true,
			"polygon": [Vector2(66, 36), Vector2(76, 36), Vector2(76, 50), Vector2(64, 48)]
		},
		{
			"name": "Canal birch",
			"flora": "riparian",
			"density": 0.45,
			"natural": true,
			"polygon": [Vector2(118, 78), Vector2(132, 76), Vector2(134, 85), Vector2(120, 86)]
		},
	],
	"sands":
	[
		{
			"name": "Coal yard",
			"natural": true,
			"roughness": 1.5,
			"polygon": [Vector2(96, 58), Vector2(128, 58), Vector2(126, 74), Vector2(98, 74)]
		},
	],
	"roads":
	[
		{
			"name": "Works avenue",
			"width": 5.0,
			"line":
			[
				Vector2(112, 17),
				Vector2(96, 40),
				Vector2(88, 56),
				Vector2(112, 74),
				Vector2(112, 112)
			]
		},
		{
			"name": "Siding road",
			"width": 4.0,
			"line": [Vector2(112, 17), Vector2(128, 40), Vector2(136, 56), Vector2(144, 74)]
		},
	],
	"rails": [{"line": [Vector2(70, 56), Vector2(154, 56)]}],
	"landmarks":
	[
		{
			"name": "Mill shed",
			"asset": "works/MillShedLong",
			"position": Vector2(146, 42),
			"heading": 0.0,
			"footprints": SHED,
			"sight_height": 7.5
		},
		{
			"name": "Foundry stack",
			"asset": "works/Chimney",
			"position": Vector2(134, 42),
			"solid": 2.4,
			"sight_height": 18.0
		},
		{
			"name": "Water tower",
			"asset": "works/WaterTower",
			"position": Vector2(72, 44),
			"solid": 2.4,
			"sight_height": 11.0
		},
	],
	"bases": [{"start": Vector2(112, 17), "field": Vector2(112, 8.2)}],
	"expansions":
	[
		{"name": "West siding", "site": Vector2(84, 62), "field": Vector2(75.5, 60)},
		{"name": "East yard", "site": Vector2(140, 62), "field": Vector2(148.5, 60)},
		{"name": "Central spur", "site": Vector2(102, 76), "field": Vector2(94, 71), "rich": true},
		{"name": "Outer depot", "site": Vector2(62, 68), "field": Vector2(54, 65)},
	],
	"sites":
	[
		{
			"kind": "refinery",
			"position": Vector2(126, 74),
			"names": ["North Foundry Derrick", "South-East Foundry Derrick", "South-West Foundry Derrick"]
		},
		{
			"kind": "repair",
			"position": Vector2(96, 88),
			"names": ["North Railhead Shop", "South-East Railhead Shop", "South-West Railhead Shop"]
		},
	],
	"shared":
	{
		"sites": [{"kind": "mercenary", "position": Vector2(112, 112), "name": "Triad Exchange"}],
	},
	"ai":
	{
		"expand_order": ["West siding", "East yard", "Central spur", "Outer depot"],
		"lanes": [Vector2(112, 112), Vector2(146, 81)],
	},
}
