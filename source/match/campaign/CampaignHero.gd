extends Node

const Catalog = preload("res://source/match/campaign/CampaignCatalog.gd")
const Units = preload("res://source/match/BastionCatalog.gd")
const COOLDOWN = 30.0
var unit
var tier = 1
var cooldown = 0.0
var _game


func _ready():
	_game = get_parent()
	var act = Catalog.OPERATIONS[_game.settings.mission_id].get("act", 1)
	tier = mini(3, 1 + int((act - 1) / 2))
	if not _game.restoring:
		_bind_or_spawn()


func _bind_or_spawn():
	var human = _game._get_human_player()
	for candidate in human.get_children():
		if candidate.is_in_group("units") and candidate.type == "Hero":
			unit = candidate
			return
	var point = _game.map.get_node("SpawnPoints").get_child(0).position + Vector3(3, 0, 5)
	for candidate in human.get_children():
		if candidate.is_in_group("units") and candidate.movement_speed > 0:
			point = candidate.position + Vector3(-2, 0, -2)
			break
	unit = load(Units.scene_path("Hero")).instantiate()
	_game._setup_and_spawn_unit(unit, Transform3D(Basis(), point), human, false)


func alive():
	return is_instance_valid(unit) and not unit.is_queued_for_deletion() and unit.hp > 0


func step(delta):
	cooldown = maxf(0, cooldown - delta)
	if _game.restoring or _game.finished:
		return
	if not alive():
		_game.hud.show_notice("Your hero has fallen.")
		_game._finish("Defeat")


func title():
	return {"bastion": "Hold the Line", "helix": "Signal Break", "frontier": "Field Repairs"}[
		_game._get_human_player().faction
	]


func description():
	return {
		"bastion": "Restore nearby allied infantry health. Stronger in later acts.",
		"helix": "Damage visible enemies near Nyx. Stronger in later acts.",
		"frontier": "Repair nearby allied vehicles. Stronger in later acts."
	}[_game._get_human_player().faction]


func activate():
	if not alive() or cooldown > 0 or _game.finished or get_tree().paused or _game.restoring:
		return false
	var faction = unit.player.faction
	var affected = false
	for other in _game.battlefield.nearby_units(unit.global_position_yless, 10 + tier):
		if other.is_queued_for_deletion() or other.hp <= 0:
			continue
		if faction == "helix":
			if other.player != unit.player and _game.battlefield.is_observed(unit.player, other):
				other.receive_damage(unit, 15 + 10 * tier)
				affected = true
		elif other.player == unit.player and other.hp < other.hp_max:
			var eligible = (
				Units.is_infantry(other.type)
				if faction == "bastion"
				else not Units.is_infantry(other.type)
			)
			if eligible and other.movement_speed > 0:
				other.hp = minf(other.hp_max, other.hp + other.hp_max * (.1 + .05 * tier))
				affected = true
	if affected:
		cooldown = COOLDOWN
		_game.hud.show_notice(title())
	return affected


func capture(reference):
	return {"unit": reference.call(unit), "tier": tier, "cooldown": cooldown}


func restore(data, entities):
	unit = entities.get(data.unit)
	tier = data.tier
	cooldown = data.cooldown
