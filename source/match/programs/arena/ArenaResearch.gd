extends RefCounted

const Catalog = preload("res://source/match/research/TechnologyCatalog.gd")


static func baseline():
	return {"coordination": false, "completed": []}


static func capture(player):
	return {
		"coordination": player.coordination_unlocked,
		"completed": player.technology.completed.duplicate()
	}


static func valid(profile):
	if not profile is Dictionary or profile.size() != 2:
		return false
	if not profile.get("coordination") is bool or not profile.get("completed") is Array:
		return false
	var state = Catalog.empty_state()
	state.completed = profile.completed
	return Catalog.valid_state(state, profile.coordination)


static func apply(player, profile):
	player.coordination_unlocked = profile.coordination
	var state = Catalog.empty_state()
	state.completed = profile.completed.duplicate()
	player.technology.restore(state)


static func summary(profile):
	if not valid(profile):
		return "Research setup unavailable"
	var parts = PackedStringArray()
	var weapons = Catalog.rank("weapons", profile.completed)
	var armor = Catalog.rank("armor", profile.completed)
	if weapons > 0:
		parts.append("Weapons +%d%%" % (weapons * 10))
	if armor > 0:
		parts.append("HP +%d%%" % (armor * 10))
	if "service" in profile.completed:
		parts.append("Service +25%")
	if "doctrine" in profile.completed:
		parts.append("Faction doctrine")
	if profile.coordination:
		parts.append("Coordination")
	return " · ".join(parts) if not parts.is_empty() else "No completed research"
