extends "res://tests/rendered/SplitClearancePreview.gd"

var next_audit = 0.0
var audit_rows = []


func _prepare_display():
	if DisplayServer.get_name() != "headless":
		await super()


func _restore_display():
	if DisplayServer.get_name() != "headless":
		await super()


func _frames(count):
	await super(count)
	if is_instance_valid(game) and game.is_node_ready() and not paused:
		if game.simulation_time >= next_audit:
			next_audit = game.simulation_time + 10
			audit_rows.append(_audit())


func _review_recovery(label):
	if DisplayServer.get_name() != "headless":
		await super(label)
	if label == "result":
		audit_rows.append(_audit())
		FileAccess.open(evidence_prefix + "-audit.json", FileAccess.WRITE).store_string(
			JSON.stringify(audit_rows, "\t")
		)
		if not game.finished:
			game.hud._toggle_pause()
			var snapshot = Snapshot.new().capture(game)
			_check(
				Store.new().write_file(evidence_prefix + "-archive.json", snapshot),
				"Audit archive failed"
			)


func _audit():
	var sample = _sample()
	sample.units = []
	for side in [game._get_human_player(), game._enemy]:
		for unit in side.get_children():
			if not unit.is_in_group("units") or unit.movement_speed <= 0 or unit.hp <= 0:
				continue
			var row = {
				"id": unit.get_instance_id(),
				"human": side == game._get_human_player(),
				"role": unit.type,
				"hp": unit.hp,
				"position": [unit.position.x, unit.position.y, unit.position.z],
				"order": unit.manual_orders.current.get("kind", "none"),
				"order_status": unit.manual_orders.status,
				"pending": unit.manual_orders.pending.map(func(order): return order.kind),
				"action": _action_audit(unit.action),
				"observed_enemies": []
			}
			for target in game.battlefield.nearby_units(unit.position, 10):
				if target.player == side or not game.battlefield.is_observed(side, target):
					continue
				row.observed_enemies.append(
					{
						"id": target.get_instance_id(),
						"role": target.type,
						"distance": unit.position.distance_to(target.position),
						"can_fire": game.battlefield.can_fire(unit, target)
					}
				)
			sample.units.append(row)
	return sample


func _action_audit(action):
	if not is_instance_valid(action):
		return {}
	var result = {"kind": action.get_script().resource_path.get_file(), "children": []}
	for key in ["_shots", "_charge_left", "_lost_contact"]:
		if key in action:
			result[key] = action.get(key)
	if "_target_unit" in action and is_instance_valid(action._target_unit):
		result.target = action._target_unit.get_instance_id()
	for child in action.get_children():
		if child is Timer:
			result.children.append({"timer_left": child.time_left, "stopped": child.is_stopped()})
		elif child.get_script() != null and child.get_script().resource_path.contains("actions/"):
			result.children.append(_action_audit(child))
	return result
