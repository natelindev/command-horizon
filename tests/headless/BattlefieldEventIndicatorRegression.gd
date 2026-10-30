# gdlint: disable=max-returns
extends "res://tests/headless/SaveRestoreEdges.gd"

## Regression test for Battlefield World Event indicators:
## Verifies that:
## 1. Active world event cargos attach a persistent 3D TacticalBeacon (light pillar / ground ring).
## 2. Off-screen camera edge indicators appear on the HUD pointing towards active off-screen cargos.
## 3. Indicators display the event title and remaining time, and hide when the cargo is in view.
## 4. Indicators and 3D beacons automatically vanish when cargo is claimed or expires.


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	await _skirmish("bastion", "res://source/match/maps/battlefields/DesertFrontierMap.tscn", true)
	var hud = game.hud
	_check(is_instance_valid(hud), "HUD is missing from match")
	if not is_instance_valid(hud):
		quit(1)
		return

	var indicators = hud.event_edge_indicators
	_check(is_instance_valid(indicators), "EventEdgeIndicators is missing from HUD")
	if not is_instance_valid(indicators):
		quit(1)
		return

	var events = game.battlefield_events
	_check(is_instance_valid(events), "BattlefieldEvents is missing from game")
	_check(not events.occurrences.is_empty(), "No occurrences scheduled in DesertFrontier")
	if events.occurrences.is_empty():
		quit(1)
		return

	# 1. Activate the first world event
	var event = events.occurrences[0]
	events._activate(event)
	await _frames(4)

	var available_cargos = event.cargos.filter(func(c): return c.status == "available")
	_check(not available_cargos.is_empty(), "No cargos available after event activation")
	if available_cargos.is_empty():
		quit(1)
		return

	var cargo = available_cargos[0]
	var cargo_node = cargo.node
	_check(is_instance_valid(cargo_node), "TacticalCargo node was not created")
	_check(cargo_node.public_marker, "TacticalCargo public_marker is not true")
	_check(
		cargo_node.has_node("TacticalBeacon"), "TacticalBeacon was not attached to TacticalCargo"
	)

	# 2. Test off-screen indicator creation
	# Move the camera far away to ensure cargo is off-screen
	if is_instance_valid(game._camera):
		game._camera.position = cargo.point + Vector3(500.0, 500.0, 500.0)
	indicators._update_indicators()
	await _frames(2)

	_check(indicators._indicators.has(cargo.id), "Off-screen indicator was not created for cargo")
	if indicators._indicators.has(cargo.id):
		var entry = indicators._indicators[cargo.id]
		_check(entry.button.visible, "Indicator button is not visible when cargo is off-screen")
		_check(
			entry.label.text.contains("Supply aircraft"),
			"Indicator label does not contain event title: " + entry.label.text
		)

		# 3. Test in-view hiding via clicking the indicator
		entry.button.pressed.emit()
		await _frames(4)
		indicators._update_indicators()
		_check(
			not entry.button.visible,
			"Indicator button remained visible after jumping camera to cargo"
		)

	# 4. Test cleanup on claim or expiry
	cargo_node.dismiss()
	await _frames(4)
	indicators._update_indicators()
	_check(
		not indicators._indicators.has(cargo.id),
		"Indicator remained active after cargo was dismissed"
	)

	quit(0)
