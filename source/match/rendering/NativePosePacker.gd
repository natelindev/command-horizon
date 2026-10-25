extends RefCounted


## Optional native pose serialization and spatial-query kernels. Missing binaries
## retain the ordinary renderer and GDScript queries with the same semantics.
static func create():
	if OS.get_name() != "Windows" or not OS.has_feature("x86_64") or OS.has_feature("double"):
		return null
	if ClassDB.class_exists("CopperfinPosePacker"):
		return ClassDB.instantiate("CopperfinPosePacker")
	var relative := "native/bin/copperfin.gdextension"
	var candidates := [
		OS.get_executable_path().get_base_dir().path_join(relative),
		ProjectSettings.globalize_path("res://" + relative),
	]
	for path in candidates:
		if path.is_absolute_path() and FileAccess.file_exists(path):
			GDExtensionManager.load_extension(path)
			if ClassDB.class_exists("CopperfinPosePacker"):
				return ClassDB.instantiate("CopperfinPosePacker")
	return null
