extends SceneTree


func _initialize():
	_run.call_deferred()


func _run():
	var loader = load("res://source/match/rendering/NativePosePacker.gd")
	var arguments = OS.get_cmdline_user_args()
	var disabled = "--disable-native-kernels" in arguments
	var supported = OS.get_name() in ["Windows", "macOS"] or "--enable-native-kernels" in arguments
	supported = supported and not OS.has_feature("double")
	supported = supported and (OS.get_name() != "Windows" or OS.has_feature("x86_64"))
	var expected = supported and not disabled and "--expect-no-native" not in arguments
	var native = loader.create()
	var failed = (native != null) != expected
	for flag in loader.OPTIMIZED_FLAGS:
		var enabled = (
			not disabled and (flag in arguments or OS.has_feature("copperfin_optimized_macos"))
		)
		failed = failed or loader.runtime_enabled(flag) != enabled
	failed = failed or loader.runtime_enabled("--unqualified-experimental-runtime")
	if native != null:
		failed = failed or not native.has_method("nearby_units_filtered")
		failed = failed or not native.has_method("rebase_poses")
	# A helper may already have registered the library before a later caller.
	# Repeated lookup must still respect disable/unsupported-host decisions.
	if disabled and supported and "--expect-no-native" not in arguments:
		var helper = loader._load()
		failed = failed or helper == null
	failed = failed or (loader.create() != null) != expected
	if failed:
		push_error("Native kernel startup did not match platform, availability and flags")
	print("Native kernel startup: expected=", expected, " failures=", int(failed))
	quit(1 if failed else 0)
