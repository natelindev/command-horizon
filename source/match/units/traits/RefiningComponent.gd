# gdlint: disable=duplicated-load,max-returns,max-public-methods
extends Node

## Per-unit Risk-the-Batch Refining trait.
## Supports three distinct faction refining engines:
## - "bastion": Upfront batch smelting (ForwardRefinery / Industrial Smelter)
## - "helix": Continuous Raw siphon into escalating resonance tiers (PhaseCondenser)
## - "frontier": Deployable mobile distillation (CrackRig)

signal state_changed

const Profile = preload("res://source/match/economy/RefiningProfile.gd")
const Players = preload("res://source/match/Players.gd")

var mode: String = "bastion"
var auto_cycle: bool = true

# Bastion & Frontier batch state
var batch_tier: String = "standard"
var active: bool = false
var locked_raw: int = 0
var target_refined: int = 0
var elapsed: float = 0.0
var duration: float = 15.0
var overpressure_enabled: bool = false
var overpressure_cooldown: float = 0.0
var last_delivery_time: float = -INF

# Helix condenser state
var target_tier: int = 2
var charge_seconds: float = 0.0
var raw_siphoned: float = 0.0
var raw_accumulator: float = 0.0
var brownout_elapsed: float = 0.0
var grace_active: bool = false

# Frontier Crack-Rig deploy state
var deploy_state: String = "mobile"  # mobile | deploying | deployed | packing
var transition_left: float = 0.0
var ready_batch: int = 0

var _visual_root: Node3D = null
var _visual_mesh: MeshInstance3D = null
var _visual_beam: MeshInstance3D = null
var _visual_mat: StandardMaterial3D = null
var _visual_beam_mat: StandardMaterial3D = null
var _smoke_left: float = 0.0
var _destroyed_handled: bool = false
@onready var unit = get_parent()


func _init(engine_mode: String = "bastion"):
	mode = engine_mode
	name = "Refining"


func _ready():
	_build_visuals()


func _match():
	return unit._match if is_instance_valid(unit) and "_match" in unit else null


func _manager():
	var game = _match()
	return game.refining_manager if game != null and "refining_manager" in game else null


func _is_operational() -> bool:
	return (
		is_instance_valid(unit)
		and not unit.is_queued_for_deletion()
		and unit.hp != null
		and unit.hp > 0.0
		and unit.player != null
		and (not unit.has_method("is_constructed") or unit.is_constructed())
	)


func _physics_process(delta: float):
	if not _is_operational() or get_tree().paused:
		return
	match mode:
		"bastion":
			_tick_bastion(delta)
		"helix":
			_tick_helix(delta)
		"frontier":
			_tick_frontier(delta)
	_update_visuals(delta)


# --- BASTION: Industrial Batch Smelting ---


func set_batch_tier(tier_id: String) -> bool:
	if mode != "bastion" or not _is_operational():
		return false
	if not Profile.bastion_batch_unlocked(unit.player, tier_id):
		return false
	batch_tier = tier_id
	if not active:
		_start_bastion_batch()
	state_changed.emit()
	return true


func toggle_auto_cycle() -> bool:
	auto_cycle = not auto_cycle
	if auto_cycle and mode == "bastion" and not active and _is_operational():
		_start_bastion_batch()
	state_changed.emit()
	return auto_cycle


func toggle_overpressure() -> bool:
	if mode != "bastion" or not _is_operational():
		return false
	if overpressure_enabled:
		overpressure_enabled = false
		unit.player.emit_changed()
		state_changed.emit()
		return true
	if overpressure_cooldown > 0.0 and not Profile.has_tech(unit.player, "iron_blitz"):
		return false
	overpressure_enabled = true
	unit.player.emit_changed()
	state_changed.emit()
	return true


func extra_power_draw() -> int:
	if (
		mode == "bastion"
		and _is_operational()
		and overpressure_enabled
		and not Profile.has_tech(unit.player, "iron_blitz")
	):
		return Profile.BASTION_OVERPRESSURE_POWER
	return 0


func record_delivery():
	var game = _match()
	if game != null:
		last_delivery_time = game.simulation_time


