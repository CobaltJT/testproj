extends RefCounted
## Individual interaction methods can be ordered independently of this controller.
const CONTEXT = preload("res://scripts/interaction/context.gd")
const WORKSHOP = preload("res://scripts/workshop_state.gd")
const JOB = preload("res://scripts/station_job.gd")
signal items_changed
signal workshop_changed
signal feedback_requested(id: int, message: String)
var workshop: RefCounted
var items: RefCounted
var needs: RefCounted
var cycle: RefCounted
var find_vein: Callable

func bind(stations: RefCounted, inventory: RefCounted, vitals: RefCounted, day: RefCounted, mining_query: Callable) -> void:
	workshop = stations
	items = inventory
	needs = vitals
	cycle = day
	find_vein = mining_query

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
