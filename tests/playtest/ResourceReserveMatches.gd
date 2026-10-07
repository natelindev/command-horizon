extends "res://tests/playtest/CautiousRelayMatches.gd"


func _observe_production(prototype, producer):
	super(prototype, producer)
	if producer.player == human or Catalog.type_from_path(prototype.resource_path) != "Infantry":
		return
	var player = producer.player
	var desired = player._next_building(player._units())
	var reserve = production_policy.reserve(player, player._units(), desired)
	if player.resource_b >= reserve.y:
		return
	var paid = producer.production_queue.get_elements()[-1].paid_cost
	var event = {
		"seconds": game.simulation_time,
		"faction": player.faction,
		"desired": desired,
		"reserve": [reserve.x, reserve.y],
		"before": [player.resource_a + paid.resource_a, player.resource_b + paid.resource_b],
		"after": [player.resource_a, player.resource_b],
		"paid": [paid.resource_a, paid.resource_b]
	}
	_check(
		paid.resource_b == 0 and player.resource_a >= reserve.x,
		"Production spent building reserves"
	)
	if not metrics.has("independent_resource_orders"):
		metrics.independent_resource_orders = []
	metrics.independent_resource_orders.append(event)
	print("INDEPENDENT RESOURCE ORDER ", JSON.stringify(event))
