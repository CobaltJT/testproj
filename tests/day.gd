extends SceneTree
const DAY = preload("res://scripts/day_state.gd")
const ORDERS = preload("res://scripts/customer_state.gd")
const MERCHANT = preload("res://scripts/merchant_state.gd")
const ORE = preload("res://scripts/ore_state.gd")
const WORKSHOP = preload("res://scripts/workshop_state.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if ok: print("PASS day: ", message)
	else:
		failures += 1
		push_error(message)
func _initialize() -> void:
	var day = DAY.new()
	var orders = ORDERS.new()
	var merchant = MERCHANT.new()
	var ore = ORE.new()
	var workshop = WORKSHOP.new()
	day.step(500, orders, merchant)
	check(day.phase == "morning" and orders.number == 0 and merchant.visits == 0, "Morning has no automatic opening, customers or merchant visits")
	workshop.purchase(1, "anvil", orders, ore, 0.9)
	workshop.cancel(1, orders)
	check(day.advance(1) and not day.advance(1), "Morning opens once; repeated button cannot skip shop hours")
	day.step(orders.until_arrival, orders, merchant)
	orders.queue[0].kind = "horseshoe"
	day.step(2, orders, merchant)
	check(orders.number == 1 and orders.decide(1, Vector2(166, 216), 1, true), "Regular hours spawn decidable requests")
	ore.pieces[0].kind = "horseshoe"
	ore.pickup(1, 0)
	orders.deliver(1, Vector2(166, 216), ore)
	orders.number = 2
	orders.queue = [{"id": 2, "kind": "sword", "age": 2.0, "remaining": 30.0, "accepted": true}]
	orders.until_arrival = 20
	day.remaining = 1
	day.step(1, orders, merchant)
	check(day.phase == "evening" and orders.queue.size() == 1 and merchant.remaining == 0, "Closing preserves pending orders and sends merchant away")
	day.step(29, orders, merchant)
	check(orders.number == 2 and orders.missed == 1 and day.phase == "evening", "Evening spawns nobody and lets accepted orders expire normally")
	day.step(2, orders, merchant)
	check(day.phase == "summary" and day.summary.customers == 2 and day.summary.served == 1 and day.summary.failed == 1, "Report waits for last departure and counts daily outcomes")
	check(day.summary.earned == 10 and day.summary.spent == 18 and day.summary.refunds == 18 and orders.coins == 110, "Accounting records gross sales, purchases and refunds separately")
	var copy = DAY.new()
	copy.restore(day.snapshot())
	check(copy.summary == day.summary and copy.phase == "summary", "Snapshot preserves report for joining clients")
	check(day.advance(1) and not day.advance(1), "Summary closure begins one transition")
	day.step(DAY.FADE_DURATION, orders, merchant)
	check(day.day == 2 and day.phase == "morning" and orders.coins == 110 and orders.reputation == -4, "Next morning preserves economy and reputation")
	check(not day.advance(1), "Stale previous-day button cannot open new day")
	day.advance(2)
	day.remaining = 0.01
	day.step(0.01, orders, merchant)
	check(day.summary.earned == 0 and day.summary.spent == 0 and day.summary.customers == 0, "Next report excludes previous day's totals")
	var large = DAY.new()
	var small = DAY.new()
	var a = ORDERS.new()
	var b = ORDERS.new()
	a.seed_rng(3456)
	b.seed_rng(3456)
	large.advance(1)
	small.advance(1)
	large.step(140, a, MERCHANT.new())
	var m = MERCHANT.new()
	for i in range(1400): small.step(0.1, b, m)
	check(a.number > 0 and a.number == b.number and large.phase == small.phase, "Large clock steps respect closing boundary and daily arrival count")
	print("DAY RESULT: ", failures, " failures")
	quit(1 if failures else 0)