func is_field_fed() -> bool:
	var game = _match()
	return (
		mode == "bastion"
		and game != null
		and (game.simulation_time - last_delivery_time) <= Profile.BASTION_FIELD_FED_WINDOW
	)


func abort_batch() -> bool:
	if mode != "bastion" or not active or not _is_operational():
		return false
	var refund_ratio = (
		Profile.BASTION_PRESSURIZED_ABORT_REFUND
		if Profile.has_tech(unit.player, "pressurized_furnaces")
		else Profile.BASTION_ABORT_REFUND
	)
	var refund = floori(locked_raw * refund_ratio)
	active = false
	locked_raw = 0
	target_refined = 0
	elapsed = 0.0
	auto_cycle = false
	if refund > 0:
		unit.player.add_resources({"resource_a": refund})
	state_changed.emit()
	return true


func _start_bastion_batch() -> bool:
	if active or not _is_operational():
		return false
	if not Profile.bastion_batch_unlocked(unit.player, batch_tier):
		batch_tier = "standard"
	var spec = Profile.bastion_batch(batch_tier)
	if unit.player.resource_a < spec.raw:
		return false
	unit.player.subtract_resources({"resource_a": spec.raw})
	active = true
	locked_raw = spec.raw
	target_refined = spec.refined
	elapsed = 0.0
	duration = spec.duration
	state_changed.emit()
	return true


func _tick_bastion(delta: float):
	if overpressure_cooldown > 0.0:
		overpressure_cooldown = maxf(0.0, overpressure_cooldown - delta)
	if not active:
		if Profile.has_tech(unit.player, "fortress_doctrine") and unit.hp < unit.hp_max:
			unit.hp = minf(unit.hp_max, unit.hp + Profile.BASTION_FORTRESS_IDLE_REPAIR * delta)
		if auto_cycle:
			_start_bastion_batch()
		return
	var speed = _bastion_speed_factor()
	elapsed = minf(duration, elapsed + delta * speed)
	if elapsed >= duration:
		var payout = target_refined
		active = false
		locked_raw = 0
		target_refined = 0
		elapsed = 0.0
		unit.player.add_resources({"resource_b": payout})
		if overpressure_enabled and not Profile.has_tech(unit.player, "iron_blitz"):
			overpressure_enabled = false
			overpressure_cooldown = Profile.BASTION_OVERPRESSURE_COOLDOWN
			unit.player.emit_changed()
		var mgr = _manager()
		if mgr != null:
			mgr.trigger_slag_surge(unit.player, unit.global_position)
		if auto_cycle:
			_start_bastion_batch()
		state_changed.emit()


func _bastion_speed_factor() -> float:
	var factor = 0.25 if unit.player.is_brownout() else 1.0
	if is_field_fed():
		factor *= 1.0 + Profile.BASTION_FIELD_FED_BONUS
	if overpressure_enabled and not unit.player.is_brownout():
		factor *= 1.0 + Profile.BASTION_OVERPRESSURE_BONUS
	var mgr = _manager()
	if mgr != null:
		factor *= 1.0 + mgr.catalyst_bonus(unit.player, unit.global_position)
	return factor


# --- HELIX: Harmonic Capacitor Condensing ---


func helix_max_tier() -> int:
	if not _is_operational():
		return 3
	var mgr = _manager()
	if (
		Profile.has_tech(unit.player, "harmonic_lattice")
		and mgr != null
		and mgr.lattice_partner(unit) != null
	):
		return 4
	return 3


func set_target_tier(tier: int) -> bool:
	if mode != "helix" or not _is_operational():
		return false
	var capped = clampi(tier, 1, 4)
	if capped == 4 and not Profile.has_tech(unit.player, "harmonic_lattice"):
		return false
	target_tier = capped
	if charge_seconds >= Profile.helix_tier(mini(target_tier, helix_max_tier())).time:
		discharge_now()
	state_changed.emit()
	return true


