extends SceneTree

var errors = []


func _initialize():
	_run.call_deferred()


func _run():
	var globals = root.get_node("Globals")
	var material = _cached_material()
	_check(material.get_ref() != null, "Runtime cache did not retain its shared material")
	globals.cache.erase("object_materials")
	_check(material.get_ref() == null, "Cleared runtime cache retained its material")
	var catalog = load("res://source/match/campaign/CampaignCatalog.gd")
	var count = catalog.operations().size()
	_check(count > 5 and not catalog.stories().is_empty(), "Campaign catalog did not load")
	globals.cache.erase("campaign_catalog")
	_check(catalog.operations().size() == count, "Campaign cache did not rebuild")
	var director = root.get_node("MusicDirector")
	director.play_track("bastion")
	var deadline = Time.get_ticks_msec() + 10000
	while director.current_track != "bastion" and Time.get_ticks_msec() < deadline:
		await process_frame
	_check(director.current_track == "bastion", "Music did not start before shutdown")
	# Quit during playback with another threaded load outstanding. Include the
	# positional players used by scene effects, and quit while already paused.
	director.play_track("frontier")
	for player in [AudioStreamPlayer.new(), AudioStreamPlayer2D.new(), AudioStreamPlayer3D.new()]:
		root.add_child(player)
		player.stream = load("res://assets/audio/ui/click.wav")
		player.play()
	paused = true
	Engine.time_scale = 0.0
	for message in errors:
		push_error(message)
	if errors.is_empty() and "--window-close" in OS.get_cmdline_user_args():
		print("Runtime shutdown: native close requested with 0 failures")
		root.propagate_notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
		# Repeated close requests must share the existing shutdown operation.
		root.propagate_notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
		return
	await globals.quit_game(0 if errors.is_empty() else 1)
	print("Runtime shutdown: %d failures" % errors.size())


func _cached_material():
	var materials = load("res://source/match/ObjectMaterials.gd")
	var original = StandardMaterial3D.new()
	return weakref(materials.textured(original))


func _check(value, message):
	if not value:
		errors.append(message)
