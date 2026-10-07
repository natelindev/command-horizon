extends Node2D

const Ownership = preload("res://source/match/hud/Ownership.gd")
var kind = "own"
var color = Color.WHITE


func _draw():
	Ownership.paint(self, Vector2.ZERO, kind, 3.0 if kind != "resource" else 2.0, color)
