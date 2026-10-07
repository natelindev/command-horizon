extends "res://tests/headless/BattlePlanRegression.gd"

const EARNED = (
	"res://docs/playtests/2026-10-06/construction-safety/"
	+ "control6-earned-case6-10-infantry_ready.json"
)
var human
var blocked
var faulted


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	plan_rules = load("res://source/match/SkirmishPlan.gd")
	library = load("res://source/match/programs/ProgramLibrary.gd")
	for faction in ["bastion", "helix", "frontier"]:
		await _fixture(faction)
		if (
			game.hud.battle_plan.get_node_or_null("SelectProgramIssues") == null
			and not plan_rules.has_method("program_issues")
		):
			_check(false, faction + ": no program issue discovery")
		else:
			await _selection_case(faction)
			await _recovery_case(faction)
		paused = false
		game.queue_free()
		await _frames(5)
	if plan_rules.has_method("program_issues"):
		await _earned_case()
	for message in errors:
		push_error(message)
	print("Program issues: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _fixture(faction):
	await _skirmish(faction, "res://source/match/maps/DesertFrontier.tscn", true)
	human = game._get_human_player()
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	for unit in get_nodes_in_group("units"):
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	_spawn_for_plan("AircraftFactory", human, Vector3(40, 0, 21))
	blocked = _spawn_for_plan("Tank", human, Vector3(41.26, 0, 24.05))
	blocked.program.installed = true
	blocked.program.configure(library.defaults("guard"))
	blocked.program.anchor = Vector3(40.5, 0, 22.5)
	blocked.program.safe_point = Vector3(34, 0, 20)
	faulted = _spawn_for_plan("Helicopter", human, Vector3(47, 1.5, 30))
	_check(
		faulted.program.configure_lua("return function(ctx,m) error('Issue fixture') end").ok,
		"Fault fixture did not compile"
	)
	_check(blocked.program.run() and faulted.program.run(), "Issue fixture did not start")
	await _frames(720)
	_check(blocked.program.mode == "Blocked", faction + ": real guard did not block")
	_check(faulted.program.mode == "Error", faction + ": real Lua fault did not suspend")
	game.hud.pause_after_load()


func _selection_case(label):
	var panel = game.hud.battle_plan
	var before = _authority()
	panel.refresh()
	_check(
		plan_rules.program_issues(human) == [blocked, faulted],
		"Issue filter includes unrelated units"
	)
	_check(
		panel._programs.visible and panel._programs.text == "Program issues · 2",
		"Issue count missing"
	)
	_check(
		"does not restart" in panel._programs.accessibility_description,
		"Issue selection authority is unexplained"
	)
	var primary = panel._title.text
	var camera = game.get_node("IsometricCamera3D")
	camera.set_physics_process(false)
	camera.set_position_safely(Vector3(10, 0, 10))
	var location = camera.position
	game.hud._overlay = Control.new()
	await panel._select_program_issues()
	_check(
		camera.position == location and _authority() == before, "Issue discovery bypassed a modal"
	)
	game.hud._overlay.free()
	game.hud._overlay = null
	panel._toggle_body()
	_check(panel._programs.is_visible_in_tree(), "Collapsed guidance hid program issues")
	await _activate_issues(panel)
	await _frames(6)
	_check(
		get_nodes_in_group("selected_units") == [blocked, faulted],
		"Issue shortcut selected the wrong units"
	)
	_check(_authority() == before, "Issue inspection altered programs, funds, orders or simulation")
	_check(panel._title.text == primary, "Issue shortcut replaced primary battle advice")
	var menus = game.find_child("UnitMenus")
	_check(
		menus._program_panel != null and menus._scroll.scroll_vertical > 0,
		"Program status stayed below the visible controls"
	)
	await _review(label + "-collapsed")
	panel._toggle_body()
	await _review(label + "-expanded")
	# Ordinary Waiting/Manual states, foreign programs and dead/queued actors
	# are not issues, and a click re-evaluates the current membership.
	var ignored = _spawn_for_plan("Tank", human, Vector3(50, 0, 30))
	for mode in ["Manual", "Waiting", "Running", "Ready"]:
		ignored.program.set_status(mode, "Filter fixture")
		_check(
			plan_rules.program_issues(human) == [blocked, faulted],
			"Ordinary state reported as issue"
		)
	ignored.program.set_status("Blocked", "Dead fixture")
	ignored.hp = 0
	_check(
		plan_rules.program_issues(human) == [blocked, faulted], "Dead program remained selectable"
	)
	ignored.queue_free()
	var enemy = get_nodes_in_group("players").filter(func(side): return side != human)[0]
	var foreign = _spawn_for_plan("Tank", enemy, Vector3(100, 0, 80))
	foreign.program.set_status("Error", "Foreign fixture")
	_check(
		plan_rules.program_issues(human) == [blocked, faulted],
		"Foreign program leaked into issue list"
	)
	foreign.queue_free()
	await _frames(2)


func _recovery_case(label):
	# Resolve one issue explicitly, then use the shortcut to find only the
	# remaining blocked guard. Its ordinary program panel performs recovery.
	faulted.issue_manual_order(null)
	game.hud.battle_plan.refresh()
	_check(
		game.hud.battle_plan._programs.text == "Program issues · 1",
		"Manual control did not clear the fault count"
	)
	await _activate_issues(game.hud.battle_plan)
	await _frames(4)
	_check(
		get_nodes_in_group("selected_units") == [blocked],
		"Resolved unit remained selected by the shortcut"
	)
	var point = Vector3(47, 0, 26)
	await _assign_and_resume(blocked, point)
	_check(
		paused and blocked.program.mode == "Ready", "Explicit paused recovery did not become Ready"
	)
	game.hud.battle_plan.refresh()
	_check(not game.hud.battle_plan._programs.visible, "Resolved issues left a stale badge")
	game.hud._toggle_pause()
	await _frames(600)
	_check(
		blocked.program.mode == "Running" and blocked.position.distance_to(point) < 1.2,
		"Recovered guard did not reach its new assignment"
	)
	game.hud.pause_after_load()
	await _review(label + "-recovered")


func _earned_case():
	var loaded = await Restore.new().restore(self, FileStore.new().read_file(EARNED))
	_check(loaded.ok, "Earned program-issue archive failed to load")
	if not loaded.ok:
		return
	game = loaded.game
	human = game._get_human_player()
	var issues = plan_rules.program_issues(human)
	_check(
		issues.size() == 2 and issues.all(func(unit): return unit.program.mode == "Blocked"),
		"Earned archive no longer has two blocked guards"
	)
	var before = _authority()
	await _activate_issues(game.hud.battle_plan)
	await _frames(6)
	_check(
		get_nodes_in_group("selected_units") == issues and _authority() == before,
		"Earned issue selection changed battle state"
	)
	await _review("earned")
	var file = "user://program-issues-%d.json" % OS.get_process_id()
	_check(
		FileStore.new().write_file(file, Snapshot.new().capture(game)), "Issue archive write failed"
	)
	loaded = await Restore.new().restore(self, FileStore.new().read_file(file))
	DirAccess.remove_absolute(file)
	_check(loaded.ok, "Issue archive disk reload failed")
	if loaded.ok:
		game = loaded.game
		human = game._get_human_player()
		before = _authority()
		await _activate_issues(game.hud.battle_plan)
		await _frames(6)
		_check(
			plan_rules.program_issues(human).size() == 2 and _authority() == before,
			"Paused disk inspection changed issue state"
		)
		await _review("earned-reloaded")
	paused = false
	game.queue_free()
	await _frames(5)


func _authority():
	return {
		"time": game.simulation_time,
		"funds": [human.resource_a, human.resource_b],
		"units":
		plan_rules.owned_units(human).map(
			func(unit):
				return {
					"id": unit.get_instance_id(),
					"position": unit.position,
					"hp": unit.hp,
					"action": unit.action,
					"orders":
					(
						unit.manual_orders.pending.duplicate(true)
						if unit.manual_orders != null
						else []
					),
					"program":
					(
						[
							unit.program.mode,
							unit.program.reason,
							unit.program.anchor,
							unit.program.safe_point,
							(
								unit.program.lua_runtime.checkpoint()
								if unit.program.lua_runtime != null
								else {}
							)
						]
						if unit.program != null
						else []
					)
				}
		)
	}


func _activate_issues(panel):
	panel.refresh()
	await panel._select_program_issues()


func _assign_and_resume(unit, point):
	unit.program.anchor = point
	_check(unit.program.run(), "Issue recovery Resume failed")


func _review(_label):
	pass
