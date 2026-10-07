extends "res://source/match/units/actions/Action.gd"

var controller
var service
var _paid = true
var _last_position = Vector3.ZERO
var _stalled = 0.0
@onready var _unit = get_parent()
@onready var _movement = _unit.get_node("Movement")


func _init(program, provider):
	controller = program
	service = provider


func _ready():
	if restoring:
		return
	_last_position = _unit.global_position_yless


func _physics_process(delta):
	if not controller.valid_service(service):
		controller.set_status(
			"Manual", "Installation cancelled: service unavailable. Fee refunded."
		)
		queue_free()
		return
	var distance = _unit.global_position_yless.distance_to(service.global_position_yless)
	if distance > service.radius + _unit.radius + 0.75:
		_movement.move(service.global_position)
		_stalled += delta
		if _last_position.distance_to(_unit.global_position_yless) > 0.2:
			_last_position = _unit.global_position_yless
			_stalled = 0.0
		if _stalled >= 5.0:
			controller.set_status(
				"Manual", "Installation blocked. Fee refunded; choose another service."
			)
			queue_free()
		return
	_movement.stop()
	controller.install_left = maxf(
		0.0, controller.install_left - delta * _unit.player.production_factor()
	)
	controller.reason = "Fitting chip: %.1f s remaining" % controller.install_left
	if controller.install_left <= 0:
		_paid = false
		controller.installed = true
		_unit.set_meta("chip_installed", true)
		controller.set_status("Manual", "Chip installed. Choose a preset and Run.")
		queue_free()


func _exit_tree():
	if is_instance_valid(_movement):
		_movement.stop()
	if is_instance_valid(controller):
		controller.install_left = 0.0
	if _paid and is_instance_valid(_unit) and not _unit.is_queued_for_deletion() and _unit.hp > 0:
		_unit.player.add_resources(
			{
				"resource_b":
				load("res://source/match/FactionCatalog.gd").chip_cost(_unit.player.faction)
			}
		)
		_paid = false
