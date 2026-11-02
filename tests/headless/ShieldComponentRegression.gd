extends SceneTree

var errors = []


func _initialize():
	_run.call_deferred()


func _run():
	var component = load("res://source/match/units/traits/ShieldComponent.gd").new()
	var events = {"break": 0, "start": 0, "full": 0}
	component.broken.connect(func(): events["break"] += 1)
	component.recharge_started.connect(func(): events.start += 1)
	component.recharged.connect(func(): events.full += 1)
	component.set_capacity(30.0)
	_check(component.charge == 30.0, "Equipped shield was not full")
	_check(component.absorb(12.0, 0.0) == 0.0, "Shield leaked damage")
	component.set_capacity(30.0)
	_check(component.charge == 18.0, "Applying capacity refilled the shield")
	_check(component.absorb(20.0, 1.0) == 2.0, "Overflow damage differs")
	_check(events["break"] == 1, "Shield break signal missing or duplicated")
	component.absorb(1.0, 3.0)
	component.tick(1.0, 7.9)
	_check(component.charge == 0.0, "Hull damage did not delay recharge")
	component.tick(0.5, 8.0)
	_check(component.charge == 4.0 and events.start == 1, "Recharge rate/start differs")
	component.tick(0.0, 8.0)
	_check(component.charge == 4.0, "Paused simulation advanced shields")
	component.tick(0.5, 8.5, 1.5)
	_check(component.charge == 10.0 and events.start == 1, "Support multiplier differs")
	component.tick(100.0, 9.0)
	_check(component.charge == 30.0 and events.full == 1, "Full recharge event/cap differs")
	component.tick(1.0, 10.0)
	_check(events.full == 1, "Full shield repeatedly emitted recharge")
	component.drain(50.0, 11.0)
	_check(component.charge == 0.0 and events["break"] == 2, "EMP did not break shields")
	component.tick(1.0, 15.9)
	_check(component.charge == 0.0, "EMP bypassed the recharge delay")
	component.set_capacity(0.0)
	_check(component.absorb(9.0, 16.0) == 9.0, "Unshielded damage changed")
	for error in errors:
		push_error(error)
	print("Shield component: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _check(condition, message):
	if not condition:
		errors.append(message)
