extends "res://tests/headless/HeroCampaignRegression.gd"


func _initialize():
	_run.call_deferred()


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	path = "user://campaign-load-%d.json" % OS.get_process_id()
	var report = []
	for cycle in 2:
		for faction in Campaigns.ORDER:
			for id in Campaigns.ORDER[faction]:
				paused = false
				var started = Time.get_ticks_usec()
				await _make_operation(id)
				for frame in 600:
					if game.navigation.terrain.is_synchronized():
						break
					await process_frame
				var row = {
					"mission": id,
					"cycle": cycle + 1,
					"load_ms": (Time.get_ticks_usec() - started) / 1000.0,
					"static_mib": Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
					"nodes": get_node_count(),
					"navigation_ready": game.navigation.terrain.is_synchronized()
				}
				report.append(row)
				_check(row.navigation_ready, "Navigation did not finish loading: " + id)
				game.queue_free()
				await _frames(20)
				row.after_free_static_mib = (
					Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
				)
				row.after_free_nodes = get_node_count()
				row.after_free_resources = Performance.get_monitor(
					Performance.OBJECT_RESOURCE_COUNT
				)
				row.cache_entries = {}
				for key in root.get_node("Globals").cache:
					row.cache_entries[key] = root.get_node("Globals").cache[key].size()
				print("CAMPAIGN LOAD ", JSON.stringify(row))
	DirAccess.make_dir_recursive_absolute("res://tmp/hero-campaign")
	var file = FileAccess.open(
		"res://tmp/hero-campaign/campaign-load-results.json", FileAccess.WRITE
	)
	file.store_string(JSON.stringify(report, "  "))
	for message in errors:
		push_error(message)
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)
