extends "res://tests/rendered/HudConsolePreview.gd"

var _native_proof := []


func _shot(label, spectator = false):
	var selected = get_nodes_in_group("selected_units")
	_check(selected.size() == 1, "Passenger render requires one selected carrier")
	var carrier = selected[0]
	var renderer = game.get_node("UnitBatchRenderer")
	_check(carrier.occupants.size() == 4, "Passenger render requires four mounted infantry")
	_check(carrier.is_visible_in_tree(), "Selected carrier is not visible")
	_check(carrier._native_state != null, "Carrier silently skipped native unit state")
	_check(carrier.get_node("Movement")._native_runtime != null, "Carrier skipped native crowd")
	_check(renderer._native != null, "Native pose packing is absent")
	_check(renderer._presentation != null, "Native presentation batch is absent")
	var rows := []
	for passenger in carrier.occupants:
		_check(passenger._native_state != null, "Passenger silently skipped native state")
		_check(not passenger.visible, "Mounted passenger root remained visible")
		_check(
			not passenger.get_node("Geometry").is_visible_in_tree(),
			"Mounted passenger geometry remained visible"
		)
		_check(not passenger.is_in_group("selected_units"), "Hidden passenger stayed selected")
		_check(renderer._units.has(passenger), "Mounted passenger has no actual batch entry")
		if not renderer._units.has(passenger):
			continue
		var entry: Dictionary = renderer._units[passenger]
		_check(entry.has("presentation_handle"), "Passenger has no resident presentation handle")
		var all_zero := true
		for byte in range(entry.offset * 64, (entry.offset + entry.anchors.size()) * 64, 4):
			all_zero = all_zero and renderer._last_pixels.decode_float(byte) == 0.0
		_check(all_zero, "Hidden passenger retained a rendered pose or hit pulse")
		rows.append({"offset": entry.offset, "count": entry.anchors.size(), "all_zero": all_zero})
	_check(root.get_node("Globals").options.interface_scale == 1.5, "Passenger UI lost150%")
	await super._shot(label, spectator)
	_native_proof.append(
		{
			"label": label,
			"locale": TranslationServer.get_locale(),
			"window": [root.size.x, root.size.y],
			"logical_viewport": [root.get_visible_rect().size.x, root.get_visible_rect().size.y],
			"interface_scale": root.get_node("Globals").options.interface_scale,
			"native_state": carrier._native_state.get_class(),
			"native_presentation": renderer._presentation.get_class(),
			"passenger_pose_rows": rows,
			"selected_carriers": selected.size(),
			"hidden_passengers": carrier.occupants.size()
		}
	)
	var file = FileAccess.open(
		"res://docs/playtests/2026-11-02/graphical-resume/passengers/native-state.json",
		FileAccess.WRITE
	)
	file.store_string(JSON.stringify(_native_proof, "\t") + "\n")
