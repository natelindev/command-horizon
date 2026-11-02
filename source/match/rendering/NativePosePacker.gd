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
	if ClassDB.class_exists("CopperfinPosePacker"):
		return _instantiate()
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
