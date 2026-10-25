extends "res://source/match/units/Tank.gd"

const SWITCH_SECONDS = 2.0
const PRECISION_RANGE = 12.0
const INTERCEPTION_RANGE = 8.0
const MODES = ["precision", "interception"]
var weapon_mode = "precision"
var pending_weapon_mode = ""
var weapon_switch_left = 0.0
var _mode_badge
var _badge_elapsed = 0.0


func _ready():
	await super()
	if not can_switch_weapon():
		set_physics_process(false)
		return
	_mode_badge = load("res://source/match/debug/UnitInfoLabel.gd").new()
	_mode_badge.position = Vector3(0, 1.85, 0)
	_mode_badge.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_mode_badge.font = load("res://assets/fonts/NotoSansSC.ttf")
	_mode_badge.font_size = 32
	_mode_badge.pixel_size = 0.012
	_mode_badge.no_depth_test = false
	_mode_badge.refresh_requested.connect(_update_badge)
	add_child(_mode_badge)
	_update_badge()


func can_switch_weapon():
	return player.faction == "helix"


func request_weapon_mode(mode):
	if not can_switch_weapon() or hp <= 0 or is_queued_for_deletion():
		return false
	if mode not in MODES or mode == weapon_mode or weapon_switch_left > 0:
		return false
	pending_weapon_mode = mode
	weapon_switch_left = SWITCH_SECONDS
	if is_instance_valid(weapon_charge_owner):
		weapon_charge_owner.restart_preparation()
	_update_badge()
	return true


func _physics_process(delta):
	super(delta)
	if weapon_switch_left > 0:
		weapon_switch_left = maxf(0, weapon_switch_left - delta)
		if weapon_switch_left == 0:
			weapon_mode = pending_weapon_mode
			pending_weapon_mode = ""
			configure_weapon()
	if not is_instance_valid(_mode_badge) or not _mode_badge.diagnostics_enabled():
		_badge_elapsed = 0.0
		return
	_badge_elapsed += delta
	if _badge_elapsed >= 0.1:
		_badge_elapsed = 0
		_update_badge()


func configure_weapon():
	if not can_switch_weapon():
		attack_domains = [
			Constants.Match.Navigation.Domain.TERRAIN, Constants.Match.Navigation.Domain.AIR
		]
		return
	var precision = weapon_mode == "precision"
	attack_domains = [Constants.Match.Navigation.Domain.TERRAIN]
	if not precision:
		attack_domains.append(Constants.Match.Navigation.Domain.AIR)
	attack_range = PRECISION_RANGE if precision else INTERCEPTION_RANGE
	sight_range = 13.0
	attack_damage = 15.0 if precision else 5.0
	attack_interval = 1.25 if precision else 0.7
	_update_badge()


func weapon_delay():
	return weapon_switch_left


func weapon_status():
	if weapon_switch_left > 0:
		return "Switching to %s · %.1f s" % [pending_weapon_mode.capitalize(), weapon_switch_left]
	return (
		"Precision · anti-armor"
		if weapon_mode == "precision"
		else (
			tr("Interception · %d%% ground damage")
			% roundi(_rules().aa_ground_damage_factor(player) * 100)
		)
	)


func _update_badge():
	if not is_instance_valid(_mode_badge) or not _mode_badge.diagnostics_enabled():
		return
	_mode_badge.text = (
		(
			"%s %.1f"
			% [
				(
					tr("Precision", "weapon_badge")
					if pending_weapon_mode == "precision"
					else tr("Anti-air", "weapon_badge")
				),
				weapon_switch_left
			]
		)
		if weapon_switch_left > 0
		else (
			tr("Precision", "weapon_badge")
			if weapon_mode == "precision"
			else tr("Anti-air", "weapon_badge")
		)
	)
	_mode_badge.modulate = Color("eac77d") if weapon_switch_left > 0 else Color("d7ecf5")
