extends SceneTree
## Simulation contract without a Session, physics world or network peer.
class Actor extends RefCounted:
	var position := Vector2(456, 216)
	var transport_locked := false
	var climbing := false
	var hit_stun := 0.0
	var controls := Vector2.ZERO
	var jump_held := false
	func is_on_floor() -> bool: return true
var failures := 0
var outputs: Array = []
var rewards: Array = []
func check(ok: bool, message: String) -> void:
	if ok: print("PASS placeables controller: ", message)
	else:
		failures += 1
		push_error(message)
func _initialize() -> void:
	var controller = preload("res://scripts/controllers/placeables.gd").new()
	var workshop = preload("res://scripts/workshop_state.gd").new()
	var items = preload("res://scripts/ore_state.gd").new()
	var needs = preload("res://scripts/needs_state.gd").new()
	var skills = preload("res://scripts/progression_state.gd").new()
	var day = preload("res://scripts/day_state.gd").new()
	var job = preload("res://scripts/station_job.gd").new()
	job.configure("anvil")
	workshop.stations[1] = {"kind": "anvil", "at": Vector2(456, 216), "job": job}
	var actors := {2: Actor.new(), 1: Actor.new()}
	var held := {1: true, 2: true}
	for id in actors:
		needs.add(id)
		skills.add(id)
	controller.bind(workshop, items, needs, day, func(_at: Vector2) -> int: return 0)
	var mine = preload("res://scripts/mining_state.gd").new()
	controller.bind_workers(actors, held, skills, {0: mine}, true)
	controller.output_ready.connect(func(piece: int, at: Vector2): outputs.append([piece, at]))
	controller.experience_requested.connect(func(id: int, task: String): rewards.append([id, task]))
	items.pieces[0].kind = "ingot"
	items.pickup(1, 0)
	job.load_material(1, items)
	controller.step_workstations(1)
	check(job.worker == 1 and job.progress == 1 and needs.dwarfs[2].energy == 100, "One worker progresses and pays needs costs; lowest ID selected")
	held[1] = false
	controller.step_workstations(1)
	check(job.worker == 2 and job.progress == 2, "Worker handoff preserves progress")
	controller.authoritative = false
	controller.step_workstations(10)
	check(job.progress == 2 and outputs.is_empty(), "Replica cannot advance production")
	controller.authoritative = true
	held[1] = true
	controller.step_workstations(0)
	check(job.worker == 2, "Current worker keeps job when a lower ID becomes eligible")
	workshop.pending[2] = "anvil"
	check(not controller.available(2), "Holding a placement kit prevents work and recovery")
	workshop.pending.clear()
	actors[2].transport_locked = true
	check(not controller.available(2), "Transport lock prevents work and recovery")
	actors[2].transport_locked = false
	actors[2].controls = Vector2.RIGHT
	check(not controller.available(2), "Moving prevents work and recovery")
	actors[2].controls = Vector2.ZERO
	controller.step_workstations(3)
	check(items.pieces[0].kind == "horseshoe" and outputs.size() == 1 and rewards == [[2, "crafting"]], "Completion emits one physical output and credits actual worker")
	controller.step_mining(3)
	check(mine.extracted == 0, "Mine is closed in morning")
	day.phase = "shop"
	held[1] = false
	controller.step_mining(3)
	check(mine.extracted == 1 and outputs.size() == 2 and rewards.back() == [2, "mining"], "Mining emits output and experience through the same boundary")
	job = preload("res://scripts/station_job.gd").new()
	job.configure("bed")
	workshop.stations[1] = {"kind": "bed", "at": Vector2(456, 216), "job": job}
	needs.dwarfs[2].energy = 0
	controller.step_care(1)
	check(needs.dwarfs[2].energy == 12, "Recovery remains available at zero energy")
	job = preload("res://scripts/station_job.gd").new()
	job.configure("dining")
	workshop.stations[1] = {"kind": "dining", "at": Vector2(456, 216), "job": job}
	var food: int = items.add_material("food")
	items.pickup(2, food)
	job.load_material(2, items)
	needs.dwarfs[2].food = 0
	held[1] = true
	controller.step_care(1)
	check(job.worker == 2 and needs.dwarfs[2].food == 8, "Meal belongs to its diner even when another player is eligible")
	controller.forget_actor(2)
	check(items.pieces[food].consumed and not items.pieces[food].processing and job.slots.is_empty() and job.diner == 0, "Disconnect consumes reserved meal and frees table")
	print("PLACEABLES CONTROLLER RESULT: ", failures, " failures")
	quit(1 if failures else 0)
