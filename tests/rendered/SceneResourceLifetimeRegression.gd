extends SceneTree

# Reproduce the original teardown failure without entering the gameplay tree:
# the temporary PackedScene returned by load() dies immediately after instantiate.
# Compatibility leaked two 256x256 mipmapped texture allocations per instance.
var errors: Array[String] = []


func _initialize():
	_run.call_deferred()


func _run():
	if "--require-renderer" in OS.get_cmdline_user_args():
		var api = RenderingServer.get_video_adapter_api_version()
		var driver = RenderingServer.get_current_rendering_driver_name()
		if (
			DisplayServer.get_name() == "headless"
			or not (
				RenderingServer.get_current_rendering_method() == "gl_compatibility"
				and driver.begins_with("opengl")
				and not api.is_empty()
			)
		):
			push_error("Scene lifetime graphical gate requires an actual OpenGL/GLES renderer")
			await root.get_node("Globals").quit_game(1)
			return
		print("Actual scene-lifetime renderer: ", driver, " / ", api)
	for path in ["res://source/match/Match.tscn", "res://source/match/Skirmish.tscn"]:
		for iteration in 3:
			var instance = load(path).instantiate()
			if not instance._scene_template is PackedScene:
				errors.append("Instance lost its originating PackedScene: " + path)
			elif instance._scene_template.resource_path != path:
				errors.append("Wrong originating PackedScene: " + path)
			for frame in 3:
				await process_frame
			instance.free()
			for frame in 5:
				await process_frame
	for message in errors:
		push_error(message)
	print(
		(
			"Scene resource lifetime: %d failures; six temporary-template instances freed"
			% errors.size()
		)
	)
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)
