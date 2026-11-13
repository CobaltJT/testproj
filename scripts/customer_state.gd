extends RefCounted
## Arrival-based queue deadlines, remote decisions, and front-only delivery.
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
var rng := RandomNumberGenerator.new()
var until_arrival := 0.0
var number := 0
var completed := 0
var missed := 0
var rejected := 0
var unanswered := 0
var earned := 0
var spent := 0
var refunds := 0
var coins := 100
var reputation := 0

func _init() -> void:
	rng.randomize()
	reset_arrival()

func difficulty_tier() -> int:
	return clampi(floori(maxi(0, reputation) / 10.0), 0, 9)

func max_quantity() -> int:
	return 1 + difficulty_tier()

func arrival_range() -> Vector2:
	var tier := difficulty_tier()
	return Vector2(18.0 - 1.3 * tier, 26.0 - 1.8 * tier)

func reset_arrival() -> void:
	var interval := arrival_range()
	until_arrival = rng.randf_range(interval.x, interval.y)

func seed_rng(value: int) -> void:
	rng.seed = value
	reset_arrival()

func at_counter(player: int, at: Vector2) -> bool:
	return player > 0 and at.is_finite() and absf(at.x - 166) <= 30 and absf(at.y - 216) <= 6

func step(delta: float, arrivals: bool = true) -> void:
	# Process each clock boundary so large steps agree with normal physics ticks.
	var left := maxf(0, delta)
	while left > 0.000001:
		var advance := minf(left, until_arrival) if arrivals else left
		for order in queue:
			advance = minf(advance, order.remaining)
		for departure in departures:
			departure.remaining -= advance
		departures = departures.filter(func(entry): return entry.remaining > 0)
		for order in queue:
			order.age += advance
			order.remaining -= advance
		if arrivals:
			until_arrival -= advance
		left -= advance
		for index in range(queue.size() - 1, -1, -1):
			if queue[index].remaining > 0.000001: continue
			var expired: Dictionary = queue[index]
			queue.remove_at(index)
			if expired.accepted:
				missed += 1
				reputation -= FAIL_PENALTY
				depart(expired, index, false, "failed")
			else:
				rejected += 1
				unanswered += 1
				reputation -= REJECT_PENALTY
				depart(expired, index, false, "unanswered")
		if arrivals and until_arrival <= 0.000001:
			number += 1
			queue.append({"id": number, "kind": PRODUCTS[rng.randi_range(0, PRODUCTS.size() - 1)], "remaining": DECISION_TIME, "age": 0.0, "accepted": false, "quantity": rng.randi_range(1, max_quantity()), "delivered": 0})
			reset_arrival()

func depart(order: Dictionary, index: int, served: bool, reason: String = "fulfilled") -> void:
	departures.append({"id": order.id, "kind": order.kind, "remaining": WALK_TIME, "served": served, "reason": reason, "x": lerpf(70, 120.0 - index * 20, minf(1, order.age / WALK_TIME))})

func decide(player: int, at: Vector2, order_id: int, accept: bool, rejection_cost: int = REJECT_PENALTY) -> bool:
	if player <= 0 or not at.is_finite(): return false
	for index in range(queue.size()):
		var order: Dictionary = queue[index]
		if order.id != order_id: continue
		if order.remaining <= 0 or accept and order.accepted: return false
		if accept:
			order.accepted = true
			order.remaining = PATIENCE
		else:
			queue.remove_at(index)
			if order.accepted:
				missed += 1
				reputation -= FAIL_PENALTY
				depart(order, index, false, "failed")
			else:
				rejected += 1
				reputation -= rejection_cost
				depart(order, index, false, "rejected")
		return true
	return false

func deliver(player: int, at: Vector2, materials: RefCounted, sale_multiplier: float = 1.0) -> bool:
	if not at_counter(player, at) or queue.is_empty():
		return false
	var first: Dictionary = queue[0]
	if not first.accepted or first.remaining <= 0 or first.age < WALK_TIME:
		return false
	var piece: int = materials.carried_by(player)
	if piece == -1 or materials.pieces[piece].kind != first.kind:
		return false
	materials.release_carrier(player)
	materials.pieces[piece].delivered = true
	var reward := ceili(PRICES[first.kind] * sale_multiplier - 0.000001)
	coins += reward
	earned += reward
	first.delivered = first.get("delivered", 0) + 1
	if first.delivered >= first.get("quantity", 1):
		completed += 1
		reputation += SUCCESS_REWARD
		depart(first, 0, true)
		queue.pop_front()
	return true

func snapshot() -> Dictionary:
	return {"rng_state": rng.state, "earned": earned, "spent": spent, "refunds": refunds, "queue": queue.duplicate(true), "departures": departures.duplicate(true), "until_arrival": until_arrival, "number": number, "completed": completed, "missed": missed, "rejected": rejected, "unanswered": unanswered, "coins": coins, "reputation": reputation}

func restore(state: Dictionary) -> void:
	rng.state = state.rng_state
	earned = state.earned
	spent = state.spent
	refunds = state.refunds
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
