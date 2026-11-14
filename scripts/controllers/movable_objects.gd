extends RefCounted
## Owns loose-item and cart bodies, physics interactions, and input handlers.
## State and view dependencies are explicit; networking stays with the session.
const MAP = preload("res://scripts/map_layout.gd")
const ITEM_STATE = preload("res://scripts/ore_state.gd")
const CART_STATE = preload("res://scripts/transport_state.gd")
const BIN_BODY = preload("res://scenes/ore_bin.tscn")
const ITEM_BODY = preload("res://scenes/ore_piece.tscn")
const CART_BODY = preload("res://scenes/mine_cart.tscn")
const ORE_TEXTURE = preload("res://assets/textures/ore.svg")
const TEXTURES = {"food": preload("res://assets/textures/food.svg"),
	"horseshoe": preload("res://assets/textures/horseshoe.svg"),
	"sword": preload("res://assets/textures/sword.svg"),
	"axe": preload("res://assets/textures/axe.svg"),
	"wood": preload("res://assets/textures/wood.svg"),
	"dull_sword": preload("res://assets/textures/dull_sword.svg"),
	"axe_head": preload("res://assets/textures/axe_head.svg"),
	"shaft": preload("res://assets/textures/shaft.svg"),
	"ingot": preload("res://assets/textures/ingot.svg"),
	"ore_bin": preload("res://assets/textures/ore_bin.svg")
}
const CONTEXT = preload("res://scripts/interaction/context.gd")
signal items_changed
signal transport_changed
signal feedback_requested(id: int, message: String)
signal motion_changed
var world: Node2D
var players: Dictionary
var bodies: Dictionary = {}
var cart_nodes: Dictionary = {}
var throw_grace: Dictionary = {}
var hit_cooldowns: Dictionary = {}
var authoritative := false
var catch_stationary: Callable
var items: RefCounted
var transport: RefCounted

func bind(at_world: Node2D, actors: Dictionary, inventory: RefCounted, carts: RefCounted, simulate: bool) -> void:
	world = at_world
	players = actors
	items = inventory
	transport = carts
	authoritative = simulate

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
		release(id, true)
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

func create_body(id: int, simulate: bool, at: Vector2) -> RigidBody2D:
	var body: RigidBody2D = (BIN_BODY if items.pieces[id].kind == "ore_bin" else ITEM_BODY).instantiate()
	body.name = "Ore_%s" % id
	body.get_node("Sprite2D").texture = material_texture(items.pieces[id].kind)
	world.add_child(body)
	body.global_position = world.to_global(at)
	var physics := simulate and authoritative
	body.freeze = not physics
	body.collision_layer = 4 if physics else 0
	body.collision_mask = 29 if physics else 0
	bodies[id] = body
	return body

func release(id: int, drop: bool) -> bool:
	if not authoritative or not players.has(id):
		return false
	var piece_id: int = items.release_carrier(id)
	if piece_id == -1:
		return false
	var dwarf = players[id]
	var direction := -1.0 if dwarf.sprite.flip_h else 1.0
	var body: RigidBody2D = bodies[piece_id]
	# Release within the dwarf's footprint so a wall cannot swallow the ore.
	var bin: bool = items.pieces[piece_id].kind == "ore_bin"
	var at: Vector2 = dwarf.position + Vector2(direction * 2, (-22 if not drop else -13) if bin else (-18 if not drop else -7))
	if bin: at.x = clampf(at.x, 70, MAP.RIGHT_WALL - 20)
	var motion := Vector2(direction * 280, -180) if not drop else Vector2(direction * 25, 0)
	position_body(body, at, motion)
	body.angular_velocity = direction * 6 if not drop and not bin else 0
	throw_grace[piece_id] = [id, Time.get_ticks_msec() + 300]
	items_changed.emit()
	motion_changed.emit()
	return true

func motion_snapshot() -> Array:
	var result: Array = []
	for id in bodies:
		if items.is_loose(id):
			var body: RigidBody2D = bodies[id]
			result.append([id, body.global_position, body.rotation, body.linear_velocity])
	return result

func apply_motion(state: Array) -> void:
	for item in state:
		if bodies.has(item[0]):
			var body: RigidBody2D = bodies[item[0]]
			body.global_position = item[1]
			body.rotation = item[2]
			body.linear_velocity = item[3]

func step_loose() -> void:
	if not authoritative: return
	var collected := false
	for piece_id in bodies:
		if not items.is_loose(piece_id):
			continue
		var body: RigidBody2D = bodies[piece_id]
		var stored := false
		if items.pieces[piece_id].kind == "ore" and body.linear_velocity.y >= 0:
			for cart in cart_nodes:
				if cart_nodes[cart].get_node("Catch").overlaps_body(body):
					stored = transport.store(cart, piece_id, items)
					if stored:
						collected = true
						break
		if stored: continue
		if items.pieces[piece_id].kind in ITEM_STATE.BIN_PRODUCTS and body.linear_velocity.y >= 0:
			for bin in bodies:
				if items.pieces[bin].kind == "ore_bin" and items.is_loose(bin) and bodies[bin].get_node("Catch").overlaps_body(body):
					stored = items.store_in_bin(bin, piece_id)
					if stored:
						collected = true
						break
		if stored: continue
		if body.linear_velocity.y >= 0 and catch_stationary.is_valid():
			stored = catch_stationary.call(piece_id, body)
			if stored: collected = true
		if stored:
			continue
		if body.linear_velocity.length() < 110:
			continue
		for id in players:
			var now := Time.get_ticks_msec()
			var grace: Array = throw_grace.get(piece_id, [0, 0])
			if (grace[0] == id and now < grace[1]) or now < hit_cooldowns.get(Vector2i(piece_id, id), 0):
				continue
			var hurtbox := Rect2(players[id].global_position - Vector2(20, 54), Vector2(40, 62))
			if hurtbox.has_point(body.global_position):
				players[id].apply_ore_hit(body.linear_velocity * 0.7)
				hit_cooldowns[Vector2i(piece_id, id)] = now + 400
				body.linear_velocity = Vector2(-body.linear_velocity.x * 0.4, -70)
				break

	if collected:
		transport_changed.emit()
		items_changed.emit()

