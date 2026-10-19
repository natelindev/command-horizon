extends RefCounted

# Ground colours for the authored terrain shader, per biome. Values are linear
# albedo before lighting; maps may override any key in their definition's
# "palette" entry.

const PALETTES = {
	"canyon":
	{
		"ground_low": Color("8a4f33"),
		"ground_high": Color("b97a4f"),
		"accent": Color("8f8656"),
		"road": Color("a4744d"),
		"rock": Color("9a5636"),
		"bed": Color("5a4433"),
		"forest_floor": Color("5d5434"),
		"accent_amount": 0.22,
		"strata": 1.0,
	},
	"desert":
	{
		"ground_low": Color("b08a5c"),
		"ground_high": Color("d6b483"),
		"accent": Color("a39a64"),
		"road": Color("9c7a52"),
		"rock": Color("a7825a"),
		"bed": Color("6d5a44"),
		"forest_floor": Color("6f6a3c"),
		"accent_amount": 0.2,
		"strata": 0.8,
	},
	"temperate":
	{
		"ground_low": Color("4f6b35"),
		"ground_high": Color("78894a"),
		"accent": Color("8c8a52"),
		"road": Color("8a7658"),
		"rock": Color("77736a"),
		"bed": Color("4a4a3c"),
		"forest_floor": Color("3b4527"),
		"accent_amount": 0.35,
		"strata": 0.5,
	},
	"alpine":
	{
		"ground_low": Color("c9d3da"),
		"ground_high": Color("eef2f5"),
		"accent": Color("a9b4b7"),
		"road": Color("8f9497"),
		"rock": Color("6e7276"),
		"bed": Color("59646b"),
		"forest_floor": Color("aab4b5"),
		"accent_amount": 0.3,
		"strata": 0.7,
	},
}


static func configure(material: ShaderMaterial, biome: String, overrides := {}):
	var palette = PALETTES.get(biome, PALETTES.desert).duplicate()
	palette.merge(overrides, true)
	for key in palette:
		material.set_shader_parameter(key, palette[key])
