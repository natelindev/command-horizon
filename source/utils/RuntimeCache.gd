extends RefCounted


# Keep shared runtime data under the autoload's lifetime. Static GDScript
# variables retain their scripts (and preloaded shaders) past engine shutdown.
static func bucket(key: String) -> Dictionary:
	return Engine.get_main_loop().root.get_node("Globals").cache.get_or_add(key, {})
