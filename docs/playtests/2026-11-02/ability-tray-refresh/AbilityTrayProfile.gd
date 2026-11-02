extends "res://tests/headless/HudSelectionProfile.gd"

func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	_cpu = load("res://source/match/rendering/NativePosePacker.gd").create()
	if _cpu == null or _cpu.cpu_sample()[0] != 1:
		push_error("Caller CPU clock unavailable")
		await root.get_node("Globals").quit_game(1)
		return
	await _open("bastion")
	var units = []
	for index in 200:
		var unit = _spawn("Tank", _human, Vector3(8 + index % 20 * 3.0, 0, 8 + index / 20 * 3.0))
		units.append(unit)
	_game.hud.select_units(units)
	await _frames(5)
	var tray = _game.hud.ability_tray
	var entries = []
	for coordinated in [false, true]:
		_human.coordination_unlocked = coordinated
		tray._refresh(.1)
		var data = {}
		data.full = _measure(tray._refresh.bind(.1))
		data.units = _measure_prepared(tray._gather_unit_abilities.bind(_game.hud, entries), entries.clear)
		data.signature = _measure_prepared(tray._gather_faction_signature.bind(_game.hud, _human, entries), entries.clear)
		data.commander = _measure_prepared(tray._gather_commander_support.bind(_game, _human, entries), entries.clear)
		data.position = _measure(tray._update_position.bind(_game.hud))
		entries.clear()
		tray._gather_unit_abilities(_game.hud, entries)
		if not entries.is_empty():
			data.block = _measure(tray._blocks.back().update_data.bind(entries[0]))
		print("TRAY CPU ", JSON.stringify({"coordinated":coordinated,"units":200,"samples":40,"measurements":data}))
	_human.coordination_unlocked = true
	_human.signatures.groups.clear()
	for index in range(0,198,6):
		_human.signatures.groups.append({"id":index+1,"left":20.0,"members":units.slice(index,index+6)})
	var grouped = {}
	grouped.signature = _measure_prepared(tray._gather_faction_signature.bind(_game.hud, _human, entries), entries.clear)
	grouped.full = _measure(tray._refresh.bind(.1))
	print("TRAY GROUP CPU ", JSON.stringify({"units":200,"groups":33,"samples":40,"measurements":grouped}))
	_game.queue_free()
	await _frames(5)
	await root.get_node("Globals").quit_game(0)