func discharge_now() -> int:
	if mode != "helix" or not _is_operational() or charge_seconds <= 0.0:
		return 0
	var max_t = helix_max_tier()
	var reached = Profile.helix_tier_for_charge(charge_seconds, max_t)
	var payout = Profile.helix_yield_for_charge(charge_seconds, max_t)
	charge_seconds = 0.0
	raw_siphoned = 0.0
	raw_accumulator = 0.0
	brownout_elapsed = 0.0
	grace_active = false
	if payout > 0:
		unit.player.add_resources({"resource_b": payout})
		if reached >= 2 and Profile.has_tech(unit.player, "phase_overload"):
			_emit_phase_overload_pulse()
	state_changed.emit()
	return payout


func shock_from_partner():
	if mode != "helix" or not _is_operational() or charge_seconds <= 0.0:
		return
	var max_t = helix_max_tier()
	var current_tier = Profile.helix_tier_for_charge(charge_seconds, max_t)
	var before_yield = Profile.helix_yield_for_charge(charge_seconds, max_t)
	if current_tier <= 1:
		charge_seconds = maxf(0.0, charge_seconds * 0.4)
	else:
		charge_seconds = Profile.helix_tier(current_tier - 1).time
	var after_yield = Profile.helix_yield_for_charge(charge_seconds, max_t)
	var lost = maxi(0, before_yield - after_yield)
	var mgr = _manager()
	if mgr != null and lost > 0:
		mgr.spawn_canisters(
			unit.global_position, maxi(Profile.SPILL_MIN_REFINED, floori(lost * 0.45)), unit.player
		)
	state_changed.emit()


func is_lattice_aura_active() -> bool:
	if mode != "helix" or not _is_operational():
		return false
	return helix_max_tier() >= 4 and charge_seconds >= Profile.HELIX_TIERS[3].time


func _tick_helix(delta: float):
	var brownout = unit.player.is_brownout()
	if brownout:
		if charge_seconds <= 0.0:
			brownout_elapsed = 0.0
			grace_active = false
			return
		brownout_elapsed += delta
		var failsafe = Profile.has_tech(unit.player, "failsafe_capacitors")
		if failsafe and brownout_elapsed <= Profile.HELIX_FAILSAFE_GRACE:
			grace_active = true
			return
		grace_active = false
		var bleed_time = brownout_elapsed - (Profile.HELIX_FAILSAFE_GRACE if failsafe else 0.0)
		charge_seconds = maxf(
			0.0, charge_seconds - charge_seconds * Profile.HELIX_BROWNOUT_BLEED * delta
		)
		if bleed_time >= Profile.HELIX_BROWNOUT_CANCEL:
			charge_seconds = 0.0
			raw_siphoned = 0.0
			raw_accumulator = 0.0
			brownout_elapsed = 0.0
			state_changed.emit()
		return
	brownout_elapsed = 0.0
	grace_active = false
	var max_t = helix_max_tier()
	var effective_target = mini(target_tier, max_t)
	var limit_time = Profile.helix_tier(effective_target).time
	if charge_seconds >= limit_time:
		if auto_cycle:
			discharge_now()
		return
	var mgr = _manager()
	var speed = (
		1.0 + (mgr.catalyst_bonus(unit.player, unit.global_position) if mgr != null else 0.0)
	)
	var needed_raw = Profile.HELIX_SIPHON_RATE * delta * speed
	raw_accumulator += needed_raw
	var whole_raw = floori(raw_accumulator)
	if whole_raw > 0:
		if unit.player.resource_a >= whole_raw:
			unit.player.subtract_resources({"resource_a": whole_raw})
			raw_accumulator -= whole_raw
			raw_siphoned += whole_raw
			charge_seconds = minf(limit_time, charge_seconds + delta * speed)
		else:
			raw_accumulator -= needed_raw
			return
	else:
		if unit.player.resource_a > 0:
			charge_seconds = minf(limit_time, charge_seconds + delta * speed)
	if charge_seconds >= limit_time and auto_cycle:
		discharge_now()


