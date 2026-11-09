extends SceneTree
var session: Node
var failures := 0
func check(ok: bool, message: String) -> void:
	if ok:
		print("PASS market interaction: ", message)
	else:
		failures += 1
		push_error(message)
func frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame
func press(action: String) -> void:
	Input.action_press(action)
	await frames(2)
	Input.action_release(action)
	await frames(12)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	session = load("res://scenes/session.tscn").instantiate()
	root.add_child(session)
	session.host_game()
	var dwarf = session.players[1]
	session.merchant.step(12)
	session.refresh_merchant()
	check(session.merchant_node.visible, "Visiting merchant appears")
	dwarf.position = Vector2(212, 216)
	await frames(5)
	await press("buy_wood")
	await frames(30)
	check(session.orders.coins == 15 and session.ore.pieces.has(8) and session.ore.pieces[8].kind == "wood", "Real B purchases one wood for five shared coins")
	var body: RigidBody2D = session.ore_bodies[8]
	check(body.visible and not body.freeze and body.get_node("Sprite2D").texture == session.EXTRA_TEXTURES.wood, "Purchased wood is a physical textured object")
	await press("interact")
	check(session.ore.carried_by(1) == 8, "Wood on floor can be picked up with E")
	await press("throw_ore")
	check(session.ore.is_loose(8) and body.visible and body.linear_velocity.length() > 100, "Wood uses existing throw physics")
	# Set up the same log as a carried ingredient to isolate station input behavior.
	session.ore.pickup(1, 8)
	session.refresh_ore()
	dwarf.position = Vector2(260, 216)
	dwarf.velocity = Vector2.ZERO
	await frames(5)
	await press("recipe_axe")
	await press("interact")
	check(session.anvil.recipe == "axe" and session.anvil.wood_piece == 8 and session.anvil.piece == -1, "Key 3 selects axe and E loads wood first")
	Input.action_press("interact")
	await frames(30)
	Input.action_release("interact")
	check(session.anvil.progress == 0, "Missing ingot blocks axe work")
	session.ore.pieces[0].kind = "ingot"
	session.ore.pickup(1, 0)
	session.refresh_ore()
	await frames(12)
	await press("interact")
	await press("recipe_sword")
	check(session.anvil.recipe == "axe", "Loaded ingredients lock recipe selection")
	Input.action_press("interact")
	for i in range(330):
		await frames(1)
		if session.ore.pieces[0].kind == "axe":
			break
	Input.action_release("interact")
	await frames(30)
	check(session.ore.pieces[0].kind == "axe" and session.ore_bodies[0].visible and session.ore_bodies[0].get_node("Sprite2D").texture == session.EXTRA_TEXTURES.axe, "Five-second axe work produces physical axe image")
	check(session.ore.pieces[8].consumed and not body.visible, "Axe consumes purchased wood")
	await press("recipe_sword")
	check(session.anvil.recipe == "sword", "Empty anvil can select sword after completion")
	session.disconnect_game("Done")
	check(session.orders.coins == 20 and session.orders.reputation == 0 and session.merchant.visits == 0 and session.anvil.recipe == "hammer", "Reset restores initial economy, merchant and recipe")
	print("MARKET INTERACTION RESULT: ", failures, " failures")
	quit(1 if failures else 0)
