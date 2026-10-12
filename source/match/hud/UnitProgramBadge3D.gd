extends Label3D

var _unit = null
var _program = null


func setup(unit, program):
	_unit = unit
	_program = program
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	no_depth_test = true
	font_size = 14
	pixel_size = 0.0035
	outline_size = 3
	outline_modulate = Color(0.05, 0.08, 0.12, 0.9)
	modulate = Color("68d391")  # subtle tech green/cyan
	var rad = _unit.radius if ("radius" in _unit and _unit.radius != null) else 1.0
	position = Vector3(0, maxf(1.6, (rad * 1.8) + 0.8), 0)
	_update_text()
	_program.evaluated.connect(_on_evaluated)


func _process(_delta):
	if not is_instance_valid(_unit) or not is_instance_valid(_program):
		queue_free()
		return
	var active = _program.mode in ["Running", "Ready", "Waiting"]
	visible = active and (_unit.is_in_group("selected_units") or _program.mode == "Running")


func _on_evaluated(_snapshot, result):
	if result != null and typeof(result) == TYPE_DICTIONARY and "intent" in result:
		var intent = result.intent
		if typeof(intent) == TYPE_DICTIONARY and "kind" in intent:
			var action_kind = str(intent.kind).to_upper()
			text = "⚙ [%s]" % action_kind
			return
	_update_text()


func _update_text():
	if not is_instance_valid(_program):
		return
	var preset = _program.config.get("preset", "")
	if not preset.is_empty():
		text = "⚙ [%s]" % preset.to_upper()
	elif _program.mode in ["Running", "Ready"]:
		text = "⚙ [ACTIVE]"
	else:
		text = ""
