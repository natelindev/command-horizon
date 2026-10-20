extends RefCounted

# What grows and lies on each kind of authored ground: tree sets for forests,
# open-ground scatter (shrubs, rocks, occasional lone trees), cliff-foot talus
# and densities per square metre. Entries are [asset, height in metres].

const KITS = {
	"canyon":
	{
		"trees":
		[
			["canyon/UtahJuniperA", 3.4],
			["canyon/UtahJuniperB", 2.9],
			["canyon/UtahJuniperA", 2.6],
			["canyon/PinyonPine", 4.4]
		],
		"riparian": [["canyon/FremontCottonwood", 8.2], ["canyon/FremontCottonwood", 6.8]],
		"shrubs":
		[
			["canyon/Sagebrush", 0.75],
			["canyon/Sagebrush", 0.6],
			["canyon/Rabbitbrush", 0.8],
			["canyon/Yucca", 1.5]
		],
		"rocks": [["canyon/BoulderA", 1.0], ["canyon/BoulderB", 1.5], ["canyon/BoulderC", 0.7]],
		"talus": [["canyon/TalusCluster", 0.8], ["canyon/BoulderC", 0.7], ["canyon/BoulderA", 0.9]],
		"lone_trees": [["canyon/UtahJuniperB", 2.6], ["canyon/UtahJuniperA", 3.0]],
		"shrub_density": 0.02,
		"rock_density": 0.004,
		"tree_density": 0.0012,
	},
}

# Shared by grounds without their own kit entry below.
const SALT = {
	"trees": [["drylands/Greasewood", 1.7], ["drylands/Greasewood", 1.4]],
	"riparian": [["drylands/Greasewood", 1.7]],
	"shrubs":
	[
		["drylands/Saltbush", 0.75],
		["drylands/Saltbush", 0.6],
		["drylands/Greasewood", 1.0],
		["drylands/Tumbleweed", 0.8]
	],
	"rocks": [["drylands/GypsumBoulderA", 1.0], ["drylands/GypsumBoulderB", 0.7]],
	"talus": [["drylands/GypsumBoulderA", 0.8], ["drylands/GypsumBoulderB", 0.6]],
	"lone_trees": [],
	"shrub_density": 0.016,
	"rock_density": 0.003,
	"tree_density": 0.0,
	# The pan floor stays nearly bare.
	"low_ground_density": 0.12,
}

const COPPER = {
	"trees": [["drylands/Greasewood", 1.5]],
	"riparian": [["drylands/Greasewood", 1.5]],
	"shrubs": [["drylands/Tumbleweed", 0.7], ["drylands/Saltbush", 0.5]],
	"rocks":
	[["drylands/OreBoulderA", 1.2], ["drylands/OreBoulderB", 0.9], ["canyon/BoulderC", 0.8]],
	"talus": [["drylands/OreBoulderA", 0.9], ["drylands/OreBoulderB", 0.7]],
	"lone_trees": [],
	"shrub_density": 0.004,
	"rock_density": 0.009,
	"tree_density": 0.0,
}
const OASIS = {
	"trees":
	[["drylands/DatePalmA", 7.5], ["drylands/DatePalmB", 5.8], ["drylands/DatePalmA", 6.4]],
	"riparian": [["drylands/DatePalmA", 7.5], ["drylands/Oleander", 1.6]],
	"shrubs":
	[
		["drylands/DuneGrass", 0.7],
		["drylands/PalmScrub", 1.3],
		["drylands/Saltbush", 0.6],
		["drylands/DuneGrass", 0.55]
	],
	"rocks": [["canyon/BoulderC", 0.7], ["canyon/BoulderA", 0.9]],
	"talus": [["canyon/TalusCluster", 0.7], ["canyon/BoulderC", 0.6]],
	"lone_trees": [["drylands/DatePalmB", 5.8]],
	"shrub_density": 0.012,
	"rock_density": 0.002,
	"tree_density": 0.0006,
}
const MOJAVE = {
	"trees":
	[["drylands/JoshuaTree", 5.0], ["drylands/JoshuaTree", 4.2], ["drylands/Creosote", 1.3]],
	"riparian": [["canyon/FremontCottonwood", 7.5]],
	"shrubs":
	[
		["drylands/Creosote", 1.1],
		["drylands/Creosote", 0.9],
		["drylands/Cholla", 1.0],
		["canyon/Sagebrush", 0.6]
	],
	"rocks": [["canyon/BoulderA", 1.0], ["canyon/BoulderB", 1.4], ["canyon/BoulderC", 0.7]],
	"talus": [["canyon/TalusCluster", 0.8], ["canyon/BoulderC", 0.7]],
	"lone_trees": [["drylands/JoshuaTree", 4.6], ["drylands/JoshuaTree", 3.8]],
	"shrub_density": 0.018,
	"rock_density": 0.004,
	"tree_density": 0.0018,
}

const FOREST = {
	"trees":
	[
		["temperate/DouglasFir", 13.0],
		["temperate/WesternRedCedar", 9.8],
		["temperate/DouglasFir", 11.0],
		["temperate/YoungSpruce", 5.0]
	],
	"riparian":
	[["temperate/RiverWillow", 6.5], ["temperate/MapleTree", 8.0], ["temperate/BirchCluster", 8.0]],
	"shrubs":
	[
		["temperate/FernClump", 0.6],
		["temperate/SalalShrub", 1.0],
		["temperate/Bramble", 1.0],
		["temperate/FernClump", 0.5]
	],
	"rocks":
	[
		["temperate/GraniteBoulderA", 1.2],
		["temperate/GraniteBoulderB", 0.9],
		["temperate/MossyLog", 0.8],
		["temperate/Stump", 0.7]
	],
	"talus": [["temperate/GraniteBoulderA", 0.9], ["temperate/GraniteBoulderB", 0.7]],
	"lone_trees": [["temperate/YoungSpruce", 5.0], ["temperate/DouglasFir", 11.0]],
	"shrub_density": 0.03,
	"rock_density": 0.006,
	"tree_density": 0.004,
}
const FARMLAND = {
	"trees":
	[["temperate/OakTree", 9.0], ["temperate/MapleTree", 8.0], ["temperate/BirchCluster", 8.0]],
	"riparian": [["temperate/RiverWillow", 6.5], ["temperate/BirchCluster", 7.5]],
	"hedges": [["temperate/HedgeSegment", 1.8]],
	"shrubs":
	[["temperate/Wildflowers", 0.4], ["temperate/Bramble", 0.9], ["temperate/FernClump", 0.5]],
	"rocks": [["temperate/GraniteBoulderB", 0.8]],
	"talus": [["temperate/GraniteBoulderA", 0.8], ["temperate/GraniteBoulderB", 0.6]],
	"lone_trees": [["temperate/OakTree", 9.0], ["temperate/MapleTree", 7.5]],
	"shrub_density": 0.012,
	"rock_density": 0.002,
	"tree_density": 0.0015,
}


static func kit(ground: String) -> Dictionary:
	match ground:
		"forest":
			return FOREST
		"farmland", "village":
			return FARMLAND
		"salt":
			return SALT
		"copper":
			return COPPER
		"oasis":
			return OASIS
		"mojave":
			return MOJAVE
	return KITS.get(ground, KITS.canyon)
