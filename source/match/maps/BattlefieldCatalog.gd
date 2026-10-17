# gdlint: disable=max-file-lines
extends RefCounted

# Explicit layouts; order is stable for resource and facility save identities.
const MAPS = {
	"RedrockDivide":
	{
		"name": "Redrock Divide",
		"players": 2,
		"size": Vector2(192.0000, 160.0000),
		"biome": "desert",
		"description": "Three canyon crossings with rich outer flanks.",
		"low": Color("774936"),
		"high": Color("b98b60"),
		"road": Color("956a46"),
		"surface": 0,
		"starts": [Vector2(24.0000, 28.0000), Vector2(168.0000, 132.0000)],
		"fields":
		[
			Vector2(38.5922, 38.5388),
			Vector2(153.4078, 121.4612),
			Vector2(174.0000, 36.0000),
			Vector2(18.0000, 124.0000),
			Vector2(144.0000, 72.0000),
			Vector2(48.0000, 88.0000),
			Vector2(138.0000, 18.0000),
			Vector2(54.0000, 142.0000)
		],
		"ridges":
		[
			Vector2(96.0000, 20.0000),
			Vector2(96.0000, 140.0000),
			Vector2(96.0000, 33.0000),
			Vector2(96.0000, 127.0000),
			Vector2(96.0000, 66.0000),
			Vector2(96.0000, 94.0000)
		],
		"radius": 6.0,
		"water": [],
		"water_radius": 0.0,
		"models": ["desert/SandstoneShelfA", "desert/SandstoneShelfC"],
		"roads":
		[
			Vector4(28.000, 36.000, 164.000, 36.000),
			Vector4(28.000, 80.000, 164.000, 80.000),
			Vector4(28.000, 124.000, 164.000, 124.000),
			Vector4(28.000, 28.000, 28.000, 132.000),
			Vector4(164.000, 28.000, 164.000, 132.000)
		],
		"sites":
		[
			{"kind": "refinery", "position": Vector2(66.0000, 60.0000), "name": "Refinery 1"},
			{"kind": "refinery", "position": Vector2(126.0000, 100.0000), "name": "Refinery 2"},
			{
				"kind": "mercenary",
				"position": Vector2(120.0000, 48.0000),
				"name": "Mercenary Camp 1"
			},
			{
				"kind": "mercenary",
				"position": Vector2(72.0000, 112.0000),
				"name": "Mercenary Camp 2"
			},
			{"kind": "repair", "position": Vector2(18.0000, 72.0000), "name": "Repair Shop 1"},
			{"kind": "repair", "position": Vector2(174.0000, 88.0000), "name": "Repair Shop 2"}
		]
	},
	"SaltwindBasin":
	{
		"name": "Saltwind Basin",
		"players": 2,
		"size": Vector2(192.0000, 160.0000),
		"biome": "desert",
		"description": "A pale salt pan: exposed center, sheltered edge expansions.",
		"low": Color("aaa58d"),
		"high": Color("dbd1ae"),
		"road": Color("8c8573"),
		"surface": 1,
		"starts": [Vector2(24.0000, 28.0000), Vector2(168.0000, 132.0000)],
		"fields":
		[
			Vector2(38.5922, 38.5388),
			Vector2(153.4078, 121.4612),
			Vector2(174.0000, 18.0000),
			Vector2(18.0000, 142.0000),
			Vector2(168.0000, 66.0000),
			Vector2(24.0000, 94.0000),
			Vector2(96.0000, 18.0000),
			Vector2(96.0000, 142.0000)
		],
		"ridges":
		[
			Vector2(72.0000, 52.0000),
			Vector2(120.0000, 108.0000),
			Vector2(120.0000, 52.0000),
			Vector2(72.0000, 108.0000)
		],
		"radius": 6.0,
		"water": [Vector2(96.0000, 80.0000)],
		"water_radius": 13.0,
		"models": ["desert/SandstoneShelfD", "desert/FrontierExtractionRig"],
		"roads":
		[
			Vector4(148.000, 80.000, 132.770, 116.770),
			Vector4(132.770, 116.770, 96.000, 132.000),
			Vector4(96.000, 132.000, 59.230, 116.770),
			Vector4(59.230, 116.770, 44.000, 80.000),
			Vector4(44.000, 80.000, 59.230, 43.230),
			Vector4(59.230, 43.230, 96.000, 28.000),
			Vector4(96.000, 28.000, 132.770, 43.230),
			Vector4(132.770, 43.230, 148.000, 80.000),
			Vector4(24.000, 28.000, 59.230, 43.230),
			Vector4(168.000, 132.000, 132.770, 116.770)
		],
		"sites":
		[
			{"kind": "refinery", "position": Vector2(138.0000, 24.0000), "name": "Refinery 1"},
			{"kind": "refinery", "position": Vector2(54.0000, 136.0000), "name": "Refinery 2"},
			{
				"kind": "mercenary",
				"position": Vector2(48.0000, 72.0000),
				"name": "Mercenary Camp 1"
			},
			{
				"kind": "mercenary",
				"position": Vector2(144.0000, 88.0000),
				"name": "Mercenary Camp 2"
			},
			{"kind": "repair", "position": Vector2(66.0000, 18.0000), "name": "Repair Shop 1"},
			{"kind": "repair", "position": Vector2(126.0000, 142.0000), "name": "Repair Shop 2"}
		]
	},
	"PinebreakValley":
	{
		"name": "Pinebreak Valley",
		"players": 2,
		"size": Vector2(192.0000, 160.0000),
		"biome": "temperate",
		"description": "Wooded islands split a winding valley into ambush lanes.",
		"low": Color("394e39"),
		"high": Color("748160"),
		"road": Color("77715a"),
		"surface": 0,
		"starts": [Vector2(24.0000, 28.0000), Vector2(168.0000, 132.0000)],
		"fields":
		[
			Vector2(38.5922, 38.5388),
			Vector2(153.4078, 121.4612),
			Vector2(174.0000, 54.0000),
			Vector2(18.0000, 106.0000),
			Vector2(156.0000, 18.0000),
			Vector2(36.0000, 142.0000),
			Vector2(78.0000, 18.0000),
			Vector2(114.0000, 142.0000)
		],
		"ridges":
		[
			Vector2(64.0000, 68.0000),
			Vector2(128.0000, 92.0000),
			Vector2(77.0000, 66.0000),
			Vector2(115.0000, 94.0000),
			Vector2(108.0000, 35.0000),
			Vector2(84.0000, 125.0000),
			Vector2(119.0000, 33.0000),
			Vector2(73.0000, 127.0000)
		],
		"radius": 6.0,
		"water": [],
		"water_radius": 0.0,
		"models": ["coastal/CoastalPineStand", "industrial-surroundings/BirchScrub"],
		"roads":
		[
			Vector4(24.000, 28.000, 56.000, 52.000),
			Vector4(56.000, 52.000, 80.000, 96.000),
			Vector4(80.000, 96.000, 136.000, 108.000),
			Vector4(136.000, 108.000, 168.000, 132.000)
		],
		"sites":
		[
			{"kind": "refinery", "position": Vector2(138.0000, 60.0000), "name": "Refinery 1"},
			{"kind": "refinery", "position": Vector2(54.0000, 100.0000), "name": "Refinery 2"},
			{
				"kind": "mercenary",
				"position": Vector2(30.0000, 72.0000),
				"name": "Mercenary Camp 1"
			},
			{
				"kind": "mercenary",
				"position": Vector2(162.0000, 88.0000),
				"name": "Mercenary Camp 2"
			},
			{"kind": "repair", "position": Vector2(108.0000, 66.0000), "name": "Repair Shop 1"},
			{"kind": "repair", "position": Vector2(84.0000, 94.0000), "name": "Repair Shop 2"}
		]
	},
	"GlacierNarrows":
	{
		"name": "Glacier Narrows",
		"players": 2,
		"size": Vector2(192.0000, 160.0000),
		"biome": "alpine",
		"description": "Frozen meltwater divides two broad mountain passes.",
		"low": Color("728b96"),
		"high": Color("c5d1ce"),
		"road": Color("566c76"),
		"surface": 2,
		"starts": [Vector2(24.0000, 28.0000), Vector2(168.0000, 132.0000)],
		"fields":
		[
			Vector2(38.5922, 38.5388),
			Vector2(153.4078, 121.4612),
			Vector2(174.0000, 24.0000),
			Vector2(18.0000, 136.0000),
			Vector2(150.0000, 66.0000),
			Vector2(42.0000, 94.0000),
			Vector2(132.0000, 24.0000),
			Vector2(60.0000, 136.0000)
		],
		"ridges":
		[
			Vector2(96.0000, 30.0000),
			Vector2(96.0000, 130.0000),
			Vector2(96.0000, 18.0000),
			Vector2(96.0000, 142.0000)
		],
		"radius": 6.0,
		"water": [Vector2(96.0000, 60.0000), Vector2(96.0000, 100.0000)],
		"water_radius": 12.0,
		"models": ["alpine/GlacialShelfB", "alpine/AbandonedCableStation"],
		"roads":
		[
			Vector4(28.000, 36.000, 164.000, 36.000),
			Vector4(28.000, 80.000, 164.000, 80.000),
			Vector4(28.000, 124.000, 164.000, 124.000),
			Vector4(28.000, 28.000, 28.000, 132.000),
			Vector4(164.000, 28.000, 164.000, 132.000)
		],
		"sites":
		[
			{"kind": "refinery", "position": Vector2(60.0000, 66.0000), "name": "Refinery 1"},
			{"kind": "refinery", "position": Vector2(132.0000, 94.0000), "name": "Refinery 2"},
			{
				"kind": "mercenary",
				"position": Vector2(18.0000, 72.0000),
				"name": "Mercenary Camp 1"
			},
			{
				"kind": "mercenary",
				"position": Vector2(174.0000, 88.0000),
				"name": "Mercenary Camp 2"
			},
			{"kind": "repair", "position": Vector2(66.0000, 18.0000), "name": "Repair Shop 1"},
			{"kind": "repair", "position": Vector2(126.0000, 142.0000), "name": "Repair Shop 2"}
		]
	},
	"Emberworks":
	{
		"name": "Emberworks",
		"players": 2,
		"size": Vector2(192.0000, 160.0000),
		"biome": "urban",
		"description": "Abandoned furnaces and service alleys around a central works.",
		"low": Color("343b3c"),
		"high": Color("68695f"),
		"road": Color("827c68"),
		"surface": 3,
		"starts": [Vector2(24.0000, 28.0000), Vector2(168.0000, 132.0000)],
		"fields":
		[
			Vector2(38.5922, 38.5388),
			Vector2(153.4078, 121.4612),
			Vector2(174.0000, 18.0000),
			Vector2(18.0000, 142.0000),
			Vector2(162.0000, 66.0000),
			Vector2(30.0000, 94.0000),
			Vector2(132.0000, 18.0000),
			Vector2(60.0000, 142.0000)
		],
		"ridges":
		[
			Vector2(78.0000, 62.0000),
			Vector2(114.0000, 98.0000),
			Vector2(114.0000, 62.0000),
			Vector2(78.0000, 98.0000),
			Vector2(96.0000, 28.0000),
			Vector2(96.0000, 132.0000)
		],
		"radius": 6.0,
		"water": [],
		"water_radius": 0.0,
		"models": ["industrial/FurnaceBlock", "industrial/DamagedWarehouse"],
		"roads":
		[
			Vector4(18.000, 34.000, 174.000, 34.000),
			Vector4(50.000, 18.000, 50.000, 142.000),
			Vector4(18.000, 80.000, 174.000, 80.000),
			Vector4(96.000, 18.000, 96.000, 142.000),
			Vector4(18.000, 126.000, 174.000, 126.000),
			Vector4(142.000, 18.000, 142.000, 142.000)
		],
		"sites":
		[
			{"kind": "refinery", "position": Vector2(66.0000, 18.0000), "name": "Refinery 1"},
			{"kind": "refinery", "position": Vector2(126.0000, 142.0000), "name": "Refinery 2"},
			{
				"kind": "mercenary",
				"position": Vector2(138.0000, 48.0000),
				"name": "Mercenary Camp 1"
			},
			{
				"kind": "mercenary",
				"position": Vector2(54.0000, 112.0000),
				"name": "Mercenary Camp 2"
			},
			{"kind": "repair", "position": Vector2(54.0000, 72.0000), "name": "Repair Shop 1"},
			{"kind": "repair", "position": Vector2(138.0000, 88.0000), "name": "Repair Shop 2"}
		]
	},
	"CinderRing":
	{
		"name": "Cinder Ring",
		"players": 4,
		"size": Vector2(224.0000, 224.0000),
		"biome": "desert",
		"description": "A black volcanic caldera with an open outer circuit.",
		"low": Color("373437"),
		"high": Color("71605a"),
		"road": Color("8c7962"),
		"surface": 4,
		"starts":
		[
			Vector2(28.0000, 28.0000),
			Vector2(196.0000, 28.0000),
			Vector2(196.0000, 196.0000),
			Vector2(28.0000, 196.0000)
		],
		"fields":
		[
			Vector2(40.7279, 40.7279),
			Vector2(183.2721, 40.7279),
			Vector2(183.2721, 183.2721),
			Vector2(40.7279, 183.2721),
			Vector2(108.0000, 18.0000),
			Vector2(206.0000, 108.0000),
			Vector2(116.0000, 206.0000),
			Vector2(18.0000, 116.0000),
			Vector2(84.0000, 54.0000),
			Vector2(170.0000, 84.0000),
			Vector2(140.0000, 170.0000),
			Vector2(54.0000, 140.0000)
		],
		"ridges":
		[
			Vector2(91.0000, 102.0000),
			Vector2(122.0000, 91.0000),
			Vector2(133.0000, 122.0000),
			Vector2(102.0000, 133.0000),
			Vector2(81.0000, 96.0000),
			Vector2(128.0000, 81.0000),
			Vector2(143.0000, 128.0000),
			Vector2(96.0000, 143.0000)
		],
		"radius": 6.0,
		"water": [Vector2(112.0000, 112.0000)],
		"water_radius": 13.0,
		"models": ["desert/CanyonMesa2", "quarry/QuarryBenchA"],
		"roads":
		[
			Vector4(177.000, 112.000, 157.962, 157.962),
			Vector4(157.962, 157.962, 112.000, 177.000),
			Vector4(112.000, 177.000, 66.038, 157.962),
			Vector4(66.038, 157.962, 47.000, 112.000),
			Vector4(47.000, 112.000, 66.038, 66.038),
			Vector4(66.038, 66.038, 112.000, 47.000),
			Vector4(112.000, 47.000, 157.962, 66.038),
			Vector4(157.962, 66.038, 177.000, 112.000),
			Vector4(28.000, 28.000, 66.038, 66.038),
			Vector4(196.000, 28.000, 157.962, 66.038),
			Vector4(196.000, 196.000, 157.962, 157.962),
			Vector4(28.000, 196.000, 66.038, 157.962)
		],
		"sites":
		[
			{"kind": "refinery", "position": Vector2(42.0000, 84.0000), "name": "Refinery 1"},
			{"kind": "refinery", "position": Vector2(140.0000, 42.0000), "name": "Refinery 2"},
			{"kind": "refinery", "position": Vector2(182.0000, 140.0000), "name": "Refinery 3"},
			{"kind": "refinery", "position": Vector2(84.0000, 182.0000), "name": "Refinery 4"},
			{
				"kind": "mercenary",
				"position": Vector2(72.0000, 18.0000),
				"name": "Mercenary Camp 1"
			},
			{
				"kind": "mercenary",
				"position": Vector2(206.0000, 72.0000),
				"name": "Mercenary Camp 2"
			},
			{
				"kind": "mercenary",
				"position": Vector2(152.0000, 206.0000),
				"name": "Mercenary Camp 3"
			},
			{
				"kind": "mercenary",
				"position": Vector2(18.0000, 152.0000),
				"name": "Mercenary Camp 4"
			},
			{"kind": "repair", "position": Vector2(54.0000, 108.0000), "name": "Repair Shop 1"},
			{"kind": "repair", "position": Vector2(116.0000, 54.0000), "name": "Repair Shop 2"},
			{"kind": "repair", "position": Vector2(170.0000, 116.0000), "name": "Repair Shop 3"},
			{"kind": "repair", "position": Vector2(108.0000, 170.0000), "name": "Repair Shop 4"}
		]
	},
	"FourRivers":
	{
		"name": "Four Rivers",
		"players": 4,
		"size": Vector2(224.0000, 224.0000),
		"biome": "temperate",
		"description": "Four headwater pools separate spokes into a shared heartland.",
		"low": Color("3e5c4b"),
		"high": Color("809276"),
		"road": Color("8d8b6e"),
		"surface": 0,
		"starts":
		[
			Vector2(28.0000, 28.0000),
			Vector2(196.0000, 28.0000),
			Vector2(196.0000, 196.0000),
			Vector2(28.0000, 196.0000)
		],
		"fields":
		[
			Vector2(40.7279, 40.7279),
			Vector2(183.2721, 40.7279),
			Vector2(183.2721, 183.2721),
			Vector2(40.7279, 183.2721),
			Vector2(18.0000, 90.0000),
			Vector2(134.0000, 18.0000),
			Vector2(206.0000, 134.0000),
			Vector2(90.0000, 206.0000),
			Vector2(84.0000, 18.0000),
			Vector2(206.0000, 84.0000),
			Vector2(140.0000, 206.0000),
			Vector2(18.0000, 140.0000)
		],
		"ridges":
		[
			Vector2(74.0000, 74.0000),
			Vector2(150.0000, 74.0000),
			Vector2(150.0000, 150.0000),
			Vector2(74.0000, 150.0000)
		],
		"radius": 6.0,
		"water":
		[
			Vector2(112.0000, 67.0000),
			Vector2(157.0000, 112.0000),
			Vector2(112.0000, 157.0000),
			Vector2(67.0000, 112.0000)
		],
		"water_radius": 12.0,
		"models": ["coastal/CoastalHeadland", "coastal/ShorePines"],
		"roads":
		[
			Vector4(28.000, 28.000, 112.000, 112.000),
			Vector4(196.000, 28.000, 112.000, 112.000),
			Vector4(196.000, 196.000, 112.000, 112.000),
			Vector4(28.000, 196.000, 112.000, 112.000),
			Vector4(28.000, 28.000, 196.000, 28.000),
			Vector4(196.000, 28.000, 196.000, 196.000),
			Vector4(196.000, 196.000, 28.000, 196.000),
			Vector4(28.000, 196.000, 28.000, 28.000)
		],
		"sites":
		[
			{"kind": "refinery", "position": Vector2(48.0000, 84.0000), "name": "Refinery 1"},
			{"kind": "refinery", "position": Vector2(140.0000, 48.0000), "name": "Refinery 2"},
			{"kind": "refinery", "position": Vector2(176.0000, 140.0000), "name": "Refinery 3"},
			{"kind": "refinery", "position": Vector2(84.0000, 176.0000), "name": "Refinery 4"},
			{
				"kind": "mercenary",
				"position": Vector2(84.0000, 48.0000),
				"name": "Mercenary Camp 1"
			},
			{
				"kind": "mercenary",
				"position": Vector2(176.0000, 84.0000),
				"name": "Mercenary Camp 2"
			},
			{
				"kind": "mercenary",
				"position": Vector2(140.0000, 176.0000),
				"name": "Mercenary Camp 3"
			},
			{
				"kind": "mercenary",
				"position": Vector2(48.0000, 140.0000),
				"name": "Mercenary Camp 4"
			},
			{"kind": "repair", "position": Vector2(96.0000, 96.0000), "name": "Repair Shop 1"},
			{"kind": "repair", "position": Vector2(128.0000, 96.0000), "name": "Repair Shop 2"},
			{"kind": "repair", "position": Vector2(128.0000, 128.0000), "name": "Repair Shop 3"},
			{"kind": "repair", "position": Vector2(96.0000, 128.0000), "name": "Repair Shop 4"}
		]
	},
	"SunkenExchange":
	{
		"name": "Sunken Exchange",
		"players": 4,
		"size": Vector2(224.0000, 224.0000),
		"biome": "coastal",
		"description": "Flooded port basins leave a cross of cargo roads.",
		"low": Color("4f6563"),
		"high": Color("8b9a8c"),
		"road": Color("8d9187"),
		"surface": 3,
		"starts":
		[
			Vector2(28.0000, 28.0000),
			Vector2(196.0000, 28.0000),
			Vector2(196.0000, 196.0000),
			Vector2(28.0000, 196.0000)
		],
		"fields":
		[
			Vector2(40.7279, 40.7279),
			Vector2(183.2721, 40.7279),
			Vector2(183.2721, 183.2721),
			Vector2(40.7279, 183.2721),
			Vector2(18.0000, 90.0000),
			Vector2(134.0000, 18.0000),
			Vector2(206.0000, 134.0000),
			Vector2(90.0000, 206.0000),
			Vector2(84.0000, 18.0000),
			Vector2(206.0000, 84.0000),
			Vector2(140.0000, 206.0000),
			Vector2(18.0000, 140.0000)
		],
		"ridges":
		[
			Vector2(112.0000, 60.0000),
			Vector2(164.0000, 112.0000),
			Vector2(112.0000, 164.0000),
			Vector2(60.0000, 112.0000)
		],
		"radius": 6.0,
		"water":
		[
			Vector2(82.0000, 82.0000),
			Vector2(142.0000, 82.0000),
			Vector2(142.0000, 142.0000),
			Vector2(82.0000, 142.0000)
		],
		"water_radius": 14.0,
		"models": ["coastal/HarborCrane", "coastal/PortFreightYard"],
		"roads":
		[
			Vector4(18.000, 66.000, 206.000, 66.000),
			Vector4(66.000, 18.000, 66.000, 206.000),
			Vector4(18.000, 112.000, 206.000, 112.000),
			Vector4(112.000, 18.000, 112.000, 206.000),
			Vector4(18.000, 158.000, 206.000, 158.000),
			Vector4(158.000, 18.000, 158.000, 206.000)
		],
		"sites":
		[
			{"kind": "refinery", "position": Vector2(48.0000, 72.0000), "name": "Refinery 1"},
			{"kind": "refinery", "position": Vector2(152.0000, 48.0000), "name": "Refinery 2"},
			{"kind": "refinery", "position": Vector2(176.0000, 152.0000), "name": "Refinery 3"},
			{"kind": "refinery", "position": Vector2(72.0000, 176.0000), "name": "Refinery 4"},
			{
				"kind": "mercenary",
				"position": Vector2(72.0000, 48.0000),
				"name": "Mercenary Camp 1"
			},
			{
				"kind": "mercenary",
				"position": Vector2(176.0000, 72.0000),
				"name": "Mercenary Camp 2"
			},
			{
				"kind": "mercenary",
				"position": Vector2(152.0000, 176.0000),
				"name": "Mercenary Camp 3"
			},
			{
				"kind": "mercenary",
				"position": Vector2(48.0000, 152.0000),
				"name": "Mercenary Camp 4"
			},
			{"kind": "repair", "position": Vector2(108.0000, 36.0000), "name": "Repair Shop 1"},
			{"kind": "repair", "position": Vector2(188.0000, 108.0000), "name": "Repair Shop 2"},
			{"kind": "repair", "position": Vector2(116.0000, 188.0000), "name": "Repair Shop 3"},
			{"kind": "repair", "position": Vector2(36.0000, 116.0000), "name": "Repair Shop 4"}
		]
	},
	"FrostboundCrown":
	{
		"name": "Frostbound Crown",
		"players": 4,
		"size": Vector2(224.0000, 224.0000),
		"biome": "alpine",
		"description": "A crown of glacial shelves guards the central repair network.",
		"low": Color("657f91"),
		"high": Color("becdd4"),
		"road": Color("4c6273"),
		"surface": 2,
		"starts":
		[
			Vector2(28.0000, 28.0000),
			Vector2(196.0000, 28.0000),
			Vector2(196.0000, 196.0000),
			Vector2(28.0000, 196.0000)
		],
		"fields":
		[
			Vector2(40.7279, 40.7279),
			Vector2(183.2721, 40.7279),
			Vector2(183.2721, 183.2721),
			Vector2(40.7279, 183.2721),
			Vector2(18.0000, 108.0000),
			Vector2(116.0000, 18.0000),
			Vector2(206.0000, 116.0000),
			Vector2(108.0000, 206.0000),
			Vector2(84.0000, 42.0000),
			Vector2(182.0000, 84.0000),
			Vector2(140.0000, 182.0000),
			Vector2(42.0000, 140.0000)
		],
		"ridges":
		[
			Vector2(94.0000, 80.0000),
			Vector2(144.0000, 94.0000),
			Vector2(130.0000, 144.0000),
			Vector2(80.0000, 130.0000),
			Vector2(82.0000, 92.0000),
			Vector2(132.0000, 82.0000),
			Vector2(142.0000, 132.0000),
			Vector2(92.0000, 142.0000)
		],
		"radius": 6.0,
		"water": [],
		"water_radius": 0.0,
		"models": ["alpine/GlacialShelfA", "alpine/MountainWeatherStation"],
		"roads":
		[
			Vector4(177.000, 112.000, 157.962, 157.962),
			Vector4(157.962, 157.962, 112.000, 177.000),
			Vector4(112.000, 177.000, 66.038, 157.962),
			Vector4(66.038, 157.962, 47.000, 112.000),
			Vector4(47.000, 112.000, 66.038, 66.038),
			Vector4(66.038, 66.038, 112.000, 47.000),
			Vector4(112.000, 47.000, 157.962, 66.038),
			Vector4(157.962, 66.038, 177.000, 112.000),
			Vector4(28.000, 28.000, 66.038, 66.038),
			Vector4(196.000, 28.000, 157.962, 66.038),
			Vector4(196.000, 196.000, 157.962, 157.962),
			Vector4(28.000, 196.000, 66.038, 157.962)
		],
		"sites":
		[
			{"kind": "refinery", "position": Vector2(48.0000, 84.0000), "name": "Refinery 1"},
			{"kind": "refinery", "position": Vector2(140.0000, 48.0000), "name": "Refinery 2"},
			{"kind": "refinery", "position": Vector2(176.0000, 140.0000), "name": "Refinery 3"},
			{"kind": "refinery", "position": Vector2(84.0000, 176.0000), "name": "Refinery 4"},
			{
				"kind": "mercenary",
				"position": Vector2(18.0000, 72.0000),
				"name": "Mercenary Camp 1"
			},
			{
				"kind": "mercenary",
				"position": Vector2(152.0000, 18.0000),
				"name": "Mercenary Camp 2"
			},
			{
				"kind": "mercenary",
				"position": Vector2(206.0000, 152.0000),
				"name": "Mercenary Camp 3"
			},
			{
				"kind": "mercenary",
				"position": Vector2(72.0000, 206.0000),
				"name": "Mercenary Camp 4"
			},
			{"kind": "repair", "position": Vector2(60.0000, 108.0000), "name": "Repair Shop 1"},
			{"kind": "repair", "position": Vector2(116.0000, 60.0000), "name": "Repair Shop 2"},
			{"kind": "repair", "position": Vector2(164.0000, 116.0000), "name": "Repair Shop 3"},
			{"kind": "repair", "position": Vector2(108.0000, 164.0000), "name": "Repair Shop 4"}
		]
	},
	"CopperBadlands":
	{
		"name": "Copper Badlands",
		"players": 4,
		"size": Vector2(224.0000, 224.0000),
		"biome": "desert",
		"description": "Staggered copper mesas create diagonal flanking corridors.",
		"low": Color("885538"),
		"high": Color("c49d62"),
		"road": Color("ad8357"),
		"surface": 0,
		"starts":
		[
			Vector2(28.0000, 28.0000),
			Vector2(196.0000, 28.0000),
			Vector2(196.0000, 196.0000),
			Vector2(28.0000, 196.0000)
		],
		"fields":
		[
			Vector2(40.7279, 40.7279),
			Vector2(183.2721, 40.7279),
			Vector2(183.2721, 183.2721),
			Vector2(40.7279, 183.2721),
			Vector2(18.0000, 102.0000),
			Vector2(122.0000, 18.0000),
			Vector2(206.0000, 122.0000),
			Vector2(102.0000, 206.0000),
			Vector2(60.0000, 90.0000),
			Vector2(134.0000, 60.0000),
			Vector2(164.0000, 134.0000),
			Vector2(90.0000, 164.0000)
		],
		"ridges":
		[
			Vector2(96.0000, 68.0000),
			Vector2(156.0000, 96.0000),
			Vector2(128.0000, 156.0000),
			Vector2(68.0000, 128.0000),
			Vector2(84.0000, 59.0000),
			Vector2(165.0000, 84.0000),
			Vector2(140.0000, 165.0000),
			Vector2(59.0000, 140.0000),
			Vector2(112.0000, 94.0000),
			Vector2(130.0000, 112.0000),
			Vector2(112.0000, 130.0000),
			Vector2(94.0000, 112.0000)
		],
		"radius": 6.0,
		"water": [],
		"water_radius": 0.0,
		"models": ["desert/SandstoneShelfB", "desert/FrontierExtractionRig"],
		"roads":
		[
			Vector4(28.000, 28.000, 112.000, 112.000),
			Vector4(196.000, 28.000, 112.000, 112.000),
			Vector4(196.000, 196.000, 112.000, 112.000),
			Vector4(28.000, 196.000, 112.000, 112.000),
			Vector4(28.000, 28.000, 196.000, 28.000),
			Vector4(196.000, 28.000, 196.000, 196.000),
			Vector4(196.000, 196.000, 28.000, 196.000),
			Vector4(28.000, 196.000, 28.000, 28.000)
		],
		"sites":
		[
			{"kind": "refinery", "position": Vector2(78.0000, 18.0000), "name": "Refinery 1"},
			{"kind": "refinery", "position": Vector2(206.0000, 78.0000), "name": "Refinery 2"},
			{"kind": "refinery", "position": Vector2(146.0000, 206.0000), "name": "Refinery 3"},
			{"kind": "refinery", "position": Vector2(18.0000, 146.0000), "name": "Refinery 4"},
			{
				"kind": "mercenary",
				"position": Vector2(30.0000, 72.0000),
				"name": "Mercenary Camp 1"
			},
			{
				"kind": "mercenary",
				"position": Vector2(152.0000, 30.0000),
				"name": "Mercenary Camp 2"
			},
			{
				"kind": "mercenary",
				"position": Vector2(194.0000, 152.0000),
				"name": "Mercenary Camp 3"
			},
			{
				"kind": "mercenary",
				"position": Vector2(72.0000, 194.0000),
				"name": "Mercenary Camp 4"
			},
			{"kind": "repair", "position": Vector2(108.0000, 42.0000), "name": "Repair Shop 1"},
			{"kind": "repair", "position": Vector2(182.0000, 108.0000), "name": "Repair Shop 2"},
			{"kind": "repair", "position": Vector2(116.0000, 182.0000), "name": "Repair Shop 3"},
			{"kind": "repair", "position": Vector2(42.0000, 116.0000), "name": "Repair Shop 4"}
		]
	},
	"VerdantCommons":
	{
		"name": "Verdant Commons",
		"players": 4,
		"size": Vector2(224.0000, 224.0000),
		"biome": "temperate",
		"description": "Sheltered groves ring a broad, resource-rich common.",
		"low": Color("415539"),
		"high": Color("849465"),
		"road": Color("968b66"),
		"surface": 0,
		"starts":
		[
			Vector2(28.0000, 28.0000),
			Vector2(196.0000, 28.0000),
			Vector2(196.0000, 196.0000),
			Vector2(28.0000, 196.0000)
		],
		"fields":
		[
			Vector2(40.7279, 40.7279),
			Vector2(183.2721, 40.7279),
			Vector2(183.2721, 183.2721),
			Vector2(40.7279, 183.2721),
			Vector2(96.0000, 18.0000),
			Vector2(206.0000, 96.0000),
			Vector2(128.0000, 206.0000),
			Vector2(18.0000, 128.0000),
			Vector2(18.0000, 84.0000),
			Vector2(140.0000, 18.0000),
			Vector2(206.0000, 140.0000),
			Vector2(84.0000, 206.0000)
		],
		"ridges":
		[
			Vector2(67.0000, 104.0000),
			Vector2(120.0000, 67.0000),
			Vector2(157.0000, 120.0000),
			Vector2(104.0000, 157.0000),
			Vector2(64.0000, 92.0000),
			Vector2(132.0000, 64.0000),
			Vector2(160.0000, 132.0000),
			Vector2(92.0000, 160.0000),
			Vector2(77.0000, 87.0000),
			Vector2(137.0000, 77.0000),
			Vector2(147.0000, 137.0000),
			Vector2(87.0000, 147.0000)
		],
		"radius": 6.0,
		"water": [],
		"water_radius": 0.0,
		"models": ["coastal/CoastalPineStand", "industrial-surroundings/BirchScrub"],
		"roads":
		[
			Vector4(28.000, 28.000, 112.000, 112.000),
			Vector4(196.000, 28.000, 112.000, 112.000),
			Vector4(196.000, 196.000, 112.000, 112.000),
			Vector4(28.000, 196.000, 112.000, 112.000),
			Vector4(28.000, 28.000, 196.000, 28.000),
			Vector4(196.000, 28.000, 196.000, 196.000),
			Vector4(196.000, 196.000, 28.000, 196.000),
			Vector4(28.000, 196.000, 28.000, 28.000)
		],
		"sites":
		[
			{"kind": "refinery", "position": Vector2(84.0000, 54.0000), "name": "Refinery 1"},
			{"kind": "refinery", "position": Vector2(170.0000, 84.0000), "name": "Refinery 2"},
			{"kind": "refinery", "position": Vector2(140.0000, 170.0000), "name": "Refinery 3"},
			{"kind": "refinery", "position": Vector2(54.0000, 140.0000), "name": "Refinery 4"},
			{
				"kind": "mercenary",
				"position": Vector2(42.0000, 108.0000),
				"name": "Mercenary Camp 1"
			},
			{
				"kind": "mercenary",
				"position": Vector2(116.0000, 42.0000),
				"name": "Mercenary Camp 2"
			},
			{
				"kind": "mercenary",
				"position": Vector2(182.0000, 116.0000),
				"name": "Mercenary Camp 3"
			},
			{
				"kind": "mercenary",
				"position": Vector2(108.0000, 182.0000),
				"name": "Mercenary Camp 4"
			},
			{"kind": "repair", "position": Vector2(48.0000, 72.0000), "name": "Repair Shop 1"},
			{"kind": "repair", "position": Vector2(152.0000, 48.0000), "name": "Repair Shop 2"},
			{"kind": "repair", "position": Vector2(176.0000, 152.0000), "name": "Repair Shop 3"},
			{"kind": "repair", "position": Vector2(72.0000, 176.0000), "name": "Repair Shop 4"}
		]
	},
	"RailspireJunction":
	{
		"name": "Railspire Junction",
		"players": 4,
		"size": Vector2(224.0000, 224.0000),
		"biome": "urban",
		"description": "Rail depots divide a grid of long industrial sightlines.",
		"low": Color("45474b"),
		"high": Color("777d79"),
		"road": Color("9a9382"),
		"surface": 3,
		"starts":
		[
			Vector2(28.0000, 28.0000),
			Vector2(196.0000, 28.0000),
			Vector2(196.0000, 196.0000),
			Vector2(28.0000, 196.0000)
		],
		"fields":
		[
			Vector2(40.7279, 40.7279),
			Vector2(183.2721, 40.7279),
			Vector2(183.2721, 183.2721),
			Vector2(40.7279, 183.2721),
			Vector2(18.0000, 90.0000),
			Vector2(134.0000, 18.0000),
			Vector2(206.0000, 134.0000),
			Vector2(90.0000, 206.0000),
			Vector2(84.0000, 18.0000),
			Vector2(206.0000, 84.0000),
			Vector2(140.0000, 206.0000),
			Vector2(18.0000, 140.0000)
		],
		"ridges":
		[
			Vector2(84.0000, 84.0000),
			Vector2(140.0000, 84.0000),
			Vector2(140.0000, 140.0000),
			Vector2(84.0000, 140.0000),
			Vector2(84.0000, 70.0000),
			Vector2(154.0000, 84.0000),
			Vector2(140.0000, 154.0000),
			Vector2(70.0000, 140.0000),
			Vector2(112.0000, 54.0000),
			Vector2(170.0000, 112.0000),
			Vector2(112.0000, 170.0000),
			Vector2(54.0000, 112.0000)
		],
		"radius": 6.0,
		"water": [],
		"water_radius": 0.0,
		"models": ["industrial-surroundings/RailServiceBay", "industrial/SawtoothWorkshop"],
		"roads":
		[
			Vector4(18.000, 66.000, 206.000, 66.000),
			Vector4(66.000, 18.000, 66.000, 206.000),
			Vector4(18.000, 112.000, 206.000, 112.000),
			Vector4(112.000, 18.000, 112.000, 206.000),
			Vector4(18.000, 158.000, 206.000, 158.000),
			Vector4(158.000, 18.000, 158.000, 206.000)
		],
		"sites":
		[
			{"kind": "refinery", "position": Vector2(54.0000, 78.0000), "name": "Refinery 1"},
			{"kind": "refinery", "position": Vector2(146.0000, 54.0000), "name": "Refinery 2"},
			{"kind": "refinery", "position": Vector2(170.0000, 146.0000), "name": "Refinery 3"},
			{"kind": "refinery", "position": Vector2(78.0000, 170.0000), "name": "Refinery 4"},
			{
				"kind": "mercenary",
				"position": Vector2(72.0000, 48.0000),
				"name": "Mercenary Camp 1"
			},
			{
				"kind": "mercenary",
				"position": Vector2(176.0000, 72.0000),
				"name": "Mercenary Camp 2"
			},
			{
				"kind": "mercenary",
				"position": Vector2(152.0000, 176.0000),
				"name": "Mercenary Camp 3"
			},
			{
				"kind": "mercenary",
				"position": Vector2(48.0000, 152.0000),
				"name": "Mercenary Camp 4"
			},
			{"kind": "repair", "position": Vector2(78.0000, 108.0000), "name": "Repair Shop 1"},
			{"kind": "repair", "position": Vector2(116.0000, 78.0000), "name": "Repair Shop 2"},
			{"kind": "repair", "position": Vector2(146.0000, 116.0000), "name": "Repair Shop 3"},
			{"kind": "repair", "position": Vector2(108.0000, 146.0000), "name": "Repair Shop 4"}
		]
	},
	"ShatteredOasis":
	{
		"name": "Shattered Oasis",
		"players": 4,
		"size": Vector2(224.0000, 224.0000),
		"biome": "desert",
		"description": "A turquoise oasis forces clockwise expansion around its shores.",
		"low": Color("8c8054"),
		"high": Color("c6b67d"),
		"road": Color("a29572"),
		"surface": 1,
		"starts":
		[
			Vector2(28.0000, 28.0000),
			Vector2(196.0000, 28.0000),
			Vector2(196.0000, 196.0000),
			Vector2(28.0000, 196.0000)
		],
		"fields":
		[
			Vector2(40.7279, 40.7279),
			Vector2(183.2721, 40.7279),
			Vector2(183.2721, 183.2721),
			Vector2(40.7279, 183.2721),
			Vector2(18.0000, 108.0000),
			Vector2(116.0000, 18.0000),
			Vector2(206.0000, 116.0000),
			Vector2(108.0000, 206.0000),
			Vector2(84.0000, 60.0000),
			Vector2(164.0000, 84.0000),
			Vector2(140.0000, 164.0000),
			Vector2(60.0000, 140.0000)
		],
		"ridges":
		[
			Vector2(85.0000, 105.0000),
			Vector2(119.0000, 85.0000),
			Vector2(139.0000, 119.0000),
			Vector2(105.0000, 139.0000)
		],
		"radius": 6.0,
		"water": [Vector2(112.0000, 112.0000)],
		"water_radius": 20.0,
		"models": ["desert/DesertAcacia", "desert/SandstoneShelfD"],
		"roads":
		[
			Vector4(177.000, 112.000, 157.962, 157.962),
			Vector4(157.962, 157.962, 112.000, 177.000),
			Vector4(112.000, 177.000, 66.038, 157.962),
			Vector4(66.038, 157.962, 47.000, 112.000),
			Vector4(47.000, 112.000, 66.038, 66.038),
			Vector4(66.038, 66.038, 112.000, 47.000),
			Vector4(112.000, 47.000, 157.962, 66.038),
			Vector4(157.962, 66.038, 177.000, 112.000),
			Vector4(28.000, 28.000, 66.038, 66.038),
			Vector4(196.000, 28.000, 157.962, 66.038),
			Vector4(196.000, 196.000, 157.962, 157.962),
			Vector4(28.000, 196.000, 66.038, 157.962)
		],
		"sites":
		[
			{"kind": "refinery", "position": Vector2(54.0000, 84.0000), "name": "Refinery 1"},
			{"kind": "refinery", "position": Vector2(140.0000, 54.0000), "name": "Refinery 2"},
			{"kind": "refinery", "position": Vector2(170.0000, 140.0000), "name": "Refinery 3"},
			{"kind": "refinery", "position": Vector2(84.0000, 170.0000), "name": "Refinery 4"},
			{
				"kind": "mercenary",
				"position": Vector2(78.0000, 18.0000),
				"name": "Mercenary Camp 1"
			},
			{
				"kind": "mercenary",
				"position": Vector2(206.0000, 78.0000),
				"name": "Mercenary Camp 2"
			},
			{
				"kind": "mercenary",
				"position": Vector2(146.0000, 206.0000),
				"name": "Mercenary Camp 3"
			},
			{
				"kind": "mercenary",
				"position": Vector2(18.0000, 146.0000),
				"name": "Mercenary Camp 4"
			},
			{"kind": "repair", "position": Vector2(18.0000, 72.0000), "name": "Repair Shop 1"},
			{"kind": "repair", "position": Vector2(152.0000, 18.0000), "name": "Repair Shop 2"},
			{"kind": "repair", "position": Vector2(206.0000, 152.0000), "name": "Repair Shop 3"},
			{"kind": "repair", "position": Vector2(72.0000, 206.0000), "name": "Repair Shop 4"}
		]
	},
}


static func profile(map_path):
	return MAPS.get(map_path.get_file().get_basename(), {})
