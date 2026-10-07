extends Node

const Structure = preload("res://source/match/units/Structure.gd")
const EVENTS = preload("res://source/match/MatchConstants.gd").VoiceNarrator.Events

@onready var _player = get_parent()
@onready var _voice = get_parent().get_node("BattleVoice")


func _ready():
	MatchSignals.match_started.connect(_handle_event.bind(EVENTS.MATCH_STARTED))
	MatchSignals.match_aborted.connect(_handle_event.bind(EVENTS.MATCH_ABORTED))
	MatchSignals.match_finished_with_victory.connect(
		_handle_event.bind(EVENTS.MATCH_FINISHED_WITH_VICTORY)
	)
	MatchSignals.match_finished_with_defeat.connect(
		_handle_event.bind(EVENTS.MATCH_FINISHED_WITH_DEFEAT)
	)
	MatchSignals.unit_weapon_hit.connect(_on_unit_weapon_hit)
	MatchSignals.unit_died.connect(_on_unit_died)
	MatchSignals.unit_production_started.connect(_on_production_started)
	MatchSignals.unit_production_finished.connect(_on_production_finished)
	MatchSignals.not_enough_resources_for_production.connect(_on_not_enough_resources)
	MatchSignals.not_enough_resources_for_construction.connect(_on_not_enough_resources)
	MatchSignals.unit_construction_finished.connect(_on_construction_finished)


func _handle_event(event):
	_voice.say(event)


func _on_unit_weapon_hit(unit, _source):
	if unit.player == _player:
		_handle_event(EVENTS.BASE_UNDER_ATTACK if unit is Structure else EVENTS.UNIT_UNDER_ATTACK)


func _on_unit_died(unit):
	# Death is emitted on tree exit, after the parent ownership link is gone.
	if unit.is_in_group("controlled_units"):
		_handle_event(EVENTS.UNIT_LOST)


func _on_production_started(_unit_prototype, producer_unit):
	if producer_unit.player == _player:
		_handle_event(EVENTS.UNIT_PRODUCTION_STARTED)


func _on_production_finished(_unit, producer_unit):
	if producer_unit.player == _player:
		_handle_event(EVENTS.UNIT_PRODUCTION_FINISHED)


func _on_construction_finished(unit):
	if unit.player == _player:
		_handle_event(EVENTS.UNIT_CONSTRUCTION_FINISHED)


func _on_not_enough_resources(player):
	if player == _player:
		_handle_event(EVENTS.NOT_ENOUGH_RESOURCES)
