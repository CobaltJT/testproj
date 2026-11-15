extends RefCounted
## Visitor simulation and interactions. Networking and presentation stay outside.
const CONTEXT = preload("res://scripts/interaction/context.gd")
const CUSTOMERS = preload("res://scripts/customer_state.gd")
const MERCHANT = preload("res://scripts/merchant_state.gd")
signal items_changed
signal orders_changed
signal experience_requested(id: int, task: String)
signal feedback_requested(id: int, message: String)
var items: RefCounted
var orders: RefCounted
var progression: RefCounted

signal output_ready(piece: int, at: Vector2)
signal purchase_completed
var cycle: RefCounted
var merchant: RefCounted
var supplies: RefCounted
var authoritative := false

func bind(inventory: RefCounted, requests: RefCounted, skills: RefCounted) -> void:
	items = inventory
	orders = requests
	progression = skills

func try_deliver(context: CONTEXT) -> bool:
	if context.action != &"interact" or context.carried_item == -1 or orders.queue.is_empty() or not orders.at_counter(context.player_id, context.position): return false
	var request: Dictionary = orders.queue[0]
	var product: String = request.kind
	var completed: int = orders.completed
	var sold: bool = orders.deliver(context.player_id, context.position, items, 1.0 + 0.1 * progression.rank(context.player_id, "sales"))
	var message: String
	if sold:
		var result := "Order complete! +2 reputation." if orders.completed > completed else "%s more needed." % (request.get("quantity", 1) - request.delivered)
		message = "%s delivered! +%s coins. %s" % [product.capitalize(), progression.sale_price(context.player_id, CUSTOMERS.PRICES[product]), result]
		experience_requested.emit(context.player_id, "delivery")
	else:
		message = "Accept the request first." if not request.accepted else "Front customer needs a %s." % product
	orders_changed.emit()
	items_changed.emit()
	feedback_requested.emit(context.player_id, message)
	return true

func bind_visitors(day: RefCounted, wood_trader: RefCounted, supply_trader: RefCounted, simulate: bool) -> void:
	cycle = day
	merchant = wood_trader
	supplies = supply_trader
	authoritative = simulate

## Day owns shop boundaries and summary accounting; visitor models own their clocks.
## Return whether the session must replicate a phase transition immediately.
func step(delta: float) -> bool:
	if not authoritative: return false
	var previous_phase: String = cycle.phase
	cycle.step(delta, orders, merchant)
	if cycle.phase == "shop": supplies.step_supplies(delta, merchant.remaining > 0)
	else: supplies.remaining = 0
	if previous_phase == "transition" and cycle.phase == "morning":
		supplies.until_visit = 20
		supplies.stock = 0
	return previous_phase != cycle.phase

func visiting_merchant() -> RefCounted:
	return merchant if merchant.remaining > 0 else supplies

func decide_order(id: int, at: Vector2, order_id: int, accept: bool) -> void:
	if not authoritative or cycle.phase in ["summary", "transition"]: return
	var failed_before: int = orders.missed
	var changed: bool = orders.decide(id, at, order_id, accept, progression.reject_cost(id))
	var message := "Order accepted · 30s" if accept else "Order declined · −%s rep" % progression.reject_cost(id)
	if orders.missed > failed_before: message = "Request failed · −6 rep"
	if not changed: message = "Request no longer available"
	feedback_requested.emit(id, message)
	orders_changed.emit()

func buy_wood(id: int, at: Vector2) -> void:
	if not authoritative or cycle.phase != "shop": return
	var cost: int = progression.purchase_price(id, MERCHANT.WOOD_PRICE)
	var piece: int = merchant.buy(id, at, orders, items, cost)
	if piece == -1:
		feedback_requested.emit(id, "Wood unavailable: empty hands, %s coins, stock and merchant proximity required." % cost)
		return
	finish_purchase(piece)

func buy_goods(id: int, at: Vector2, kind: String) -> void:
	if not authoritative or cycle.phase != "shop": return
	var visiting = visiting_merchant()
	if visiting.kind != kind or kind not in MERCHANT.PRICES: return
	var piece: int = visiting.buy(id, at, orders, items, progression.purchase_price(id, MERCHANT.PRICES[kind]))
	if piece == -1:
		feedback_requested.emit(id, "Purchase unavailable: check proximity, stock, coins and empty hands.")
		return
	finish_purchase(piece)

func finish_purchase(piece: int) -> void:
	output_ready.emit(piece, Vector2(222, 202))
	purchase_completed.emit()
