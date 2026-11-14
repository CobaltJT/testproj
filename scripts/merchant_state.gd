extends RefCounted
const FIRST_VISIT := 12.0
const INTERVAL := 45.0
const STAY := 20.0
const STOCK := 4
const WOOD_PRICE := 5
const PRICES := {"wood": 5, "ore": 3, "food": 4}
const POSITION := Vector2(212, 216)
var kind := "wood"
var supplies := false
var rng := RandomNumberGenerator.new()
var until_visit := FIRST_VISIT
var remaining := 0.0
var stock := 0
var visits := 0

func configure_supplies() -> void:
	supplies = true
	kind = "food"
	rng.randomize()
	until_visit = 20.0

func step_supplies(delta: float, wood_present: bool) -> void:
	if wood_present:
		if remaining > 0:
			remaining = 0
			until_visit = rng.randf_range(8, 15)
		return
	step(delta)

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
			if supplies: kind = "ore" if rng.randi_range(0, 1) == 0 else "food"
			stock = (8 if kind == "ore" else 6) if supplies else STOCK
			until_visit += rng.randf_range(30, 45) if supplies else INTERVAL

func buy(player: int, at: Vector2, economy: RefCounted, materials: RefCounted, cost: int = -1) -> int:
	if cost < 0: cost = PRICES[kind]
	if player <= 0 or not at.is_finite() or remaining <= 0 or stock <= 0 or economy.coins < cost:
		return -1
	if absf(at.x - POSITION.x) > 12 or absf(at.y - POSITION.y) > 6 or materials.carried_by(player) != -1:
		return -1
	var id: int = materials.add_material(kind)
	economy.coins -= cost
	economy.spent += cost
	stock -= 1
	return id

func snapshot() -> Dictionary:
	return {"kind": kind, "supplies": supplies, "rng_state": rng.state, "until_visit": until_visit, "remaining": remaining, "stock": stock, "visits": visits}

func restore(state: Dictionary) -> void:
	kind = state.get("kind", "wood")
	supplies = state.get("supplies", false)
	rng.state = state.get("rng_state", rng.state)
	until_visit = state.until_visit
	remaining = state.remaining
	stock = state.stock
	visits = state.visits
