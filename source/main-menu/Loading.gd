extends Control

var match_settings = null
var map_path = null
var presentation_only = false
var _pending_match
var _pause_owned = false

@onready var _label = find_child("Label")
@onready var _progress_bar = find_child("ProgressBar")


func _ready():
	_label.text = tr("Loading battle…")
	_progress_bar.value = .9 if presentation_only else 0.0
	if presentation_only:
		return
	await get_tree().physics_frame
	_preload_scenes()
	_progress_bar.value = 0.2

	await get_tree().physics_frame
	var map = load(map_path).instantiate()
	if not match_settings.scenario.is_empty():
		map.scenario = match_settings.scenario.duplicate(true)
	_progress_bar.value = 0.4

	await get_tree().physics_frame
	var campaigns = load("res://source/match/campaign/CampaignCatalog.gd").operations()
	var scene_path = (
		"res://source/match/Skirmish.tscn"
		if match_settings.skirmish
		else "res://source/match/Match.tscn"
	)
	if match_settings.mission_id in campaigns:
		scene_path = campaigns[match_settings.mission_id].scene
	var match_prototype = load(scene_path)
	_progress_bar.value = 0.7

	await get_tree().physics_frame
	var a_match = match_prototype.instantiate()
	a_match.settings = match_settings
	a_match.map = map
	_progress_bar.value = 0.9

	await get_tree().physics_frame
	var tree = get_tree()
	_pending_match = a_match
	_pause_owned = not tree.paused
	tree.paused = true
	get_parent().add_child(a_match)
	if not await load("res://source/match/effects/CombatPrewarm.gd").prepare(a_match):
		if is_instance_valid(a_match):
			a_match.queue_free()
		_restore_pause()
		return
	_restore_pause()
	_pending_match = null
	tree.current_scene = a_match
	queue_free()


func _restore_pause():
	if _pause_owned and get_tree().current_scene == self and not Globals._quitting:
		get_tree().paused = false
	_pause_owned = false


func _exit_tree():
	if is_instance_valid(_pending_match):
		_pending_match.queue_free()
	_restore_pause()


func _preload_scenes():
	var scene_paths = []
	scene_paths += Constants.Match.Units.CONSTRUCTION_COSTS.keys()
	for scene_path in scene_paths:
		Globals.cache[scene_path] = load(scene_path)
