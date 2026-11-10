extends RefCounted
const DURATION := 5.0
const ANVIL_RECIPES := ["horseshoe", "blade", "head", "axe"]
const INPUTS := {"horseshoe": ["ore"], "blade": ["ore"], "head": ["ore"], "axe": ["axe_head", "shaft"], "sharpen": ["dull_sword"], "shaft": ["wood"], "smelt": ["ore"]}
const OUTPUTS := {"horseshoe": "horseshoe", "blade": "dull_sword", "head": "axe_head", "axe": "axe", "sharpen": "sword", "shaft": "shaft", "smelt": "ingot"}
var kind := "anvil"
var recipe := "horseshoe"
var slots: Dictionary = {}
var progress := 0.0
var worker := 0
var ore_queue: Array[int] = []

func configure(value: String) -> void:
	kind = value
	recipe = "smelt" if kind == "forge" else ("sharpen" if kind == "grinder" else ("shaft" if kind == "woodbench" else "horseshoe"))

func select(choice: String) -> bool:
	if kind != "anvil" or choice not in ANVIL_RECIPES or not slots.is_empty():
		return false
	recipe = choice
	return true

func load_material(player: int, materials: RefCounted) -> bool:
	if player <= 0 or kind == "forge":
		return false
	var id: int = materials.carried_by(player)
	if id == -1:
		return false
	var ingredient: String = materials.pieces[id].kind
	if kind == "anvil" and ingredient == "ingot":
		ingredient = "ore"
	if ingredient not in INPUTS[recipe] or slots.has(ingredient):
		return false
	materials.release_carrier(player)
	materials.pieces[id].processing = true
	slots[ingredient] = id
	return true

func ready() -> bool:
	for ingredient in INPUTS[recipe]:
		if not slots.has(ingredient):
			return false
	return true

func step(delta: float, eligible: Array[int], materials: RefCounted) -> int:
	if worker not in eligible:
		worker = eligible[0] if not eligible.is_empty() else 0
	if kind == "forge" and worker != 0 and slots.is_empty() and not ore_queue.is_empty():
		slots["ore"] = ore_queue.pop_front()
	if worker == 0 or not ready():
		worker = 0
		return -1
	progress = minf(DURATION, progress + delta)
	if progress < DURATION - 0.00001:
		return -1
	var primary: int = slots[INPUTS[recipe][0]]
	for id in slots.values():
		materials.pieces[id].processing = false
		if id != primary:
			materials.pieces[id].consumed = true
	materials.pieces[primary].kind = OUTPUTS[recipe]
	slots.clear()
	progress = 0.0
	worker = 0
	return primary

func snapshot() -> Dictionary:
	return {"kind": kind, "recipe": recipe, "slots": slots.duplicate(), "progress": progress, "worker": worker, "ore_queue": ore_queue.duplicate()}

func restore(state: Dictionary) -> void:
	kind = state.kind
	recipe = state.recipe
	slots = state.slots.duplicate()
	progress = state.progress
	worker = state.worker
	ore_queue.assign(state.ore_queue)

func store_ore(id: int, materials: RefCounted) -> bool:
	if kind != "forge" or not materials.is_loose(id) or materials.pieces[id].kind != "ore":
		return false
	materials.pieces[id].processing = true
	ore_queue.append(id)
	return true
