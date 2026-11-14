extends RefCounted
## Customer interactions. Visitor simulation and card actions retain their owners.
const CONTEXT = preload("res://scripts/interaction/context.gd")
const CUSTOMERS = preload("res://scripts/customer_state.gd")
signal items_changed
signal orders_changed
signal experience_requested(id: int, task: String)
signal feedback_requested(id: int, message: String)
var items: RefCounted
var orders: RefCounted
var progression: RefCounted

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