func _emit_phase_overload_pulse():
	var game = _match()
	if game == null:
		return
	var limit_sq = Profile.HELIX_OVERLOAD_PULSE_RADIUS * Profile.HELIX_OVERLOAD_PULSE_RADIUS
	for ally in unit.player.live_units():
		if not is_instance_valid(ally) or ally.hp <= 0.0:
			continue
		if ally.global_position_yless.distance_squared_to(unit.global_position_yless) > limit_sq:
			continue
		if ally.shields_max > 0.0:
			ally.shield_component.charge = ally.shields_max
		if ally.abilities != null:
			var shift = ally.abilities.get_ability("phase_shift")
			if shift != null:
				shift.cooldown_left = 0.0
	if game.combat_effects != null:
		game.combat_effects.airburst(unit.global_position + Vector3.UP * 1.4, 4.0, Color("5cddff"))


# --- FRONTIER: Mobile Crack-Rig Distillation ---


func deploy() -> bool:
	if mode != "frontier" or not _is_operational():
		return false
	if deploy_state in ["deploying", "deployed"]:
		return false
	deploy_state = "deploying"
	transition_left = Profile.FRONTIER_DEPLOY_SECONDS
	var movement = unit.get_node_or_null("Movement")
	if movement != null:
		movement.stop()
	unit.action = null
	state_changed.emit()
	return true


func pack_up() -> bool:
	if mode != "frontier" or not _is_operational():
		return false
	if deploy_state in ["mobile", "packing"]:
		return false
	if active:
		var refund = floori(locked_raw * 0.5)
		active = false
		locked_raw = 0
		target_refined = 0
		elapsed = 0.0
		if refund > 0:
			unit.player.add_resources({"resource_a": refund})
	deploy_state = "packing"
	transition_left = (
		Profile.FRONTIER_QUICK_PACK_SECONDS
		if Profile.has_tech(unit.player, "exhaust_scrubbers")
		else Profile.FRONTIER_PACK_SECONDS
	)
	if Profile.has_tech(unit.player, "exhaust_scrubbers"):
		var game = _match()
		if game != null and game.combat_effects != null:
			game.combat_effects.airburst(unit.global_position + Vector3.UP, 3.0, Color("8b897a"))
	state_changed.emit()
	return true


func is_immobilized() -> bool:
	return mode == "frontier" and deploy_state != "mobile"


func is_hot_zone() -> bool:
	if mode != "frontier" or not _is_operational():
		return false
	var game = _match()
	if game == null:
		return false
	var pos = unit.global_position_yless
	var limit_sq = Profile.FRONTIER_HOT_ZONE_RADIUS * Profile.FRONTIER_HOT_ZONE_RADIUS
	for deposit in game.get_cached_group("resource_units"):
		if is_instance_valid(deposit) and not deposit.is_queued_for_deletion():
			if deposit.global_position_yless.distance_squared_to(pos) <= limit_sq:
				return true
	var mgr = _manager()
	return mgr != null and mgr.catalyst_bonus(unit.player, unit.global_position) > 0.0


func inject_fuel() -> bool:
	if (
		mode != "frontier"
		or not _is_operational()
		or not Profile.has_tech(unit.player, "battlefield_alchemy")
		or deploy_state != "deployed"
	):
		return false
	if unit.player.resource_b < Profile.FRONTIER_BATCH_REFINED and ready_batch <= 0:
		return false
	if ready_batch > 0:
		ready_batch = 0
	else:
		unit.player.subtract_resources({"resource_b": Profile.FRONTIER_BATCH_REFINED})
	var mgr = _manager()
	if mgr != null:
		mgr.trigger_fuel_injection(unit.player, unit.global_position)
	state_changed.emit()
	return true


func assemble_raider() -> bool:
	if (
		mode != "frontier"
		or not _is_operational()
		or not Profile.has_tech(unit.player, "salvage_war_machine")
		or deploy_state != "deployed"
	):
		return false
	var cost = {"resource_a": 16, "resource_b": Profile.FRONTIER_BATCH_REFINED}
	if not unit.player.has_resources(cost):
		return false
	var catalog = load("res://source/match/FactionCatalog.gd")
	if unit.player.population(true) >= catalog.Bastion.POPULATION_LIMIT:
		return false
	var raider = load(catalog.scene_path("frontier", "Tank")).instantiate()
	var game = _match()
	var point = _find_spawn_point(unit.global_position, raider.radius)
	if not point.is_finite():
		raider.free()
		return false
	unit.player.subtract_resources(cost)
	game._setup_and_spawn_unit(raider, Transform3D(Basis(), point), unit.player, false)
	state_changed.emit()
	return true


