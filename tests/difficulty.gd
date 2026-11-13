extends SceneTree
const ORDERS = preload("res://scripts/customer_state.gd")
const ORE = preload("res://scripts/ore_state.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if ok: print("PASS difficulty: ", message)
	else:
		failures += 1
		push_error(message)
func _initialize() -> void:
	var low = ORDERS.new()
	var high = ORDERS.new()
	low.seed_rng(1234)
	high.reputation = 90
	high.seed_rng(1234)
	var kinds: Dictionary = {}
	var sizes: Dictionary = {}
	var gaps: Dictionary = {}
	var last_kind := ""
	var repeated := false
	var low_total := 0.0
	var high_total := 0.0
	var low_sizes := 0
	var high_sizes := 0
	var valid := true
	for i in range(300):
		low_total += low.until_arrival
		high_total += high.until_arrival
		gaps[snappedf(high.until_arrival, 0.01)] = true
		low.step(low.until_arrival)
		high.step(high.until_arrival)
		var a: Dictionary = low.queue[0]
		var b: Dictionary = high.queue[0]
		valid = valid and a.quantity == 1 and b.quantity >= 1 and b.quantity <= 10 and a.kind in ORDERS.PRODUCTS and b.kind in ORDERS.PRODUCTS
		kinds[b.kind] = true
		sizes[b.quantity] = true
		repeated = repeated or last_kind == b.kind
		last_kind = b.kind
		low_sizes += a.quantity
		high_sizes += b.quantity
		low.queue.clear()
		high.queue.clear()
	check(valid and kinds.size() == 3 and repeated, "Random orders use all products, permit repeats and stay within quantity bounds")
	check(sizes.size() == 10 and high_sizes > low_sizes * 3, "Higher reputation produces larger orders up to ten")
	check(gaps.size() > 100 and high_total < low_total / 2, "Arrival intervals vary and high reputation increases frequency")
	low.reputation = -1000
	high.reputation = 100000
	check(low.max_quantity() == 1 and low.arrival_range() == Vector2(18, 26) and high.max_quantity() == 10 and high.arrival_range().x > 6, "Negative reputation uses starter difficulty and high reputation is capped")
	low.reputation = 10
	check(low.max_quantity() == 2, "Each ten reputation unlocks one more possible item")
	var copy = ORDERS.new()
	copy.restore(high.snapshot())
	high.step(high.until_arrival)
	copy.step(copy.until_arrival)
	check(copy.snapshot() == high.snapshot(), "Snapshot restores RNG state and reproduces the next randomized order")
	var orders = ORDERS.new()
	var ore = ORE.new()
	var counter := Vector2(166, 216)
	orders.queue = [{"id": 1, "kind": "horseshoe", "quantity": 3, "delivered": 0, "remaining": 30.0, "age": 2.0, "accepted": true}]
	for i in range(3): ore.pieces[i].kind = "horseshoe"
	ore.pickup(1, 0)
	check(orders.deliver(1, counter, ore) and orders.completed == 0 and orders.reputation == 0 and orders.coins == 110 and orders.queue[0].delivered == 1, "First partial delivery pays once without completing order or granting reputation")
	check(not orders.deliver(1, counter, ore) and orders.queue[0].delivered == 1, "Duplicate empty-handed delivery cannot advance progress")
	var partial = ORDERS.new()
	partial.restore(orders.snapshot())
	check(partial.queue[0].quantity == 3 and partial.queue[0].delivered == 1, "Partial quantities survive client snapshot")
	ore.pickup(2, 1)
	orders.deliver(2, counter, ore, 1.1)
	ore.pickup(1, 2)
	check(orders.deliver(1, counter, ore) and orders.queue.is_empty() and orders.completed == 1 and orders.reputation == 2 and orders.earned == 31, "Cooperative completion counts one request, rewards reputation once and applies each seller's bonus")
	partial.step(30, false)
	check(partial.missed == 1 and partial.reputation == -6 and partial.coins == 110, "Partial order still fails on original deadline; already delivered goods stay sold")
	var a = ORDERS.new()
	var b = ORDERS.new()
	a.reputation = 80
	b.reputation = 80
	a.seed_rng(5678)
	b.seed_rng(5678)
	a.step(100)
	for i in range(1000): b.step(0.1)
	check(a.number == b.number and a.reputation == b.reputation and a.rng.state == b.rng.state, "Large and small steps preserve randomized arrivals across reputation losses")
	print("DIFFICULTY RESULT: ", failures, " failures")
	quit(1 if failures else 0)
