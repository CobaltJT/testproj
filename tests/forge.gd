extends SceneTree
const WORKSHOP = preload("res://scripts/workshop_state.gd")
const JOB = preload("res://scripts/station_job.gd")
const MATERIALS = preload("res://scripts/ore_state.gd")
const ECONOMY = preload("res://scripts/customer_state.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if ok: print("PASS forge: ", message)
	else:
		failures += 1
		push_error(message)
func _initialize() -> void:
	var model = WORKSHOP.new()
	var materials = MATERIALS.new()
	var economy = ECONOMY.new()
	check(model.stations.is_empty() and model.purchase(1, "forge", economy, materials) and economy.coins == 75, "Forge and included bin are one purchasable kit")
	var id: int = model.place(1, Vector2(256, 216))
	var job = model.stations[id].job
	check(job.kind == "forge" and job.recipe == "smelt", "Placed forge has smelting recipe")
	check(job.store_ore(0, materials) and not job.store_ore(0, materials), "Bin reserves each loose ore once")
	check(job.store_ore(1, materials) and job.ore_queue == [0, 1], "Bin holds multiple pieces in order")
	var wood: int = materials.add_material("wood")
	check(not job.store_ore(wood, materials), "Bin rejects wood without consuming it")
	check(not model.pack(1, Vector2(256, 216), materials), "Forge with stocked bin cannot be packed")
	var none: Array[int] = []
	var both: Array[int] = [1, 2]
	var second: Array[int] = [2]
	job.step(10, none, materials)
	check(job.ore_queue.size() == 2 and job.slots.is_empty(), "Idle forge retains bin stock without starting")
	job.step(2, both, materials)
	check(job.progress == 2 and job.slots.ore == 0 and job.ore_queue == [1], "One worker consumes one queued ore at normal speed")
	job.step(10, none, materials)
	check(job.progress == 2 and job.worker == 0, "Release pauses forge work")
	var restored = WORKSHOP.new()
	restored.restore(model.snapshot())
	check(restored.stations[id].job.ore_queue == [1] and restored.stations[id].job.progress == 2, "Snapshot preserves bin contents and active smelt")
	check(job.step(2.9, second, materials) == -1 and job.step(0.1, second, materials) == 0 and materials.pieces[0].kind == "ingot", "Handoff smelts exactly once after five seconds")
	check(not job.store_ore(0, materials), "Ingots cannot be smelted again")
	check(job.step(5, both, materials) == 1 and job.ore_queue.is_empty(), "Held work can smelt next queued piece")
	check(model.pack(1, Vector2(256, 216), materials) and model.place(1, Vector2(160, 288)) == id, "Empty forge and bin relocate as one station")
	for recipe in ["horseshoe", "blade", "head"]:
		var anvil = JOB.new()
		anvil.configure("anvil")
		anvil.select(recipe)
		materials.pickup(1, 2)
		check(not anvil.load_material(1, materials) and materials.carried_by(1) == 2, "Anvil rejects raw ore for " + recipe)
		materials.release_carrier(1)
		materials.pickup(1, 0)
		check(anvil.load_material(1, materials) and anvil.slots.ingot == 0, "Anvil accepts ingot for " + recipe)
		anvil.step(5, both, materials)
		check(materials.pieces[0].kind == JOB.OUTPUTS[recipe], "Ingot follows existing anvil product route")
		materials.pieces[0].kind = "ingot"
	print("FORGE RESULT: ", failures, " failures")
	quit(1 if failures else 0)
