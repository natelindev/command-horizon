extends MarginContainer

const ProductionQueueElement = preload("res://source/match/hud/ProductionQueueElement.tscn")

var _production_queues = []

@onready var _queue_elements = find_child("QueueElements")


func _ready():
	theme = preload("res://source/match/hud/BattleTheme.gd").create()
	_fit_queue()
	get_viewport().size_changed.connect(_fit_queue)
	_reset()
	MatchSignals.unit_selected.connect(func(_unit): _reset())
	MatchSignals.unit_deselected.connect(func(_unit): _reset())
	MatchSignals.unit_died.connect(func(_unit): _reset())


func _reset():
	if not is_inside_tree():
		return
	_detach_observed_production_queue()
	_try_observing_production_queue()
	visible = _is_observing_production_queue()
	_remove_queue_element_nodes()
	_try_rendering_queue()


func _remove_queue_element_nodes():
	for child in _queue_elements.get_children():
		child.queue_free()


func _is_observing_production_queue():
	return not _production_queues.is_empty()


func _detach_observed_production_queue():
	for queue in _production_queues:
		if is_instance_valid(queue):
			queue.element_enqueued.disconnect(_on_production_queue_element_enqueued.bind(queue))
			queue.element_removed.disconnect(_on_production_queue_element_removed)
	_production_queues.clear()


func _try_observing_production_queue():
	for unit in get_tree().get_nodes_in_group("selected_units"):
		if (
			unit.is_in_group("controlled_units")
			and not unit.is_queued_for_deletion()
			and "production_queue" in unit
			and unit.production_queue != null
		):
			_observe(unit.production_queue)


func _observe(queue):
	_production_queues.append(queue)
	queue.element_enqueued.connect(_on_production_queue_element_enqueued.bind(queue))
	queue.element_removed.connect(_on_production_queue_element_removed)


func _try_rendering_queue():
	for queue in _production_queues:
		for element in queue.get_elements():
			_add_queue_element_node(element, queue)


func _add_queue_element_node(element, queue):
	var node = ProductionQueueElement.instantiate()
	node.queue = queue
	node.queue_element = element
	_queue_elements.add_child(node)
	_queue_elements.move_child(node, 0)


func _on_production_queue_element_enqueued(element, queue):
	_add_queue_element_node(element, queue)


func _on_production_queue_element_removed(element):
	(
		_queue_elements
		. get_children()
		. filter(func(queue_element_node): return queue_element_node.queue_element == element)
		. map(func(queue_element_node): queue_element_node.queue_free())
	)


func _fit_queue():
	find_child("QueueScroll").custom_minimum_size.x = minf(480, get_viewport_rect().size.x * .45)
