extends SceneTree


func _initialize():
	_run.call_deferred()


func _run():
	var script = load("res://source/main-menu/SkirmishMapPreview.gd")
	var preview = script.new()
	var reference = script.new()
	root.add_child(preview)
	root.add_child(reference)
	var failures = 0
	for entry in load("res://source/main-menu/Play.gd").MAPS:
		var started = Time.get_ticks_usec()
		preview.set_map(entry[0])
		print("PREVIEW ", entry[1], " ms=", (Time.get_ticks_usec() - started) / 1000.0)
		reference._generate_map(entry[0])
		for field in script.PREVIEW_FIELDS:
			if preview.get(field) != reference.get(field):
				push_error("Stale preview metadata: %s %s" % [entry[1], field])
				failures += 1
		if preview._terrain.get_image().get_data() != reference._terrain.get_image().get_data():
			push_error("Stale preview terrain: " + entry[1])
			failures += 1
	preview.free()
	reference.free()
	print("Map preview regression: %d failures" % failures)
	await root.get_node("Globals").quit_game(0 if failures == 0 else 1)
