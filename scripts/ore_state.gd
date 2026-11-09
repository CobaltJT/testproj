extends RefCounted
## Mutated only by the host. All positions are smithy-local foot coordinates.
const SUPPLY := Vector2(238, 288)
const BIN := Vector2(310, 216)
const INITIAL_ORE := 8
var available := INITIAL_ORE
var deposited := 0
var carriers: Array[int] = []

func in_reach(at: Vector2, target: Vector2) -> bool:
	return absf(at.x - target.x) <= 24 and absf(at.y - target.y) <= 12

func interact(id: int, at: Vector2) -> String:
	if id in carriers:
		if not in_reach(at, BIN):
			return "Carry your ore to the forge bin on the ground floor."
		carriers.erase(id)
		deposited += 1
		return "Ore deposited!"
	if in_reach(at, SUPPLY):
		if available == 0:
			return "The ore supply is empty."
		available -= 1
		carriers.append(id)
		return "Ore picked up. Take it to the forge bin."
	if in_reach(at, BIN):
		return "Collect ore in the basement first."
	return "Move closer to the basement ore supply or forge bin."

func release_carrier(id: int) -> void:
	if id in carriers:
		carriers.erase(id)
		available += 1

func snapshot() -> Dictionary:
	return {"available": available, "deposited": deposited, "carriers": carriers.duplicate()}

func restore(state: Dictionary) -> void:
	available = state["available"]
	deposited = state["deposited"]
	carriers.assign(state["carriers"])
