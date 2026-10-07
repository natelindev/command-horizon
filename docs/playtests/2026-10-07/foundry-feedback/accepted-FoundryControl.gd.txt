extends "res://source/match/objectives/CaptureRelay.gd"


func _physics_process(delta):
	if not _match.production_disabled():
		_update_presentation()
		return
	super(delta)


func _update_presentation():
	super()
	_label.text = "FOUNDRY · " + _match.control_status().to_upper()
