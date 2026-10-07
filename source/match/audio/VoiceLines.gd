extends RefCounted

const EVENTS = preload("res://source/match/MatchConstants.gd").VoiceNarrator.Events
const TEXT = {
	EVENTS.MATCH_STARTED: "Battle control online.",
	EVENTS.MATCH_ABORTED: "Battle control offline.",
	EVENTS.MATCH_FINISHED_WITH_VICTORY: "You are victorious.",
	EVENTS.MATCH_FINISHED_WITH_DEFEAT: "You have lost.",
	EVENTS.BASE_UNDER_ATTACK: "Your base is under attack.",
	EVENTS.UNIT_UNDER_ATTACK: "Unit under attack.",
	EVENTS.UNIT_LOST: "Unit lost.",
	EVENTS.UNIT_PRODUCTION_STARTED: "Training.",
	EVENTS.UNIT_PRODUCTION_FINISHED: "Unit ready.",
	EVENTS.UNIT_CONSTRUCTION_FINISHED: "Construction complete.",
	EVENTS.UNIT_HELLO: "Sir?",
	EVENTS.UNIT_ACK_1: "Yes, sir.",
	EVENTS.UNIT_ACK_2: "Acknowledged.",
	EVENTS.NOT_ENOUGH_RESOURCES: "Not enough resources.",
}
const UNIT_EVENTS = [EVENTS.UNIT_HELLO, EVENTS.UNIT_ACK_1, EVENTS.UNIT_ACK_2]
const TERMINAL = [
	EVENTS.MATCH_ABORTED, EVENTS.MATCH_FINISHED_WITH_VICTORY, EVENTS.MATCH_FINISHED_WITH_DEFEAT
]


static func priority(event):
	if event in TERMINAL:
		return 100
	if event == EVENTS.BASE_UNDER_ATTACK:
		return 90
	if event == EVENTS.UNIT_LOST:
		return 80
	if event == EVENTS.UNIT_UNDER_ATTACK:
		return 70
	if event == EVENTS.MATCH_STARTED:
		return 50
	if event == EVENTS.NOT_ENOUGH_RESOURCES:
		return 40
	return 10 if event in UNIT_EVENTS or event == EVENTS.UNIT_PRODUCTION_STARTED else 30


static func cooldown(event):
	if event in [EVENTS.BASE_UNDER_ATTACK, EVENTS.UNIT_UNDER_ATTACK]:
		return 10.0
	if event == EVENTS.UNIT_LOST:
		return 6.0
	return 2.0 if event in UNIT_EVENTS else 3.0


static func record(event):
	return {
		"event": event,
		"speaker": "Unit" if event in UNIT_EVENTS else "Command",
		"text": TEXT[event],
		"priority": priority(event),
	}