func position_body(body: RigidBody2D, at: Vector2, motion: Vector2) -> void:
	body.freeze = not authoritative
	body.sleeping = false
	body.rotation = 0
	body.global_position = world.to_global(at)
	body.linear_velocity = motion
	# Update the physics transform as well when releasing a formerly frozen body.
	PhysicsServer2D.body_set_state(body.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, body.global_transform)
	PhysicsServer2D.body_set_state(body.get_rid(), PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, motion)

func refresh() -> void:
	for piece_id in items.pieces:
		if not bodies.has(piece_id):
			create_body(piece_id, false, MAP.VEINS[0] + Vector2(-46, -12))
	for piece_id in bodies:
		var body: RigidBody2D = bodies[piece_id]
		var loose: bool = items.is_loose(piece_id)
		body.get_node("Sprite2D").texture = material_texture(items.pieces[piece_id].kind)
		body.visible = loose
		body.freeze = not loose or not authoritative
		body.collision_layer = 4 if loose and authoritative else 0
		body.collision_mask = 29 if loose and authoritative else 0
		if items.pieces[piece_id].kind == "ore_bin":
			body.get_node("Catch").monitoring = loose and authoritative
			body.get_node("Count").text = "%s/10" % items.pieces[piece_id].contents.size()
	for id in players:
		var carried: int = items.carried_by(id)
		players[id].get_node("CarriedOre").visible = carried != -1
		if carried != -1:
			players[id].get_node("CarriedOre").texture = material_texture(items.pieces[carried].kind)

func refresh_carts() -> void:
	for id in cart_nodes.keys():
		if not transport.carts.has(id):
			cart_nodes[id].free()
			cart_nodes.erase(id)
	for id in transport.carts:
		if not cart_nodes.has(id):
			cart_nodes[id] = CART_BODY.instantiate()
			world.add_child(cart_nodes[id])
		cart_nodes[id].position = transport.carts[id].at
		cart_nodes[id].get_node("Catch").monitoring = authoritative
		cart_nodes[id].get_node("Count").text = "%s/25" % transport.carts[id].items.size()

func cart_positions() -> Dictionary:
	var result: Dictionary = {}
	for id in transport.carts: result[id] = transport.carts[id].at
	return result

func step_carts(delta: float, previous_positions: Dictionary, active_lift_riders: Dictionary, previous_lift_riders: Dictionary) -> void:
	if not authoritative: return
	for cart in transport.carts.values():
		var driver: int = cart.driver
		if not players.has(driver) or players[driver].jump_held or items.carried_by(driver) != -1:
			cart.driver = 0
			continue
		var id: int = transport.carts.find_key(cart)
		if not active_lift_riders.has(driver): transport.move_cart(id, players[driver].controls.x * 70 * delta)
		players[driver].transport_locked = true
		players[driver].position.x = CART_STATE.follow_cart_x(players[driver].position.x, previous_positions[id].x, cart.at.x)
		if not previous_lift_riders.has(driver): players[driver].position.y += cart.at.y - previous_positions[id].y
		players[driver].velocity = Vector2.ZERO

func material_texture(kind: String) -> Texture2D:
	return TEXTURES.get(kind, ORE_TEXTURE)

func spawn_initial_items() -> void:
	for id in items.pieces:
		create_body(id, authoritative, Vector2(310 + id * 8, 209 - (id % 2) * 3))
	refresh()

func update_labels(at: Vector2) -> void:
	for id in bodies:
		if items.pieces[id].kind == "ore_bin": bodies[id].get_node("Count").visible = world.to_local(bodies[id].global_position).distance_to(at) < 65
	for id in cart_nodes:
		cart_nodes[id].get_node("Count").visible = transport.carts[id].at.distance_to(at) < 65

func forget_actor(id: int) -> void:
	for cart in transport.carts.values():
		if cart.driver == id: cart.driver = 0
	for piece in throw_grace.keys():
		if throw_grace[piece][0] == id: throw_grace.erase(piece)
	for key in hit_cooldowns.keys():
		if key.y == id: hit_cooldowns.erase(key)

func clear() -> void:
	authoritative = false
	for body in bodies.values(): body.free()
	for cart in cart_nodes.values(): cart.free()
	bodies.clear()
	cart_nodes.clear()
	throw_grace.clear()
	hit_cooldowns.clear()
