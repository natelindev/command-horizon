extends RefCounted

## Independent clocks for draw submission. frame_post_draw is deferred to the
## main thread by a threaded renderer and may deliver multiple completions at
## once. Keep those original samples, but also record one timestamp per draw.
signal drained
var main_ticks := PackedInt64Array()
var render_ticks := PackedInt64Array()
var queue_us := PackedInt64Array()
var render_thread_id := 0


func start():
	RenderingServer.frame_pre_draw.connect(_submission)


func _submission():
	var now := Time.get_ticks_usec()
	main_ticks.append(now)
	RenderingServer.call_on_render_thread(_render_submission.bind(now))


func _render_submission(submitted: int):
	var now := Time.get_ticks_usec()
	if render_thread_id == 0:
		render_thread_id = OS.get_thread_caller_id()
	render_ticks.append(now)
	queue_us.append(now - submitted)


func stop():
	RenderingServer.frame_pre_draw.disconnect(_submission)
	# The queued sentinel follows every captured draw. Read the render-owned
	# arrays only after its completion has crossed back to the main thread.
	RenderingServer.call_on_render_thread(_finish)
	await drained


func _finish():
	_finish_main.call_deferred()


func _finish_main():
	drained.emit()


static func intervals(ticks: PackedInt64Array) -> Array:
	var result := []
	for index in range(1, ticks.size()):
		result.append((ticks[index] - ticks[index - 1]) / 1000.0)
	return result
