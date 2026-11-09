extends RefCounted
## Host-only queue. Patience starts on arrival, including time behind others.
const FIRST_VISIT := 8.0
const ARRIVAL_INTERVAL := 20.0
const PATIENCE := 30.0
const WALK_TIME := 2.0
const PRICES := {"horseshoe": 10, "sword": 15, "axe": 25}
const PRODUCTS := ["horseshoe", "sword", "axe"]
var queue: Array = []
var departures: Array = []
var until_arrival := FIRST_VISIT
var number := 0
var completed := 0
var missed := 0
var coins := 100
var reputation := 0

func step(delta: float) -> void:
	# Advance through event boundaries, preserving the schedule even after a long frame.
	var left := maxf(0, delta)
	while left > 0.000001:
		var advance := minf(left, until_arrival)
		for order in queue:
			advance = minf(advance, order.remaining)
		for departure in departures:
			departure.remaining -= advance
		departures = departures.filter(func(entry): return entry.remaining > 0)
		for order in queue:
			order.remaining -= advance
			order.age += advance
		until_arrival -= advance
		left -= advance
		for i in range(queue.size() - 1, -1, -1):
			if queue[i].remaining <= 0.000001:
				depart(queue[i], i, false)
				queue.remove_at(i)
				missed += 1
				reputation -= 1
		if until_arrival <= 0.000001:
			number += 1
			queue.append({"id": number, "kind": PRODUCTS[(number - 1) % PRODUCTS.size()], "remaining": PATIENCE, "age": 0.0})
			until_arrival += ARRIVAL_INTERVAL

func depart(order: Dictionary, index: int, served: bool) -> void:
	departures.append({"id": order.id, "kind": order.kind, "remaining": WALK_TIME, "served": served, "x": 120.0 - index * 20})

func deliver(player: int, at: Vector2, materials: RefCounted) -> bool:
	if player <= 0 or queue.is_empty() or absf(at.x - 166) > 30 or absf(at.y - 216) > 6:
		return false
	var first: Dictionary = queue[0]
	if first.age < WALK_TIME or first.remaining <= 0:
		return false
	var piece: int = materials.carried_by(player)
	if piece == -1 or materials.pieces[piece].kind != first.kind:
		return false
	materials.release_carrier(player)
	materials.pieces[piece].delivered = true
	coins += PRICES[first.kind]
	completed += 1
	reputation += 1
	depart(first, 0, true)
	queue.pop_front()
	return true

func snapshot() -> Dictionary:
	return {"queue": queue.duplicate(true), "departures": departures.duplicate(true), "until_arrival": until_arrival, "number": number, "completed": completed, "missed": missed, "coins": coins, "reputation": reputation}

func restore(state: Dictionary) -> void:
	queue = state.queue.duplicate(true)
	departures = state.departures.duplicate(true)
	until_arrival = state.until_arrival
	number = state.number
	completed = state.completed
	missed = state.missed
	coins = state.coins
	reputation = state.reputation
