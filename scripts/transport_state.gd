extends RefCounted
const STOPS := [288.0, 368.0, 448.0, 528.0]
const UPGRADE_PRICE := 30
const RAIL_PRICE := 5
const CART_PRICE := 25
const CART_CAPACITY := 25
var upgrades := 0
var lift_y := 288.0
var target := 0
var moving := false
var tracks: Array = []
var pending: Dictionary = {}
var carts: Dictionary = {}
var next_cart := 1

func pay(economy: RefCounted, cost: int) -> bool:
	if economy.coins < cost: return false
	economy.coins -= cost
	economy.spent += cost
	return true

func upgrade(level: int, economy: RefCounted, price: int = UPGRADE_PRICE) -> bool:
	if level != upgrades + 1 or level > 3 or moving or not pay(economy, price): return false
	upgrades = level
	for floor in range(upgrades + 1):
		for x in [358.0, 422.0]:
			var at := Vector2(x, STOPS[floor])
			if at not in tracks: tracks.append(at)
	return true

func snap_rail(at: Vector2) -> Vector2:
	var y: float = STOPS[0]
	for stop in STOPS:
		if absf(at.y - stop) < absf(at.y - y): y = stop
	var base := 358.0 if at.x < 390 else 422.0
	return Vector2(base + snappedf(at.x - base, 32), y)

func can_rail(at: Vector2) -> bool:
	if not at.is_finite() or upgrades == 0 or at.y not in STOPS or STOPS.find(at.y) > upgrades or at.x < 70 or at.x > 566 or at in tracks or absf(at.x - 390) < 32: return false
	return at + Vector2(32, 0) in tracks or at - Vector2(32, 0) in tracks

func buy_rail(player: int, economy: RefCounted, price: int = RAIL_PRICE) -> bool:
	if player <= 0 or pending.has(player) or upgrades == 0 or not pay(economy, price): return false
	pending[player] = price
	return true

func place_rail(player: int, at: Vector2) -> bool:
	if not pending.has(player) or not can_rail(at): return false
	tracks.append(at)
	pending.erase(player)
	return true

func cancel(player: int, economy: RefCounted) -> void:
	if pending.has(player):
		economy.coins += pending[player]
		economy.refunds += pending[player]
		pending.erase(player)

func supported(at: Vector2) -> bool:
	for rail in tracks:
		if is_equal_approx(rail.y, at.y) and absf(rail.x - at.x) <= 16.001: return true
	return upgrades > 0 and not moving and is_equal_approx(at.y, lift_y) and absf(at.x - 390) <= 16.001

func buy_cart(at: Vector2, economy: RefCounted, price: int = CART_PRICE) -> int:
	if not supported(at) or not pay(economy, price): return -1
	for cart in carts.values():
		if cart.at.distance_to(at) < 30:
			economy.coins += price
			economy.spent -= price
			return -1
	var id := next_cart
	next_cart += 1
	carts[id] = {"at": at, "items": [], "driver": 0}
	return id

func move_cart(id: int, dx: float) -> void:
	if not carts.has(id) or moving and absf(carts[id].at.x - 390) < 17: return
	var cart: Dictionary = carts[id]
	var steps := maxi(1, ceili(absf(dx) / 2))
	for i in range(steps):
		var next: Vector2 = cart.at + Vector2(dx / steps, 0)
		if not supported(next): break
		var blocked := false
		for other in carts:
			if other != id and carts[other].at.distance_to(next) < 30: blocked = true
		if blocked: break
		cart.at = next

func store(id: int, piece: int, ore: RefCounted) -> bool:
	if not carts.has(id) or carts[id].items.size() >= CART_CAPACITY or not ore.is_loose(piece) or ore.pieces[piece].kind != "ore": return false
	ore.pieces[piece].processing = true
	carts[id].items.append(piece)
	return true

func deposit(id: int, player: int, ore: RefCounted) -> bool:
	var piece: int = ore.carried_by(player)
	if not carts.has(id) or piece == -1 or ore.pieces[piece].kind != "ore" or carts[id].items.size() >= CART_CAPACITY: return false
	ore.release_carrier(player)
	return store(id, piece, ore)

func take(id: int, player: int, ore: RefCounted) -> bool:
	if player <= 0 or not carts.has(id) or carts[id].items.is_empty() or ore.carried_by(player) != -1: return false
	var piece: int = carts[id].items.pop_front()
	ore.pieces[piece].processing = false
	return ore.pickup(player, piece)

func start_lift(stop: int) -> bool:
	if moving or stop < 0 or stop > upgrades or upgrades == 0 or is_equal_approx(lift_y, STOPS[stop]): return false
	target = stop
	moving = true
	return true

func step_lift(delta: float) -> float:
	var old := lift_y
	if moving:
		lift_y = move_toward(lift_y, STOPS[target], 80 * delta)
		if is_equal_approx(lift_y, STOPS[target]):
			lift_y = STOPS[target]
			moving = false
	var dy := lift_y - old
	for cart in carts.values():
		if absf(cart.at.x - 390) <= 16 and absf(cart.at.y - old) < 0.1: cart.at.y = lift_y
	return dy

func snapshot() -> Dictionary:
	return {"upgrades": upgrades, "lift_y": lift_y, "target": target, "moving": moving, "tracks": tracks.duplicate(), "pending": pending.duplicate(), "carts": carts.duplicate(true), "next_cart": next_cart}

func restore(state: Dictionary) -> void:
	upgrades = state.upgrades
	lift_y = state.lift_y
	target = state.target
	moving = state.moving
	tracks = state.tracks.duplicate()
	pending = state.pending.duplicate()
	carts = state.carts.duplicate(true)
	next_cart = state.next_cart
