extends RefCounted
const FIRST_VISIT := 12.0
const INTERVAL := 45.0
const STAY := 20.0
const STOCK := 4
const WOOD_PRICE := 5
const POSITION := Vector2(212, 216)
var until_visit := FIRST_VISIT
var remaining := 0.0
var stock := 0
var visits := 0

func step(delta: float) -> void:
	var left := maxf(0, delta)
	while left > 0.000001:
		var advance := minf(left, until_visit)
		remaining = maxf(0, remaining - advance)
		until_visit -= advance
		left -= advance
		if until_visit <= 0.000001:
			visits += 1
			remaining = STAY
			stock = STOCK
			until_visit += INTERVAL

func buy(player: int, at: Vector2, economy: RefCounted, materials: RefCounted, cost: int = WOOD_PRICE) -> int:
	if player <= 0 or remaining <= 0 or stock <= 0 or economy.coins < cost:
		return -1
	if absf(at.x - POSITION.x) > 12 or absf(at.y - POSITION.y) > 6 or materials.carried_by(player) != -1:
		return -1
	var id: int = materials.add_material("wood")
	economy.coins -= cost
	stock -= 1
	return id

func snapshot() -> Dictionary:
	return {"until_visit": until_visit, "remaining": remaining, "stock": stock, "visits": visits}

func restore(state: Dictionary) -> void:
	until_visit = state.until_visit
	remaining = state.remaining
	stock = state.stock
	visits = state.visits
