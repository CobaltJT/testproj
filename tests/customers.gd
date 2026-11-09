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
	check(orders.phase == "away", "First customer does not arrive immediately")
	orders.step(0.1)
	orders.step(2)
	check(orders.phase == "waiting" and orders.number == 1, "Customer arrives and requests a hammer")
	orders.step(1000)
	check(orders.phase == "waiting", "Patient order does not expire")
	ore.pickup(1, 0)
	check(not orders.deliver(1, Vector2(166, 216), ore) and ore.carried_by(1) == 0, "Wrong item rejected without consuming it")
	ore.release_carrier(1)
	for id in [0, 1]:
		ore.pieces[id].kind = "hammer"
	ore.pickup(1, 0)
	ore.pickup(2, 1)
	check(not orders.deliver(1, Vector2(166, 288), ore), "Cannot deliver from another floor")
	check(not orders.deliver(1, Vector2(260, 216), ore), "Cannot deliver away from counter")
	check(orders.deliver(1, Vector2(166, 216), ore) and ore.pieces[0].delivered and not ore.is_loose(0), "Delivery consumes only the carried hammer")
	check(not orders.deliver(2, Vector2(166, 216), ore) and ore.carried_by(2) == 1 and orders.coins == 10 and orders.completed == 1, "Competing delivery cannot duplicate reward or consume second hammer")
	check(not ore.pickup(3, 0), "Sold hammer cannot be picked up again")
	orders.step(2)
	orders.step(15)
	orders.step(2)
	check(orders.phase == "waiting" and orders.number == 2 and orders.coins == 10, "Another customer visits after departure and interval")
	var copy = ORDERS.new()
	copy.restore(orders.snapshot())
	check(copy.phase == "waiting" and copy.number == 2 and copy.coins == 10 and copy.completed == 1, "Snapshot preserves order and shared earnings")
	print("ORDERS RESULT: ", failures, " failures")
	quit(1 if failures else 0)
