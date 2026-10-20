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
	"copper":
	{
		"ground_low": Color("7d5a43"),
		"ground_high": Color("a5805e"),
		"accent": Color("6f7d66"),
		"road": Color("8c7660"),
		"rock": Color("8f6a4a"),
		"bed": Color("4f6a62"),
		"forest_floor": Color("6a5a45"),
		"slickrock": Color("b29274"),
		"sand": Color("b39575"),
		"accent_amount": 0.3,
		"slickrock_amount": 0.25,
		"strata": 1.0,
		"water_deep": Color("1d5e5a"),
		"water_shallow": Color("4f9c8a"),
		"water_foam": Color("c9d4c2"),
	},
	"oasis":
	{
		"ground_low": Color("c09a6a"),
		"ground_high": Color("dcbc8a"),
		"accent": Color("9c8a58"),
		"road": Color("b39470"),
		"rock": Color("b8946a"),
		"bed": Color("6b6248"),
		"forest_floor": Color("7b6a40"),
		"slickrock": Color("d6b88e"),
		"sand": Color("e6cc9c"),
		"accent_amount": 0.2,
		"slickrock_amount": 0.2,
		"strata": 0.8,
		"water_deep": Color("1c4d52"),
		"water_shallow": Color("3f8f86"),
		"water_foam": Color("e8dcc0"),
	},
	"mojave":
	{
		"ground_low": Color("a88763"),
		"ground_high": Color("c9a983"),
		"accent": Color("8c8a5c"),
		"road": Color("8e7558"),
		"rock": Color("9c7656"),
		"bed": Color("6a5a46"),
		"forest_floor": Color("7a6e48"),
		"slickrock": Color("c4a682"),
		"sand": Color("d0b48c"),
		"accent_amount": 0.25,
		"slickrock_amount": 0.3,
		"strata": 0.9,
		"water_deep": Color("26443f"),
		"water_shallow": Color("5d6b52"),
		"water_foam": Color("d6c8aa"),
	},
	"forest":
	{
		"ground_low": Color("44532e"),
		"ground_high": Color("66733f"),
		"accent": Color("73663f"),
		"road": Color("736048"),
		"rock": Color("6b6d68"),
		"bed": Color("474c40"),
		"forest_floor": Color("3a3322"),
		"slickrock": Color("80807a"),
		"sand": Color("8c8066"),
		"accent_amount": 0.3,
		"slickrock_amount": 0.2,
		"strata": 0.6,
		"water_deep": Color("12333a"),
		"water_shallow": Color("3f6155"),
		"water_foam": Color("d9e0d9"),
	},
	"farmland":
	{
		"ground_low": Color("5c7333"),
		"ground_high": Color("85954d"),
		"accent": Color("9e8c4d"),
		"road": Color("806b4d"),
		"rock": Color("9e9479"),
		"bed": Color("4d4d3d"),
		"forest_floor": Color("3d4724"),
		"slickrock": Color("a69c80"),
		"sand": Color("998c6b"),
		"crop": Color("b39a4f"),
		"crop_alt": Color("5c7a2e"),
		"accent_amount": 0.25,
		"furrow_amount": 0.9,
		"strata": 0.8,
		"water_deep": Color("193d42"),
		"water_shallow": Color("4d6b5c"),
		"water_foam": Color("dce0d4"),
	},
	"village":
	{
		"ground_low": Color("527030"),
		"ground_high": Color("738c42"),
		"accent": Color("9a9a59"),
		"road": Color("8c806b"),
		"rock": Color("b3ad99"),
		"bed": Color("4a4d3d"),
		"forest_floor": Color("3a4523"),
		"slickrock": Color("b8b3a0"),
		"sand": Color("8c8c5c"),
		"crop": Color("bfa859"),
		"crop_alt": Color("6b8a36"),
		"accent_amount": 0.3,
		"furrow_amount": 0.85,
		"strata": 0.5,
		"water_deep": Color("1a3a3d"),
		"water_shallow": Color("4d6658"),
		"water_foam": Color("e0e3da"),
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
	# Fjord head: wet dark gneiss and heath by the water, snow from the moraines up.
	"fjord":
	{
		"canopy": Color("2c3d31"),
		"ground_low": Color("4c5446"),
		"ground_high": Color("6c7259"),
		"accent": Color("6b5f45"),
		"road": Color("6e6a62"),
		"rock": Color("585d5e"),
		"bed": Color("3c4a4c"),
		"forest_floor": Color("c9d1d4"),
		"slickrock": Color("7b8080"),
		"sand": Color("8a877d"),
		"snow": Color("e9eef1"),
		"accent_amount": 0.35,
		"snow_amount": 0.18,
		"snow_high": 0.85,
		"strata": 0.6,
		"water_deep": Color("17414b"),
		"water_shallow": Color("4a8a8a"),
		"water_foam": Color("e6eeee"),
	},
	# High alpine pass: wind-crusted snow over scree, the valleys partly bare.
	"alpine":
	{
		"canopy": Color("33443a"),
		"ground_low": Color("6a6c63"),
		"ground_high": Color("8a8b80"),
		"accent": Color("7d7458"),
		"road": Color("7f7d78"),
		"rock": Color("6e7276"),
		"bed": Color("4d5a60"),
		"forest_floor": Color("d3dade"),
		"slickrock": Color("8f9294"),
		"sand": Color("94918a"),
		"snow": Color("edf1f4"),
		"accent_amount": 0.3,
		"snow_amount": 0.55,
		"snow_high": 1.0,
		"strata": 0.7,
		"water_deep": Color("1c4250"),
		"water_shallow": Color("4f8592"),
		"water_foam": Color("eef2f4"),
	},
	# Polar plateau: snow throughout; the sand mask marks wind-scoured blue ice.
	"polar":
	{
		"ground_low": Color("c9d3da"),
		"ground_high": Color("e4eaee"),
		"accent": Color("b7c3cb"),
		"road": Color("b9c0c4"),
		"rock": Color("5d6166"),
		"bed": Color("51606a"),
		"forest_floor": Color("c8d0d4"),
		"slickrock": Color("d6dee3"),
		"sand": Color("9cc2d6"),
		"snow": Color("eef3f6"),
		"accent_amount": 0.25,
		"snow_amount": 1.0,
		"snow_high": 1.0,
		"strata": 0.4,
		"water_deep": Color("1b3f52"),
		"water_shallow": Color("6aa2b8"),
		"water_foam": Color("f2f6f8"),
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
	"forest":
	{
		"band_dark": Color("3f413e"),
		"band_mid": Color("5a5c58"),
		"band_light": Color("72736d"),
		"cap": Color("4d5c33"),
		"varnish": Color("262b22"),
		"strata_scale": 0.6,
	},
	"farmland":
	{
		"band_dark": Color("8c8470"),
		"band_mid": Color("a89e87"),
		"band_light": Color("c2b8a0"),
		"cap": Color("5c7333"),
		"varnish": Color("666052"),
		"strata_scale": 1.8,
	},
	"village":
	{
		"band_dark": Color("a8a291"),
		"band_mid": Color("c2bdab"),
		"band_light": Color("d9d4c2"),
		"cap": Color("527030"),
		"varnish": Color("7a7566"),
		"strata_scale": 2.2,
	},
	"fjord":
	{
		"band_dark": Color("3c4042"),
		"band_mid": Color("53585a"),
		"band_light": Color("6d7170"),
		"cap": Color("5f6a52"),
		"varnish": Color("23292b"),
		"strata_scale": 0.9,
	},
	"alpine":
	{
		"band_dark": Color("4f5357"),
		"band_mid": Color("676b6f"),
		"band_light": Color("85898b"),
		"cap": Color("e6ebee"),
		"varnish": Color("34383b"),
		"strata_scale": 0.8,
	},
	"polar":
	{
		"band_dark": Color("3f4347"),
		"band_mid": Color("55595e"),
		"band_light": Color("6c7075"),
		"cap": Color("e9eef1"),
		"varnish": Color("2a2d31"),
		"strata_scale": 0.7,
	},
	# Glacier fronts, seracs and crevasse walls.
	"ice":
	{
		"band_dark": Color("5d93ad"),
		"band_mid": Color("8dbcd2"),
		"band_light": Color("c4e0ea"),
		"cap": Color("eef4f7"),
		"varnish": Color("3e7590"),
		"strata_scale": 1.3,
		"rock_roughness": 0.3,
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
		# Water colours go to the water material; the canopy is preview-only.
		if not key.begins_with("water_") and key != "canopy":
			material.set_shader_parameter(key, palette[key])


static func configure_water(material: ShaderMaterial, biome: String):
	var palette = PALETTES.get(biome, PALETTES.desert)
	for key in ["deep", "shallow", "foam"]:
		if palette.has("water_" + key):
			material.set_shader_parameter(key, palette["water_" + key])
