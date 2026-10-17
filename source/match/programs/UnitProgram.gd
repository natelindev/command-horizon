extends Node

# Compatibility state for authored native mission orders and older archives.
# Battle controls use UnitBehavior and never create a Lua VM.

signal evaluated(snapshot, result)

const FactionRules = preload("res://source/match/FactionRules.gd")
const Library = preload("res://source/match/programs/ProgramLibrary.gd")
var installed = false
var config = Library.defaults()
var program_title = "Hold · built-in"
var anchor = null
var safe_point = null
var escort = null
var route = []
var mode = "Manual"
var reason = "Hold position; ordinary orders are available."
var install_left = 0.0
var trace = []
var saved_record = {}
var lua_source = ""
var lua_runtime = null
var _pending = false
var _owned_action = null
var _changing = false
var _last_lua_alert = ""
@onready var unit = get_parent()


func _ready():
	installed = true
	if unit.has_signal("action_changed"):
		unit.action_changed.connect(_on_action_changed)
	set_physics_process(false)


func ready_to_run():
	return installed and install_left <= 0.0


func configure(value, title = "Custom preset"):
	if not Library.validate(value) or not Library.compatible(value.preset, unit.type):
		return false
	if "manual_orders" in unit and unit.manual_orders != null:
		unit.manual_orders.cancel()
	# Editing a draft never silently replaces a live program.
	manual_override()
	if "action" in unit:
		unit.action = null
	config = value.duplicate(true)
	program_title = title
	saved_record = {}
	lua_source = ""
	lua_runtime = null
	return true


func configure_lua(_source, _title = "Custom Lua"):
	return {"ok": false, "error": "Use Attack, Defensive, Follow, Guard or Hold Fire."}


func apply_prepared(entry, _runtime):
	# Legacy native presets remain available to authored missions and archive tools.
	if entry.mode != "preset":
		return
	configure(entry.config, "%s · v%d" % [entry.name, entry.version])
	saved_record = entry.duplicate(true)
	_pending = true
	set_physics_process(true)
	set_status("Ready", "Program starts on the next simulation tick.")


func run():
	if not ready_to_run() or not Library.compatible(config.preset, unit.type):
		return false
	if not lua_source.is_empty():
		return false
	if "manual_orders" in unit and unit.manual_orders != null:
		unit.manual_orders.cancel()
	# Resume takes authority immediately, including while paused. Retire the
	# old attack/move before its late completion can install an idle action and
	# cancel the accepted program while it is waiting for its first tick.
	_changing = true
	if "action" in unit:
		unit.action = null
	_owned_action = null
	_changing = false
	_pending = true
	set_physics_process(true)
	set_status("Ready", "Program starts on the next simulation tick.")
	return true


func manual_override():
	if "program_squad" in unit and is_instance_valid(unit.program_squad):
		unit.program_squad.release(unit)
	_pending = false
	set_physics_process(false)
	set_status("Manual", "Direct orders have priority. Resume to return to the assignment.")


func disable():
	var was_active = mode in ["Running", "Ready", "Blocked", "Waiting", "Error"]
	manual_override()
	if was_active and "action" in unit:
		unit.action = null


func set_status(state, explanation):
	if mode == state and reason == explanation:
		return
	mode = state
	reason = explanation
	var match_time = (
		unit._match.simulation_time
		if ("_match" in unit and unit._match != null and "simulation_time" in unit._match)
		else 0.0
	)
	trace.append({"time": match_time, "reason": explanation})
	if trace.size() > 16:
		trace.pop_front()


func _physics_process(_delta):
	set_physics_process(false)
	if not _pending:
		return
	_pending = false
	if not ready_to_run() or not Library.compatible(config.preset, unit.type):
		return
	if lua_source.is_empty() and Library.behavior(config.preset) == "hold":
		anchor = unit.global_position_yless
	_changing = true
	var action_path = (
		"res://source/match/programs/SpecialistAction.gd"
		if config.preset in Library.SPECIALISTS
		else "res://source/match/programs/PresetAction.gd"
	)
	if not lua_source.is_empty():
		return
	_owned_action = load(action_path).new(self)
	unit.action = _owned_action
	_changing = false


func _on_action_changed(action):
	if (
		not _changing
		and mode in ["Running", "Ready", "Waiting", "Blocked", "Error"]
		and action != _owned_action
	):
		manual_override()


func report_lua_error(message):
	var key = lua_source.sha256_text() + message
	if key == _last_lua_alert:
		return
	_last_lua_alert = key
	if unit.player != unit._match._get_human_player():
		return
	if "hud" in unit._match and is_instance_valid(unit._match.hud):
		var unit_title = load("res://source/match/FactionCatalog.gd").title(
			unit.player.faction, unit.type
		)
		unit._match.hud.show_notice(
			(
				"%s · %s: %s. Program suspended; Resume starts clean."
				% [unit_title, program_title, message.left(160)]
			)
		)


func install_at(service):
	if installed or install_left > 0 or not unit.player.basic_programs_unlocked():
		return false
	if (
		not valid_service(service)
		or not unit.player.has_resources(
			{"resource_b": FactionRules.chip_cost(unit.player.faction)}
		)
	):
		return false
	unit.issue_manual_order(null)
	unit.player.subtract_resources({"resource_b": FactionRules.chip_cost(unit.player.faction)})
	install_left = FactionRules.chip_seconds(unit.player.faction)
	set_status("Installing", "Moving to service for chip installation.")
	unit.action = load("res://source/match/programs/ChipInstalling.gd").new(self, service)
	return true


func valid_service(service):
	return (
		is_instance_valid(service)
		and not service.is_queued_for_deletion()
		and service.player == unit.player
		and service.type in ["CommandCenter", "RepairDepot"]
		and service.is_constructed()
	)
