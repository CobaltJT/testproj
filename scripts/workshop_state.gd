extends RefCounted
const JOB = preload("res://scripts/station_job.gd")
const PRICES := {"anvil": 20, "grinder": 25, "woodbench": 25, "forge": 25, "intermediate_small": 10, "intermediate_medium": 20, "intermediate_large": 35, "finished_small": 10, "finished_medium": 20, "finished_large": 35}
const STORAGE := {
	"intermediate_small": {"capacity": 5, "group": "intermediate", "size": "Small"},
	"intermediate_medium": {"capacity": 15, "group": "intermediate", "size": "Medium"},
	"intermediate_large": {"capacity": 30, "group": "intermediate", "size": "Large"},
	"finished_small": {"capacity": 5, "group": "finished", "size": "Small"},
	"finished_medium": {"capacity": 15, "group": "finished", "size": "Medium"},
	"finished_large": {"capacity": 30, "group": "finished", "size": "Large"}
}
const STORAGE_PRODUCTS := {"intermediate": ["ingot", "dull_sword", "axe_head", "shaft"], "finished": ["horseshoe", "sword", "axe"]}

static func display_name(kind: String) -> String:
	if kind in STORAGE:
		return "%s · %s (%s items)" % [STORAGE[kind].group.capitalize(), STORAGE[kind].size, STORAGE[kind].capacity]
	return "Forge + bin" if kind == "forge" else kind.capitalize()

const MAP = preload("res://scripts/map_layout.gd")
const FLOORS = MAP.FLOORS
var stations: Dictionary = {}
var pending: Dictionary = {}
var next_id := 1
var opened := false

func snap(at: Vector2) -> Vector2:
	var floor_y: float = FLOORS[0]
	for y in FLOORS:
		if absf(at.y - y) < absf(at.y - floor_y):
			floor_y = y
	return Vector2(snappedf(at.x, 8), floor_y)

func footprint(at: Vector2) -> Rect2:
	return Rect2(at + Vector2(-24, -40), Vector2(64, 40))

func can_place(at: Vector2) -> bool:
	if not at.is_finite() or at.y not in FLOORS or not is_equal_approx(at.x, snappedf(at.x, 8)):
		return false
	var rect := footprint(at)
	if rect.position.x < 52 or rect.end.x > MAP.RIGHT_WALL - 4:
		return false
	# Keep the storefront, merchant, ladders, landing space, and mine usable.
	var blocked: Array[Rect2] = []
	if at.y == 136:
		blocked = [Rect2(344, 96, 48, 40)]
	elif at.y == 216:
		blocked = [Rect2(52, 176, 172, 40), Rect2(344, 176, 48, 40)]
	else:
		blocked = [Rect2(88, 248, 48, 40), Rect2(328, 248, 100, 40)]
	for zone in blocked:
		if rect.intersects(zone):
			return false
	for station in stations.values():
		if rect.intersects(footprint(station.at).grow(2)):
			return false
	return true

func purchase(player: int, kind: String, economy: RefCounted, materials: RefCounted, price_multiplier: float = 1.0) -> bool:
	if kind not in PRICES:
		return false
	var cost := maxi(1, ceili(PRICES[kind] * price_multiplier - 0.000001))
	if player <= 0 or kind not in PRICES or pending.has(player) or materials.carried_by(player) != -1 or economy.coins < cost:
		return false
	economy.coins -= cost
	economy.spent += cost
	pending[player] = {"id": next_id, "kind": kind, "paid": cost}
	next_id += 1
	return true

func place(player: int, at: Vector2) -> int:
	if not pending.has(player) or not can_place(at):
		return -1
	var kit: Dictionary = pending[player]
	var job = JOB.new()
	job.configure(kit.kind)
	stations[kit.id] = {"kind": kit.kind, "at": at, "job": job, "paid": kit.paid, "items": [], "selected": ""}
	pending.erase(player)
	if kit.kind == "anvil":
		opened = true
	return kit.id

func cancel(player: int, economy: RefCounted) -> bool:
	if not pending.has(player):
		return false
	economy.coins += pending[player].paid
	economy.refunds += pending[player].paid
	pending.erase(player)
	return true

