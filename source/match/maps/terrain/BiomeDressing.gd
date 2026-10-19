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


static func kit(ground: String) -> Dictionary:
	return KITS.get(ground, KITS.canyon)
