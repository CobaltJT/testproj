extends RefCounted
## Stationary production and recovery; interaction methods retain independent priorities.
const CONTEXT = preload("res://scripts/interaction/context.gd")
const WORKSHOP = preload("res://scripts/workshop_state.gd")
const JOB = preload("res://scripts/station_job.gd")
const NEEDS = preload("res://scripts/needs_state.gd")
const MAP = preload("res://scripts/map_layout.gd")
signal items_changed
signal workshop_changed
signal feedback_requested(id: int, message: String)
var workshop: RefCounted
var items: RefCounted
var needs: RefCounted
var cycle: RefCounted
var find_vein: Callable
var views: Dictionary = {}

signal experience_requested(id: int, task: String)
signal output_ready(piece: int, at: Vector2)
signal production_completed
signal mining_completed
var players: Dictionary = {}
var work_held: Dictionary = {}
var progression: RefCounted
var mine_veins: Dictionary = {}
var authoritative := false

func bind(stations: RefCounted, inventory: RefCounted, vitals: RefCounted, day: RefCounted, mining_query: Callable, station_views: Dictionary = {}) -> void:
	workshop = stations
	items = inventory
	needs = vitals
	cycle = day
	find_vein = mining_query
	views = station_views

func station(context: CONTEXT) -> int:
	return context.query(&"station", workshop.nearest)

func try_mine(context: CONTEXT) -> bool:
	if context.action != &"interact" or context.query(&"vein", find_vein) == -1: return false
	feedback_requested.emit(context.player_id, "Mine closed until shop hours." if cycle.phase != "shop" else "Hold E with empty hands to mine ore. Prospector speeds up extraction.")
	return true

func try_storage(context: CONTEXT) -> bool:
	if context.action != &"interact": return false
	var id := station(context)
	if id == -1 or workshop.stations[id].kind not in WORKSHOP.STORAGE: return false
	var transferred: bool = workshop.storage_transfer(context.player_id, context.position, items, id)
	var message := "Stored item." if transferred and context.carried_item != -1 else ("Retrieved item. T: select another stored product." if transferred else "Storage: check category, capacity and selected product. T: cycle products.")
	workshop_changed.emit()
	items_changed.emit()
	feedback_requested.emit(context.player_id, message)
	return true

func try_care(context: CONTEXT) -> bool:
	if context.action != &"interact": return false
	var id := station(context)
	if id == -1 or workshop.stations[id].kind not in WORKSHOP.CARE: return false
	var entry: Dictionary = workshop.stations[id]
	var message: String
	if entry.kind == "bed": message = "Hold E with empty hands to sleep."
	elif context.carried_item != -1 and needs.dwarfs[context.player_id].food < 100 and entry.job.load_material(context.player_id, items): message = "Meal loaded. Hold E to eat."
	else: message = "Carry food to an empty table, then hold E to eat."
	workshop_changed.emit()
	items_changed.emit()
	feedback_requested.emit(context.player_id, message)
	return true

func try_load(context: CONTEXT) -> bool:
	if context.action != &"interact" or context.carried_item == -1: return false
	var id := station(context)
	if id == -1: return false
	var job = workshop.stations[id].job
	var message := "Ingredient loaded. Hold E with empty hands to work." if job.load_material(context.player_id, items) else ("Throw ore into the attached forge bin, then hold E to smelt." if job.kind == "forge" else "Wrong or duplicate ingredient for this station recipe.")
	workshop_changed.emit()
	items_changed.emit()
	feedback_requested.emit(context.player_id, message)
	return true

func try_cycle(context: CONTEXT) -> bool:
	if context.action != &"cycle_storage": return false
	var id := station(context)
	if id == -1: return false
	if workshop.stations[id].kind == "anvil":
		var job = workshop.stations[id].job
		var next: String = JOB.ANVIL_RECIPES[(JOB.ANVIL_RECIPES.find(job.recipe) + 1) % JOB.ANVIL_RECIPES.size()]
		if job.select(next): workshop_changed.emit()
		return true
	if workshop.stations[id].kind not in WORKSHOP.STORAGE: return false
	if workshop.cycle_storage(context.player_id, context.position, items, id): workshop_changed.emit()
	return true

func catch_item(piece: int, body: RigidBody2D) -> bool:
	if not items.is_loose(piece) or body.linear_velocity.y < 0: return false
	for id in workshop.stations:
		if not views.has(id): continue
		var entry: Dictionary = workshop.stations[id]
		var caught := false
		if entry.kind in WORKSHOP.STORAGE and WORKSHOP.STORAGE[entry.kind].group == "intermediate" and views[id].get_node("PartsCatch").overlaps_body(body):
			caught = workshop.catch_intermediate(id, piece, items)
		elif entry.kind == "forge" and views[id].get_node("BinCatch").overlaps_body(body):
			caught = entry.job.store_ore(piece, items)
		if caught:
			workshop_changed.emit()
			return true
	return false

