# gdlint: disable=max-returns
extends "res://tests/headless/SaveRestoreEdges.gd"

## Regression test for Dynamic Modular Ability Tray:
## Verifies that abilities appear as modular blocks at the top of the screen when available,
## that commander support, faction signatures, and unit tactical abilities are surfaced without
## nested menus, and that one-click direct arming / activation functions properly.

const HudLayout = preload("res://source/match/hud/HudLayout.gd")
var _signature_checked = false


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	await _skirmish("bastion", "res://source/match/maps/DesertFrontier.tscn", true)
	var human = game._get_human_player()
	var hud = game.hud
	var tray = hud.ability_tray
	_check(is_instance_valid(tray), "Ability tray is missing from HUD")
	if not is_instance_valid(tray):
		quit(1)
		return

	# 1. Deselect everything initially - tray should be hidden before any abilities are ready
	root.get_node("MatchSignals").deselect_all_units.emit()
	tray._refresh(0.1)
	await _frames(8)

	# 2. Select a Tank - Smoke Screen should appear dynamically
	var tanks = _units(human, "Tank")
	_check(not tanks.is_empty(), "No tanks available in advanced start")
	if not tanks.is_empty():
		var tank = tanks[0]
		game.hud.select_units([tank])
		tray._refresh(0.1)
		await _frames(8)
		_check(tray.visible, "Ability tray stayed hidden with a tank selected")
		var blocks = tray._blocks.filter(func(b): return b.visible)
		_check(
			blocks.any(func(b): return b.ability_id == "unit_smoke_screen"),
			"Smoke Screen block did not appear in ability tray"
		)
		var smoke_block = blocks.filter(func(b): return b.ability_id == "unit_smoke_screen")[0]
		_check(smoke_block._badge.text == "Q", "Smoke screen badge is not Q")
		_check(smoke_block.disabled == false, "Smoke screen is not ready initially")

		# Click the smoke screen block
		smoke_block._on_pressed()
		await _frames(4)
		var smoke_ability = tank.abilities.get_ability("smoke_screen")
		_check(smoke_ability.is_active, "Clicking Smoke Screen block did not activate smoke")
		if tanks.size() > 1:
			var second = tanks[1].abilities.get_ability("smoke_screen")
			game.hud.select_units([tank, tanks[1]])
			var entries = []
			tray._gather_unit_abilities(hud, entries)
			var group = entries.filter(func(entry): return entry.id == "unit_smoke_screen")[0]
			_check(
				group.charges_text == "1/2" and group.is_ready and group.is_active,
				"Grouped tray lost mixed readiness or an active member"
			)
			second.cooldown_left = 3.0
			entries.clear()
			tray._gather_unit_abilities(hud, entries)
			group = entries.filter(func(entry): return entry.id == "unit_smoke_screen")[0]
			_check(
				not group.is_ready and group.cooldown_left == 3.0 and group.charges_text == "0/2",
				"Grouped tray retained stale readiness or the wrong cooldown"
			)
			second.cooldown_left = 0.0

	# 3. Deselect - tactical unit ability should disappear
	root.get_node("MatchSignals").deselect_all_units.emit()
	tray._refresh(0.1)
	await _frames(8)
	var active_unit_blocks = tray._blocks.filter(func(b): return b.visible and b.kind == "unit")
	_check(active_unit_blocks.is_empty(), "Unit ability blocks remained visible after deselect")

	# 4. Commander Support: Spawn power and lab, complete both and charge support
	var support = game.commander_support
	support.set_physics_process(false)
	human.resource_a = 500
	human.resource_b = 500
	var plant = load("res://source/match/units/PowerPlant.tscn").instantiate()
	game._setup_and_spawn_unit(plant, Transform3D(Basis.IDENTITY, Vector3(26, 0, 20)), human, false)
	plant._construction_progress = 1.0
	var lab = load("res://source/match/units/CommandLab.tscn").instantiate()
	game._setup_and_spawn_unit(lab, Transform3D(Basis.IDENTITY, Vector3(20, 0, 20)), human, false)
	lab._construction_progress = 1.0
	support.state(human).started = true
	support.state(human).left = 0.0
	tray._refresh(0.1)
	await _frames(4)

	_check(tray.visible, "Ability tray hidden with ready commander support")
	var cmd_blocks = tray._blocks.filter(func(b): return b.visible and b.kind == "commander")
	_check(not cmd_blocks.is_empty(), "Commander support block missing from ability tray")
	if not cmd_blocks.is_empty():
		var cmd_block = cmd_blocks[0]
		_check(cmd_block.ability_id == "commander_barrage", "Wrong commander power for Bastion")
		_check(
			cmd_block.disabled == false,
			"Commander support reported not ready: " + cmd_block.tooltip_text
		)

		# Click commander block -> arms directly without opening nested menu
		cmd_block._on_pressed()
		await _frames(4)
		_check(
			hud.direct_orders.kind == "commander",
			"Clicking commander block did not arm direct orders"
		)
		_check(
			is_instance_valid(hud.direct_orders._ability_range),
			"Commander targeting omitted range preview"
		)
		var unit_menus = game.find_child("UnitMenus")
		_check(not unit_menus._commander_open, "Direct arming unexpectedly opened bottom submenu")

		# Cancel targeting
		hud.direct_orders.cancel()
		await _frames(4)
		_check(hud.direct_orders.kind.is_empty(), "Cancel did not clear commander targeting")

	# 5. Faction Signature: unlock Coordination
	human.coordination_unlocked = true
	tray._refresh(0.1)
	await _frames(4)
	var sig_blocks = tray._blocks.filter(func(b): return b.visible and b.kind == "signature")
	_check(not sig_blocks.is_empty(), "Signature block missing after unlocking Coordination")
	if not sig_blocks.is_empty():
		var sig_block = sig_blocks[0]
		_check(sig_block._badge.text.is_empty(), "Signature advertises a conflicting hotkey")
		sig_block._on_pressed()
		_check(
			hud._assignment_kind == "signature", "Signature tile did not arm its sector directly"
		)
		hud.cancel_map_assignment()

	# 6. Responsive positioning check
	_check(tray.position.y >= HudLayout.TOP_RAIL - 1.0, "Ability tray position above top rail")
	_check(tray.position.x >= 0.0, "Ability tray off left screen")
	_check(tray.position.x + tray.size.x <= 1920.0 + 1.0, "Ability tray off right screen")
	await _signature_refresh_and_restore(human, hud, tray)
	_check(_signature_checked, "Signature refresh and restore checks did not finish")

	paused = false
	game.queue_free()
	await _frames(5)
	for err in errors:
		push_error(err)
	print("Ability tray regression: %d failures" % errors.size())
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)


