extends Node3D

signal changed

const COORDINATION_COST = {"resource_a": 20, "resource_b": 20}
const COORDINATION_DURATION = 30.0

const BastionCatalog = preload("res://source/match/BastionCatalog.gd")

@export var resource_a = 0:
	set(value):
		resource_a = value
		emit_changed()
@export var resource_b = 0:
	set(value):
		resource_b = value
		emit_changed()
@export var color = Color.WHITE
@export var faction = "bastion"
@export var difficulty = 1

var technology = null
var squad_roster = null
var signatures = null
var coordination_unlocked = false
var coordination_left = -1.0

var _color_material = null
var _footprint_material = null
var _basic_programs = false


func _ready():
	if get_meta("skirmish", false):
		technology = load("res://source/match/research/TechnologyResearch.gd").new()
		technology.name = "TechnologyResearch"
		add_child(technology)
		squad_roster = load("res://source/match/programs/SquadRoster.gd").new()
		squad_roster.name = "SquadRoster"
		add_child(squad_roster)
		signatures = load("res://source/match/combat/FactionSignatures.gd").new()
		signatures.name = "FactionSignatures"
		add_child(signatures)


func add_resources(resources):
	for resource in resources:
		set(resource, get(resource) + resources[resource])


func has_resources(resources):
	if FeatureFlags.allow_resources_deficit_spending:
		return true
	for resource in resources:
		if get(resource) < resources[resource]:
			return false
	return true


func subtract_resources(resources):
	for resource in resources:
		set(resource, get(resource) - resources[resource])


func get_color_material():
	if _color_material == null:
		_color_material = StandardMaterial3D.new()
		_color_material.vertex_color_use_as_albedo = true
		_color_material.albedo_color = color
		# Low metalness and a faint self-light keep team trim readable in shadow and fog memory.
		_color_material.metallic = 0.1
		_color_material.roughness = 0.55
		_color_material.emission_enabled = true
		_color_material.emission = color
		_color_material.emission_energy_multiplier = 0.12
	return _color_material


func get_footprint_material():
	if _footprint_material == null:
		_footprint_material = ShaderMaterial.new()
		_footprint_material.shader = preload("res://source/shaders/3d/team_footprint.gdshader")
		_footprint_material.set_shader_parameter("color", color)
	return _footprint_material


func has_completed_structure(unit_type):
	for child in get_children():
		if child.has_method("is_constructed") and child.type == unit_type:
			if child.is_constructed() and not child.is_queued_for_deletion():
				return true
	return false


func power_totals():
	var supply = 0
	var demand = 0
	for child in get_children():
		if not child.has_method("is_constructed") or child.is_queued_for_deletion():
			continue
		if child.is_constructed():
			supply += BastionCatalog.POWER_SUPPLY.get(child.type, 0)
			demand += BastionCatalog.POWER_USAGE.get(child.type, 0)
	return Vector2i(supply, demand)


func production_factor():
	var power = power_totals()
	return 1.0 if power.x >= power.y else 0.35


func population(include_queued = false):
	var count = 0
	for child in get_children():
		if child.is_queued_for_deletion():
			continue
		if child.find_child("Movement", true, false) != null:
			count += 1
		if include_queued:
			var queue = child.find_child("ProductionQueue", true, false)
			if queue != null:
				count += queue.size()
	if include_queued:
		count += load("res://source/match/world/PointOfInterestCatalog.gd").reserved(self)
	return count


func structure_count():
	var count = 0
	for unit in get_children():
		if unit.has_method("is_constructed") and not unit.is_queued_for_deletion():
			count += 1
	return count


func emit_changed():
	changed.emit()


func basic_programs_unlocked():
	if not _basic_programs and get_meta("skirmish", false):
		_basic_programs = (
			has_completed_structure("VehicleFactory") and has_completed_structure("CommandLab")
		)
	return _basic_programs


func _physics_process(delta):
	if not _basic_programs:
		basic_programs_unlocked()
	if coordination_left > 0.0 and has_completed_structure("CommandLab"):
		coordination_left = maxf(0.0, coordination_left - delta * production_factor())
		if coordination_left == 0.0:
			coordination_unlocked = true
			MatchSignals.research_completed.emit(self, "coordination")
			emit_changed()
			var game = find_parent("Match")
			if game != null and game._get_human_player() == self:
				game.hud.show_notice("Research complete · Coordination")


func start_coordination(lab):
	if technology != null and technology.active != "":
		return false
	if coordination_unlocked or coordination_left >= 0.0 or not basic_programs_unlocked():
		return false
	if not is_instance_valid(lab) or lab.is_queued_for_deletion():
		return false
	if lab.player != self or lab.type != "CommandLab" or not lab.is_constructed():
		return false
	if not has_resources(COORDINATION_COST):
		return false
	subtract_resources(COORDINATION_COST)
	coordination_left = COORDINATION_DURATION
	emit_changed()
	return true


func cancel_coordination():
	if coordination_left <= 0.0 or coordination_unlocked:
		return false
	coordination_left = -1.0
	add_resources(COORDINATION_COST)
	return true


func coordination_status():
	if coordination_unlocked:
		return "Coordination ready · long-range armor unlocked"
	if coordination_left > 0:
		if not has_completed_structure("CommandLab"):
			return "Coordination paused · rebuild a lab (%.1f s remaining)" % coordination_left
		return (
			"Coordination: %.1f s remaining%s"
			% [coordination_left, " · low power, 35% speed" if production_factor() < 1 else ""]
		)
	return "Coordination · 20 M / 20 E · 30 s"
