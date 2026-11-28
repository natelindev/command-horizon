extends SceneTree

var _errors: Array[String] = []


func _initialize():
	_run.call_deferred()


func _check(condition: bool, message: String):
	if not condition:
		_errors.append(message)


func _run():
	var profile = load("res://source/data-model/HardwareProfile.gd")
	var options_script = load("res://source/data-model/Options.gd")

	_check(
		(
			profile.classify(
				"NVIDIA GeForce RTX 4090",
				"NVIDIA",
				RenderingDevice.DEVICE_TYPE_DISCRETE_GPU,
				16,
				"forward_plus"
			)
			== profile.Tier.ULTRA
		),
		"RTX 4090 did not classify as Ultra"
	)
	_check(
		(
			profile.classify(
				"NVIDIA GeForce RTX 4060",
				"NVIDIA",
				RenderingDevice.DEVICE_TYPE_DISCRETE_GPU,
				8,
				"forward_plus"
			)
			== profile.Tier.HIGH
		),
		"RTX 4060 did not classify as High"
	)
	_check(
		(
			profile.classify(
				"Apple M1 Pro",
				"Apple",
				RenderingDevice.DEVICE_TYPE_INTEGRATED_GPU,
				10,
				"forward_plus"
			)
			== profile.Tier.MEDIUM
		),
		"Apple M1 Pro did not classify as Medium"
	)
	_check(
		(
			profile.classify(
				"Intel(R) UHD Graphics 630",
				"Intel",
				RenderingDevice.DEVICE_TYPE_INTEGRATED_GPU,
				4,
				"forward_plus"
			)
			== profile.Tier.LOW
		),
		"UHD Graphics did not classify as Low"
	)

	# RTX 4090 keeps 100% native 4K/1440p; Apple M1 Pro scales 8K HiDPI down.
	_check(
		is_equal_approx(
			profile.recommended_render_scale(Vector2(3840, 2160), profile.Tier.ULTRA), 1.0
		),
		"Ultra tier downscaled native 4K"
	)
	_check(
		profile.recommended_render_scale(Vector2(7680, 4320), profile.Tier.MEDIUM) < 0.5,
		"Medium tier did not downscale 8K HiDPI backing buffer"
	)
	_check(
		is_equal_approx(
			profile.recommended_render_scale(Vector2(1280, 720), profile.Tier.MEDIUM), 1.0
		),
		"Medium tier downscaled 720p"
	)

	var opts = options_script.new()
	opts.apply_preset(profile.Tier.ULTRA)
	_check(opts.current_preset() == profile.Tier.ULTRA, "Ultra preset did not match")
	_check(
		(
			opts.graphics_gi
			and opts.graphics_rt_gi
			and opts.graphics_reflections == 2
			and opts.graphics_rt_quality == 1
			and opts.graphics_extreme_shadows
			and opts.graphics_ao
			and opts.graphics_water_refraction
			and opts.graphics_msaa == 2
			and opts.graphics_post_aa == 2
			and opts.graphics_anisotropy == 3
			and opts.graphics_tonemap == 1
			and opts.graphics_shadow_quality == 2
			and opts.area_lighting
		),
		"Ultra preset missing max-fidelity PC/RT options"
	)

	opts.apply_preset(profile.Tier.HIGH)
	_check(opts.current_preset() == profile.Tier.HIGH, "High preset did not match")
	_check(
		(
			not opts.graphics_rt_gi
			and opts.graphics_reflections == 1
			and not opts.graphics_extreme_shadows
			and opts.graphics_anisotropy == 2
			and opts.graphics_tonemap == 1
		),
		"High preset has unexpected RT or shadow defaults"
	)

	opts.apply_preset(profile.Tier.MEDIUM)
	_check(opts.current_preset() == profile.Tier.MEDIUM, "Medium preset did not match")
	_check(
		(
			not opts.graphics_gi
			and not opts.graphics_rt_gi
			and opts.graphics_reflections == 0
			and not opts.graphics_extreme_shadows
			and not opts.graphics_water_refraction
			and opts.graphics_msaa == 0
		),
		"Medium preset kept expensive GPU passes enabled"
	)

	opts.graphics_ao = true
	_check(opts.current_preset() == profile.PRESET_CUSTOM, "Tweaking preset did not report Custom")

	# Clamping of new PC fidelity options and headless RT capability contract.
	(
		opts
		. restore(
			{
				"screen": 1,
				"graphics_msaa": 99,
				"graphics_post_aa": -4,
				"graphics_anisotropy": 12,
				"graphics_tonemap": 5,
				"graphics_reflections": 7,
				"graphics_rt_quality": -2,
			}
		)
	)
	_check(
		(
			opts.graphics_msaa == 3
			and opts.graphics_post_aa == 0
			and opts.graphics_anisotropy == 3
			and opts.graphics_tonemap == 1
			and opts.graphics_reflections == 2
			and opts.graphics_rt_quality == 0
		),
		"New PC graphics options were not clamped to valid ranges"
	)
	var detected: Dictionary = profile.detect()
	_check(
		detected.has("supports_raytracing") and detected.supports_raytracing == false,
		"Headless detection should report supports_raytracing == false"
	)

	for message in _errors:
		push_error(message)
	print("Hardware profile regression: %d failures" % _errors.size())
	quit(0 if _errors.is_empty() else 1)
