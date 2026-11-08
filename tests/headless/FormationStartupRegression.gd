class_name FormationStartupMainLoop
extends "res://tests/headless/MechanicsRegression.gd"


func _run():
	print("Formation startup fixture entered")
	root.get_node("SaveManager").autosaves_enabled = false
	await _open("bastion")
	var planner = load("res://source/match/orders/FormationPlanner.gd")
	var loader = load("res://source/match/rendering/NativePosePacker.gd")
	if "--require-optimized-runtime" in OS.get_cmdline_user_args():
		_check(OS.has_feature("copperfin_optimized_macos"), "Optimized engine feature is missing")
		_check(
			ProjectSettings.get_setting_with_override("rendering/driver/threads/thread_model") == 2,
			"Optimized release did not select the patched renderer"
		)
	_test_descriptor_preflight(planner)
	var native_expected = (
		not OS.has_feature("double")
		and "--disable-native-kernels" not in OS.get_cmdline_user_args()
		and planner._native_library_available(
			ProjectSettings.globalize_path("res://native/bin/copperfin.gdextension")
		)
	)
	if "--require-native-solver" in OS.get_cmdline_user_args():
		native_expected = true
	_check(
		not native_expected or ClassDB.class_exists("CopperfinCrowdRuntime"),
		"Solver was not warmed before match input"
	)
	if native_expected and ClassDB.class_exists("CopperfinCrowdRuntime"):
		var solver = ClassDB.instantiate("CopperfinCrowdRuntime")
		_check(solver.has_method("assign_formation"), "Warmed solver lacks exact assignment API")
	var origins = PackedVector3Array()
	var targets = PackedVector3Array()
	for index in 200:
		origins.append(Vector3(index % 20, 0, index / 20))
		targets.append(Vector3(index % 20, 0, index / 20) + Vector3(2, 0, 5))
	var started = Time.get_ticks_usec()
	var assignment = planner.hungarian(origins, targets)
	var elapsed = (Time.get_ticks_usec() - started) / 1000.0
	_check(assignment.size() == 200, "First input lost formation members")
	if native_expected:
		_check(elapsed <= 16.6, "First formation input performed deferred extension loading")
	if not loader.runtime_enabled("--native-crowd-runtime"):
		_check(_game.crowd_runtime == null, "Numerical warm-up enabled native crowd")
	elif native_expected:
		_check(
			_game.crowd_runtime != null and _game.crowd_runtime.active,
			"Configured native crowd did not activate"
		)
	if not loader.runtime_enabled("--native-unit-state"):
		_check(_game.unit_state_store == null, "Numerical warm-up enabled native unit state")
	elif native_expected:
		_check(_game.unit_state_store != null, "Configured native unit state did not activate")
	if OS.has_feature("copperfin_optimized_macos") and native_expected:
		_check(_game.battlefield._native_visibility != null, "Optimized visibility is inactive")
		_check(_game.battlefield.native_combat_queries, "Optimized combat queries are inactive")
		_check(
			_game.battlefield.native_battlefield_index, "Optimized battlefield index is inactive"
		)
		_check(_game.battlefield.native_exploration, "Optimized exploration is inactive")
		for player in get_nodes_in_group("players"):
			_check(player.indexed_rosters, "Optimized roster is inactive")
	if (
		OS.get_name() not in ["Windows", "macOS"]
		and "--enable-native-kernels" not in OS.get_cmdline_user_args()
	):
		_check(
			_game.battlefield._native_queries == null, "Numerical warm-up enabled native queries"
		)
		var renderer = _game.get_node_or_null("UnitBatchRenderer")
		_check(
			renderer == null or renderer._native == null,
			"Numerical warm-up enabled native rendering"
		)
	_game.queue_free()
	await _frames(5)
	for message in _errors:
		push_error(message)
	print("Formation startup: first200_ms=", elapsed, " failures=", _errors.size())
	await root.get_node("Globals").quit_game(0 if _errors.is_empty() else 1)


func _test_descriptor_preflight(planner):
	var directory = "user://test-artifacts/formation-native-preflight"
	DirAccess.make_dir_recursive_absolute(directory)
	var descriptor_path = directory.path_join("solver.gdextension")
	var library_path = directory.path_join("solver.bin")
	var library = FileAccess.open(library_path, FileAccess.WRITE)
	library.store_8(0)
	library.close()
	var features = func(feature): return feature in ["testos", "testarch"]
	var descriptor = ConfigFile.new()
	descriptor.set_value("libraries", "testos.otherarch", "solver.bin")
	descriptor.save(descriptor_path)
	_check(
		not planner._native_library_available(descriptor_path, features),
		"Unsupported architecture was passed to the extension loader"
	)
	descriptor.erase_section("libraries")
	descriptor.set_value("libraries", "testos.testarch", "missing.bin")
	descriptor.save(descriptor_path)
	_check(
		not planner._native_library_available(descriptor_path, features),
		"Missing native library was passed to the extension loader"
	)
	descriptor.set_value("libraries", "testos.testarch", "solver.bin")
	descriptor.save(descriptor_path)
	_check(
		planner._native_library_available(descriptor_path, features),
		"Compatible relative native library was rejected"
	)
	descriptor.set_value("libraries", "testos.testarch", library_path)
	descriptor.save(descriptor_path)
	_check(
		planner._native_library_available(descriptor_path, features),
		"Compatible absolute native library was rejected"
	)
	DirAccess.remove_absolute(descriptor_path)
	DirAccess.remove_absolute(library_path)
	_check(
		not planner._native_library_available(descriptor_path, features),
		"Absent native descriptor was passed to the extension loader"
	)
