# gdlint: disable=max-returns
extends "res://tests/headless/SaveRestoreEdges.gd"

## Regression test for Dynamic Modular Ability Tray:
## Verifies that abilities appear as modular blocks at the top of the screen when available,
## that commander support, faction signatures, and unit tactical abilities are surfaced without
## nested menus, and that one-click direct arming / activation functions properly.

const HudLayout = preload("res://source/match/hud/HudLayout.gd")


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
		_check(sig_block._badge.text == "Z", "Signature shortcut is not Z")

	# 6. Responsive positioning check
	_check(tray.position.y >= HudLayout.TOP_RAIL - 1.0, "Ability tray position above top rail")
	_check(tray.position.x >= 0.0, "Ability tray off left screen")
	_check(tray.position.x + tray.size.x <= 1920.0 + 1.0, "Ability tray off right screen")

	paused = false
	game.queue_free()
	await _frames(5)
	for err in errors:
		push_error(err)
	print("Ability tray regression: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)
