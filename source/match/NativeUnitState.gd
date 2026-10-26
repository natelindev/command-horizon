extends RefCounted


## Cold binding only. Native arrays retain hot facts; mutations update their
## fields immediately. Unsupported script behavior keeps the existing live path.
static func uses_base_method(object: Object, base_path: String, method: StringName) -> bool:
	var script: Script = object.get_script()
	var methods := script.get_script_method_list()
	while script != null:
		if script.resource_path == base_path:
			# The public list includes every base definition, including duplicate
			# names for overrides. An extra definition changes the count. Calling
			# Object.has_method on the resource tests resource API methods instead.
			var expected := 0
			var actual := 0
			for entry in script.get_script_method_list():
				expected += int(entry.name == method)
			for entry in methods:
				actual += int(entry.name == method)
			return expected > 0 and actual == expected
		script = script.get_base_script()
	return false


static func bind(unit, store: RefCounted):
	var navigation_trait = unit._get_navigation_trait()
	var flags := 0
	if uses_base_method(unit, "res://source/match/units/Unit.gd", &"combat_domain"):
		flags |= 1
	if uses_base_method(unit, "res://source/match/units/Structure.gd", &"is_constructed"):
		flags |= 2
	if load("res://source/match/BastionCatalog.gd").is_infantry(unit.type):
		flags |= 4
	if unit.type in ["AntiGroundTurret", "AntiAirTurret"]:
		flags |= 8
	if (
		uses_base_method(unit, "res://source/match/units/Unit.gd", &"effective_sight_range")
		and uses_base_method(unit, "res://source/match/units/Unit.gd", &"terrain_advantage")
	):
		flags |= 4096
	return (
		store
		. bind_unit(
			unit,
			navigation_trait,
			[
				unit.hp,
				unit.hp_max,
				unit._base_attack_damage,
				unit._base_attack_interval,
				unit._base_attack_range,
				unit.sight_range,
				unit.get("_construction_progress"),
				navigation_trait.domain if navigation_trait != null else null,
				(
					navigation_trait._native_base_speed
					if navigation_trait is NavigationAgent3D
					else 0.0
				),
				unit.veterancy_speed_factor,
				unit.veterancy_reload_factor,
				unit.scrap_hardened_tiers,
			],
			unit.attack_domains,
			flags
		)
	)
