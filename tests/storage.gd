extends SceneTree
const WORKSHOP = preload("res://scripts/workshop_state.gd")
const ORE = preload("res://scripts/ore_state.gd")
const ECONOMY = preload("res://scripts/customer_state.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if ok: print("PASS storage: ", message)
	else:
		failures += 1
		push_error(message)
func _initialize() -> void:
	var at := Vector2(456, 216)
	for kind in WORKSHOP.STORAGE:
		var model = WORKSHOP.new()
		var ore = ORE.new()
		var economy = ECONOMY.new()
		check(model.purchase(1, kind, economy, ore) and model.place(1, at) == 1, "Purchase and place " + kind)
		var definition: Dictionary = WORKSHOP.STORAGE[kind]
		var product: String = WORKSHOP.STORAGE_PRODUCTS[definition.group][0]
		var capacity: int = definition.capacity
		for i in range(capacity):
			var piece: int = ore.add_material(product)
			ore.pickup(1, piece)
			check(model.storage_transfer(1, at, ore) and not ore.is_loose(piece) and ore.carried_by(1) == -1, "Store unique identity in " + kind)
		var extra: int = ore.add_material(product)
		ore.pickup(1, extra)
		check(not model.storage_transfer(1, at, ore) and ore.carried_by(1) == extra and model.stations[1].items.size() == capacity, "Full container preserves carried overflow item")
		ore.release_carrier(1)
		check(not model.pack(1, at, ore), "Stocked container cannot be packed or refunded")
		check(not model.storage_transfer(2, at + Vector2(0, 72), ore), "Wrong floor cannot access contents")
		var copy = WORKSHOP.new()
		copy.restore(model.snapshot())
		check(copy.stations[1].items == model.stations[1].items and copy.stations[1].selected == product, "Snapshot preserves contents and selection")
		var identities: Dictionary = {}
		for i in range(capacity):
			check(model.storage_transfer(2, at, ore), "Another player retrieves stored item")
			var piece: int = ore.carried_by(2)
			identities[piece] = true
			ore.release_carrier(2)
		check(identities.size() == capacity and model.stations[1].items.is_empty() and not model.storage_transfer(3, at, ore), "Retrieval preserves every identity without duplication")
		check(model.pack(1, at, ore) and model.cancel(1, economy) and economy.coins == 100, "Empty container packs and refunds original purchase")
	var model = WORKSHOP.new()
	var ore = ORE.new()
	var economy = ECONOMY.new()
	model.purchase(1, "intermediate_small", economy, ore)
	model.place(1, at)
	for product in ["ore", "wood", "horseshoe", "sword", "axe"]:
		var piece: int = ore.add_material(product)
		ore.pickup(1, piece)
		check(not model.storage_transfer(1, at, ore) and ore.carried_by(1) == piece, "Intermediate storage rejects " + product)
		ore.release_carrier(1)
	for product in WORKSHOP.STORAGE_PRODUCTS.intermediate:
		var piece: int = ore.add_material(product)
		ore.pickup(1, piece)
		check(model.storage_transfer(1, at, ore), "Intermediate storage accepts " + product)
	check(model.cycle_storage(2, at, ore) and model.stations[1].selected == "dull_sword", "Cycle chooses next actual stored product")
	check(model.storage_transfer(2, at, ore) and ore.pieces[ore.carried_by(2)].kind == "dull_sword" and model.stations[1].selected == "ingot", "Retrieve selected product and choose valid fallback when exhausted")
	print("STORAGE RESULT: ", failures, " failures")
	quit(1 if failures else 0)
