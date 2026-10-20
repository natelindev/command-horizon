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
		"slickrock": Color("d7a582"),
		"sand": Color("d9a97a"),
		"accent_amount": 0.22,
		"slickrock_amount": 0.6,
		"strata": 1.0,
		"water_deep": Color("1f3330"),
		"water_shallow": Color("5b6146"),
		"water_foam": Color("cdb79a"),
	},
	"salt":
	{
		"ground_low": Color("b3a690"),
		"ground_high": Color("cbbfa8"),
		"accent": Color("9c8f74"),
		"road": Color("8f8676"),
		"rock": Color("a8977f"),
		"bed": Color("8e9a92"),
		"forest_floor": Color("8a8466"),
		"slickrock": Color("cbbfa8"),
		"sand": Color("bfae92"),
		"crust": Color("f0eee6"),
		"accent_amount": 0.2,
		"crust_amount": 0.9,
		"strata": 0.6,
		"water_deep": Color("1f6f7c"),
		"water_shallow": Color("6fc1bd"),
		"water_foam": Color("f4f2ea"),
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

# Cliff and formation colours (canyon_rock.gdshader) per ground; grounds
# without an entry keep the shader's canyon sandstone.
const ROCK = {
	"salt":
	{
		"band_dark": Color("8c7a66"),
		"band_mid": Color("a8977f"),
		"band_light": Color("cbbfa8"),
		"cap": Color("ddd4c2"),
		"varnish": Color("5a4a3c"),
		"strata_scale": 2.2,
	},
	"copper":
	{
		"band_dark": Color("6e4a35"),
		"band_mid": Color("8f6a4a"),
		"band_light": Color("7d8a6e"),
		"cap": Color("a88d6c"),
		"varnish": Color("3f5a4f"),
		"strata_scale": 0.34,
	},
	"oasis":
	{
		"band_dark": Color("9a7650"),
		"band_mid": Color("b8946a"),
		"band_light": Color("d6b88e"),
		"cap": Color("e0c9a0"),
		"varnish": Color("6d5238"),
		"strata_scale": 1.2,
	},
	"mojave":
	{
		"band_dark": Color("7c5a40"),
		"band_mid": Color("9c7656"),
		"band_light": Color("bf9e7a"),
		"cap": Color("cdb08a"),
		"varnish": Color("3d2c22"),
		"strata_scale": 1.4,
	},
}


static func rock(ground: String) -> Dictionary:
	return ROCK.get(ground, {})


static func configure(material: ShaderMaterial, biome: String, overrides := {}):
	var palette = PALETTES.get(biome, PALETTES.desert).duplicate()
	palette.merge(overrides, true)
	for key in palette:
		if not key.begins_with("water_"):
			material.set_shader_parameter(key, palette[key])


static func configure_water(material: ShaderMaterial, biome: String):
	var palette = PALETTES.get(biome, PALETTES.desert)
	for key in ["deep", "shallow", "foam"]:
		if palette.has("water_" + key):
			material.set_shader_parameter(key, palette["water_" + key])
