extends "res://tests/headless/HQCountdownRegression.gd"

var plan
var owner
var site
var producer
var hq_scene
var barracks_scene
var infantry_scene


func _run():
	plan = load("res://source/match/SkirmishPlan.gd")
	hq_scene = load("res://source/match/units/CommandCenter.tscn")
	barracks_scene = load("res://source/match/units/Barracks.tscn")
	infantry_scene = load("res://source/match/units/Infantry.tscn")
	root.get_node("SaveManager").autosaves_enabled = false
	for faction in ["bastion", "helix", "frontier"]:
		await _mirror(faction)
		owner = game._get_human_player()
		_units(owner, "CommandCenter")[0].hp = 0
		await _frames(5)
		producer = _spawn(barracks_scene, Vector3(30, 0, 50), false)
		site = _spawn(barracks_scene, Vector3(38, 0, 50), true)
		await _frames(5)
		site.construct(.5)
		owner.resource_a = 6
		owner.resource_b = 0
		var job = producer.production_queue.produce(infantry_scene)
		_check(job != null, "Could not create paid production refund")
		owner.resource_a = 64
		owner.resource_b = 20
		_check(
			plan.next_step(owner).id == "hq_refund",
			"Combined queue and foundation funds overlooked"
		)
		producer.production_queue.cancel(job)
		_check(
			plan.next_step(owner).id == "hq_foundation",
			"Queue refund did not lead to construction refund"
		)
		var funds = Vector2i(owner.resource_a, owner.resource_b)
		var action = _units(owner, "Worker")[0].action
		game.hud.battle_plan._select_step()
		_check(site.is_in_group("selected_units"), "Recovery action did not select foundation")
		_check(
			(
				Vector2i(owner.resource_a, owner.resource_b) == funds
				and _units(owner, "Worker")[0].action == action
			),
			"Review action changed funds or worker order"
		)
		site.cancel_construction()
		await _frames(4)
		_check(plan.next_step(owner).id == "CommandCenter", "Combined refunds cannot fund HQ")
		await _research_and_foundation()
		await _worker_replacement()
		paused = false
		game.queue_free()
		await _frames(5)
	for message in errors:
		push_error(message)
	print("Foundation refund advice: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _spawn(scene, point, construction):
	var unit = scene.instantiate()
	game._setup_and_spawn_unit(unit, Transform3D(Basis(), point), owner, construction)
	return unit


func _research_and_foundation():
	var lab = _spawn(load("res://source/match/units/CommandLab.tscn"), Vector3(46, 0, 50), false)
	site = _spawn(barracks_scene, Vector3(38, 0, 50), true)
	await _frames(5)
	site.construct(.5)
	owner.resource_a = 20
	owner.resource_b = 20
	_check(owner.start_coordination(lab), "Paid coordination fixture failed")
	owner.resource_a = 50
	owner.resource_b = 0
	_check(plan.next_step(owner).id == "hq_research", "Research plus foundation funding overlooked")
	owner.cancel_coordination()
	_check(
		plan.next_step(owner).id == "hq_foundation", "Research refund did not lead to foundation"
	)
	var second = _spawn(barracks_scene, Vector3(38, 0, 58), true)
	await _frames(4)
	second.construct(.75)
	owner.resource_a = 65
	_check(plan.next_step(owner).id == "hq_foundation", "Combined foundation refunds overlooked")
	site.cancel_construction()
	await _frames(4)
	_check(plan.next_step(owner).units == [second], "Second foundation refund not exposed")
	second.cancel_construction()
	await _frames(4)
	_check(plan.next_step(owner).id == "CommandCenter", "Combined foundations did not fund HQ")


func _worker_replacement():
	_spawn(hq_scene, Vector3(30, 0, 58), false)
	site = _spawn(barracks_scene, Vector3(38, 0, 50), true)
	for worker in _units(owner, "Worker"):
		worker.queue_free()
	await _frames(5)
	site.construct(.75)
	owner.resource_a = 1
	owner.resource_b = 0
	_check(
		plan.next_step(owner).id == "workers_foundation",
		"Engineer recovery overlooked unfinished structure"
	)
	site.cancel_construction()
	await _frames(4)
	_check(
		plan.next_step(owner).id == "workers", "Foundation refund did not fund replacement engineer"
	)
