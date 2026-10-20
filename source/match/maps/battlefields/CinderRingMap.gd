extends RefCounted

# Cinder Ring — an Icelandic/Hawaiian caldera. A lava lake smoulders at the
# heart of the crater, feeding a flow toward each corner; the crater rim
# stands as a high ring around it, breached between the corners, and each
# start climbs onto its own stretch of rim from outside and down into the
# crater from within. Each start holds an old lava shield in a corner with a
# steam field below it, the geothermal plant and its wellheads, and rich
# ground on the rim and on the crater floor. Authored for the start near
# (0, 0); the others receive 90-degree rotations.
const PLANT = [
	[Vector2(-9, -5.5), Vector2(9, -5.5), Vector2(9, 5.5), Vector2(-9, 5.5)],
	[
		Vector2(-1, -13),
		Vector2(-2.2, -9.8),
		Vector2(-5, -8.6),
		Vector2(-7.8, -9.8),
		Vector2(-9, -13),
		Vector2(-7.8, -16.2),
		Vector2(-5, -17.4),
		Vector2(-2.2, -16.2)
	],
	[
		Vector2(9, -13),
		Vector2(7.8, -9.8),
		Vector2(5, -8.6),
		Vector2(2.2, -9.8),
		Vector2(1, -13),
		Vector2(2.2, -16.2),
		Vector2(5, -17.4),
		Vector2(7.8, -16.2)
	],
]
const DEFINITION = {
	"id": "CinderRingMap",
	"name": "Cinder Ring",
	"revision": 1,
	"players": 4,
	"size": Vector2(224, 224),
	"symmetry": "rotate",
	"biome": "urban",
	"ground": "volcanic",
	"texture_preset": "desert",
	"backdrop": {"rise": 18.0},
	"tiers":
	[
		{
			"name": "Lava shield",
			"height": 3.0,
			"natural": true,
			"polygon":
			[
				Vector2(0, 0),
				Vector2(56, 0),
				Vector2(60, 18),
				Vector2(54, 38),
				Vector2(38, 52),
				Vector2(18, 58),
				Vector2(0, 58)
			]
		},
		{
			"name": "Crater rim",
			"height": 3.0,
			"natural": true,
			"roughness": 1.4,
			"polygon":
			[
				Vector2(52.91, 101.58),
				Vector2(54.28, 95.63),
				Vector2(56.24, 89.85),
				Vector2(58.78, 84.3),
				Vector2(61.87, 79.03),
				Vector2(65.48, 74.11),
				Vector2(69.57, 69.57),
				Vector2(74.11, 65.48),
				Vector2(79.03, 61.87),
				Vector2(84.3, 58.78),
				Vector2(89.85, 56.24),
				Vector2(95.63, 54.28),
				Vector2(101.58, 52.91),
				Vector2(104.36, 68.67),
				Vector2(100.0, 69.67),
				Vector2(95.75, 71.11),
				Vector2(91.68, 72.97),
				Vector2(87.82, 75.24),
				Vector2(84.21, 77.89),
				Vector2(80.89, 80.89),
				Vector2(77.89, 84.21),
				Vector2(75.24, 87.82),
				Vector2(72.97, 91.68),
				Vector2(71.11, 95.75),
				Vector2(69.67, 100.0),
				Vector2(68.67, 104.36)
			]
		},
	],
	"ramps":
	[
		{
			"name": "Shield road",
			"from": Vector2(65.1, 30.4),
			"to": Vector2(49.3, 25.7),
			"width": 10.0,
			"from_height": 0.0,
			"to_height": 3.0
		},
		{
			"name": "Rim climb",
			"from": Vector2(63.92, 63.92),
			"to": Vector2(73.82, 73.82),
			"width": 9.0,
			"from_height": 0.0,
			"to_height": 3.0
		},
		{
			"name": "Crater descent",
			"from": Vector2(79.37, 96.79),
			"to": Vector2(66.68, 90.87),
			"width": 8.0,
			"from_height": 0.0,
			"to_height": 3.0
		},
	],
	"water":
	[
		{
			"name": "Lava flow",
			"lava": true,
			"level": 0.0,
			"natural": true,
			"roughness": 1.2,
			"line": [Vector2(104.22, 104.22), Vector2(97.28, 95.65), Vector2(88.98, 89.77)],
			"width": 6.0
		},
	],
	"sands":
	[
		{
			"name": "Scoria field",
			"natural": true,
			"roughness": 2.0,
			"polygon": [Vector2(70, 2), Vector2(100, 4), Vector2(98, 30), Vector2(72, 32)]
		},
		{
			"name": "Crater cinders",
			"natural": true,
			"roughness": 2.0,
			"polygon": [Vector2(92, 74), Vector2(104, 70), Vector2(108, 84), Vector2(96, 90)]
		},
	],
	"forests":
	[
		{
			"name": "Ohia hollow",
			"density": 0.55,
			"natural": true,
			"roughness": 1.6,
			"polygon": [Vector2(4, 70), Vector2(18, 66), Vector2(22, 80), Vector2(8, 86)]
		},
	],
	"blockers":
	[
		{
			"name": "Basalt spire",
			"height": 5.0,
			"natural": true,
			"roughness": 0.8,
			"polygon": [Vector2(56, 100), Vector2(64, 98), Vector2(66, 106), Vector2(58, 109)]
		},
	],
	"roads":
	[
		{
			"name": "Shield road",
			"width": 5.0,
			"line":
			[
				Vector2(26, 24),
				Vector2(40, 24),
				Vector2(49.3, 25.7),
				Vector2(65.1, 30.4),
				Vector2(80, 20),
				Vector2(100, 40)
			]
		},
		{
			"name": "Rim track",
			"width": 4.0,
			"line":
			[Vector2(65.1, 30.4), Vector2(62, 52), Vector2(63.92, 63.92), Vector2(73.82, 73.82)]
		},
	],
	"landmarks":
	[
		{
			"name": "Geothermal plant",
			"asset": "volcanic/GeothermalPlant",
			"position": Vector2(36, 96),
			"heading": 0.0,
			"footprints": PLANT,
			"sight_height": 11.0
		},
		{
			"name": "Wellhead",
			"asset": "volcanic/Wellhead",
			"position": Vector2(72, 8),
			"heading": 0.0,
			"solid": 3.0,
			"sight_height": 4.4
		},
		{
			"name": "Wellhead",
			"asset": "volcanic/Wellhead",
			"position": Vector2(98, 14),
			"heading": 90.0,
			"solid": 3.0,
			"sight_height": 4.4
		},
		{
			"name": "Steam pipeline",
			"asset": "volcanic/Pipeline",
			"position": Vector2(86, 6),
			"heading": 0.0
		},
		{
			"name": "Volcano observatory",
			"asset": "volcanic/Observatory",
			"position": Vector2(68.39, 83.68),
			"heading": 120.0,
			"solid": 3.4,
			"sight_height": 9.0
		},
		{
			"name": "Fumarole",
			"asset": "volcanic/Fumarole",
			"position": Vector2(83.47, 102.73),
			"solid": 2.2,
			"sight_height": 1.8
		},
		{
			"name": "Fumarole",
			"asset": "volcanic/Fumarole",
			"position": Vector2(89.06, 79.23),
			"solid": 2.2,
			"sight_height": 1.8
		},
		{
			"name": "Basalt columns",
			"asset": "volcanic/BasaltColumn",
			"position": Vector2(46, 70),
			"solid": 1.4,
			"sight_height": 2.6
		},
	],
	"bases": [{"start": Vector2(26, 24), "field": Vector2(19, 19)}],
	"expansions":
	[
		{"name": "Steam field", "site": Vector2(80, 20), "field": Vector2(88, 14)},
		{"name": "Tephra flats", "site": Vector2(72, 50), "field": Vector2(80, 44)},
		{"name": "Ohia hollow", "site": Vector2(14, 98), "field": Vector2(8, 106)},
		{
			"name": "Rim terrace",
			"site": Vector2(86, 66.97),
			"field": Vector2(95.07, 62.83),
			"rich": true
		},
		{
			"name": "Crater floor",
			"site": Vector2(98.51, 78.62),
			"field": Vector2(101.02, 87.33),
			"rich": true
		},
	],
	"sites":
	[
		{
			"kind": "refinery",
			"position": Vector2(100, 42),
			"names":
			[
				"North-West Sulphur Works",
				"North-East Sulphur Works",
				"South-East Sulphur Works",
				"South-West Sulphur Works"
			]
		},
		{
			"kind": "repair",
			"position": Vector2(30, 70),
			"names":
			[
				"North-West Field Station",
				"North-East Field Station",
				"South-East Field Station",
				"South-West Field Station"
			]
		},
	],
	"shared":
	{
		"water":
		[
			{
				"name": "Lava lake",
				"lava": true,
				"level": 0.0,
				"polygon":
				[
					Vector2(124.0, 112.0),
					Vector2(124.59, 115.37),
					Vector2(123.29, 118.52),
					Vector2(120.49, 120.49),
					Vector2(117.48, 121.49),
					Vector2(114.84, 122.59),
					Vector2(112.0, 124.0),
					Vector2(108.63, 124.59),
					Vector2(105.48, 123.29),
					Vector2(103.51, 120.49),
					Vector2(102.51, 117.48),
					Vector2(101.41, 114.84),
					Vector2(100.0, 112.0),
					Vector2(99.41, 108.63),
					Vector2(100.71, 105.48),
					Vector2(103.51, 103.51),
					Vector2(106.52, 102.51),
					Vector2(109.16, 101.41),
					Vector2(112.0, 100.0),
					Vector2(115.37, 99.41),
					Vector2(118.52, 100.71),
					Vector2(120.49, 103.51),
					Vector2(121.49, 106.52),
					Vector2(122.59, 109.16)
				]
			},
		],
	},
	"ai":
	{
		"expand_order":
		["Steam field", "Tephra flats", "Ohia hollow", "Rim terrace", "Crater floor"],
		# The breach toward the next start, the rim climb, and the outer road.
		"lanes": [Vector2(112, 60), Vector2(68.9, 68.9), Vector2(112, 30)],
	},
}
