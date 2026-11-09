extends SceneTree
const ORE = preload("res://scripts/ore_state.gd")
const ORDERS = preload("res://scripts/customer_state.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if ok:
		print("PASS orders: ", message)
	else:
		failures += 1
		push_error(message)
func _initialize() -> void:
	var ore = ORE.new()
	var orders = ORDERS.new()
	orders.step(7.9)
	check(orders.queue.is_empty() and orders.coins == 20, "Start with 20 coins and delayed first arrival")
	orders.step(0.1)
	orders.step(20)
	check(orders.queue.size() == 2 and orders.queue[0].kind == "hammer" and orders.queue[1].kind == "sword", "Customers arrive every 20 seconds even with a waiting order")
	ore.pieces[0].kind = "sword"
	ore.pickup(1, 0)
	check(not orders.deliver(1, Vector2(166, 216), ore) and ore.carried_by(1) == 0, "Cannot skip front hammer order to deliver queued sword")
	ore.pieces[0].kind = "hammer"
	check(not orders.deliver(1, Vector2(166, 288), ore) and not orders.deliver(1, Vector2(260, 216), ore), "Counter range and floor are authoritative")
	check(orders.deliver(1, Vector2(166, 216), ore) and orders.coins == 30 and orders.reputation == 1 and orders.completed == 1, "Correct front delivery rewards coins and reputation")
	ore.pieces[1].kind = "hammer"
	ore.pickup(2, 1)
	check(not orders.deliver(2, Vector2(166, 216), ore) and ore.carried_by(2) == 1 and orders.completed == 1, "Competing delivery cannot duplicate reward or consume wrong item")
	check(not ore.pickup(3, 0) and ore.pieces[0].delivered, "Sold product cannot be picked up again")
	orders.step(29.99)
	check(orders.missed == 0 and orders.queue[0].remaining > 0, "Queued customer retains only its original arrival-based patience")
	orders.step(0.01)
	check(orders.missed == 1 and orders.reputation == 0 and orders.coins == 30, "Expiry at 30 seconds costs reputation once and no coins")
	check(orders.queue[0].kind == "axe", "Expired front leaves and exposes next specific item")
	var copy = ORDERS.new()
	copy.restore(orders.snapshot())
	orders.queue[0].kind = "hammer"
	check(copy.queue[0].kind == "axe" and copy.reputation == 0 and copy.coins == 30, "Snapshot preserves independent queue, economy, and reputation")
	var a = ORDERS.new()
	var b = ORDERS.new()
	a.step(100)
	for i in range(1000):
		b.step(0.1)
	check(a.number == b.number and a.missed == b.missed and a.reputation == b.reputation and a.queue.size() == b.queue.size(), "Large and small clock steps preserve arrivals and expiry counts")
	print("ORDERS RESULT: ", failures, " failures")
	quit(1 if failures else 0)
