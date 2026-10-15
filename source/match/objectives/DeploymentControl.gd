extends "res://source/match/objectives/CaptureRelay.gd"


func _init():
	label_title = "DEPLOYMENT"


func _update_presentation():
	super()
	_label.text = tr("DEPLOYMENT") + " · " + tr(_match.deployment_status()).to_upper()
