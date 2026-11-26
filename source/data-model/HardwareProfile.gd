extends RefCounted

## Hardware capability detection, graphics presets, and 3D render-scale tuning.
## Keeps Ultra/max-fidelity options intact for high-end desktop GPUs (e.g. RTX 4090)
## while automatically scaling resolution and expensive passes on integrated or
## HiDPI Apple Silicon hardware.

enum Tier { LOW = 0, MEDIUM = 1, HIGH = 2, ULTRA = 3 }

const PRESET_CUSTOM = 4
const PRESET_NAMES = ["Low", "Medium", "High", "Ultra", "Custom"]
const TIER_NAMES = ["Low", "Medium", "High", "Ultra"]
const TARGET_PIXELS = {
	Tier.LOW: 1280.0 * 720.0,
	Tier.MEDIUM: 1600.0 * 900.0,
	Tier.HIGH: 2560.0 * 1440.0,
	Tier.ULTRA: 3840.0 * 2160.0,
}
const PRESETS = {
	Tier.LOW:
	{
		"graphics_shadows": false,
		"graphics_shadow_quality": 0,
		"graphics_ao": false,
		"graphics_gi": false,
		"graphics_glow": false,
		"graphics_fog": false,
		"graphics_liquids": false,
		"graphics_water_refraction": false,
		"graphics_clouds": false,
		"graphics_dust": false,
		"environment_quality": 0,
		"graphics_dof": false,
		"graphics_msaa": 0,
		"graphics_ground_detail": false,
		"battlefield_wear": false,
		"area_lighting": false,
		"weather_particles": false,
		"living_world": false,
		"graphics_render_scale": 0.0,
		"graphics_upscaling": 1,
	},
	Tier.MEDIUM:
	{
		"graphics_shadows": true,
		"graphics_shadow_quality": 1,
		"graphics_ao": false,
		"graphics_gi": false,
		"graphics_glow": true,
		"graphics_fog": true,
		"graphics_liquids": true,
		"graphics_water_refraction": false,
		"graphics_clouds": true,
		"graphics_dust": true,
		"environment_quality": 0,
		"graphics_dof": false,
		"graphics_msaa": 0,
		"graphics_ground_detail": true,
		"battlefield_wear": true,
		"area_lighting": false,
		"weather_particles": true,
		"living_world": true,
		"graphics_render_scale": 0.0,
		"graphics_upscaling": 1,
	},
	Tier.HIGH:
	{
		"graphics_shadows": true,
		"graphics_shadow_quality": 1,
		"graphics_ao": true,
		"graphics_gi": false,
		"graphics_glow": true,
		"graphics_fog": true,
		"graphics_liquids": true,
		"graphics_water_refraction": true,
		"graphics_clouds": true,
		"graphics_dust": true,
		"environment_quality": 1,
		"graphics_dof": false,
		"graphics_msaa": 1,
		"graphics_ground_detail": true,
		"battlefield_wear": true,
		"area_lighting": false,
		"weather_particles": true,
		"living_world": true,
		"graphics_render_scale": 0.0,
		"graphics_upscaling": 1,
	},
	Tier.ULTRA:
	{
		"graphics_shadows": true,
		"graphics_shadow_quality": 2,
		"graphics_ao": true,
		"graphics_gi": true,
		"graphics_glow": true,
		"graphics_fog": true,
		"graphics_liquids": true,
		"graphics_water_refraction": true,
		"graphics_clouds": true,
		"graphics_dust": true,
		"environment_quality": 1,
		"graphics_dof": false,
		"graphics_msaa": 2,
		"graphics_ground_detail": true,
		"battlefield_wear": true,
		"area_lighting": true,
		"weather_particles": true,
		"living_world": true,
		"graphics_render_scale": 0.0,
		"graphics_upscaling": 1,
	},
}
const PRESET_COMPARE_KEYS = [
	"graphics_shadows",
	"graphics_shadow_quality",
	"graphics_ao",
	"graphics_gi",
	"graphics_glow",
	"graphics_fog",
	"graphics_liquids",
	"graphics_water_refraction",
	"graphics_clouds",
	"graphics_dust",
	"environment_quality",
	"graphics_dof",
	"graphics_msaa",
	"graphics_ground_detail",
	"battlefield_wear",
	"area_lighting",
	"weather_particles",
	"living_world",
]


