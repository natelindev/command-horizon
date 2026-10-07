extends "res://tests/headless/FrontierGameplayRegression.gd"

const EVIDENCE = "res://docs/playtests/2026-10-07/signature-feedback/"
var actor
var other
var panel
var stage_records = []


func _run():
	factions = load("res://source/match/FactionCatalog.gd")
	root.get_node("SaveManager").autosaves_enabled = false
	await _display_setup()
	for faction in ["frontier", "bastion", "helix"]:
		await _skirmish(faction, "res://source/match/maps/PlainAndSimple.tscn")
		human = game._get_human_player()
		enemy = get_nodes_in_group("players").filter(func(side): return side != human)[0]
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
		for unit in get_nodes_in_group("units"):
			unit.process_mode = Node.PROCESS_MODE_DISABLED
		actor = _spawn_frontier("CombatRobot", human, Vector3(23, 0, 32))
		other = _spawn_frontier("CombatRobot", human, Vector3(23, 0, 35))
		var target = _spawn_frontier("Tank", enemy, Vector3(27, 0, 32))
		for unit in [actor, other, target]:
			unit.process_mode = Node.PROCESS_MODE_DISABLED
			unit.issue_manual_order(null)
		actor.signature.process_mode = Node.PROCESS_MODE_PAUSABLE
		other.signature.process_mode = Node.PROCESS_MODE_PAUSABLE
		game.battlefield.invalidate()
		game.hud._toggle_pause()
		await _select([actor])
		_check(
			panel._summary.text == "Research Coordination",
			faction + ": research instruction missing"
		)
		human.coordination_unlocked = true
		panel.refresh()
		_check(not panel._activate.disabled, faction + ": eligible ability disabled")
		await _review(faction + "-ready")
		var order = actor.action
		await _activate()
		_check(actor.action == order, faction + ": ability changed current order")
		panel.refresh()
		_expect_active(faction)
		await _review(faction + "-active")
		if not "--baseline" in OS.get_cmdline_user_args():
			await _archive(faction)
		var before = actor.signature.capture()
		await _frames(15)
		_check(actor.signature.capture() == before, faction + ": paused ability advanced")
		game.hud._toggle_pause()
		await _frames(150 if faction == "bastion" else 390)
		game.hud._toggle_pause()
		panel.refresh()
		if faction == "bastion":
			_check(
				"anchored" in panel._summary.text.to_lower(), "Settled Anchor hidden by cooldown"
			)
		else:
			_check("Recharging" in panel._summary.text, faction + ": expired effect not recharging")
		await _review(faction + "-later")
		# Distinct real cohorts: the older cooldown must determine first availability.
		_check(
			human.signatures.activate([other], other.position) == 1,
			faction + ": second cohort rejected"
		)
		actor.signature.kind = ""
		actor.signature.anchored = false
		other.signature.kind = ""
		other.signature.anchored = false
		# Controlled end-of-effect fixture retains actual independently aged cooldowns.
		await _select([actor, other])
		panel.refresh()
		var soon = minf(actor.signature.cooldown, other.signature.cooldown)
		_check(
			("%.1f s" % soon) in panel._summary.text,
			faction + ": summary shows latest instead of earliest recharge"
		)
		await _review(faction + "-mixed-recharge")
		# A ready unit in another selection remains usable while this cohort cools.
		var ready = _spawn_frontier("CombatRobot", human, Vector3(24, 0, 34))
		ready.process_mode = Node.PROCESS_MODE_DISABLED
		ready.issue_manual_order(null)
		game.battlefield.invalidate()
		await _select([actor, ready])
		_check(
			not panel._activate.disabled and "1 ready" in panel._summary.text,
			faction + ": partial ready selection disabled"
		)
		actor.program.installed = false
		actor.signature.cooldown = 0
		actor.signature.group_id = 0
		human.signatures.groups.clear()
		await _select([actor])
		_check(
			"chip" in panel._summary.text.to_lower(), faction + ": missing chip has no instruction"
		)
		await _cleanup()
	await _display_restore()
	(
		FileAccess
		. open(
			(
				EVIDENCE
				+ (
					"baseline.json"
					if "--baseline" in OS.get_cmdline_user_args()
					else "verified.json"
				)
			),
			FileAccess.WRITE
		)
		. store_string(JSON.stringify(stage_records, "\t"))
	)
	for message in errors:
		push_error(message)
	print("Signature feedback: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _select(units):
	for unit in get_nodes_in_group("selected_units"):
		unit.get_node("Selection").deselect()
	for unit in units:
		unit.get_node("Selection").select()
	await _frames(6)
	panel = game.find_child("UnitMenus")._signature_panel
	_check(panel != null, "Selection lacks ability controls")
	if panel != null:
		panel.refresh()


func _activate():
	_check(human.signatures.activate([actor], actor.position) == 1, "Actual activation failed")


func _expect_active(faction):
	var word = {"frontier": "Maneuver", "bastion": "Setting up", "helix": "Precision"}[faction]
	_check(word in panel._summary.text, faction + ": active effect hidden by recharge")


func _archive(faction):
	var builder = Snapshot.new()
	var data = builder.capture(game)
	var id = builder._reference(actor)
	var other_id = builder._reference(other)
	var store = FileStore.new()
	var file = EVIDENCE + faction + "-active.json"
	_check(store.write_file(file, data), "Active ability archive write failed")
	var restore = Restore.new()
	var result = await restore.restore(self, store.read_file(file))
	_check(result.ok, "Active ability archive rejected")
	if not result.ok:
		return
	game = result.game
	human = game._get_human_player()
	actor = restore.entities[id]
	other = restore.entities[other_id]
	for unit in get_nodes_in_group("units"):
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	actor.signature.process_mode = Node.PROCESS_MODE_PAUSABLE
	other.signature.process_mode = Node.PROCESS_MODE_PAUSABLE
	var again = builder.capture(game)
	_check(
		paused and again.simulation_time == data.simulation_time and again.players == data.players,
		"Ability UI changed saved time/economy/cohorts"
	)
	for record in data.units:
		var saved = again.units.filter(func(unit): return unit.id == record.id)[0]
		for key in ["position", "hp", "action", "orders", "signature"]:
			if record.has(key):
				_check(saved[key] == record[key], "Ability UI changed saved " + key)
	await _select([actor])
	_expect_active(faction)


func _review(label):
	stage_records.append(
		{
			"stage": label,
			"text": panel._summary.text,
			"disabled": panel._activate.disabled,
			"time": game.simulation_time
		}
	)


func _display_setup():
	pass


func _display_restore():
	pass
