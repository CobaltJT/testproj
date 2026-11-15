extends SceneTree
## Visitor orchestration without Session, views, physical bodies or network peers.
const NPCS = preload("res://scripts/controllers/npcs.gd")
const CONTEXT = preload("res://scripts/interaction/context.gd")
const MERCHANT = preload("res://scripts/merchant_state.gd")
var failures := 0
var outputs: Array = []
var purchases := 0
var rewards: Array = []
func check(ok: bool, message: String) -> void:
	if ok: print("PASS NPC controller: ", message)
	else:
		failures += 1
		push_error(message)
func fixture(simulate: bool = true) -> RefCounted:
	var controller = NPCS.new()
	var items = preload("res://scripts/ore_state.gd").new()
	var orders = preload("res://scripts/customer_state.gd").new()
	var skills = preload("res://scripts/progression_state.gd").new()
	skills.add(1)
	var day = preload("res://scripts/day_state.gd").new()
	var wood = MERCHANT.new()
	var supplies = MERCHANT.new()
	supplies.configure_supplies()
	controller.bind(items, orders, skills)
	controller.bind_visitors(day, wood, supplies, simulate)
	controller.output_ready.connect(func(piece: int, at: Vector2): outputs.append([piece, at]))
	controller.purchase_completed.connect(func(): purchases += 1)
	controller.experience_requested.connect(func(id: int, task: String): rewards.append([id, task]))
	return controller
func order(id: int, kind: String, quantity: int = 1) -> Dictionary:
	return {"id": id, "kind": kind, "quantity": quantity, "delivered": 0, "age": 3.0, "remaining": 10.0, "accepted": false}
func _initialize() -> void:
	var npc = fixture()
	npc.step(100)
	check(npc.orders.number == 0 and npc.merchant.visits == 0 and npc.supplies.visits == 0, "Morning has no arrivals")
	npc.cycle.advance(1)
	npc.orders.until_arrival = 1
	npc.merchant.until_visit = 2
	npc.supplies.until_visit = 1
	npc.step(1)
	check(npc.orders.queue.size() == 1 and npc.supplies.remaining > 0 and npc.visiting_merchant() == npc.supplies, "Shop advances customer and random supply visits")
	npc.step(1)
	check(npc.visiting_merchant() == npc.merchant and npc.supplies.remaining == 0, "Wood visit takes priority and displaces supplies")
	npc.orders.queue = [order(10, "horseshoe"), order(11, "axe")]
	npc.orders.reputation = 40
	npc.progression.dwarfs[1].skills.diplomacy = 2
	npc.decide_order(1, Vector2.ZERO, 11, true)
	check(npc.orders.queue[1].accepted and npc.orders.queue[1].remaining == 30, "Any queued order can be accepted; current acceptance timer preserved")
	npc.decide_order(1, Vector2.ZERO, 11, false)
	check(npc.orders.missed == 1 and npc.orders.reputation == 34, "Rejecting accepted order counts as failure")
	npc.decide_order(1, Vector2.ZERO, 10, false)
	check(npc.orders.rejected == 1 and npc.orders.reputation == 33, "Unaccepted rejection uses player's diplomacy discount")
	var before: int = npc.orders.reputation
	npc.decide_order(1, Vector2.ZERO, 10, false)
	check(npc.orders.reputation == before, "Stale decisions cannot charge twice")
	npc.orders.queue = [order(20, "horseshoe", 2), order(21, "axe")]
	for request in npc.orders.queue: npc.decide_order(1, Vector2.ZERO, request.id, true)
	var piece: int = npc.items.add_material("axe")
	npc.items.pickup(1, piece)
	var context = CONTEXT.new(1, &"interact", Vector2(166, 216), piece)
	npc.try_deliver(context)
	check(npc.items.carried_by(1) == piece and npc.orders.completed == 0, "Only front customer can be served")
	npc.items.release_carrier(1)
	npc.progression.dwarfs[1].skills.sales = 2
	before = npc.orders.coins
	for i in range(2):
		piece = npc.items.add_material("horseshoe")
		npc.items.pickup(1, piece)
		npc.try_deliver(CONTEXT.new(1, &"interact", Vector2(166, 216), piece))
	check(npc.orders.completed == 1 and npc.orders.coins == before + 24 and rewards == [[1, "delivery"], [1, "delivery"]], "Multi-item delivery retains sales bonus and per-item EXP events")
	npc.cycle.remaining = 1
	npc.step(2)
	check(npc.cycle.phase == "evening" and npc.merchant.remaining == 0 and npc.supplies.remaining == 0 and npc.orders.queue.size() == 1, "Closing stops visits while remaining orders continue")
	npc.step(31)
	check(npc.cycle.phase == "summary" and npc.orders.missed == 2, "Evening waits for deadlines and departures before summary")
	npc.cycle.advance(1)
	check(npc.step(1) and npc.cycle.phase == "morning" and npc.supplies.until_visit == 20 and npc.supplies.stock == 0, "Next morning resets visitor clocks and stock")
	npc = fixture()
	npc.cycle.phase = "shop"
	npc.supplies.kind = "food"
	npc.supplies.remaining = 10
	npc.supplies.stock = 2
	npc.progression.dwarfs[1].skills.purchasing = 3
	before = npc.orders.coins
	npc.buy_goods(1, MERCHANT.POSITION, "ore")
	check(npc.orders.coins == before and purchases == 0, "Stale product card cannot buy different stock")
	npc.buy_goods(1, Vector2.ZERO, "food")
	check(npc.orders.coins == before and purchases == 0, "Purchase validates proximity without side effects")
	npc.buy_goods(1, MERCHANT.POSITION, "food")
	check(npc.orders.coins == before - 3 and npc.orders.spent == 3 and npc.supplies.stock == 1 and purchases == 1 and npc.items.pieces[outputs.back()[0]].kind == "food", "Purchase applies discount once and emits physical output")
	npc.merchant.remaining = 10
	npc.merchant.stock = 2
	npc.buy_wood(1, MERCHANT.POSITION)
	check(npc.orders.spent == 7 and npc.merchant.stock == 1 and purchases == 2 and npc.items.pieces[outputs.back()[0]].kind == "wood", "Legacy wood endpoint uses same output boundary and discount")
	npc.authoritative = false
	var until: float = npc.orders.until_arrival
	npc.step(100)
	npc.buy_goods(1, MERCHANT.POSITION, "wood")
	npc.buy_wood(1, MERCHANT.POSITION)
	npc.orders.queue = [order(30, "sword")]
	npc.decide_order(1, Vector2.ZERO, 30, true)
	check(npc.orders.until_arrival == until and purchases == 2 and not npc.orders.queue[0].accepted, "Replica cannot advance visitors, buy or decide")
	var old_orders = npc.orders
	var fresh = fixture()
	npc.bind(fresh.items, fresh.orders, fresh.progression)
	npc.bind_visitors(fresh.cycle, fresh.merchant, fresh.supplies, true)
	npc.cycle.phase = "shop"
	npc.orders.until_arrival = 1
	npc.step(1)
	check(npc.orders.number == 1 and old_orders.number == 0 and not old_orders.queue[0].accepted, "Rebinding targets fresh models and leaves old session untouched")
	print("NPC CONTROLLER RESULT: ", failures, " failures")
	quit(1 if failures else 0)
