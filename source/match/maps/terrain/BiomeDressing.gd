extends RefCounted

# What grows and lies on each kind of authored ground: tree sets for forests,
# open-ground scatter (shrubs, rocks, occasional lone trees), cliff-foot talus
# and densities per square metre. Entries are [asset, height in metres].

const KITS = {
	"canyon":
	{
		"trees":
		[
			["canyon/UtahJuniperA", 2.9],
			["canyon/UtahJuniperB", 2.4],
			["canyon/UtahJuniperA", 2.1],
			["canyon/PinyonPine", 3.8]
		],
		"riparian": [["canyon/FremontCottonwood", 5.6], ["canyon/FremontCottonwood", 4.6]],
		"shrubs":
		[
			["canyon/Sagebrush", 0.55],
			["canyon/Sagebrush", 0.45],
			["canyon/Rabbitbrush", 0.6],
			["canyon/Yucca", 1.1]
		],
		"rocks": [["canyon/BoulderA", 0.75], ["canyon/BoulderB", 1.0], ["canyon/BoulderC", 0.5]],
		"talus": [["canyon/TalusCluster", 0.65], ["canyon/BoulderC", 0.55], ["canyon/BoulderA", 0.7]],
		"lone_trees": [["canyon/UtahJuniperB", 2.3], ["canyon/UtahJuniperA", 2.7]],
		"shrub_density": 0.028,
		"rock_density": 0.0055,
		"tree_density": 0.0016,
	},
}

# Shared by grounds without their own kit entry below.
const SALT = {
	"trees": [["drylands/Greasewood", 1.5], ["drylands/Greasewood", 1.2]],
	"riparian": [["drylands/Greasewood", 1.5]],
	"shrubs":
	[
		["drylands/Saltbush", 0.6],
		["drylands/Saltbush", 0.48],
		["drylands/Greasewood", 0.85],
		["drylands/Tumbleweed", 0.65]
	],
	"rocks": [["drylands/GypsumBoulderA", 0.75], ["drylands/GypsumBoulderB", 0.55]],
	"talus": [["drylands/GypsumBoulderA", 0.65], ["drylands/GypsumBoulderB", 0.5]],
	"lone_trees": [],
	"shrub_density": 0.02,
	"rock_density": 0.004,
	"tree_density": 0.0,
	# The pan floor stays nearly bare.
	"low_ground_density": 0.14,
}

const COPPER = {
	"trees": [["drylands/Greasewood", 1.3]],
	"riparian": [["drylands/Greasewood", 1.3]],
	"shrubs": [["drylands/Tumbleweed", 0.55], ["drylands/Saltbush", 0.45]],
	"rocks":
	[["drylands/OreBoulderA", 0.85], ["drylands/OreBoulderB", 0.65], ["canyon/BoulderC", 0.6]],
	"talus": [["drylands/OreBoulderA", 0.7], ["drylands/OreBoulderB", 0.55]],
	"lone_trees": [],
	"shrub_density": 0.006,
	"rock_density": 0.011,
	"tree_density": 0.0,
}
const OASIS = {
	"trees":
	[["drylands/DatePalmA", 5.6], ["drylands/DatePalmB", 4.4], ["drylands/DatePalmA", 4.9]],
	"riparian": [["drylands/DatePalmA", 5.6], ["drylands/Oleander", 1.2]],
	"shrubs":
	[
		["drylands/DuneGrass", 0.48],
		["drylands/PalmScrub", 0.95],
		["drylands/Saltbush", 0.5],
		["drylands/DuneGrass", 0.38]
	],
	"rocks": [["canyon/BoulderC", 0.55], ["canyon/BoulderA", 0.7]],
	"talus": [["canyon/TalusCluster", 0.6], ["canyon/BoulderC", 0.5]],
	"lone_trees": [["drylands/DatePalmB", 4.4]],
	"shrub_density": 0.018,
	"rock_density": 0.003,
	"tree_density": 0.0009,
}
const MOJAVE = {
	"trees":
	[["drylands/JoshuaTree", 3.9], ["drylands/JoshuaTree", 3.2], ["drylands/Creosote", 1.0]],
	"riparian": [["canyon/FremontCottonwood", 5.4]],
	"shrubs":
	[
		["drylands/Creosote", 0.85],
		["drylands/Creosote", 0.7],
		["drylands/Cholla", 0.75],
		["canyon/Sagebrush", 0.5]
	],
	"rocks": [["canyon/BoulderA", 0.75], ["canyon/BoulderB", 0.95], ["canyon/BoulderC", 0.55]],
	"talus": [["canyon/TalusCluster", 0.65], ["canyon/BoulderC", 0.55]],
	"lone_trees": [["drylands/JoshuaTree", 3.6], ["drylands/JoshuaTree", 2.9]],
	"shrub_density": 0.025,
	"rock_density": 0.0055,
	"tree_density": 0.0022,
}

