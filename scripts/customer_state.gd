extends RefCounted
## Front-only service: decide within 10 seconds, then fulfill within 30 seconds.
const FIRST_VISIT := 8.0
const ARRIVAL_INTERVAL := 20.0
const DECISION_TIME := 10.0
const PATIENCE := 30.0
const WALK_TIME := 2.0
const PRICES := {"horseshoe": 10, "sword": 15, "axe": 25}
const PRODUCTS := ["horseshoe", "sword", "axe"]
const REJECT_PENALTY := 3
const FAIL_PENALTY := 6
const SUCCESS_REWARD := 2
var queue: Array = []
var departures: Array = []
var until_arrival := FIRST_VISIT
var number := 0
var completed := 0
var missed := 0
var rejected := 0
var unanswered := 0
var coins := 100
var reputation := 0

func at_counter(player: int, at: Vector2) -> bool:
	return player > 0 and at.is_finite() and absf(at.x - 166) <= 30 and absf(at.y - 216) <= 6

func step(delta: float) -> void:
	# Process each clock boundary so large steps agree with normal physics ticks.
	var left := maxf(0, delta)
	while left > 0.000001:
		var advance := minf(left, until_arrival)
		var ticking := false
		if not queue.is_empty():
			var first: Dictionary = queue[0]
			ticking = first.accepted or first.age >= WALK_TIME - 0.000001
			advance = minf(advance, first.remaining if ticking else WALK_TIME - first.age)
		for departure in departures:
			departure.remaining -= advance
		departures = departures.filter(func(entry): return entry.remaining > 0)
		if ticking:
			queue[0].remaining -= advance
		for order in queue:
			order.age += advance
		until_arrival -= advance
		left -= advance
		if not queue.is_empty() and queue[0].remaining <= 0.000001:
			var expired: Dictionary = queue.pop_front()
			if expired.accepted:
				missed += 1
				reputation -= FAIL_PENALTY
				depart(expired, 0, false, "failed")
			else:
				rejected += 1
				unanswered += 1
				reputation -= REJECT_PENALTY
				depart(expired, 0, false, "unanswered")
		if until_arrival <= 0.000001:
			number += 1
			queue.append({"id": number, "kind": PRODUCTS[(number - 1) % PRODUCTS.size()], "remaining": DECISION_TIME, "age": 0.0, "accepted": false})
			until_arrival += ARRIVAL_INTERVAL

func depart(order: Dictionary, index: int, served: bool, reason: String = "fulfilled") -> void:
	departures.append({"id": order.id, "kind": order.kind, "remaining": WALK_TIME, "served": served, "reason": reason, "x": 120.0 - index * 20})

func decide(player: int, at: Vector2, order_id: int, accept: bool, rejection_cost: int = REJECT_PENALTY) -> bool:
	if not at_counter(player, at) or queue.is_empty():
		return false
	var first: Dictionary = queue[0]
	if first.id != order_id or first.accepted or first.age < WALK_TIME or first.remaining <= 0:
		return false
	if accept:
		first.accepted = true
		first.remaining = PATIENCE
	else:
		queue.pop_front()
		rejected += 1
		reputation -= rejection_cost
		depart(first, 0, false, "rejected")
	return true

func deliver(player: int, at: Vector2, materials: RefCounted, sale_multiplier: float = 1.0) -> bool:
	if not at_counter(player, at) or queue.is_empty():
		return false
	var first: Dictionary = queue[0]
	if not first.accepted or first.remaining <= 0:
		return false
	var piece: int = materials.carried_by(player)
	if piece == -1 or materials.pieces[piece].kind != first.kind:
		return false
	materials.release_carrier(player)
	materials.pieces[piece].delivered = true
	coins += ceili(PRICES[first.kind] * sale_multiplier - 0.000001)
	completed += 1
	reputation += SUCCESS_REWARD
	depart(first, 0, true)
	queue.pop_front()
	return true

func snapshot() -> Dictionary:
	return {"queue": queue.duplicate(true), "departures": departures.duplicate(true), "until_arrival": until_arrival, "number": number, "completed": completed, "missed": missed, "rejected": rejected, "unanswered": unanswered, "coins": coins, "reputation": reputation}

func restore(state: Dictionary) -> void:
	queue = state.queue.duplicate(true)
	departures = state.departures.duplicate(true)
	until_arrival = state.until_arrival
	number = state.number
	completed = state.completed
	missed = state.missed
	rejected = state.rejected
	unanswered = state.unanswered
	coins = state.coins
	reputation = state.reputation