func _start_frontier_batch() -> bool:
	if active or deploy_state != "deployed" or not _is_operational():
		return false
	if unit.player.resource_a < Profile.FRONTIER_BATCH_RAW:
		return false
	unit.player.subtract_resources({"resource_a": Profile.FRONTIER_BATCH_RAW})
	active = true
	locked_raw = Profile.FRONTIER_BATCH_RAW
	target_refined = Profile.FRONTIER_BATCH_REFINED
	elapsed = 0.0
	duration = Profile.FRONTIER_BATCH_DURATION
	state_changed.emit()
	return true


func _tick_frontier(delta: float):
	if deploy_state == "deploying":
		transition_left = maxf(0.0, transition_left - delta)
		if transition_left == 0.0:
			deploy_state = "deployed"
			if auto_cycle:
				_start_frontier_batch()
			state_changed.emit()
		return
	if deploy_state == "packing":
		transition_left = maxf(0.0, transition_left - delta)
		if transition_left == 0.0:
			deploy_state = "mobile"
			state_changed.emit()
		return
	if deploy_state != "deployed":
		return
	if not active:
		if auto_cycle:
			_start_frontier_batch()
		return
	var speed = 1.0 + (Profile.FRONTIER_HOT_ZONE_BONUS if is_hot_zone() else 0.0)
	var mgr = _manager()
	if mgr != null:
		speed *= 1.0 + mgr.catalyst_bonus(unit.player, unit.global_position)
	elapsed = minf(duration, elapsed + delta * speed)
	if elapsed >= duration:
		var payout = target_refined
		active = false
		locked_raw = 0
		target_refined = 0
		elapsed = 0.0
		unit.player.add_resources({"resource_b": payout})
		if auto_cycle:
			_start_frontier_batch()
		state_changed.emit()


# --- SHARED: Death Rupture, Spill & Status ---


func progress_ratio() -> float:
	if mode == "helix":
		var cap = Profile.helix_tier(mini(target_tier, helix_max_tier())).time
		return clampf(charge_seconds / maxf(0.1, cap), 0.0, 1.0)
	return clampf(elapsed / maxf(0.1, duration), 0.0, 1.0) if active else 0.0


func accrued_refined() -> float:
	if mode == "helix":
		return float(Profile.helix_yield_for_charge(charge_seconds, helix_max_tier()))
	if not active:
		return 0.0
	return float(target_refined) * progress_ratio()


func splash_damage_factor() -> float:
	if (
		mode == "bastion"
		and active
		and _is_operational()
		and Profile.has_tech(unit.player, "pressurized_furnaces")
	):
		return Profile.BASTION_PRESSURIZED_SPLASH_FACTOR
	return 1.0


func status_summary() -> String:
	match mode:
		"bastion":
			var label = batch_tier.capitalize().replace("_", " ")
			if active:
				var tags = []
				if is_field_fed():
					tags.append("Field-Fed")
				if overpressure_enabled:
					tags.append("Overpressure")
				var suffix = (" · " + ", ".join(tags)) if not tags.is_empty() else ""
				return (
					"Smelting %s · %d%% (+%d R)%s"
					% [label, roundi(progress_ratio() * 100.0), target_refined, suffix]
				)
			return "Smelter idle · %s batch (%s)" % [label, "Auto" if auto_cycle else "Manual"]
		"helix":
			var max_t = helix_max_tier()
			var current = Profile.helix_tier_for_charge(charge_seconds, max_t)
			var yield_now = Profile.helix_yield_for_charge(charge_seconds, max_t)
			var status = "T%d/%d · +%d R ready" % [current, mini(target_tier, max_t), yield_now]
			if grace_active:
				status += " · BROWNOUT GRACE"
			elif brownout_elapsed > 0.0:
				status += " · UNSTABLE"
			elif max_t >= 4:
				status += " · Lattice"
			return status
		"frontier":
			if deploy_state == "mobile":
				return "Crack-Rig mobile · Deploy to distill"
			if deploy_state == "deploying":
				return "Deploying rig · %.1fs" % transition_left
			if deploy_state == "packing":
				return "Packing rig · %.1fs" % transition_left
			if active:
				return (
					"Distilling · %d%% (+%d R)%s"
					% [
						roundi(progress_ratio() * 100.0),
						target_refined,
						" · Hot Zone" if is_hot_zone() else "",
					]
				)
			return "Deployed · waiting for %d Raw" % Profile.FRONTIER_BATCH_RAW
	return ""