static func detect() -> Dictionary:
	var headless := DisplayServer.get_name() == "headless"
	var method := RenderingServer.get_current_rendering_method()
	var adapter_name := ""
	var adapter_vendor := ""
	var adapter_type := RenderingDevice.DEVICE_TYPE_OTHER
	if not headless and RenderingServer.get_rendering_device() != null:
		adapter_name = RenderingServer.get_video_adapter_name()
		adapter_vendor = RenderingServer.get_video_adapter_vendor()
		adapter_type = RenderingServer.get_video_adapter_type()
	elif not headless:
		adapter_name = RenderingServer.get_video_adapter_name()
		adapter_vendor = RenderingServer.get_video_adapter_vendor()
	var cpu_cores := OS.get_processor_count()
	var tier := classify(adapter_name, adapter_vendor, adapter_type, cpu_cores, method)
	return {
		"adapter_name": adapter_name if not adapter_name.is_empty() else "Software / Headless",
		"adapter_vendor": adapter_vendor,
		"adapter_type": adapter_type,
		"cpu_cores": cpu_cores,
		"rendering_method": method,
		"tier": tier,
		"tier_name": TIER_NAMES[tier],
	}


static func classify(
	adapter_name: String,
	_adapter_vendor: String,
	adapter_type: int,
	cpu_cores: int,
	rendering_method: String
) -> int:
	var lower := adapter_name.to_lower()
	if rendering_method == "dummy" or adapter_type == RenderingDevice.DEVICE_TYPE_CPU:
		return Tier.LOW
	if (
		"llvmpipe" in lower
		or "swiftshader" in lower
		or "microsoft basic" in lower
		or "uhd graphics" in lower
		or "hd graphics" in lower
	):
		return Tier.LOW
	if rendering_method == "gl_compatibility":
		return Tier.MEDIUM if adapter_type == RenderingDevice.DEVICE_TYPE_DISCRETE_GPU else Tier.LOW
	for token in [
		"rtx 50",
		"rtx 409",
		"rtx 408",
		"rtx 407",
		"rtx 309",
		"rtx 308",
		"rtx 6000",
		"a6000",
		"titan",
		"rx 907",
		"rx 79",
		"rx 78",
		"rx 69",
		"rx 68",
		"m4 ultra",
		"m4 max",
		"m3 ultra",
		"m3 max",
		"m2 ultra",
	]:
		if token in lower:
			return Tier.ULTRA
	for token in [
		"rtx 406",
		"rtx 307",
		"rtx 306",
		"rtx 208",
		"rtx 207",
		"rtx 206",
		"gtx 108",
		"gtx 107",
		"rx 77",
		"rx 76",
		"rx 67",
		"rx 66",
		"rx 5700",
		"arc a7",
		"arc b5",
		"m4 pro",
		"m3 pro",
		"m2 max",
		"m1 max",
		"m1 ultra",
	]:
		if token in lower:
			return Tier.HIGH
	if "apple m" in lower:
		return Tier.MEDIUM
	if adapter_type == RenderingDevice.DEVICE_TYPE_DISCRETE_GPU:
		for entry_token in ["1050", "1650", "2050", "3050", "4050", "6400", "6500", "rx 550"]:
			if entry_token in lower:
				return Tier.MEDIUM
		return Tier.HIGH
	for igpu_token in ["iris", "radeon 780m", "radeon 890m", "radeon 760m", "vega", "vangogh"]:
		if igpu_token in lower:
			return Tier.MEDIUM
	return Tier.MEDIUM if cpu_cores >= 8 else Tier.LOW


static func recommended_render_scale(pixel_size: Vector2, tier: int) -> float:
	var pixels := maxf(1.0, pixel_size.x * pixel_size.y)
	var budget: float = TARGET_PIXELS.get(tier, TARGET_PIXELS[Tier.MEDIUM])
	if pixels <= budget * 1.08:
		return 1.0
	var scale := sqrt(budget / pixels)
	return clampf(snappedf(scale, 0.01), 0.25, 1.0)


static func matching_preset(options) -> int:
	for tier in [Tier.LOW, Tier.MEDIUM, Tier.HIGH, Tier.ULTRA]:
		var preset: Dictionary = PRESETS[tier]
		var matched := true
		for key in PRESET_COMPARE_KEYS:
			if options.get(key) != preset[key]:
				matched = false
				break
		if matched:
			return tier
	return PRESET_CUSTOM
