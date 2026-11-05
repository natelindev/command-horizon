extends RefCounted


## Workers own disjoint, node-free chassis state until the join completes.
## The caller snapshots transforms first and publishes scene changes afterwards.
class Job:
	extends RefCounted
	var chassis: RefCounted
	var root := Transform3D.IDENTITY
	var delta := 0.0
	var mode := 0

	func solve():
		match mode:
			1:
				chassis.reset(root)
			2:
				chassis.clock += delta
			3:
				chassis.advance(delta, root)


var last_worker_count := 0
var _jobs: Array = []
var _lanes := 1


func solve(jobs: Array, parallel := true, minimum_batch := 64):
	last_worker_count = 0
	if jobs.size() < minimum_batch or not parallel or OS.get_processor_count() < 4:
		for job in jobs:
			job.solve()
		return
	_jobs = jobs
	_lanes = mini(4, OS.get_processor_count() - 2)
	last_worker_count = _lanes
	var task := WorkerThreadPool.add_group_task(
		_solve_lane, _lanes, _lanes, true, "Unit body dynamics"
	)
	WorkerThreadPool.wait_for_group_task_completion(task)
	_jobs = []


func _solve_lane(lane: int):
	for index in range(lane, _jobs.size(), _lanes):
		_jobs[index].solve()
