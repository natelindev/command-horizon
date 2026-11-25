extends SceneTree

var _errors = []


func _initialize():
	_run.call_deferred()


func _run():
	var factions = load("res://source/match/FactionCatalog.gd")
	_check(
		factions.model_geometry("helix", "ForwardRefinery", 1.0) == null,
		"Missing helix model should return null cleanly"
	)
	_check(
		factions.model_geometry("frontier", "ForwardRefinery", 1.0) == null,
		"Missing frontier model should return null cleanly"
	)

	var bindings = load("res://source/input/KeyBindings.gd")
	_check(not bindings.held("nonexistent_scan_action"), "Unbound/missing action must not crash")

	var poi = load("res://source/match/world/PointOfInterest.gd").new()
	poi._physics_process(0.016)
	poi.free()

	var relay = load("res://source/match/objectives/CaptureRelay.gd").new()
	relay._physics_process(0.016)
	relay.free()

	var visuals = load("res://source/match/units/traits/UnitVisuals.gd").new()
	visuals._prepare_pose(0.016)
	visuals.free()

	var player_script = load("res://source/match/players/Player.gd")
	var player = player_script.new()
	var changed_count = [0]
	player.changed.connect(func(): changed_count[0] += 1)
	player.coordination_left = 10.0
	_check(player.cancel_coordination() == true, "cancel_coordination did not return true")
	_check(changed_count[0] > 0, "cancel_coordination did not emit changed")
	_check(player.cancel_coordination() == false, "double cancel_coordination should return false")
	player.free()

	var diag = load("res://source/match/debug/DiagnosticHud.tscn").instantiate()
	root.add_child(diag)
	diag.show()
	diag._physics_process(0.016)
	_check(
		diag.get_node("MarginContainer").get_theme_constant("margin_top") >= 78,
		"DiagnosticHUD overlaps top HUD rail"
	)
	_check("CPU Cores" in diag._fps_label.text, "DiagnosticHUD label not updated")
	_check("MiB Memory Used" in diag._fps_label.text, "DiagnosticHUD memory label not updated")
	diag.queue_free()

	var music = root.get_node("MusicDirector")
	music._update_proximity()

	var native = load("res://source/match/rendering/NativePosePacker.gd").create()
	if native != null:
		var packer_ok = native.has_method("crowd_step") or native.has_method("global_pose")
		_check(packer_ok, "NativePosePacker missing expected methods")

	if _errors.is_empty():
		print("PASS: scan fixes regression checks (0 failures)")
	else:
		for message in _errors:
			push_error(message)
	await root.get_node("Globals").quit_game(0 if _errors.is_empty() else 1)


func _check(condition, message):
	if not condition:
		_errors.append(message)
