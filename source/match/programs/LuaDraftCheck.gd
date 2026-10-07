extends RefCounted

const Runtime = preload("res://source/match/programs/LuaRuntime.gd")


static func check(source, role):
	var runtime = Runtime.new()
	var result = runtime.compile_source(source)
	if not result.ok:
		return result
	var trace = []
	var steps = []
	# Synthetic inputs only: no live world query or intent dispatch occurs here.
	for index in range(8):
		var hp = 20 if index in [3, 4] else 100
		var contact = {
			"id": 1,
			"type": "Tank",
			"hp": 50,
			"hp_max": 100,
			"position": {"x": 2, "z": 0},
			"distance": 2.0,
			"can_attack": role in ["Tank", "AdvancedTank", "CombatRobot", "Helicopter"],
			"can_repair": role == "RepairRobot"
		}
		var snapshot = {
			"api_version": 1,
			"time": index * 0.2,
			"contacts_truncated": false,
			"self":
			{
				"type": role,
				"hp": hp,
				"hp_max": 100,
				"position": {"x": 0, "z": 0},
				"attack_range": 5.0 if contact.can_attack else 0.0
			},
			"assignments":
			(
				{}
				if index == 0
				else {
					"anchor": {"x": 0, "z": 0},
					"safe": {"x": -4, "z": 0},
					"route_a": {"x": 0, "z": 0},
					"route_b": {"x": 4, "z": 0}
				}
			),
			"enemies": [contact] if index in [2, 3, 5] else [],
			"allies": [contact] if index in [1, 4, 6] else []
		}
		result = runtime.step(snapshot)
		if not result.ok:
			return {"ok": false, "error": "Sample %d: %s" % [index + 1, result.error]}
		steps.append({"index": index + 1, "hp": hp, "intent": result.intent.duplicate(true)})
		trace.append("%d. HP %d%% · %s" % [index + 1, hp, JSON.stringify(result.intent)])
	return {"ok": true, "trace": "\n".join(trace), "steps": steps}
