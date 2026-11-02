extends Node

## Admission is synchronous; expensive action/path starts have a fixed tick
## boundary. Pending ManualOrders remain the authoritative, saved work queue.
const GROUP_THRESHOLD = 64
const STARTS_PER_TICK = 96

var queued_total := 0
var activated_total := 0
var maximum_wait_ticks := 0
var maximum_batch := 0
var maximum_batch_us := 0
var _waiting := {}
var _tick := 0


static func acquire(game):
	var queue = game.get_node_or_null("OrderActivationQueue")
	if queue == null:
		queue = load("res://source/match/orders/OrderActivationQueue.gd").new()
		queue.name = "OrderActivationQueue"
		game.add_child(queue)
	return queue


func _ready():
	# Start before ordinary unit movement and the match's native crowd step.
	process_physics_priority = -1000
	set_physics_process(false)


func enqueue(orders):
	var key = orders.get_instance_id()
	if not _waiting.has(key):
		queued_total += 1
		_waiting[key] = [weakref(orders), _tick]
	set_physics_process(true)


func cancel(orders):
	_waiting.erase(orders.get_instance_id())
	if _waiting.is_empty():
		set_physics_process(false)


func _physics_process(_delta):
	_tick += 1
	var started := Time.get_ticks_usec()
	var count := 0
	# The saved unit roster preserves this order. Reconstructing a partially
	# started queue therefore needs no extra v22 scheduling fields.
	for unit in get_parent().get_units():
		if count >= STARTS_PER_TICK:
			break
		var controller = unit.get("manual_orders")
		if controller == null:
			continue
		var key: int = controller.get_instance_id()
		if not _waiting.has(key):
			continue
		var item: Array = _waiting[key]
		var orders = item[0].get_ref()
		if not is_instance_valid(orders) or orders.is_queued_for_deletion():
			_waiting.erase(key)
			continue
		if not orders.can_activate_waiting_order():
			continue
		_waiting.erase(key)
		orders.activate_waiting_order()
		maximum_wait_ticks = maxi(maximum_wait_ticks, _tick - int(item[1]))
		activated_total += 1
		count += 1
	maximum_batch = maxi(maximum_batch, count)
	maximum_batch_us = maxi(maximum_batch_us, Time.get_ticks_usec() - started)
	if _waiting.is_empty():
		set_physics_process(false)


func statistics() -> Dictionary:
	return {
		"queued": _waiting.size(),
		"queued_total": queued_total,
		"activated_total": activated_total,
		"maximum_wait_ticks": maximum_wait_ticks,
		"maximum_wait_ms": maximum_wait_ticks * 1000.0 / Engine.physics_ticks_per_second,
		"maximum_batch": maximum_batch,
		"maximum_batch_us": maximum_batch_us,
	}
