extends Resource

enum Visibility { PER_PLAYER, ALL_PLAYERS, FULL }

@export var players: Array[Resource] = []
@export var visibility = Visibility.PER_PLAYER
@export var visible_player = 0

@export var skirmish = false
@export var advanced_start = false
@export var starting_resources_multiplier = 1
@export var map_path = ""
@export var match_seed = 0
@export var mission_id = ""

# Finale replay choice; its archive contract is stored with that mission.
@export var campaign_challenge = ""
@export var tactical_doctrine = "balanced"
