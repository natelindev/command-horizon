extends "res://tests/headless/SaveRestoreEdges.gd"

# Garrisonable buildings on authored battlefields: NeutralWorld adopts every
# authored garrison in its listed order, the bodies sit on the ground (not on
# the raised navigation surface), infantry can enter, aircraft climb over
# them, and an occupied garrison survives save validation and restore.
const MAP = "res://source/match/maps/battlefields/EmberworksMap.tscn"
const Registry = preload("res://source/match/maps/terrain/BattlefieldRegistry.gd")


func _run():
	await _skirmish("bastion", MAP)
	await _frames(30)
	var layout = Registry.layout(MAP)
	var buildings = game.get_node("NeutralWorld").buildings
	_check(
		buildings.size() == layout.garrisons.size() and buildings.size() == 4,
		"Emberworks adopted %d of %d garrisons" % [buildings.size(), layout.garrisons.size()]
	)
	for index in mini(buildings.size(), layout.garrisons.size()):
		var building = buildings[index]
		var body = building.get_parent()
		var expected: Vector2 = layout.garrisons[index].position
		var flat = Vector2(body.global_position.x, body.global_position.z)
		_check(
			flat.distance_to(expected) < 1.5,
			"Garrison %d adopted out of authored order at %s" % [index, flat]
		)
		_check(
			absf(body.global_position.y - game.map.height_at(flat)) < 0.3,
			"Garrison %d floats %.2f m off the ground" % [index, body.global_position.y]
		)
		_check(building.habitable, "Garrison %d cannot house infantry" % index)
		var roof = body.get_node("MovementObstacle").sight_height
		var above = game.map.flight_height_at(body.global_position, 2.0)
		_check(above > roof, "Aircraft would clip garrison %d (%.1f m)" % [index, above])
	if buildings.is_empty():
		_finish()
		return
	var human = game._get_human_player()
	var building = buildings[0]
	var soldier = load("res://source/match/units/Infantry.tscn").instantiate()
	var door = building.global_position + Vector3(building.radius + 1.5, 0, 0)
	game._setup_and_spawn_unit(soldier, Transform3D(Basis(), door), human, true)
	await _frames(20)
	# The player's contextual order, as a right-click on the building.
	human.get_node("UnitActionsController")._navigate_unit_towards_unit(soldier, building)
	await _frames(240)
	_check(soldier in building.occupants, "Infantry could not garrison an authored building")
	_check(building.player == human, "Garrison did not take its occupant's side")
	var builder = Snapshot.new()
	paused = true
	var snapshot = builder.capture(game)
	_check(snapshot != null, "Garrison capture failed: " + builder.error)
	if snapshot != null:
		_check(Restore.new().prepare(snapshot), "Garrisoned authored map snapshot was rejected")
		var restore = Restore.new()
		var file = FileStore.new()
		var archive = "user://authored-garrison-%d.json" % OS.get_process_id()
		_check(file.write_file(archive, snapshot), "Garrison archive write failed")
		var loaded = await restore.restore(self, file.read_file(archive))
		DirAccess.remove_absolute(archive)
		_check(loaded.ok, "Garrison restore failed: " + loaded.get("error", ""))
		if loaded.ok:
			game = loaded.game
			var restored = game.get_node("NeutralWorld").buildings
			_check(
				restored.size() == 4 and restored[0].occupants.size() == 1,
				"Restore lost the garrison or its occupant"
			)
	_finish()


func _finish():
	paused = false
	print("Authored garrison regression: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _check(value, message):
	if not value:
		errors.append(message)
		push_error(message)
