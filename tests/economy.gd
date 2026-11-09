extends SceneTree
const ORE = preload("res://scripts/ore_state.gd")
const ORDERS = preload("res://scripts/customer_state.gd")
const MERCHANT = preload("res://scripts/merchant_state.gd")
const JOB = preload("res://scripts/forge_state.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if ok:
		print("PASS economy: ", message)
	else:
		failures += 1
		push_error(message)
func _initialize() -> void:
	var ore = ORE.new()
	var economy = ORDERS.new()
	var merchant = MERCHANT.new()
	check(merchant.buy(1, MERCHANT.POSITION, economy, ore) == -1, "Wood unavailable before merchant visit")
	merchant.step(12)
	check(merchant.stock == 4 and merchant.remaining == 20, "Merchant arrives with four wood")
	check(merchant.buy(1, Vector2(212, 288), economy, ore) == -1 and merchant.buy(1, Vector2(300, 216), economy, ore) == -1, "Cannot buy remotely or through a floor")
	var wood: int = merchant.buy(1, MERCHANT.POSITION, economy, ore)
	check(wood == 8 and ore.pieces[wood].kind == "wood" and economy.coins == 15 and merchant.stock == 3, "One purchase creates physical material identity and charges five coins")
	ore.pickup(1, wood)
	check(merchant.buy(1, MERCHANT.POSITION, economy, ore) == -1 and economy.coins == 15, "Full hands cannot accidentally spend more coins")
	ore.release_carrier(1)
	for i in range(3):
		merchant.buy(2, MERCHANT.POSITION, economy, ore)
	check(economy.coins == 0 and merchant.stock == 0 and merchant.buy(2, MERCHANT.POSITION, economy, ore) == -1, "Competing purchases cannot overspend or exceed stock")
	merchant.step(20)
	economy.coins = 20
	check(merchant.buy(1, MERCHANT.POSITION, economy, ore) == -1, "Merchant cannot sell after leaving")
	merchant.step(25)
	check(merchant.visits == 2 and merchant.stock == 4, "Regular return refreshes stock")
	var copy = MERCHANT.new()
	copy.restore(merchant.snapshot())
	check(copy.stock == merchant.stock and copy.until_visit == merchant.until_visit, "Merchant snapshot preserves stock and schedule")
	for recipe in JOB.RECIPES:
		var materials = ORE.new()
		materials.pieces[0].kind = "ingot"
		var job = JOB.new()
		job.output_kind = "hammer"
		job.select_recipe(recipe)
		materials.pickup(1, 0)
		check(job.load_material(1, materials), "%s accepts its ingot" % recipe)
		var helpers: Array[int] = [1, 2]
		if recipe == "axe":
			job.step(20, helpers, materials)
			check(job.progress == 0 and materials.pieces[0].processing, "Axe cannot advance without wood")
			var log_id: int = materials.add_material("wood")
			materials.pickup(2, log_id)
			check(job.load_material(2, materials) and not job.select_recipe("sword"), "Second player supplies axe wood; loaded recipe cannot be switched")
		job.step(4.9, helpers, materials)
		check(materials.pieces[0].kind == "ingot", "%s cannot finish before five seconds" % recipe)
		job.step(0.1, helpers, materials)
		check(materials.is_loose(0) and materials.pieces[0].kind == recipe, "%s produces exactly the selected physical item" % recipe)
		if recipe == "axe":
			check(materials.pieces[8].consumed and not materials.is_loose(8) and not materials.pickup(1, 8), "Axe wood is consumed exactly once")
	var wood_first = JOB.new()
	wood_first.output_kind = "hammer"
	wood_first.select_recipe("axe")
	var stock = ORE.new()
	var log_id: int = stock.add_material("wood")
	stock.pickup(1, log_id)
	check(wood_first.load_material(1, stock), "Axe accepts wood before ingot")
	var snapshot = JOB.new()
	snapshot.output_kind = "hammer"
	snapshot.restore(wood_first.snapshot())
	check(snapshot.wood_piece == log_id and snapshot.recipe == "axe" and snapshot.piece == -1, "Partially loaded recipe survives snapshot")
	print("ECONOMY RESULT: ", failures, " failures")
	quit(1 if failures else 0)
