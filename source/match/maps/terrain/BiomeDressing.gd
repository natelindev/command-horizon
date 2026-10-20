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

const FJORD = {
	"trees": [["cold/NorwaySpruce", 10.5], ["cold/NorwaySpruce", 8.6], ["cold/SpruceSapling", 4.6]],
	"riparian": [["cold/MountainBirch", 6.2], ["cold/MountainBirch", 5.0]],
	"shrubs":
	[
		["cold/DwarfJuniper", 0.6],
		["cold/Heather", 0.35],
		["cold/Tussock", 0.5],
		["cold/Heather", 0.3]
	],
	"rocks":
	[
		["cold/GneissBoulderA", 1.5],
		["cold/GneissBoulderB", 1.1],
		["cold/BareBoulder", 1.0],
		["cold/Scree", 0.6]
	],
	"talus": [["cold/Scree", 0.6], ["cold/BareBoulder", 0.9], ["cold/GneissBoulderB", 0.8]],
	"lone_trees": [["cold/MountainBirch", 5.6], ["cold/SpruceSapling", 4.6]],
	"shrub_density": 0.018,
	"rock_density": 0.006,
	"tree_density": 0.0015,
}
# Above the tree line: dwarf shrubs, tussock grass and frost-shattered rock.
const ALPINE = {
	"trees": [["cold/NorwaySpruce", 9.5], ["cold/SpruceSapling", 4.6], ["cold/NorwaySpruce", 7.8]],
	"riparian": [["cold/SpruceSapling", 4.2]],
	"shrubs": [["cold/DwarfJuniper", 0.55], ["cold/Tussock", 0.5], ["cold/Scree", 0.5]],
	"rocks": [["cold/GneissBoulderA", 1.4], ["cold/GneissBoulderB", 1.0], ["cold/Scree", 0.6]],
	"talus": [["cold/Scree", 0.6], ["cold/GneissBoulderB", 0.9], ["cold/BareBoulder", 0.8]],
	"lone_trees": [["cold/SpruceSapling", 4.2]],
	"shrub_density": 0.01,
	"rock_density": 0.008,
	"tree_density": 0.0008,
}
# Ice sheet: wind-carved sastrugi and drifts, ice blocks below fronts and walls.
const POLAR = {
	"trees": [["cold/IceBlockA", 1.9]],
	"riparian": [["cold/IceBlockB", 1.2]],
	"shrubs": [["cold/Sastrugi", 0.5], ["cold/SnowDrift", 0.8], ["cold/Sastrugi", 0.4]],
	"rocks": [["cold/IceBlockB", 1.2], ["cold/BareBoulder", 1.0]],
	"talus": [["cold/IceBlockA", 1.0], ["cold/IceBlockB", 0.8], ["cold/BareBoulder", 0.8]],
	"lone_trees": [],
	"shrub_density": 0.008,
	"rock_density": 0.002,
	"tree_density": 0.0,
}

# Idle works: birch scrub, buddleia and weeds on cinder, slag and scrap.
const WORKS = {
	"trees": [["works/ScrubBirch", 6.4], ["works/ScrubBirch", 5.2], ["works/Buddleia", 2.0]],
	"riparian": [["works/ScrubBirch", 5.6]],
	"shrubs": [["works/Buddleia", 1.8], ["works/Ruderal", 0.6], ["works/Ruderal", 0.5]],
	"rocks": [["works/SlagRockA", 1.2], ["works/SlagRockB", 0.8], ["works/ScrapPile", 1.6]],
	"talus": [["works/SlagRockA", 1.0], ["works/SlagRockB", 0.7]],
	"lone_trees": [["works/ScrubBirch", 5.8]],
	"shrub_density": 0.012,
	"rock_density": 0.004,
	"tree_density": 0.0008,
}

# Harbour verges: shore pines, bramble and weeds; riprap at the quay feet.
const HARBOUR = {
	"trees": [["coastal/ShorePines", 5.2], ["coastal/CoastalPineStand", 4.8]],
	"riparian": [["coastal/ShorePines", 5.0]],
	"shrubs": [["works/Ruderal", 0.5], ["temperate/Bramble", 0.9], ["works/Buddleia", 1.6]],
	"rocks": [["temperate/GraniteBoulderB", 0.8], ["works/ScrapPile", 1.4]],
	"talus": [["temperate/GraniteBoulderA", 0.9], ["temperate/GraniteBoulderB", 0.7]],
	"lone_trees": [["coastal/ShorePines", 4.8]],
	"shrub_density": 0.006,
	"rock_density": 0.002,
	"tree_density": 0.0005,
}
# Canal city: plane trees on the squares, willows by the water.
const CANALCITY = {
	"trees": [["temperate/MapleTree", 8.0], ["temperate/OakTree", 8.6]],
	"riparian": [["temperate/RiverWillow", 6.2]],
	"shrubs": [["works/Ruderal", 0.45], ["temperate/Wildflowers", 0.4]],
	"rocks": [],
	"talus": [["temperate/GraniteBoulderB", 0.5]],
	"lone_trees": [["temperate/MapleTree", 7.4]],
	"shrub_density": 0.003,
	"rock_density": 0.0,
	"tree_density": 0.0004,
}

# Lava fields: moss on old flows, ohia in sheltered hollows, basalt and scoria.
const VOLCANIC = {
	"trees": [["volcanic/Ohia", 3.8], ["volcanic/Ohia", 3.0]],
	"riparian": [["volcanic/Ohia", 3.4]],
	"shrubs":
	[["volcanic/MossHummocks", 0.7], ["volcanic/ScoriaHeap", 0.8], ["volcanic/LavaSlab", 0.6]],
	"rocks":
	[
		["volcanic/BasaltBoulderA", 1.4],
		["volcanic/BasaltBoulderB", 1.0],
		["volcanic/ObsidianShards", 1.2]
	],
	"talus": [["volcanic/BasaltBoulderB", 0.9], ["volcanic/ScoriaHeap", 0.8]],
	"lone_trees": [["volcanic/Ohia", 3.4]],
	"shrub_density": 0.014,
	"rock_density": 0.005,
	"tree_density": 0.0006,
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
