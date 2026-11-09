extends SceneTree
const ORE = preload("res://scripts/ore_state.gd")
const JOB = preload("res://scripts/forge_state.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if ok:
		print("PASS anvil: ", message)
	else:
		failures += 1
		push_error(message)
func _initialize() -> void:
	var ore = ORE.new()
	var job = JOB.new()
	job.output_kind = "hammer"
	ore.pickup(1, 0)
	check(not job.load_ingot(1, ore) and ore.carried_by(1) == 0, "Reject raw ore without taking it")
	ore.release_carrier(1)
	ore.store(0)
	ore.finish_smelting(ore.begin_smelting())
	ore.pickup(1, 0)
	check(job.load_ingot(1, ore) and ore.carried_by(1) == -1 and ore.pieces[0].processing, "Load one carried ingot into shared job")
	check(not job.load_ingot(2, ore), "Cannot overwrite an existing job")
	var first: Array[int] = [1, 2]
	var none: Array[int] = []
	var second: Array[int] = [2]
	job.step(2, first, ore)
	job.step(10, none, ore)
	check(job.progress == 2 and job.worker == 0, "Multiple workers do not accelerate; release pauses")
	job.step(2.9, second, ore)
	check(ore.pieces[0].kind == "ingot" and job.worker == 2, "Handoff resumes and cannot finish before five seconds")
	job.step(0.1, second, ore)
	check(ore.is_loose(0) and ore.pieces[0].kind == "hammer" and ore.pieces.size() == 8, "Five seconds makes one hammer without duplicating material")
	check(not ore.store(0), "Hammer cannot be smelted as ore")
	job.step(10, first, ore)
	check(job.piece == -1 and job.progress == 0, "Empty anvil cannot start another recipe automatically")
	print("ANVIL RESULT: ", failures, " failures")
	quit(1 if failures else 0)
