extends RefCounted
## Host-owned, session-local needs. Rates are percentage points per real second.
const ENERGY_DRAIN := 0.1
const FOOD_DRAIN := 0.08
const WORK_ENERGY := 1.0
const WORK_FOOD := 0.5
const SLEEP_RATE := 12.0
const MEAL_FOOD := 40.0
const MEAL_DURATION := 5.0
var dwarfs: Dictionary = {}
func add(id: int) -> void:
	if id > 0 and not dwarfs.has(id): dwarfs[id] = {"energy": 100.0, "food": 100.0}
func change(id: int, energy: float, food: float) -> void:
	if not dwarfs.has(id): return
	dwarfs[id].energy = clampf(dwarfs[id].energy + energy, 0, 100)
	dwarfs[id].food = clampf(dwarfs[id].food + food, 0, 100)
func step(delta: float) -> void:
	for id in dwarfs: change(id, -ENERGY_DRAIN * maxf(0, delta), -FOOD_DRAIN * maxf(0, delta))
func exert(id: int, delta: float) -> void:
	change(id, -WORK_ENERGY * maxf(0, delta), -WORK_FOOD * maxf(0, delta))
func level(id: int) -> float:
	return minf(dwarfs[id].energy, dwarfs[id].food) if dwarfs.has(id) else 100.0
func walking(id: int) -> float:
	return 0.4 if level(id) <= 0 else (0.7 if level(id) < 10 else 1.0)
func working(id: int) -> float:
	return 0.0 if level(id) <= 0 else (0.5 if level(id) < 10 else 1.0)
func snapshot() -> Dictionary: return dwarfs.duplicate(true)
func restore(state: Dictionary) -> void: dwarfs = state.duplicate(true)