const FOREST = {
	"trees":
	[
		["temperate/DouglasFir", 6.8],
		["temperate/WesternRedCedar", 5.6],
		["temperate/DouglasFir", 5.9],
		["temperate/YoungSpruce", 3.3]
	],
	"riparian":
	[["temperate/RiverWillow", 4.6], ["temperate/MapleTree", 5.2], ["temperate/BirchCluster", 5.2]],
	"shrubs":
	[
		["temperate/FernClump", 0.45],
		["temperate/SalalShrub", 0.75],
		["temperate/Bramble", 0.75],
		["temperate/FernClump", 0.38]
	],
	"rocks":
	[
		["temperate/GraniteBoulderA", 0.85],
		["temperate/GraniteBoulderB", 0.65],
		["temperate/MossyLog", 0.6],
		["temperate/Stump", 0.55]
	],
	"talus": [["temperate/GraniteBoulderA", 0.7], ["temperate/GraniteBoulderB", 0.55]],
	"lone_trees": [["temperate/YoungSpruce", 3.4], ["temperate/DouglasFir", 5.8]],
	"shrub_density": 0.036,
	"rock_density": 0.007,
	"tree_density": 0.0045,
}
const FARMLAND = {
	"trees":
	[["temperate/OakTree", 5.6], ["temperate/MapleTree", 5.1], ["temperate/BirchCluster", 5.0]],
	"riparian": [["temperate/RiverWillow", 4.6], ["temperate/BirchCluster", 4.9]],
	"hedges": [["temperate/HedgeSegment", 1.3]],
	"shrubs":
	[["temperate/Wildflowers", 0.3], ["temperate/Bramble", 0.68], ["temperate/FernClump", 0.38]],
	"rocks": [["temperate/GraniteBoulderB", 0.6]],
	"talus": [["temperate/GraniteBoulderA", 0.65], ["temperate/GraniteBoulderB", 0.5]],
	"lone_trees": [["temperate/OakTree", 5.4], ["temperate/MapleTree", 4.8]],
	"shrub_density": 0.018,
	"rock_density": 0.0025,
	"tree_density": 0.002,
}

const FJORD = {
	"trees": [["cold/NorwaySpruce", 6.4], ["cold/NorwaySpruce", 5.3], ["cold/SpruceSapling", 3.1]],
	"riparian": [["cold/MountainBirch", 4.4], ["cold/MountainBirch", 3.6]],
	"shrubs":
	[
		["cold/DwarfJuniper", 0.48],
		["cold/Heather", 0.28],
		["cold/Tussock", 0.38],
		["cold/Heather", 0.24]
	],
	"rocks":
	[
		["cold/GneissBoulderA", 1.0],
		["cold/GneissBoulderB", 0.75],
		["cold/BareBoulder", 0.7],
		["cold/Scree", 0.48]
	],
	"talus": [["cold/Scree", 0.5], ["cold/BareBoulder", 0.7], ["cold/GneissBoulderB", 0.6]],
	"lone_trees": [["cold/MountainBirch", 4.0], ["cold/SpruceSapling", 3.1]],
	"shrub_density": 0.024,
	"rock_density": 0.007,
	"tree_density": 0.002,
}
# Above the tree line: dwarf shrubs, tussock grass and frost-shattered rock.
const ALPINE = {
	"trees": [["cold/NorwaySpruce", 5.8], ["cold/SpruceSapling", 3.1], ["cold/NorwaySpruce", 4.9]],
	"riparian": [["cold/SpruceSapling", 3.0]],
	"shrubs": [["cold/DwarfJuniper", 0.45], ["cold/Tussock", 0.38], ["cold/Scree", 0.42]],
	"rocks": [["cold/GneissBoulderA", 0.95], ["cold/GneissBoulderB", 0.7], ["cold/Scree", 0.48]],
	"talus": [["cold/Scree", 0.5], ["cold/GneissBoulderB", 0.68], ["cold/BareBoulder", 0.6]],
	"lone_trees": [["cold/SpruceSapling", 2.9]],
	"shrub_density": 0.015,
	"rock_density": 0.009,
	"tree_density": 0.001,
}
# Ice sheet: wind-carved sastrugi and drifts, ice blocks below fronts and walls.
const POLAR = {
	"trees": [["cold/IceBlockA", 1.4]],
	"riparian": [["cold/IceBlockB", 0.95]],
	"shrubs": [["cold/Sastrugi", 0.4], ["cold/SnowDrift", 0.65], ["cold/Sastrugi", 0.35]],
	"rocks": [["cold/IceBlockB", 0.95], ["cold/BareBoulder", 0.75]],
	"talus": [["cold/IceBlockA", 0.8], ["cold/IceBlockB", 0.65], ["cold/BareBoulder", 0.6]],
	"lone_trees": [],
	"shrub_density": 0.012,
	"rock_density": 0.003,
	"tree_density": 0.0,
}

