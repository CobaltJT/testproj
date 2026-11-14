extends SceneTree
const ORE = preload("res://scripts/ore_state.gd")
const ORDERS = preload("res://scripts/customer_state.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if ok: print("PASS orders: ", message)
	else:
		failures += 1
		push_error(message)
func _initialize() -> void:
	var ore = ORE.new()
	var orders = ORDERS.new()
	var counter := Vector2(166, 216)
	orders.until_arrival = 1
	orders.step(1)
	orders.queue[0].kind = "horseshoe"
	orders.until_arrival = 1
	orders.step(1)
	check(orders.queue.size() == 2 and orders.queue[0].remaining == 9 and orders.queue[1].remaining == 10, "Decision timers start immediately on arrival, including walking and queuing")
	check(orders.decide(2, Vector2(500, 528), 2, true) and orders.queue[1].remaining == 30, "Any queued request can be accepted remotely from its card")
	check(not orders.decide(3, counter, 2, true) and not orders.decide(0, counter, 1, true), "Duplicate accept cannot reset deadline; invalid player cannot decide")
	check(orders.decide(1, counter, 1, true), "Front request can also be accepted while walking")
	ore.pieces[0].kind = "horseshoe"
	ore.pickup(1, 0)
	check(not orders.deliver(1, counter, ore), "First customer must reach counter before delivery")
	orders.step(1, false)
	check(orders.queue[0].remaining == 29 and orders.queue[1].remaining == 29, "Accepted deadlines tick for all queued customers")
	ore.pieces[0].kind = "sword"
	orders.queue[1].kind = "sword"
	check(not orders.deliver(1, counter, ore) and ore.carried_by(1) == 0, "Delivery cannot skip first customer")
	ore.pieces[0].kind = "horseshoe"
	check(not orders.deliver(1, Vector2(166, 288), ore), "Delivery still requires counter proximity")
	check(orders.deliver(1, counter, ore) and orders.reputation == 2 and orders.coins == 110, "Front delivery pays and rewards reputation")
	check(not orders.deliver(1, counter, ore), "Sold product cannot reward twice")
	orders.reputation = 20
	check(orders.decide(2, Vector2(500, 528), 2, false, 1) and orders.missed == 1 and orders.rejected == 0 and orders.reputation == 14, "Rejecting accepted queued request counts as failure for six reputation, ignoring rejection discounts")
	check(not orders.decide(3, counter, 2, false) and orders.reputation == 14, "Stale rejection cannot charge twice")
	orders.queue = [{"id": 3, "kind": "axe", "remaining": 30.0, "age": 2.0, "accepted": true}, {"id": 4, "kind": "sword", "remaining": 5.0, "age": 1.0, "accepted": false}, {"id": 5, "kind": "horseshoe", "remaining": 8.0, "age": 1.0, "accepted": true}]
	orders.step(8, false)
	check(orders.queue.size() == 1 and orders.queue[0].id == 3 and orders.queue[0].remaining == 22, "Queued pending and accepted orders expire independently behind front")
	check(orders.unanswered == 1 and orders.rejected == 1 and orders.missed == 2 and orders.reputation == 5, "Unanswered costs three and accepted timeout costs six once each")
	orders.queue.append({"id": 6, "kind": "axe", "remaining": 10.0, "age": 0.0, "accepted": false})
	check(orders.decide(1, counter, 6, false, 1) and orders.reputation == 4, "Unaccepted rejection keeps its skill discount even while walking or queued")
	var copy = ORDERS.new()
	copy.restore(orders.snapshot())
	check(copy.missed == 2 and copy.rejected == 2 and copy.queue[0].remaining == 22 and copy.coins == 110, "Snapshot preserves independent queue clocks and outcomes")
	var a = ORDERS.new()
	var b = ORDERS.new()
	a.seed_rng(12345)
	b.seed_rng(12345)
	a.step(100)
	for i in range(1000): b.step(0.1)
	check(a.number == b.number and a.reputation == b.reputation and a.unanswered == b.unanswered and a.rng.state == b.rng.state, "Large and small clock steps agree for arrival-based deadlines")
	var floor_test = ORDERS.new()
	for accepted in [false, true]:
		for start_rep in [0, 1, 5]:
			floor_test.reputation = start_rep
			floor_test.queue = [{"id": 1, "kind": "axe", "remaining": 1.0, "age": 2.0, "accepted": accepted}]
			floor_test.decide(1, counter, 1, false)
			check(floor_test.reputation == maxi(0, start_rep - (6 if accepted else 3)), "Rejection/failure clamps at zero: %s, %s" % [accepted, start_rep])
			floor_test.reputation = start_rep
			floor_test.queue = [{"id": 1, "kind": "axe", "remaining": 1.0, "age": 2.0, "accepted": accepted}]
			floor_test.step(1, false)
			check(floor_test.reputation == maxi(0, start_rep - (6 if accepted else 3)), "Expiry clamps at zero: %s, %s" % [accepted, start_rep])
	var old_state: Dictionary = floor_test.snapshot()
	old_state.reputation = -50
	floor_test.restore(old_state)
	check(floor_test.reputation == 0 and floor_test.snapshot().reputation == 0, "Restoring negative reputation clamps synchronized state")
	floor_test.reputation += 2
	check(floor_test.reputation == 2, "Reputation can grow immediately after hitting zero")
	print("ORDERS RESULT: ", failures, " failures")
	quit(1 if failures else 0)
