extends "res://tests/headless/PresetRecoveryRegression.gd"

const RECOVERY_LUA = """return function(s,m)
 m.ticks=(m.ticks or 0)+1
 local health=s.self.hp/s.self.hp_max
 if health<0.4 then m.retreating=true end
 if health>=0.85 then m.retreating=false end
 return {intent={kind='move',assignment=m.retreating and 'safe' or 'anchor',
 status='Scripted recovery'},state=m}
end"""
var application
var records_type
var rules_type


func _run():
	_load_authoring()
	root.get_node("SaveManager").autosaves_enabled = false
	for faction in ["bastion", "helix"]:
		await _skirmish(faction)
		for player in get_nodes_in_group("players"):
			player.set_process(false)
		for unit in get_nodes_in_group("units"):
			if unit.movement_speed > 0:
				unit.queue_free()
		await _frames(5)
		for mode in ["lua", "visual"]:
			for role in [
				"Tank", "AdvancedTank", "CombatRobot", "RepairRobot", "Drone", "Helicopter"
			]:
				await _authored_service(mode, role)
			await _authored_authority(mode)
		game.queue_free()
		await _frames(5)
	for error in errors:
		push_error(error)
	print("Authored facility recovery: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _load_authoring():
	application = load("res://source/match/programs/ProgramApplication.gd")
	records_type = load("res://source/match/programs/ProgramRecord.gd")
	rules_type = load("res://source/match/programs/VisualRules.gd")


func _recovery_entry(mode, role):
	var entry
	if mode == "visual":
		var document = rules_type.starter(1)
		document.parameters = {"retreat": 40, "recover": 85}
		if role in ["RepairRobot", "Drone"]:
			document.rules = [
				rules_type.rule("retreating", "move_safe"),
				rules_type.rule("away_anchor", "move_anchor", 2),
				rules_type.rule("always", "hold")
			]
		entry = records_type.visual("Facility recovery rules", 1, document, [role])
	else:
		entry = records_type.lua(
			"Scripted facility recovery", 1, RECOVERY_LUA, [role], ["movement"]
		)
	return entry


func _authored_service(mode, role):
	var repairs = load("res://source/match/combat/RepairService.gd")
	var service = _preset_actor(repairs.facility_for_role(role), Vector3(32, 0, 25))
	var unit = _preset_actor(role, Vector3(43, 0, 25))
	await _frames(120)
	unit.hp = unit.hp_max * .35
	unit.program.installed = true
	var entry = _recovery_entry(mode, role)
	_check(application.apply(entry, [unit], unit.player).ok, "Authored recovery could not apply")
	unit.program.anchor = Vector3(43, 0, 25)
	unit.program.safe_point = service.global_position_yless
	var healed = false
	var resumed = false
	var blocked = false
	for frame in 2400:
		await physics_frame
		if role == "Tank" and frame == 299:
			await _review_authored(unit, mode, "healing")
			var restored = await _authored_archive(unit, service)
			unit = restored[0]
			service = restored[1]
		blocked = blocked or unit.program.mode == "Blocked"
		healed = healed or unit.hp >= unit.hp_max * .85
		resumed = (
			resumed or (healed and unit.global_position_yless.distance_to(unit.program.anchor) < 3)
		)
	_check(healed, "%s %s %s never healed" % [unit.player.faction, mode, role])
	_check(not blocked, "%s %s %s blocked at service" % [unit.player.faction, mode, role])
	_check(resumed, "%s %s %s never resumed" % [unit.player.faction, mode, role])
	_check(
		(
			unit.program.lua_source == entry.source
			and unit.program.saved_record.content_hash == entry.content_hash
		),
		"Service changed the authored program"
	)
	if role == "Tank":
		await _review_authored(unit, mode, "resumed")
	print(
		"AUTHORED RECOVERY ",
		unit.player.faction,
		" ",
		mode,
		" ",
		role,
		" healed=",
		healed,
		" resumed=",
		resumed,
		" blocked=",
		blocked,
		" reason=",
		unit.program.reason
	)
	unit.queue_free()
	service.queue_free()
	await _frames(90)


func _authored_archive(unit, service):
	var memory = unit.program.lua_runtime.state_snapshot().duplicate(true)
	_check(
		memory.get("retreating", false) and unit.hp < unit.hp_max * .85,
		"Authored archive missed recovery"
	)
	_check(unit.action._destination == null, "Authored service did not stop travel")
	paused = true
	var health = unit.hp
	var position = unit.position
	var source = unit.program.lua_source
	var builder = Snapshot.new()
	var snapshot = builder.capture(game)
	var ids = [builder._reference(unit), builder._reference(service)]
	var disk = "user://authored-recovery-%d.json" % OS.get_process_id()
	_check(FileStore.new().write_file(disk, snapshot), "Authored recovery disk write failed")
	var restore = Restore.new()
	var loaded = await restore.restore(self, FileStore.new().read_file(disk))
	DirAccess.remove_absolute(disk)
	_check(loaded.ok, "Authored recovery restore failed")
	if not loaded.ok:
		paused = false
		return [unit, service]
	game = loaded.game
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	unit = restore.entities[ids[0]]
	service = restore.entities[ids[1]]
	await _frames(30)
	_check(unit.hp == health and unit.position == position, "Paused authored recovery advanced")
	_check(
		unit.program.lua_runtime.state_snapshot() == memory and unit.program.lua_source == source,
		"Authored archive changed memory/source"
	)
	paused = false
	return [unit, service]


func _authored_authority(mode):
	var service = _preset_actor("RepairDepot", Vector3(55, 0, 25))
	var unit = _preset_actor("Tank", Vector3(59.4, 0, 25))
	await _frames(120)
	unit.hp = unit.hp_max * .35
	unit.program.installed = true
	_check(
		application.apply(_recovery_entry(mode, "Tank"), [unit], unit.player).ok,
		"Authored authority Apply failed"
	)
	unit.program.anchor = Vector3(43, 0, 25)
	unit.program.safe_point = service.global_position_yless
	await _frames(120)
	unit.issue_manual_order(null)
	var memory = unit.program.lua_runtime.state_snapshot().duplicate(true)
	var position = unit.position
	await _frames(900)
	_check(unit.hp >= unit.hp_max * .99, "Authored manual Stop prevented passive healing")
	_check(
		(
			unit.program.mode == "Manual"
			and unit.position.distance_to(position) < .05
			and unit.program.lua_runtime.state_snapshot() == memory
		),
		"Service overrode authored manual authority"
	)
	_check(unit.program.run(), "Explicit authored Resume failed")
	await _frames(240)
	_check(
		unit.position.distance_to(position) > 2 and unit.program.mode == "Running",
		"Authored program did not resume explicitly"
	)
	# Only the safe assignment represents a service destination. An inaccessible
	# anchor retains ordinary bounded blocking and never silently becomes service.
	unit.issue_manual_order(null)
	_check(
		(
			unit
			. program
			. configure_lua(
				"return function(s,m) return {intent={kind='move',assignment='anchor'},state=m} end"
			)
			. ok
		),
		"Anchor control source failed"
	)
	unit.program.anchor = service.global_position_yless
	_check(unit.program.run(), "Anchor control refused to run")
	await _frames(900)
	_check(unit.program.mode == "Blocked", "Service recovery changed ordinary anchor semantics")
	print(
		"PASS: ",
		unit.player.faction,
		" ",
		mode,
		" manual Stop/state, explicit Resume and strict anchor"
	)
	unit.queue_free()
	service.queue_free()
	await _frames(90)


func _review_authored(_unit, _mode, _label):
	return true
