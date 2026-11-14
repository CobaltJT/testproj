extends RefCounted
## Discrete movable-object interactions. Physics stepping stays with the session.
const CONTEXT = preload("res://scripts/interaction/context.gd")
signal items_changed
signal transport_changed
signal feedback_requested(id: int, message: String)
signal drop_requested(id: int)
var world: Node2D
var players: Dictionary
var bodies: Dictionary
var items: RefCounted
var transport: RefCounted

func bind(at_world: Node2D, actors: Dictionary, item_bodies: Dictionary, inventory: RefCounted, carts: RefCounted) -> void:
	world = at_world
	players = actors
	bodies = item_bodies
	items = inventory
	transport = carts

func nearest_loose(at: Vector2) -> int:
	var nearest := -1
	var distance := 24.0
	for piece in bodies:
		if not items.is_loose(piece): continue
		var offset: Vector2 = world.to_local(bodies[piece].global_position) - (at - Vector2(0, 8))
		if absf(offset.y) <= 18 and offset.length() < distance:
			nearest = piece
			distance = offset.length()
	return nearest

func nearest_bin(at: Vector2) -> int:
	var nearest := -1
	var distance := 32.0
	for piece in bodies:
		if items.pieces[piece].kind != "ore_bin" or not items.is_loose(piece): continue
		var offset: Vector2 = world.to_local(bodies[piece].global_position) - (at - Vector2(0, 8))
		if absf(offset.y) <= 18 and offset.length() < distance:
			nearest = piece
			distance = offset.length()
	return nearest

func nearest_cart(at: Vector2) -> int:
	var nearest := -1
	var distance := 36.0
	for id in transport.carts:
		var offset: Vector2 = transport.carts[id].at - at
		if absf(offset.y) <= 8 and offset.length() < distance:
			nearest = id
			distance = offset.length()
	return nearest

func try_pickup(context: CONTEXT) -> bool:
	if context.action != &"interact" or context.carried_item != -1: return false
	var piece := context.query(&"loose", nearest_loose)
	if piece == -1: return false
	if items.pieces[piece].kind == "ore_bin":
		# An empty bin intentionally consumes E. Only C can pick it up.
		if items.pieces[piece].contents.is_empty(): return true
		if items.take_from_bin(context.player_id, piece):
			items_changed.emit()
			feedback_requested.emit(context.player_id, "Took one intermediate product.")
			return true
	if not items.pickup(context.player_id, piece): return false
	items_changed.emit()
	feedback_requested.emit(context.player_id, "Picked up %s. F: throw · Q: drop" % ("movable parts bin" if items.pieces[piece].kind == "ore_bin" else items.pieces[piece].kind.replace("_", " ")))
	return true

func try_cart_inventory(context: CONTEXT) -> bool:
	if context.action != &"interact": return false
	var cart := context.query(&"cart", nearest_cart)
	if cart == -1: return false
	var message: String
	if context.carried_item == -1:
		message = "Took one ore from cart." if transport.take(cart, context.player_id, items) else "Cart is empty. C: push cart."
	elif transport.deposit(cart, context.player_id, items):
		message = "Ore loaded into cart. E: take ore with empty hands · C: push cart."
	else: return false
	transport_changed.emit()
	items_changed.emit()
	feedback_requested.emit(context.player_id, message)
	return true

func try_bin_deposit(context: CONTEXT) -> bool:
	if context.action != &"interact" or context.carried_item == -1: return false
	var bin := context.query(&"bin", nearest_bin)
	if bin == -1 or not items.deposit_in_bin(context.player_id, bin): return false
	items_changed.emit()
	feedback_requested.emit(context.player_id, "Intermediate product stored.")
	return true

func try_carry(context: CONTEXT) -> bool:
	if context.action != &"push_cart": return false
	var id := context.player_id
	if context.carried_item != -1 and items.pieces[context.carried_item].kind == "ore_bin":
		drop_requested.emit(id)
		return true
	for cart in transport.carts.values():
		if cart.driver == id:
			cart.driver = 0
			players[id].transport_locked = false
			transport_changed.emit()
			return true
	var cart := context.query(&"cart", nearest_cart)
	var bin := context.query(&"bin", nearest_bin)
	if bin != -1 and (cart == -1 or (world.to_local(bodies[bin].global_position) - (context.position - Vector2(0, 8))).length() < transport.carts[cart].at.distance_to(context.position)):
		if items.pickup(id, bin): items_changed.emit()
		return true
	if cart != -1:
		if context.carried_item == -1 and transport.carts[cart].driver == 0 and not transport.moving:
			transport.carts[cart].driver = id
			transport_changed.emit()
		return true
	return false