func _signature_entry(human, hud, tray):
	var entries = []
	tray._gather_faction_signature(hud, human, entries)
	_check(entries.size() == 1, "Signature refresh did not produce one faction block")
	return entries[0] if entries.size() == 1 else {}


func _signature_refresh_and_restore(human, hud, tray):
	paused = true
	var tanks = _units(human, "Tank")
	_check(tanks.size() >= 2, "Signature refresh fixture needs two tanks")
	if tanks.size() < 2:
		return
	var first = tanks[0]
	var second = tanks[1]
	if "--native-unit-state" in OS.get_cmdline_user_args():
		_check(
			first._native_state != null and second._native_state != null,
			"Tray fixture omitted native state"
		)
	var original = first.signature.capture()
	first.signature.cooldown = 3.0
	# Retained membership may overlap; use each member's longest remaining group.
	human.signatures.groups = [
		{"id": 1, "left": 7.0, "members": [first]},
		{"id": 2, "left": 21.0, "members": [first]},
	]
	var entry = _signature_entry(human, hud, tray)
	_check(
		entry.cooldown_left == 21.0 and not entry.is_ready, "Tray lost maximum per-member recharge"
	)
	human.signatures.groups.append({"id": 3, "left": 9.0, "members": [second]})
	entry = _signature_entry(human, hud, tray)
	_check(entry.cooldown_left == 9.0, "Tray lost the earliest different-member recharge")
	human.signatures.groups[2].left = 0.0
	entry = _signature_entry(human, hud, tray)
	_check(entry.cooldown_left == 21.0, "Expired group retained a stale cooldown index")
	human.signatures.groups.clear()
	first.signature.restore(original)
	entry = _signature_entry(human, hud, tray)
	_check(entry.is_ready and entry.cooldown_left == 0.0, "Cleared groups left stale readiness")

	# A displayed block must resolve new fallback recipients at click time.
	root.get_node("MatchSignals").deselect_all_units.emit()
	var action: Callable = entry.action
	first.remove_from_group("controlled_units")
	var removed_id = second.get_instance_id()
	second.queue_free()
	var newcomer = load("res://source/match/units/Tank.tscn").instantiate()
	game._setup_and_spawn_unit(
		newcomer, Transform3D(Basis.IDENTITY, Vector3(38, 0, 30)), human, false
	)
	await _frames(2)
	action.call()
	_check(
		(
			hud._assignment_kind == "signature"
			and newcomer in hud._assignment_units
			and first not in hud._assignment_units
			and hud._assignment_units.all(
				func(unit): return is_instance_valid(unit) and unit.get_instance_id() != removed_id
			)
		),
		"Signature click reused removed recipients or omitted a newly eligible fallback"
	)
	hud.cancel_map_assignment()
	first.add_to_group("controlled_units")
	_check(
		human.signatures.activate([first], first.global_position) == 1,
		"Could not create real signature save fixture"
	)
	var builder = Snapshot.new()
	var saved = builder.capture(game)
	_check(saved != null, "Signature fixture snapshot failed: " + builder.error)
	if saved == null:
		return
	_check(
		saved.snapshot_version == 22, "Tray save verification changed the current snapshot version"
	)
	var signatures_before = human.signatures.capture(builder._reference)
	var unit_before = first.signature.capture()
	var clock_before = game.simulation_time
	for index in 20:
		tray._refresh(.1)
	await _frames(8)
	_check(
		(
			human.signatures.capture(builder._reference) == signatures_before
			and first.signature.capture() == unit_before
			and game.simulation_time == clock_before
		),
		"Paused presentation refresh changed persistent signature state or simulation time"
	)
	var before_restore = _signature_entry(human, hud, tray)
	var restore = Restore.new()
	var loaded = await restore.restore(self, saved)
	_check(loaded.ok, "Signature tray save restore failed: " + loaded.get("error", ""))
	if not loaded.ok:
		return
	game = loaded.game
	var restored_human = game._get_human_player()
	var after_restore = _signature_entry(restored_human, game.hud, game.hud.ability_tray)
	for key in ["cooldown_left", "is_ready", "is_active", "issue"]:
		_check(after_restore[key] == before_restore[key], "Restored tray changed signature " + key)
	_signature_checked = true
