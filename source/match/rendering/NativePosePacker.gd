extends RefCounted


## Optional native pose serialization and spatial-query kernels. Missing binaries
## retain the ordinary renderer and GDScript queries with the same semantics.
static func create():
	# Windows enables these optional simulation/render kernels by default.
	# Other hosts require explicit opt-in even when the package includes the
	# independent numerical formation helper beside the executable.
	if OS.get_name() != "Windows" and not "--enable-native-kernels" in OS.get_cmdline_user_args():
		return null
	if OS.has_feature("double") or (OS.get_name() == "Windows" and not OS.has_feature("x86_64")):
		return null
	if "--disable-native-kernels" in OS.get_cmdline_user_args():
		return null
	return _load()


## Pure value serialization is independent of the experimental render/simulation
## backends. Load extensions only on the main thread; workers may instantiate an
## already registered class, otherwise they retain the portable hash path.
static func create_state_hasher():
	if OS.has_feature("double") or "--disable-native-kernels" in OS.get_cmdline_user_args():
		return null
	var native = _load()
	return native if native != null and native.has_method("hash_state") else null


static func _load():
	if ClassDB.class_exists("CopperfinPosePacker"):
		return _instantiate()
	if OS.get_thread_caller_id() != OS.get_main_thread_id():
		return null
	var relative := "native/bin/copperfin.gdextension"
	var candidates := [
		OS.get_executable_path().get_base_dir().path_join(relative),
		ProjectSettings.globalize_path("res://" + relative),
	]
	for path in candidates:
		if path.is_absolute_path() and FileAccess.file_exists(path):
			GDExtensionManager.load_extension(path)
			if ClassDB.class_exists("CopperfinPosePacker"):
				return _instantiate()
	return null


static func _instantiate():
	var native = ClassDB.instantiate("CopperfinPosePacker")
	# Old optional binaries must never pack stale scene transforms for array poses.
	return native if native.has_method("global_pose") else null
