# gdlint: disable=duplicated-load,max-public-methods
# Runtime loading avoids autoload-dependent preload cycles.
extends Node3D

signal changed

const ResearchCatalog = preload("res://source/match/research/TechnologyCatalog.gd")
const COORDINATION_COST = ResearchCatalog.COORDINATION_COST
const COORDINATION_DURATION = ResearchCatalog.COORDINATION_DURATION

const BastionCatalog = preload("res://source/match/BastionCatalog.gd")
const PowerGrid = preload("res://source/match/economy/PowerGrid.gd")

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
@export var team = -1:
	set(value):
		team = value
		if _native_team_store != null:
			_native_team_store.set_team(self, team, _native_alliance_standard)
@export var spawn_index = -1

var technology = null
var signatures = null
var coordination_unlocked = false
var coordination_left = -1.0
var logistics: float = 25.0
var logistics_left: float = 5.0
var harvesting_boosts: Array = []
var production_boosts: Array = []
var market_pressure: float = 0.0

var indexed_rosters: bool = (
	load("res://source/match/rendering/NativePosePacker.gd")
	. runtime_enabled("--indexed-player-rosters")
)
var roster_rebuilds := 0
var roster_queries := 0

var _last_grid_state = ""
var _color_material = null
var _footprint_material = null
var _lab_research = false
var _roster_dirty := true
var _roster_units: Array[Node] = []
var _roster_structures: Array[Node] = []
var _roster_roles := {}
var _roster_generic_structures: Array[Node] = []
var _native_team_store: RefCounted
var _native_alliance_standard := false


func _init():
	child_order_changed.connect(_invalidate_roster)


func _invalidate_roster():
	_roster_dirty = true


func _ensure_roster():
	roster_queries += 1
	if not _roster_dirty:
		return
	_roster_units = []
	_roster_structures = []
	_roster_roles = {}
	_roster_generic_structures = []
	# Unit roles derive from their script and stay fixed. Non-unit extensions
	# retain live role lookup so a mutable generic object's type is never cached.
	var unit_script = load("res://source/match/units/Unit.gd")
	for child in get_children():
		if "type" in child:
			_roster_units.append(child)
		if not child.has_method("is_constructed"):
			continue
		_roster_structures.append(child)
		if is_instance_of(child, unit_script):
			_roster_roles.get_or_add(child.type, []).append(child)
		else:
			_roster_generic_structures.append(child)
	_roster_units.make_read_only()
	_roster_structures.make_read_only()
	_roster_generic_structures.make_read_only()
	for role in _roster_roles:
		_roster_roles[role].make_read_only()
	_roster_dirty = false
	roster_rebuilds += 1


func live_units() -> Array:
	if not indexed_rosters:
		return get_children().filter(
			func(unit): return "type" in unit and not unit.is_queued_for_deletion()
		)
	_ensure_roster()
	return _roster_units.filter(
		func(unit):
			return (
				is_instance_valid(unit)
				and unit.get_parent() == self
				and not unit.is_queued_for_deletion()
			)
	)


func is_allied_with(other):
	return other == self or (other != null and "team" in other and team >= 0 and team == other.team)


func start_index():
	return spawn_index if spawn_index >= 0 else get_index()


func _ready():
	MatchSignals.unit_production_started.connect(_production_power_warning)
	_native_alliance_standard = load("res://source/match/NativeUnitState.gd").uses_base_method(
		self, "res://source/match/players/Player.gd", &"is_allied_with"
	)
	_native_register_team()
	if get_meta("skirmish", false):
		technology = load("res://source/match/research/TechnologyResearch.gd").new()
		technology.name = "TechnologyResearch"
		add_child(technology)
		signatures = load("res://source/match/combat/FactionSignatures.gd").new()
		signatures.name = "FactionSignatures"
		add_child(signatures)


func _production_power_warning(_prototype, producer):
	if producer.player != self:
		return
	warn_if_grid_balanced()


func warn_if_grid_balanced():
	if power_state() != "balanced":
		return
	var game = find_parent("Match")
	if game != null and not game.restoring and game._get_human_player() == self:
		game.hud.show_notice(tr("Power grid balanced · no reserve for new facilities."))


