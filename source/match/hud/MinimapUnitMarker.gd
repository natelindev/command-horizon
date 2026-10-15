extends Node2D

const Ownership = preload("res://source/match/hud/Ownership.gd")
var kind = "own":
	set(value):
		if kind != value:
			kind = value
			queue_redraw()
var color = Color.WHITE:
	set(value):
		if color != value:
			color = value
			queue_redraw()


func _draw():
	Ownership.paint(self, Vector2.ZERO, kind, 3.0 if kind != "resource" else 2.0, color)
