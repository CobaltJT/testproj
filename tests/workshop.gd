extends SceneTree
const WORKSHOP = preload("res://scripts/workshop_state.gd")
const JOB = preload("res://scripts/station_job.gd")
const MATERIALS = preload("res://scripts/ore_state.gd")
const ECONOMY = preload("res://scripts/customer_state.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if ok: print("PASS workshop: ", message)
	else:
		failures += 1
		push_error(message)
func work(job: RefCounted, materials: RefCounted, primary: int) -> void:
	var both: Array[int] = [1, 2]
	var none: Array[int] = []
	var other: Array[int] = [2]
	check(job.step(2, both, materials) == -1 and job.progress == 2, "Two workers advance at normal speed")
	job.step(20, none, materials)
	check(job.progress == 2 and job.worker == 0, "Release pauses shared work")
	check(job.step(2.9, other, materials) == -1, "Handoff cannot finish before five seconds")
	check(job.step(0.1, other, materials) == primary, "Handoff finishes exactly one output at five seconds")
func load_ingredient(job: RefCounted, materials: RefCounted, id: int, who: int = 1) -> void:
	check(materials.pickup(who, id) and job.load_material(who, materials), "Correct ingredient loads from hands")
func _initialize() -> void:
	var model = WORKSHOP.new()
	var materials = MATERIALS.new()
	var economy = ECONOMY.new()
	check(model.stations.is_empty() and not model.opened and economy.coins == 100, "Start empty with enough shared setup coins")
	check(model.purchase(1, "anvil", economy, materials) and economy.coins == 80, "Buying charges once and creates an unplaced kit")
	check(not model.purchase(1, "grinder", economy, materials), "Cannot buy a second kit while holding one")
	for at in [Vector2(112, 216), Vector2(368, 136), Vector2(390, 288), Vector2(160, 216), Vector2(256, 200), Vector2(INF, 136), Vector2(257, 136)]:
		check(model.place(1, at) == -1 and model.pending.has(1), "Reject blocked, off-floor, off-grid, or nonfinite placement")
	var anvil: int = model.place(1, Vector2(256, 216))
	check(anvil > 0 and model.opened and model.stations.size() == 1, "Manual anvil placement opens workshop")
	check(model.purchase(2, "grinder", economy, materials) and model.place(2, Vector2(256, 216)) == -1, "Overlapping placement rejected without spending again")
	check(model.cancel(2, economy) and economy.coins == 80 and not model.cancel(2, economy), "Cancel refunds kit exactly once")
	check(model.pack(1, Vector2(256, 216), materials) and model.stations.is_empty(), "Idle station can be packed")
	check(model.place(1, Vector2(160, 136)) == anvil, "Packed station keeps identity when relocated to another floor")
	load_ingredient(model.stations[anvil].job, materials, 0)
	check(not model.pack(1, Vector2(160, 136), materials), "Loaded station cannot be packed or refunded")
	var snapshot = WORKSHOP.new()
	snapshot.restore(model.snapshot())
	check(snapshot.stations[anvil].at == Vector2(160, 136) and snapshot.stations[anvil].job.slots.ore == 0, "Snapshot preserves locations and loaded jobs")
	var job = model.stations[anvil].job
	work(job, materials, 0)
	check(materials.pieces[0].kind == "horseshoe" and materials.is_loose(0), "Horseshoe needs only raw ore and anvil")
	job.select("blade")
	load_ingredient(job, materials, 1)
	work(job, materials, 1)
	check(materials.pieces[1].kind == "dull_sword", "Anvil makes unfinished blade rather than sellable sword")
	var grinder = JOB.new()
	grinder.configure("grinder")
	load_ingredient(grinder, materials, 1)
	work(grinder, materials, 1)
	check(materials.pieces[1].kind == "sword", "Grinder sharpens blade into final sword")
	job.select("head")
	load_ingredient(job, materials, 2)
	work(job, materials, 2)
	check(materials.pieces[2].kind == "axe_head", "Anvil shapes axe head")
	var bench = JOB.new()
	bench.configure("woodbench")
	var wood: int = materials.add_material("wood")
	load_ingredient(bench, materials, wood)
	work(bench, materials, wood)
	check(materials.pieces[wood].kind == "shaft", "Woodworking bench shapes wood into shaft")
	job.select("axe")
	load_ingredient(job, materials, wood, 2)
	var workers: Array[int] = [1, 2]
	check(job.step(10, workers, materials) == -1 and job.progress == 0, "Assembly waits for both head and worked shaft")
	check(not job.select("horseshoe"), "Partially loaded recipe cannot change")
	load_ingredient(job, materials, 2)
	work(job, materials, 2)
	check(materials.pieces[2].kind == "axe" and materials.pieces[wood].consumed, "Assembly produces one axe and consumes shaft once")
	print("WORKSHOP RESULT: ", failures, " failures")
	quit(1 if failures else 0)
