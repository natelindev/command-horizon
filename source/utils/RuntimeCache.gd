extends RefCounted

static var _thread_fallback := {}


# Keep shared runtime data under the autoload's lifetime. Static GDScript
# variables retain their scripts (and preloaded shaders) past engine shutdown.
static func bucket(key: String) -> Dictionary:
	if OS.get_thread_caller_id() == OS.get_main_thread_id():
		var loop = Engine.get_main_loop()
		if loop != null and loop is SceneTree:
			var root = (loop as SceneTree).root
			if root != null:
				var globals = root.get_node_or_null("Globals")
				if globals != null and "cache" in globals:
					return globals.cache.get_or_add(key, {})
	return _thread_fallback.get_or_add(key, {})