func on_owner_destroyed():
	if _destroyed_handled or not is_instance_valid(unit):
		return
	var game = _match()
	if game == null or game.restoring:
		return
	_destroyed_handled = true
	var ratio = progress_ratio()
	var accrued = accrued_refined()
	var spill = Profile.spill_amount(accrued, ratio)
	var mgr = _manager()
	if mgr != null and spill > 0:
		mgr.spawn_canisters(unit.global_position, spill, unit.player, true)
	match mode:
		"bastion":
			if active and ratio >= Profile.SPILL_MIN_PROGRESS:
				_apply_area_blast(
					unit.global_position,
					Profile.BASTION_RUPTURE_RADIUS,
					Profile.BASTION_RUPTURE_DAMAGE,
					Color("ff8c3a")
				)
		"helix":
			if charge_seconds > 0.0:
				_apply_emp_burst(unit.global_position)
				var partner = mgr.lattice_partner(unit) if mgr != null else null
				if partner != null:
					var partner_refining = partner.get_node_or_null("Refining")
					if partner_refining != null:
						partner_refining.shock_from_partner()
		"frontier":
			if deploy_state == "deployed" and active and ratio >= Profile.SPILL_MIN_PROGRESS:
				var guerrilla = Profile.has_tech(unit.player, "guerrilla_insurgency")
				_apply_area_blast(
					unit.global_position,
					(
						Profile.FRONTIER_GUERRILLA_BLAST_RADIUS
						if guerrilla
						else Profile.FRONTIER_BLAST_RADIUS
					),
					(
						Profile.FRONTIER_GUERRILLA_BLAST_DAMAGE
						if guerrilla
						else Profile.FRONTIER_BLAST_DAMAGE
					),
					Color("ff6a2b")
				)
				if guerrilla:
					_spawn_ambush_militia(unit.global_position, 2)


func _apply_area_blast(origin: Vector3, blast_radius: float, damage: float, tint: Color):
	var game = _match()
	if game == null or game.battlefield == null:
		return
	for target in game.battlefield.nearby_units(origin, blast_radius):
		if target == unit or not is_instance_valid(target) or target.hp <= 0.0:
			continue
		var dist = target.global_position_yless.distance_to(origin * Vector3(1, 0, 1))
		var falloff = clampf(1.0 - dist / maxf(0.1, blast_radius) * 0.5, 0.35, 1.0)
		target.receive_damage(unit, damage * falloff, target.global_position)
	if game.combat_effects != null:
		game.combat_effects.airburst(origin + Vector3.UP * 1.1, blast_radius, tint)


func _apply_emp_burst(origin: Vector3):
	var game = _match()
	if game == null or game.battlefield == null:
		return
	for target in game.battlefield.nearby_units(origin, Profile.HELIX_EMP_RADIUS):
		if target == unit or not is_instance_valid(target) or target.hp <= 0.0:
			continue
		if target.shields_max > 0.0:
			target.shield_component.drain(Profile.HELIX_EMP_SHIELD_DRAIN, game.simulation_time)
		var movement = target.get_node_or_null("Movement")
		if movement != null and movement.has_method("apply_ion_stall"):
			movement.apply_ion_stall(Profile.HELIX_EMP_STALL)
	if game.combat_effects != null:
		game.combat_effects.airburst(
			origin + Vector3.UP * 1.5, Profile.HELIX_EMP_RADIUS, Color("5cddff")
		)


