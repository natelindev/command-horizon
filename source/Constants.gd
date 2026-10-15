extends Node

enum PlayerType {
	NONE = 0,
	HUMAN = 1,
	SIMPLE_CLAIRVOYANT_AI = 2,
}


class Match:
	extends "res://source/match/MatchConstants.gd"

	class Player:
		const CONTROLLER_SCENES = {
			PlayerType.HUMAN: preload("res://source/match/players/human/Human.tscn"),
			PlayerType.SIMPLE_CLAIRVOYANT_AI:
			preload("res://source/match/players/simple-clairvoyant-ai/SimpleClairvoyantAI.tscn"),
		}


class Player:
	# Designed team palette: mid-value, moderately saturated hues that stay distinct from
	# each other, from fog memory and from every biome ground. Slots 0/1 face each other
	# in skirmish; campaign opponents use slot 2.
	const COLORS = [
		Color("e0ad46"),  # amber
		Color("d86965"),  # coral
		Color("38c8ce"),  # teal
		Color("6f9fe0"),  # cornflower
		Color("a984d8"),  # violet
		Color("8fbf5a"),  # moss
		Color("4fb38a"),  # jade
		Color("d97ab0"),  # rose
	]


# gdlint: ignore=class-variable-name
var OPTIONS_FILE_PATH:
	set(_value):
		pass
	get:
		return (
			"user://options.tres"
			if not FeatureFlags.save_user_files_in_tmp
			else "res://tmp/options.tres"
		)