func bind_workers(actors: Dictionary, held: Dictionary, skills: RefCounted, veins: Dictionary, simulate: bool) -> void:
	players = actors
	work_held = held
	progression = skills
	mine_veins = veins
	authoritative = simulate

func available(id: int) -> bool:
	var dwarf = players[id]
	return work_held.get(id, false) and not workshop.pending.has(id) and not dwarf.transport_locked and dwarf.is_on_floor() and not dwarf.climbing and dwarf.hit_stun == 0 and dwarf.controls.is_zero_approx() and not dwarf.jump_held and items.carried_by(id) == -1

func forget_actor(id: int) -> void:
	for entry in workshop.stations.values():
		if entry.job.diner == id:
			for piece in entry.job.slots.values():
				items.pieces[piece].consumed = true
				items.pieces[piece].processing = false
			entry.job.slots.clear()
			entry.job.progress = 0
			entry.job.worker = 0
			entry.job.diner = 0

func step_workstations(delta: float) -> void:
	if not authoritative: return
	var changed := false
	for station_id in workshop.stations:
		var entry: Dictionary = workshop.stations[station_id]
		if entry.kind in WORKSHOP.STORAGE or entry.kind in WORKSHOP.CARE:
			continue
		var eligible: Array[int] = []
		for id in players:
			if available(id) and needs.working(id) > 0 and workshop.nearest(players[id].position) == station_id:
				eligible.append(id)
		eligible.sort()
		var worker: int = entry.job.worker if entry.job.worker in eligible else (eligible[0] if not eligible.is_empty() else 0)
		var specialty := "woodworking" if entry.kind == "woodbench" else "smithing"
		var before: float = entry.job.progress
		var output: int = entry.job.step(delta * progression.speed(worker, specialty) * needs.working(worker), eligible, items)
		if worker != 0 and (entry.job.progress > before or output != -1): needs.exert(worker, delta)
		if output != -1:
			experience_requested.emit(worker, "crafting")
			output_ready.emit(output, entry.at + Vector2(28, -18))
			changed = true
	if changed: production_completed.emit()

func step_mining(delta: float) -> void:
	if not authoritative: return
	for vein in mine_veins:
		var job = mine_veins[vein]
		var eligible: Array[int] = []
		if cycle.phase == "shop":
			for id in players:
				if available(id) and needs.working(id) > 0 and find_vein.call(players[id].position) == vein:
					eligible.append(id)
		eligible.sort()
		var worker: int = job.worker if job.worker in eligible else (eligible[0] if not eligible.is_empty() else 0)
		var before: float = job.progress
		var finished: bool = job.step(delta * progression.speed(worker, "mining") * needs.working(worker), eligible)
		if worker != 0 and (job.progress > before or finished): needs.exert(worker, delta)
		if finished:
			experience_requested.emit(worker, "mining")
			var piece_id: int = items.add_mined_ore()
			var output: Vector2 = MAP.VEINS[vein] + Vector2(-46, -12)
			output_ready.emit(piece_id, output)
			mining_completed.emit()

func care_eligible(id: int, station: int) -> bool:
	return available(id) and workshop.nearest(players[id].position) == station

func step_care(delta: float) -> void:
	if not authoritative: return
	var changed := false
	for station in workshop.stations:
		var entry: Dictionary = workshop.stations[station]
		if entry.kind not in WORKSHOP.CARE: continue
		var eligible: Array[int] = []
		for id in players:
			if care_eligible(id, station) and (entry.kind == "bed" and needs.dwarfs[id].energy < 100 or entry.kind == "dining" and entry.job.diner == id and needs.dwarfs[id].food < 100): eligible.append(id)
		eligible.sort()
		var job = entry.job
		job.worker = job.worker if job.worker in eligible else (eligible[0] if not eligible.is_empty() else 0)
		if job.worker == 0: continue
		if entry.kind == "bed":
			needs.change(job.worker, NEEDS.SLEEP_RATE * delta, 0)
		elif job.slots.has("food"):
			var rate: float = NEEDS.MEAL_FOOD / NEEDS.MEAL_DURATION
			var elapsed := minf(delta, minf(NEEDS.MEAL_DURATION - job.progress, (100 - needs.dwarfs[job.worker].food) / rate))
			needs.change(job.worker, 0, elapsed * rate)
			job.progress += elapsed
			if job.progress >= NEEDS.MEAL_DURATION - 0.00001 or needs.dwarfs[job.worker].food >= 100 - 0.00001:
				items.pieces[job.slots.food].processing = false
				items.pieces[job.slots.food].consumed = true
				job.slots.clear()
				job.diner = 0
				job.worker = 0
				job.progress = 0
				changed = true
	if changed: items_changed.emit()