func _spawn_ambush_militia(origin: Vector3, count: int):
	var game = _match()
	if game == null or unit.player == null:
		return
	var catalog = load("res://source/match/FactionCatalog.gd")
	var remaining = mini(count, catalog.Bastion.POPULATION_LIMIT - unit.player.population(true))
	for index in remaining:
		var militia = load(catalog.scene_path("frontier", "Infantry")).instantiate()
		var point = _find_spawn_point(origin, militia.radius)
		if not point.is_finite():
			militia.free()
			continue
		MatchSignals.setup_and_spawn_unit.emit(militia, Transform3D(Basis(), point), unit.player)


func _find_spawn_point(origin: Vector3, agent_radius: float) -> Vector3:
	var game = _match()
	if game == null:
		return Vector3.INF
	var placement = load("res://source/match/utils/UnitPlacementUtils.gd")
	var nav = game.navigation.get_navigation_map_rid_by_domain(1)
	var blockers = (
		get_tree().get_nodes_in_group("units") + get_tree().get_nodes_in_group("resource_units")
	)
	for ring in [1.8, 3.0, 4.5]:
		for index in 12:
			var angle = index * TAU / 12.0
			var desired = origin + Vector3(cos(angle), 0.0, sin(angle)) * ring
			desired.y = game.map.height_at(Vector2(desired.x, desired.z))
			var surface = NavigationServer3D.map_get_closest_point(nav, desired + Vector3.UP * 0.6)
			var point = Vector3(surface.x, desired.y, surface.z)
			if Vector2(point.x - desired.x, point.z - desired.z).length() > 0.35:
				continue
			if (
				placement.validate_agent_placement_position(
					point, agent_radius + 0.05, blockers, nav, game.map
				)
				== placement.VALID
			):
				return point
	return Vector3.INF


# --- DIEGETIC 3D VISUALS ---


func _build_visuals():
	if DisplayServer.get_name() == "headless":
		return
	_visual_root = Node3D.new()
	_visual_root.name = "RefiningVisuals"
	add_child(_visual_root)
	_visual_mat = StandardMaterial3D.new()
	_visual_mat.emission_enabled = true
	_visual_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_visual_mesh = MeshInstance3D.new()
	if mode == "helix":
		var torus = TorusMesh.new()
		torus.inner_radius = 0.85
		torus.outer_radius = 1.05
		_visual_mesh.mesh = torus
		_visual_mesh.position = Vector3(0.0, 1.8, 0.0)
		_visual_beam_mat = StandardMaterial3D.new()
		_visual_beam_mat.emission_enabled = true
		_visual_beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_visual_beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_visual_beam = MeshInstance3D.new()
		var cyl = CylinderMesh.new()
		cyl.top_radius = 0.14
		cyl.bottom_radius = 0.28
		cyl.height = 9.0
		_visual_beam.mesh = cyl
		_visual_beam.position = Vector3(0.0, 5.2, 0.0)
		_visual_beam.material_override = _visual_beam_mat
		_visual_beam.visible = false
		_visual_root.add_child(_visual_beam)
	else:
		var box = BoxMesh.new()
		box.size = Vector3(0.9, 0.32, 0.9) if mode == "bastion" else Vector3(0.65, 0.28, 0.85)
		_visual_mesh.mesh = box
		_visual_mesh.position = (
			Vector3(0.55, 1.98, -0.3) if mode == "bastion" else Vector3(0.0, 1.05, 0.0)
		)
	_visual_mesh.material_override = _visual_mat
	_visual_mesh.visible = false
	_visual_root.add_child(_visual_mesh)