func _native_register_team():
	var game = find_parent("Match")
	if game != null and "unit_state_store" in game and game.unit_state_store != null:
		_native_team_store = game.unit_state_store
		_native_team_store.set_team(self, team, _native_alliance_standard)


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
		_color_material.resource_name = "TeamColor_Player"
		_color_material.vertex_color_use_as_albedo = true
		_color_material.albedo_color = color
		# Low metalness and a self-light keep team trim readable in shadow, combat and fog memory.
		_color_material.metallic = 0.1
		_color_material.roughness = 0.55
		_color_material.emission_enabled = true
		_color_material.emission = color
		_color_material.emission_energy_multiplier = 0.28
	return _color_material


func get_footprint_material():
	if _footprint_material == null:
		_footprint_material = ShaderMaterial.new()
		_footprint_material.shader = preload("res://source/shaders/3d/team_footprint.gdshader")
		_footprint_material.set_shader_parameter("color", color)
	return _footprint_material


func has_completed_structure(unit_type):
	if indexed_rosters:
		_ensure_roster()
		for child in _roster_roles.get(unit_type, []):
			if (
				not child.is_queued_for_deletion()
				and child.get_parent() == self
				and child.is_constructed()
			):
				return true
		for child in _roster_generic_structures:
			if (
				child.type == unit_type
				and not child.is_queued_for_deletion()
				and child.get_parent() == self
				and child.is_constructed()
			):
				return true
		return false
	for child in get_children():
		if child.has_method("is_constructed") and child.type == unit_type:
			if child.is_constructed() and not child.is_queued_for_deletion():
				return true
	return false


func power_totals():
	return PowerGrid.totals(self)


func structure_candidates(role: String = "") -> Array:
	# Cache membership only. Callers still read completion, HP and abilities live,
	# so construction, damage and power toggles take effect within the same tick.
	_ensure_roster()
	if role.is_empty():
		return _roster_structures
	var candidates: Array = _roster_roles.get(role, [])
	if _roster_generic_structures.is_empty():
		return candidates
	return candidates + _roster_generic_structures.filter(func(unit): return unit.type == role)


func power_state() -> String:
	return PowerGrid.state(self)


func is_brownout() -> bool:
	var power = power_totals()
	return power.y > power.x


func production_factor(facility = null):
	var factor = PowerGrid.BROWNOUT_RATE if is_brownout() else 1.0
	if is_instance_valid(facility):
		var game = find_parent("Match")
		if game != null and game.helix_support != null:
			factor *= game.helix_support.production_factor(facility)
		for boost in production_boosts:
			if boost.target.get_ref() == facility and boost.left > 0.0:
				factor *= 1.5
				break
	return factor


func research_factor() -> float:
	# Research is player-wide: use the best completed lab, without stacking labs.
	var factor = 0.0
	for facility in live_units():
		if facility.type == "CommandLab" and facility.hp > 0 and facility.is_constructed():
			factor = maxf(factor, production_factor(facility))
	return factor if factor > 0.0 else production_factor()


func harvesting_factor(deposit) -> float:
	if not is_instance_valid(deposit):
		return 1.0
	for boost in harvesting_boosts:
		if boost.left <= 0.0:
			continue
		if boost.anchored:
			if deposit.harvest_origin.is_equal_approx(boost.field):
				return 1.3
		elif deposit.global_position_yless.distance_squared_to(boost.field) <= 100.0:
			return 1.3
	return 1.0


func add_logistics(amount: float):
	logistics = clampf(logistics + amount, 0.0, 100.0)
	emit_changed()


func spend_logistics(amount: float) -> bool:
	if amount < 0.0 or logistics < amount:
		return false
	add_logistics(-amount)
	return true


func market_quote(direction: String) -> Vector2i:
	if direction == "buy_electronics":
		return Vector2i(50, maxi(10, floori(25.0 * exp(-market_pressure * 0.03))))
	return Vector2i(maxi(20, floori(50.0 * exp(market_pressure * 0.03))), 25)


