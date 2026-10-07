extends Button

var queue = null
var queue_element = null


func _ready():
	if queue == null or queue_element == null:
		return
	queue_element.changed.connect(_on_queue_element_changed)
	pressed.connect(func(): queue.cancel(queue_element))
	var catalog = load("res://source/match/BastionCatalog.gd")
	var unit_type = catalog.type_from_path(queue_element.unit_prototype.resource_path)
	text = ""
	var factions = load("res://source/match/FactionCatalog.gd")
	var faction = queue.get_parent().player.faction
	icon = load(factions.icon(faction, unit_type))
	expand_icon = true
	tooltip_text = (
		factions.title(faction, unit_type)
		+ (" · basic chip fitted" if queue_element.fitted_chip else "")
		+ (
			" · " + queue_element.program_snapshot.title
			if not queue_element.program_snapshot.is_empty()
			else ""
		)
		+ " — click to cancel and refund"
	)
	find_child("Label").text = "{0}%".format([int(queue_element.progress() * 100.0)])


func _on_queue_element_changed():
	find_child("Label").text = "{0}%".format([int(queue_element.progress() * 100.0)])