func _update_visuals(delta: float):
	if _visual_mesh == null:
		return
	var ratio = progress_ratio()
	if mode == "bastion":
		_visual_mesh.visible = active
		if active:
			var hot = Color("ff7a22") if batch_tier != "super_heavy" else Color("fff2b2")
			_visual_mat.albedo_color = hot
			_visual_mat.emission = hot
			_visual_mat.emission_energy_multiplier = 0.8 + ratio * 2.4
	elif mode == "helix":
		var has_charge = charge_seconds > 0.0
		_visual_mesh.visible = has_charge
		if has_charge:
			_visual_mesh.position.y = 1.6 + ratio * 1.4
			_visual_mesh.rotation.y += delta * (1.2 + ratio * 4.0)
			var tier = Profile.helix_tier_for_charge(charge_seconds, helix_max_tier())
			var col = (
				Color("ff4444")
				if grace_active
				else (Color("b57cff") if tier >= 3 else Color("5ce1ff"))
			)
			_visual_mat.albedo_color = col
			_visual_mat.emission = col
			_visual_mat.emission_energy_multiplier = 1.0 + float(tier) * 0.9
			if _visual_beam != null:
				_visual_beam.visible = tier >= 3
				if _visual_beam.visible:
					_visual_beam_mat.albedo_color = Color(col.r, col.g, col.b, 0.35)
					_visual_beam_mat.emission = col
					_visual_beam_mat.emission_energy_multiplier = 2.0
		elif _visual_beam != null:
			_visual_beam.visible = false
	elif mode == "frontier":
		var distilling = deploy_state == "deployed" and active
		var scrubbed = Profile.has_tech(unit.player, "exhaust_scrubbers") and ratio < 0.75
		_visual_mesh.visible = distilling
		if distilling:
			var col = Color("ff8c3a") if not scrubbed else Color("665e4e")
			_visual_mat.albedo_color = col
			_visual_mat.emission = col
			_visual_mat.emission_energy_multiplier = 0.5 + ratio * 1.6
			if not scrubbed:
				_smoke_left -= delta
				if _smoke_left <= 0.0:
					_smoke_left = 0.65
					var game = _match()
					if game != null and game.combat_effects != null:
						game.combat_effects.ruin_smoke(unit)


# --- DETERMINISTIC SNAPSHOT STATE ---


func capture_state() -> Dictionary:
	return {
		"mode": mode,
		"auto_cycle": auto_cycle,
		"batch_tier": batch_tier,
		"active": active,
		"locked_raw": locked_raw,
		"target_refined": target_refined,
		"elapsed": elapsed,
		"duration": duration,
		"overpressure_enabled": overpressure_enabled,
		"overpressure_cooldown": overpressure_cooldown,
		"last_delivery_time": last_delivery_time if is_finite(last_delivery_time) else -9999.0,
		"target_tier": target_tier,
		"charge_seconds": charge_seconds,
		"raw_siphoned": raw_siphoned,
		"raw_accumulator": raw_accumulator,
		"brownout_elapsed": brownout_elapsed,
		"grace_active": grace_active,
		"deploy_state": deploy_state,
		"transition_left": transition_left,
		"ready_batch": ready_batch,
	}


func restore_state(saved: Dictionary):
	mode = str(saved.get("mode", mode))
	auto_cycle = bool(saved.get("auto_cycle", true))
	batch_tier = str(saved.get("batch_tier", "standard"))
	active = bool(saved.get("active", false))
	locked_raw = int(saved.get("locked_raw", 0))
	target_refined = int(saved.get("target_refined", 0))
	elapsed = float(saved.get("elapsed", 0.0))
	duration = float(saved.get("duration", 15.0))
	overpressure_enabled = bool(saved.get("overpressure_enabled", false))
	overpressure_cooldown = float(saved.get("overpressure_cooldown", 0.0))
	var saved_delivery = float(saved.get("last_delivery_time", -9999.0))
	last_delivery_time = -INF if saved_delivery <= -9000.0 else saved_delivery
	target_tier = clampi(int(saved.get("target_tier", 2)), 1, 4)
	charge_seconds = float(saved.get("charge_seconds", 0.0))
	raw_siphoned = float(saved.get("raw_siphoned", 0.0))
	raw_accumulator = float(saved.get("raw_accumulator", 0.0))
	brownout_elapsed = float(saved.get("brownout_elapsed", 0.0))
	grace_active = bool(saved.get("grace_active", false))
	deploy_state = str(saved.get("deploy_state", "mobile"))
	transition_left = float(saved.get("transition_left", 0.0))
	ready_batch = int(saved.get("ready_batch", 0))
	state_changed.emit()
