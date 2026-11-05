extends SceneTree

var _scene = null
var errors = []


func _initialize():
	call_deferred("_run")


func _run():
	if DisplayServer.get_name() == "headless":
		push_error("HelixPreview requires a graphical renderer")
		quit(1)
		return
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1440, 900)
	root.content_scale_size = root.size
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	DirAccess.make_dir_recursive_absolute("res://art/helix/v1")
	var factions = load("res://source/match/FactionCatalog.gd")
	_scene = load("res://source/showcase/HelixShowcase.tscn").instantiate()
	root.add_child(_scene)
	current_scene = _scene
	_scene._rotation_enabled = false
	var reviewed = 0
	for roster in [_scene.INFANTRY, _scene.UNITS, _scene.STRUCTURES]:
		_scene._show_roster(roster)
		for role in roster:
			_scene._select(role)
			_check(is_instance_valid(_scene._model), "Missing model: " + role)
			_check(_scene._title.text == factions.title("helix", role), "Stale title: " + role)
			_check(
				_scene._description.text == factions.description("helix", role),
				"Stale description: " + role
			)
			_check(
				not _scene._model.find_children("*", "MeshInstance3D", true, false).is_empty(),
				"Empty model: " + role
			)
			if role in _scene.INFANTRY:
				_check(
					_scene._model.has_node("InfantryRig/Chest/WeaponCarry/ServiceWeapon"),
					"Legacy infantry GLB: " + role
				)
			if role == "AdvancedTank":
				_check(
					_scene._model.get_child(0).scene_file_path.ends_with("PrismSkimmer.glb"),
					"Legacy Prism artillery"
				)
			for frame in 4:
				await process_frame
			if (
				role in _scene.INFANTRY
				or role in ["Tank", "AntiGroundTurret", "AdvancedTank", "AircraftFactory"]
			):
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://art/helix/v1/godot-%s.png" % role)
			reviewed += 1
		# All choices remain accessible at the minimum review height.
		root.size = Vector2i(1280, 720)
		await process_frame
		await process_frame
		_check(_scene._roster.get_global_rect().end.y < 620, "Review choices overflow 720p")
		root.size = Vector2i(1440, 900)
		await process_frame
	var old_color = _scene._team_material.albedo_color
	_scene._change_team()
	_check(_scene._team_material.albedo_color != old_color, "Team color control stopped working")
	_scene._back()
	await process_frame
	await process_frame
	_check(
		current_scene.scene_file_path == "res://source/main-menu/Main.tscn",
		"Back navigation failed"
	)
	current_scene.queue_free()
	await process_frame
	for message in errors:
		push_error(message)
	print("Helix production model review: %d models, %d failures" % [reviewed, errors.size()])
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)


func _check(condition, message):
	if not condition:
		errors.append(message)
