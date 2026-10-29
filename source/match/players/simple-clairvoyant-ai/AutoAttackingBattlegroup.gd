# TODO: monitor attached units and fix their actions if necessary
extends Node

enum State { FORMING, ATTACKING }

const PLAYER_TO_ATTACK_SWITCHING_DELAY_S = 0.5


class Actions:
	const MovingToUnit = preload("res://source/match/units/actions/MovingToUnit.gd")
	const AutoAttacking = preload("res://source/match/units/actions/AutoAttacking.gd")


var _expected_number_of_units = null
var _players_to_attack = null
var _player_to_attack = null

var _state = State.FORMING
var _attached_units = []


func _init(expected_number_of_units, players_to_attack):
	_expected_number_of_units = expected_number_of_units
	_players_to_attack = players_to_attack
	_player_to_attack = _players_to_attack.front()


func size():
	return _attached_units.size()


func attach_unit(unit):
	assert(_state == State.FORMING, "unexpected state")
	_attached_units.append(unit)
	unit.tree_exited.connect(_on_unit_died.bind(unit))
	if size() == _expected_number_of_units:
		_start_attacking()


func _start_attacking():
	_state = State.ATTACKING
	_attack_next_adversary_unit()


func _attack_next_adversary_unit():
	if not is_inside_tree() or is_queued_for_deletion():
		return
	_attached_units = _attached_units.filter(
		func(unit): return is_instance_valid(unit) and not unit.is_queued_for_deletion()
	)
	if _attached_units.is_empty():
		if _state == State.ATTACKING:
			queue_free()
		return
	var adversary_units = get_tree().get_nodes_in_group("units").filter(
		func(unit):
			return (
				is_instance_valid(unit)
				and not unit.is_queued_for_deletion()
				and unit.player == _player_to_attack
			)
	)
	if adversary_units.is_empty():
		_attack_next_player()
		return
	var battlegroup_position = _attached_units[0].global_position
	var adversary_units_sorted_by_distance = adversary_units.map(
		func(adversary_unit):
			return {
				"distance":
				(adversary_unit.global_position * Vector3(1, 0, 1)).distance_to(
					battlegroup_position
				),
				"unit": adversary_unit
			}
	)
	adversary_units_sorted_by_distance.sort_custom(
		func(tuple_a, tuple_b): return tuple_a["distance"] < tuple_b["distance"]
	)
	for tuple in adversary_units_sorted_by_distance:
		var target_unit = tuple["unit"]
		if not is_instance_valid(target_unit) or target_unit.is_queued_for_deletion():
			continue
		if _attached_units.any(
			func(attached_unit):
				return (
					is_instance_valid(attached_unit)
					and Actions.AutoAttacking.is_applicable(attached_unit, target_unit)
				)
		):
			if not target_unit.tree_exited.is_connected(_on_target_unit_died):
				target_unit.tree_exited.connect(_on_target_unit_died)
			for attached_unit in _attached_units:
				if not is_instance_valid(attached_unit) or attached_unit.is_queued_for_deletion():
					continue
				if Actions.AutoAttacking.is_applicable(attached_unit, target_unit):
					attached_unit.action = Actions.AutoAttacking.new(target_unit)
				else:
					attached_unit.action = Actions.MovingToUnit.new(target_unit)
			return
	# if not possible to attack remaining units:
	_attack_next_player()


func _attack_next_player():
	if not is_inside_tree() or is_queued_for_deletion() or _players_to_attack.is_empty():
		return
	var player_to_attack_index = _players_to_attack.find(_player_to_attack)
	var next_player_to_attack_index = (player_to_attack_index + 1) % _players_to_attack.size()
	_player_to_attack = _players_to_attack[next_player_to_attack_index]
	var tree = get_tree()
	if tree != null:
		tree.create_timer(PLAYER_TO_ATTACK_SWITCHING_DELAY_S).timeout.connect(
			_attack_next_adversary_unit
		)


func _on_unit_died(unit):
	if not is_inside_tree() or is_queued_for_deletion():
		return
	_attached_units.erase(unit)
	if _state == State.ATTACKING and _attached_units.is_empty():
		queue_free()


func _on_target_unit_died():
	if not is_inside_tree() or is_queued_for_deletion():
		return
	_attack_next_adversary_unit()
