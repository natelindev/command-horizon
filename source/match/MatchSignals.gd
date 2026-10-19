extends Node

# requests
signal deselect_all_units
signal setup_and_spawn_unit(unit, transform, player)
signal place_structure(structure_prototype)
signal schedule_navigation_rebake(domain)
signal navigate_unit_to_rally_point(unit, rally_point)  # currently, only for human players

# notifications
signal match_started
signal match_aborted
signal match_finished_with_victory
signal match_finished_with_defeat
signal terrain_targeted(position)
signal terrain_targeted_with_heading(position, heading)
signal tactical_ping(world_position)
signal unit_spawned(unit)
signal unit_targeted(unit)
signal unit_selected(unit)
signal unit_deselected(unit)
signal unit_damaged(unit)
signal unit_weapon_hit(unit, source)
signal unit_destroying(unit)
signal unit_died(unit)
signal unit_production_started(unit_prototype, producer_unit)
signal unit_production_finished(unit, producer_unit)
signal unit_construction_finished(unit)
signal not_enough_resources_for_production(player)
signal not_enough_resources_for_construction(player)

signal resources_mined(worker, kind, amount)

# Accepted player orders only; automatic rally movement is silent.
signal unit_order_issued(unit, kind)
# Presentation only: the destination is captured when the order is submitted.
signal order_feedback(unit, kind, point, accepted, queued, reason)
signal research_completed(player, technology)
