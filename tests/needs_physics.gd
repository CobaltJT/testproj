extends SceneTree
var session: Node
var failures := 0
func check(ok: bool, message: String) -> void:
	if ok: print("PASS needs world: ", message)
	else:
		failures += 1
		push_error(message)
func frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame
func stand(at: Vector2) -> void:
	var dwarf = session.players[1]
	dwarf.position = at
	dwarf.velocity = Vector2.ZERO
	dwarf.controls = Vector2.ZERO
	dwarf.climbing = false
	await frames(5)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	session = load("res://scenes/session.tscn").instantiate()
	root.add_child(session)
	session.host_game()
	preload("res://tests/world_fixture.gd").prepare(session)
	session.set_physics_process(false)
	session.orders.coins = 1000
	for entry in [["bed", Vector2(160, 136)], ["dining", Vector2(256, 136)], ["anvil", Vector2(456, 216)], ["forge", Vector2(552, 216)], ["grinder", Vector2(456, 136)], ["woodbench", Vector2(552, 136)]]:
		session.purchase_for(1, entry[0])
		session.place_for(1, entry[1])
	check(session.workshop.stations.size() == 6, "Beds and dining tables buy/place alongside all production stations")
	var bed: int = session.workshop.nearest(Vector2(160, 136))
	var table: int = session.workshop.nearest(Vector2(256, 136))
	var anvil: int = session.workshop.nearest(Vector2(456, 216))
	var job = session.workshop.stations[anvil].job
	var vitals: Dictionary = session.needs.dwarfs[1]
	check(session.placeables.views[bed].get_node("TrayBody").collision_layer == 0 and session.placeables.views[table].get_node("Sprite").texture == session.placeables.STATION_VIEW.TEXTURES.dining, "Care furniture has image textures and no crafting tray collision")
	await stand(Vector2(456, 216))
	session.ore.pieces[0].kind = "ingot"
	session.ore.pickup(1, 0)
	job.load_material(1, session.ore)
	vitals.energy = 9
	vitals.food = 100
	session.work_held[1] = true
	session.placeables.step_workstations(2)
	check(is_equal_approx(job.progress, 1) and vitals.energy < 9 and vitals.food < 100, "Low needs halve smithing speed and actual work drains both meters")
	vitals.energy = 0
	session.placeables.step_workstations(3)
	check(is_equal_approx(job.progress, 1), "Empty energy pauses loaded production without losing input")
	vitals.energy = 100
	vitals.food = 0
	session.placeables.step_workstations(3)
	check(is_equal_approx(job.progress, 1), "Empty food also pauses loaded production")
	session.refresh_walking()
	check(session.players[1].walking_multiplier == 0.4, "Exhausted walking multiplier reaches dwarf controller")
	vitals.energy = 5
	vitals.food = 100
	session.refresh_walking()
	check(session.players[1].walking_multiplier == 0.7, "Low walking multiplier reaches dwarf controller")
	for definition in [[Vector2(552, 216), "ore"], [Vector2(456, 136), "dull_sword"], [Vector2(552, 136), "wood"]]:
		await stand(definition[0])
		var station: int = session.workshop.nearest(definition[0])
		var production = session.workshop.stations[station].job
		var piece: int = session.ore.add_material(definition[1])
		if production.kind == "forge": production.store_ore(piece, session.ore)
		else:
			session.ore.pickup(1, piece)
			production.load_material(1, session.ore)
		vitals.energy = 0
		session.placeables.step_workstations(1)
		check(production.progress == 0, "Exhaustion blocks " + production.kind)
		vitals.energy = 9
		vitals.food = 100
		session.placeables.step_workstations(1)
		check(is_equal_approx(production.progress, 0.5), "Low needs halve " + production.kind)
	# Rest works even with both meters empty, and pauses when E is released.
	vitals.energy = 0
	vitals.food = 0
	await stand(Vector2(160, 136))
	session.placeables.step_care(4)
	check(vitals.energy == 48 and vitals.food == 0, "Holding E at a bed restores energy even when fully depleted")
	check(not session.workshop.pack(1, Vector2(160, 136), session.ore), "Occupied bed cannot be packed during sleep")
	session.work_held[1] = false
	session.placeables.step_care(2)
	check(vitals.energy == 48, "Releasing E pauses sleep")
	await stand(Vector2(256, 136))
	session.work_held[1] = true
	session.placeables.step_care(2)
	check(vitals.food == 0, "Dining without carried/loaded food cannot restore satisfaction")
	var food: int = session.ore.add_material("food")
	session.ore.pickup(1, food)
	session.movable_objects.refresh()
	var quiet_notice: String = session.hud.notice.text
	session.interact_for(1)
	check(session.hud.notice.text == quiet_notice, "Loading food keeps routine interaction notifications quiet")
	var meal = session.workshop.stations[table].job
	check(meal.diner == 1 and meal.slots.get("food") == food and session.ore.carried_by(1) == -1, "E reserves carried food for that dwarf's meal")
	session.placeables.step_care(2)
	check(vitals.food == 16 and meal.progress == 2, "Eating restores satisfaction gradually")
	check(not session.workshop.pack(1, Vector2(256, 136), session.ore), "A loaded dining table cannot be packed")
	session.work_held[1] = false
	session.placeables.step_care(2)
	check(vitals.food == 16, "Interrupted meal retains remaining food")
	session.work_held[1] = true
	session.placeables.step_care(3)
	check(vitals.food == 40 and session.ore.pieces[food].consumed and not session.ore.pieces[food].processing and meal.slots.is_empty(), "One meal restores forty satisfaction and consumes food exactly once")
	session.placeables.step_care(5)
	check(vitals.food == 40, "Empty table cannot duplicate food")
	vitals.energy = 100
	vitals.food = 100
	await stand(Vector2(456, 216))
	session.placeables.step_workstations(4)
	check(session.ore.pieces[0].kind == "horseshoe", "Recovered dwarf resumes the paused job to completion")
	vitals.energy = 0
	await stand(session.MINE_POSITION)
	session.cycle.phase = "shop"
	session.placeables.step_mining(4)
	check(session.mining.extracted == 0, "Exhaustion blocks mining too")
	vitals.energy = 100
	vitals.food = 100
	session.placeables.step_mining(3)
	check(session.mining.extracted == 1 and vitals.energy < 100 and vitals.food < 100, "Mining resumes after recovery and drains needs")
	await stand(Vector2(256, 136))
	vitals.food = 99
	var snack: int = session.ore.add_material("food")
	session.ore.pickup(1, snack)
	meal.load_material(1, session.ore)
	session.placeables.step_care(1)
	check(vitals.food == 100 and session.ore.pieces[snack].consumed and meal.slots.is_empty(), "Becoming full consumes a meal and frees the table")
	# Supplies use existing physical item and visitor-card purchase flows.
	session.merchant.remaining = 0
	session.supplies.remaining = 10
	session.supplies.kind = "food"
	session.supplies.stock = 2
	await stand(Vector2(212, 216))
	session.refresh_merchant()
	await frames(4)
	check(session.hud.merchant_card.product.texture == session.material_texture("food") and not session.hud.merchant_card.buy_button.disabled, "Food merchant card shows food and enables in-range purchases")
	var coins: int = session.orders.coins
	session.hud.merchant_card.buy_button.pressed.emit()
	check(session.orders.coins == coins - 4 and session.supplies.stock == 1, "Food card buys through host-validated shared economy")
	session.supplies.kind = "ore"
	session.buy_goods_for(1, "food")
	check(session.orders.coins == coins - 4, "Stale food card cannot purchase a different visiting product")
	session.buy_goods_for(1, "ore")
	check(session.orders.coins == coins - 7 and session.supplies.stock == 0, "Ore trader sells raw physical ore")
	session.disconnect_game("Done")
	check(session.needs.dwarfs.is_empty(), "New session clears personal needs")
	print("NEEDS WORLD RESULT: ", failures, " failures")
	quit(1 if failures else 0)
