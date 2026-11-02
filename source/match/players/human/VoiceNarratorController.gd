extends Node

const Structure = preload("res://source/match/units/Structure.gd")
const EVENTS = preload("res://source/match/MatchConstants.gd").VoiceNarrator.Events

var _power_low = false
var _power_initialized = false
var _power_check_left = 5.0
var _low_health = {}

@onready var _player = get_parent()
@onready var _voice = get_parent().get_node("BattleVoice")


func _ready():
	MatchSignals.research_completed.connect(_on_research_completed)
	MatchSignals.match_started.connect(_on_match_started)
	MatchSignals.match_aborted.connect(_on_match_aborted)
	MatchSignals.match_finished_with_victory.connect(_on_match_victory)
	MatchSignals.match_finished_with_defeat.connect(_on_match_defeat)
	MatchSignals.unit_weapon_hit.connect(_on_unit_weapon_hit)
	MatchSignals.unit_damaged.connect(_on_unit_damaged)
	MatchSignals.unit_killed.connect(_on_unit_killed)
	MatchSignals.unit_died.connect(_on_unit_died)
	MatchSignals.unit_production_started.connect(_on_production_started)
	MatchSignals.unit_production_finished.connect(_on_production_finished)
	MatchSignals.not_enough_resources_for_production.connect(_on_not_enough_resources)
	MatchSignals.not_enough_resources_for_construction.connect(_on_not_enough_resources)
	MatchSignals.unit_construction_finished.connect(_on_construction_finished)


func _exit_tree():
	if not is_instance_valid(MatchSignals):
		return
	if MatchSignals.research_completed.is_connected(_on_research_completed):
		MatchSignals.research_completed.disconnect(_on_research_completed)
	if MatchSignals.match_started.is_connected(_on_match_started):
		MatchSignals.match_started.disconnect(_on_match_started)
	if MatchSignals.match_aborted.is_connected(_on_match_aborted):
		MatchSignals.match_aborted.disconnect(_on_match_aborted)
	if MatchSignals.match_finished_with_victory.is_connected(_on_match_victory):
		MatchSignals.match_finished_with_victory.disconnect(_on_match_victory)
	if MatchSignals.match_finished_with_defeat.is_connected(_on_match_defeat):
		MatchSignals.match_finished_with_defeat.disconnect(_on_match_defeat)
	if MatchSignals.unit_weapon_hit.is_connected(_on_unit_weapon_hit):
		MatchSignals.unit_weapon_hit.disconnect(_on_unit_weapon_hit)
	if MatchSignals.unit_damaged.is_connected(_on_unit_damaged):
		MatchSignals.unit_damaged.disconnect(_on_unit_damaged)
	if MatchSignals.unit_killed.is_connected(_on_unit_killed):
		MatchSignals.unit_killed.disconnect(_on_unit_killed)
	if MatchSignals.unit_died.is_connected(_on_unit_died):
		MatchSignals.unit_died.disconnect(_on_unit_died)
	if MatchSignals.unit_production_started.is_connected(_on_production_started):
		MatchSignals.unit_production_started.disconnect(_on_production_started)
	if MatchSignals.unit_production_finished.is_connected(_on_production_finished):
		MatchSignals.unit_production_finished.disconnect(_on_production_finished)
	if MatchSignals.not_enough_resources_for_production.is_connected(_on_not_enough_resources):
		MatchSignals.not_enough_resources_for_production.disconnect(_on_not_enough_resources)
	if MatchSignals.not_enough_resources_for_construction.is_connected(_on_not_enough_resources):
		MatchSignals.not_enough_resources_for_construction.disconnect(_on_not_enough_resources)
	if MatchSignals.unit_construction_finished.is_connected(_on_construction_finished):
		MatchSignals.unit_construction_finished.disconnect(_on_construction_finished)


func _on_match_started():
	_handle_event(EVENTS.MATCH_STARTED)


func _on_match_aborted():
	_handle_event(EVENTS.MATCH_ABORTED)


func _on_match_victory():
	_handle_event(EVENTS.MATCH_FINISHED_WITH_VICTORY)


func _on_match_defeat():
	_handle_event(EVENTS.MATCH_FINISHED_WITH_DEFEAT)


func _handle_event(event):
	_voice.say(event)


func _on_unit_weapon_hit(unit, _source):
	if unit.player == _player:
		_handle_event(EVENTS.BASE_UNDER_ATTACK if unit is Structure else EVENTS.UNIT_UNDER_ATTACK)


func _combat_speaker(unit):
	return (
		is_instance_valid(unit)
		and not unit.is_queued_for_deletion()
		and unit.player == _player
		and unit.hp != null
		and unit.hp > 0
		and unit.hp_max != null
		and unit.hp_max > 0
		and unit.movement_speed > 0
		and unit.attack_damage != null
		and unit.attack_damage > 0
		and not unit.has_meta("garrison_host")
	)


func _on_unit_damaged(unit):
	if not _combat_speaker(unit):
		return
	var id = unit.get_instance_id()
	if unit.hp >= unit.hp_max * .4:
		_low_health.erase(id)
	if (
		unit.hp < unit.hp_max * .25
		and not _low_health.has(id)
		and _voice.say_unit(unit, "low_health")
	):
		_low_health[id] = weakref(unit)


func _on_unit_killed(source, target):
	if (
		_combat_speaker(source)
		and is_instance_valid(target)
		and not load("res://source/match/Players.gd").allied(source.player, target.player)
	):
		_voice.say_unit(source, "kill")


func _on_unit_died(unit):
	# Death is emitted on tree exit, after the parent ownership link is gone.
	if unit.is_in_group("controlled_units"):
		_handle_event(EVENTS.UNIT_LOST)


func _on_production_started(_unit_prototype, producer_unit):
	if producer_unit.player == _player:
		_handle_event(EVENTS.UNIT_PRODUCTION_STARTED)


func _on_production_finished(unit, producer_unit):
	if producer_unit.player == _player:
		_voice.say_unit(unit, "ready")


func _on_construction_finished(unit):
	if unit.player == _player:
		_handle_event(EVENTS.UNIT_CONSTRUCTION_FINISHED)


func _on_not_enough_resources(player):
	if player == _player:
		_handle_event(EVENTS.NOT_ENOUGH_RESOURCES)


func _on_research_completed(player, _technology):
	if player == _player:
		_handle_event(EVENTS.RESEARCH_COMPLETED)


func _process(delta):
	var game = _player.find_parent("Match")
	if game == null or game.restoring or get_tree().paused:
		return
	_power_check_left -= delta
	if _power_check_left > 0:
		return
	_power_check_left = 2.0
	# Healing does not emit damage; rearm only after a real recovery, and retain
	# weak references so casualties do not leave a per-unit history behind.
	for id in _low_health.keys():
		var unit = _low_health[id].get_ref()
		if not is_instance_valid(unit) or unit.hp == null or unit.hp >= unit.hp_max * .4:
			_low_health.erase(id)
	var totals = _player.power_totals()
	var low = totals.y > totals.x
	if low != _power_low or (low and not _power_initialized):
		_handle_event(EVENTS.LOW_POWER if low else EVENTS.POWER_RESTORED)
	_power_low = low
	_power_initialized = true
