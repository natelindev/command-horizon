extends SceneTree

## Run: godot --headless --path . --script tools/ui/bake_map_previews.gd
## Re-run after changing a selectable map's overview, spawn positions or terrain palette.
const Preview = preload("res://source/main-menu/SkirmishMapPreview.gd")
const PreviewData = preload("res://source/main-menu/MapPreviewData.gd")


func _initialize():
	_run.call_deferred()


func _run():
	var directory = "res://assets/ui/map-previews"
	DirAccess.make_dir_recursive_absolute(directory)
	var preview = Preview.new()
	root.add_child(preview)
	for entry in load("res://source/main-menu/Play.gd").MAPS:
		preview._generate_map(entry[0])
		var baked = PreviewData.new()
		baked.source_path = entry[0]
		for key in Preview.PREVIEW_FIELDS:
			baked.data[key] = preview.get(key)
		baked.terrain = preview._terrain
		var path = "%s/%s.res" % [directory, entry[0].get_file().get_basename()]
		var result = ResourceSaver.save(baked, path, ResourceSaver.FLAG_COMPRESS)
		if result != OK:
			push_error("Could not bake map preview: " + path)
			quit(1)
			return
		print("Baked ", path)
	preview.free()
	quit()