# Idle works: birch scrub, buddleia and weeds on cinder, slag and scrap.
const WORKS = {
	"trees": [["works/ScrubBirch", 4.5], ["works/ScrubBirch", 3.7], ["works/Buddleia", 1.5]],
	"riparian": [["works/ScrubBirch", 4.0]],
	"shrubs": [["works/Buddleia", 1.3], ["works/Ruderal", 0.45], ["works/Ruderal", 0.38]],
	"rocks": [["works/SlagRockA", 0.85], ["works/SlagRockB", 0.6], ["works/ScrapPile", 1.1]],
	"talus": [["works/SlagRockA", 0.75], ["works/SlagRockB", 0.55]],
	"lone_trees": [["works/ScrubBirch", 4.1]],
	"shrub_density": 0.018,
	"rock_density": 0.005,
	"tree_density": 0.0011,
}

# Harbour verges: shore pines, bramble and weeds; riprap at the quay feet.
const HARBOUR = {
	"trees": [["coastal/ShorePines", 4.0], ["coastal/CoastalPineStand", 3.7]],
	"riparian": [["coastal/ShorePines", 3.9]],
	"shrubs": [["works/Ruderal", 0.38], ["temperate/Bramble", 0.65], ["works/Buddleia", 1.2]],
	"rocks": [["temperate/GraniteBoulderB", 0.6], ["works/ScrapPile", 1.0]],
	"talus": [["temperate/GraniteBoulderA", 0.7], ["temperate/GraniteBoulderB", 0.55]],
	"lone_trees": [["coastal/ShorePines", 3.7]],
	"shrub_density": 0.01,
	"rock_density": 0.003,
	"tree_density": 0.0008,
}
# Canal city: plane trees on the squares, willows by the water.
const CANALCITY = {
	"trees": [["temperate/MapleTree", 5.2], ["temperate/OakTree", 5.5]],
	"riparian": [["temperate/RiverWillow", 4.4]],
	"shrubs": [["works/Ruderal", 0.36], ["temperate/Wildflowers", 0.3]],
	"rocks": [],
	"talus": [["temperate/GraniteBoulderB", 0.45]],
	"lone_trees": [["temperate/MapleTree", 4.9]],
	"shrub_density": 0.005,
	"rock_density": 0.0,
	"tree_density": 0.0006,
}

# Lava fields: moss on old flows, ohia in sheltered hollows, basalt and scoria.
const VOLCANIC = {
	"trees": [["volcanic/Ohia", 3.2], ["volcanic/Ohia", 2.5]],
	"riparian": [["volcanic/Ohia", 2.9]],
	"shrubs":
	[["volcanic/MossHummocks", 0.55], ["volcanic/ScoriaHeap", 0.6], ["volcanic/LavaSlab", 0.48]],
	"rocks":
	[
		["volcanic/BasaltBoulderA", 0.95],
		["volcanic/BasaltBoulderB", 0.7],
		["volcanic/ObsidianShards", 0.85]
	],
	"talus": [["volcanic/BasaltBoulderB", 0.7], ["volcanic/ScoriaHeap", 0.6]],
	"lone_trees": [["volcanic/Ohia", 2.9]],
	"shrub_density": 0.018,
	"rock_density": 0.006,
	"tree_density": 0.0009,
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
		"fjord":
			return FJORD
		"alpine":
			return ALPINE
		"polar":
			return POLAR
		"works":
			return WORKS
		"harbour":
			return HARBOUR
		"canalcity":
			return CANALCITY
		"volcanic":
			return VOLCANIC
	return KITS.get(ground, KITS.canyon)