func nearest(at: Vector2) -> int:
	for id in stations:
		if absf(at.x - stations[id].at.x) <= 22 and absf(at.y - stations[id].at.y) <= 6:
			return id
	return -1

func pack(player: int, at: Vector2, materials: RefCounted) -> bool:
	var id := nearest(at)
	if player <= 0 or id == -1 or pending.has(player) or materials.carried_by(player) != -1 or not stations[id].job.slots.is_empty() or not stations[id].job.ore_queue.is_empty() or not stations[id].items.is_empty():
		return false
	pending[player] = {"id": id, "kind": stations[id].kind, "paid": stations[id].paid, "items": stations[id].items.duplicate(), "selected": stations[id].selected}
	stations.erase(id)
	return true

func snapshot() -> Dictionary:
	var result: Dictionary = {}
	for id in stations:
		result[id] = {"kind": stations[id].kind, "at": stations[id].at, "job": stations[id].job.snapshot(), "paid": stations[id].paid, "items": stations[id].items.duplicate(), "selected": stations[id].selected}
	return {"stations": result, "pending": pending.duplicate(true), "next_id": next_id, "opened": opened}

func restore(state: Dictionary) -> void:
	stations.clear()
	for id in state.stations:
		var entry: Dictionary = state.stations[id]
		var job = JOB.new()
		job.restore(entry.job)
		stations[id] = {"kind": entry.kind, "at": entry.at, "job": job, "paid": entry.paid, "items": entry.items.duplicate(), "selected": entry.selected}
	pending = state.pending.duplicate(true)
	next_id = state.next_id
	opened = state.opened

func storage_transfer(player: int, at: Vector2, materials: RefCounted) -> bool:
	var id := nearest(at)
	if player <= 0 or id == -1 or pending.has(player) or stations[id].kind not in STORAGE:
		return false
	var entry: Dictionary = stations[id]
	var definition: Dictionary = STORAGE[entry.kind]
	var carried: int = materials.carried_by(player)
	if carried != -1:
		if entry.items.size() >= definition.capacity or materials.pieces[carried].kind not in STORAGE_PRODUCTS[definition.group]:
			return false
		materials.release_carrier(player)
		materials.pieces[carried].processing = true
		entry.items.append(carried)
		if entry.selected == "": entry.selected = materials.pieces[carried].kind
		return true
	if entry.items.is_empty():
		return false
	for piece in entry.items:
		if materials.pieces[piece].kind != entry.selected:
			continue
		materials.pieces[piece].processing = false
		if not materials.pickup(player, piece):
			materials.pieces[piece].processing = true
			return false
		entry.items.erase(piece)
		var kinds := stored_kinds(id, materials)
		if entry.selected not in kinds: entry.selected = kinds[0] if not kinds.is_empty() else ""
		return true
	return false

func stored_kinds(id: int, materials: RefCounted) -> Array:
	var result: Array = []
	for piece in stations[id].items:
		var kind: String = materials.pieces[piece].kind
		if kind not in result: result.append(kind)
	return result

func cycle_storage(player: int, at: Vector2, materials: RefCounted) -> bool:
	var id := nearest(at)
	if player <= 0 or id == -1 or pending.has(player) or stations[id].kind not in STORAGE:
		return false
	var kinds := stored_kinds(id, materials)
	if kinds.is_empty(): return false
	var entry: Dictionary = stations[id]
	entry.selected = kinds[(kinds.find(entry.selected) + 1) % kinds.size()]
	return true

func catch_intermediate(id: int, piece: int, materials: RefCounted) -> bool:
	if not stations.has(id) or stations[id].kind not in STORAGE or STORAGE[stations[id].kind].group != "intermediate" or not materials.is_loose(piece):
		return false
	var entry: Dictionary = stations[id]
	if entry.items.size() >= STORAGE[entry.kind].capacity or materials.pieces[piece].kind not in STORAGE_PRODUCTS.intermediate:
		return false
	materials.pieces[piece].processing = true
	entry.items.append(piece)
	if entry.selected == "": entry.selected = materials.pieces[piece].kind
	return true
