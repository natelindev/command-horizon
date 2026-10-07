extends "res://tests/rendered/RelayContestPreview.gd"


func _archive_file(index):
	return (
		"res://docs/playtests/2026-10-06/relay-commitment/final%d-earned-case%d-10-relay_secured.json"
		% [index, index]
	)
