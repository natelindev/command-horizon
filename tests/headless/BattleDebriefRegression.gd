extends "res://tests/headless/SaveRestoreEdges.gd"


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	for faction in ["bastion", "helix", "frontier"]:
		if "--frontier-only" in OS.get_cmdline_user_args() and faction != "frontier":
			continue
		await _record_case(faction)
		paused = false
		if is_instance_valid(game):
			game.queue_free()
		await _frames(5)
	for error in errors:
		push_error(error)
	print("Battle debrief: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _record_case(faction):
	await _skirmish(faction, "res://source/match/maps/DesertFrontier.tscn", true)
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	game.hud.pause_after_load()
	_check("battle_record" in game, faction + ": no own-force battle record")
	if not "battle_record" in game:
		return
	await _exercise(faction)


func _exercise(faction):
	var owner = game._get_human_player()
	var enemy = get_nodes_in_group("players").filter(func(player): return player != owner)[0]
	var record = game.battle_record
	_check(
		record.data.forces_trained == 0 and record.data.engineers_trained == 0,
		"Starting roster counted as trained"
	)
	_check(record.data.basic_at == 0, "Advanced unlock was not recorded at start")
	var barracks = _units(owner, "Barracks")[0]
	var infantry_scene = load("res://source/match/units/Infantry.tscn")
	var cancelled = barracks.production_queue.produce(infantry_scene)
	barracks.production_queue.cancel(cancelled)
	_check(record.data.forces_trained == 0, "Cancelled job counted as trained")
	barracks.production_queue.produce(infantry_scene)
	_units(owner, "CommandCenter")[0].production_queue.produce(
		load("res://source/match/units/Worker.tscn")
	)
	_units(enemy, "Barracks")[0].production_queue.produce(infantry_scene)
	var tank = _units(owner, "Tank")[0]
	_check(tank.program.run(), "Program fixture refused to start")
	var before_pause = record.capture()
	await _frames(30)
	_check(record.capture() == before_pause, "Paused record advanced")
	game.hud._toggle_pause()
	for frame in 1800:
		await _frames(1)
		if record.data.forces_trained == 1 and record.data.engineers_trained == 1:
			break
	game.hud.pause_after_load()
	_check(
		record.data.forces_trained == 1 and record.data.engineers_trained == 1,
		"Paid completed production was not counted exactly"
	)
	_check(record.data.program_at > 0, "Actual program activation was not recorded")
	_units(enemy, "Infantry")[0].hp = 0
	_units(owner, "Infantry")[0].hp = 0
	_units(owner, "Worker")[0].hp = 0
	_units(owner, "RepairDepot")[0].hp = 0
	var foundation = _foundation(owner)
	foundation.cancel_construction()
	await _frames(5)
	_check(record.data.foundations_lost == 0, "Cancelled foundation counted as a loss")
	foundation = _foundation(owner)
	foundation.hp = 0
	await _frames(5)
	_check(
		record.data.forces_lost == 1 and record.data.engineers_lost == 1,
		"Own and enemy casualties were mixed"
	)
	_check(
		record.data.structures_lost == 1 and record.data.foundations_lost == 1,
		"Structure loss categories were wrong"
	)
	var expected = record.capture()
	var builder = Snapshot.new()
	var snapshot = builder.capture(game)
	_check(snapshot != null, "Debrief capture failed: " + builder.error)
	if snapshot == null:
		return
	var schema = load("res://source/match/saves/SnapshotSchema.gd").new()
	_check(schema.validate(snapshot), "New snapshot rejected: " + schema.error)
	for missing in [true, false]:
		var corrupt = snapshot.duplicate(true)
		if missing:
			corrupt.battle_record.erase("program_at")
		else:
			corrupt.battle_record.unexpected = 0
		_check(not schema.validate(corrupt), "Malformed record fields accepted")
	for invalid in [-1, 1.5, 1000001]:
		var corrupt = snapshot.duplicate(true)
		corrupt.battle_record.forces_lost = invalid
		_check(not schema.validate(corrupt), "Malformed loss count accepted")
	for invalid in [NAN, INF, game.simulation_time + 1, -3]:
		var corrupt = snapshot.duplicate(true)
		corrupt.battle_record.program_at = invalid
		_check(not schema.validate(corrupt), "Malformed milestone accepted")
	var store = FileStore.new()
	var file = "user://debrief-%s-%d.json" % [faction, OS.get_process_id()]
	_check(store.write_file(file, snapshot), "Debrief disk write failed")
	var loaded = await Restore.new().restore(self, store.read_file(file))
	_check(loaded.ok, "Debrief disk restore failed")
	if not loaded.ok:
		return
	game = loaded.game
	_check(
		game.battle_record.capture() == expected, "Restore changed or duplicated recorded events"
	)
	game.finished = true
	game.result = "Victory"
	var frozen = game.battle_record.capture()
	root.get_node("MatchSignals").unit_production_finished.emit(
		_units(game._get_human_player(), "Tank")[0],
		_units(game._get_human_player(), "VehicleFactory")[0]
	)
	_check(game.battle_record.capture() == frozen, "Record changed after match end")
	game.hud.show_result(game.result)
	_check("1 trained / 1 lost" in game.result_summary(), "Result omitted recorded force outcomes")
	await _review_result(faction + "-complete")
	var legacy = snapshot.duplicate(true)
	legacy.snapshot_version = 8
	legacy.erase("rounds")
	for legacy_unit in legacy.units:
		legacy_unit.projectiles = []
		legacy_unit.erase("air")
	for stance_unit in legacy.units:
		stance_unit.erase("stance")
	legacy.erase("neutral_buildings")
	for ambient in legacy.get("ambient", []):
		ambient.erase("combat")
	legacy.erase("battle_record")
	_check(schema.validate(legacy), "Legacy snapshot rejected")
	loaded = await Restore.new().restore(self, legacy)
	_check(loaded.ok, "Legacy restore failed")
	if not loaded.ok:
		return
	game = loaded.game
	record = game.battle_record
	_check(not record.data.complete_history, "Legacy record was marked complete")
	_check(
		record.data.started_at == snapshot.simulation_time and record.data.forces_lost == 0,
		"Legacy history was invented"
	)
	_check(
		record.data.basic_at == -2 and record.data.program_at == -2,
		"Legacy milestone reported a false first event"
	)
	var partial = record.capture()
	var upgraded = Snapshot.new().capture(game)
	_check(store.write_file(file, upgraded), "Legacy record upgrade write failed")
	loaded = await Restore.new().restore(self, store.read_file(file))
	_check(loaded.ok, "Upgraded partial record restore failed")
	if not loaded.ok:
		return
	game = loaded.game
	_check(
		game.battle_record.capture() == partial,
		"Resaving partial history marked it complete or changed counts"
	)
	game.finished = true
	game.result = "Defeat"
	game.hud.show_result(game.result)
	_check(
		(
			"Battle record begins at" in game.result_summary()
			and "Not recorded" in game.result_summary()
		),
		"Partial history was not disclosed"
	)
	await _review_result(faction + "-legacy")
	print("DEBRIEF ", faction, " ", expected)
	DirAccess.remove_absolute(file)


func _foundation(owner):
	var unit = load("res://source/match/units/RepairDepot.tscn").instantiate()
	game._setup_and_spawn_unit(unit, Transform3D(Basis(), Vector3(44, 0, 27)), owner)
	return unit


func _review_result(_label):
	pass