func market_exchange(direction: String) -> bool:
	if load("res://source/match/network/NetworkGate.gd").intercept(
		self, {"kind": "exchange", "direction": direction}
	):
		return true
	if faction != "frontier" or not has_completed_structure("CommandLab"):
		return false
	if direction not in ["buy_electronics", "buy_materials"] or get_tree().paused:
		return false
	var quote = market_quote(direction)
	if direction == "buy_electronics":
		if resource_a < quote.x:
			return false
		resource_a -= quote.x
		resource_b += quote.y
		market_pressure = minf(20.0, market_pressure + 1.0)
	else:
		if resource_b < quote.y:
			return false
		resource_b -= quote.y
		resource_a += quote.x
		market_pressure = maxf(-20.0, market_pressure - 1.0)
	emit_changed()
	return true


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
				for job in queue._queue:
					count += job.batch_count if "batch_count" in job else 1
	if include_queued:
		count += load("res://source/match/world/PointOfInterestCatalog.gd").reserved(self)
		var game = find_parent("Match")
		if game != null and game.commander_support != null:
			count += game.commander_support.reserved(self)
	return count


func structure_count():
	var count = 0
	if indexed_rosters:
		_ensure_roster()
	var structures: Array = _roster_structures if indexed_rosters else get_children()
	for unit in structures:
		if (
			(indexed_rosters or unit.has_method("is_constructed"))
			and not unit.is_queued_for_deletion()
			and (not indexed_rosters or unit.get_parent() == self)
		):
			count += 1
	return count


func emit_changed():
	changed.emit()


func lab_research_unlocked():
	# Research opens permanently once a vehicle factory and lab have both stood.
	if not _lab_research and get_meta("skirmish", false):
		_lab_research = (
			has_completed_structure("VehicleFactory") and has_completed_structure("CommandLab")
		)
	return _lab_research


func _physics_process(delta):
	_advance_economy(delta)
	if not _lab_research:
		lab_research_unlocked()
	if coordination_left > 0.0 and has_completed_structure("CommandLab"):
		coordination_left = maxf(0.0, coordination_left - delta * research_factor())
		if coordination_left == 0.0:
			coordination_unlocked = true
			if technology != null:
				technology.advance_queue()
			MatchSignals.research_completed.emit(self, "coordination")
			emit_changed()
			var game = find_parent("Match")
			if game != null and game._get_human_player() == self:
				game.hud.show_notice("Research complete · Coordination")


func _advance_economy(delta):
	market_pressure = move_toward(market_pressure, 0.0, delta / 60.0)
	var state = power_state()
	if state != _last_grid_state:
		var game = find_parent("Match")
		if (
			game != null
			and game.is_node_ready()
			and not game.restoring
			and game._get_human_player() == self
		):
			if state == "brownout":
				game.hud.show_notice(tr("Warning: Power Grid Deficit"))
			elif _last_grid_state == "brownout":
				game.hud.show_notice(tr("Power grid restored"))
		_last_grid_state = state
	for boosts in [harvesting_boosts, production_boosts]:
		for boost in boosts.duplicate():
			boost.left = maxf(0.0, boost.left - delta)
			if (
				boost.left == 0.0
				or (not boost.has("field") and not is_instance_valid(boost.target.get_ref()))
			):
				boosts.erase(boost)
	logistics_left -= delta
	while logistics_left <= 0.0:
		logistics_left += 5.0
		var generators = get_children().filter(
			func(unit):
				return (
					"type" in unit
					and unit.type == "PowerPlant"
					and unit.is_constructed()
					and unit.hp > 0
					and not unit.is_queued_for_deletion()
				)
		)
		if not generators.is_empty():
			add_logistics(generators.size())


func start_coordination(lab):
	if technology != null and (technology.active != "" or not technology.queued.is_empty()):
		return false
	if coordination_unlocked or coordination_left >= 0.0 or not lab_research_unlocked():
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
	if load("res://source/match/network/NetworkGate.gd").intercept(
		self, {"kind": "cancel_research", "index": -1}
	):
		return
	if coordination_left <= 0.0 or coordination_unlocked:
		return false
	coordination_left = -1.0
	if technology != null:
		technology.coordination_cancelled()
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
			% [
				coordination_left / research_factor(),
				(
					(tr(" · brownout, %d%% speed") % roundi(research_factor() * 100))
					if is_brownout()
					else ""
				)
			]
		)
	return "Coordination · 20 M / 20 E · 30 s"
