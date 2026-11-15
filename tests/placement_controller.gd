extends SceneTree
## Placement, stationary view lifecycle and elevator/cart boundary without Session.
class Actor extends RefCounted:
	var position := Vector2(456, 216)
	var velocity := Vector2.ZERO
	var transport_locked := false
	var climbing := false
	var controls := Vector2.ZERO
	var jump_held := false
	var mine_ladder_top := 288.0
var failures := 0
var builds := 0
var transports := 0
func check(ok: bool, message: String) -> void:
	if ok: print("PASS placement controller: ", message)
	else:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var world := Node2D.new()
	root.add_child(world)
	var controller = preload("res://scripts/controllers/placeables.gd").new()
	var movable = preload("res://scripts/controllers/movable_objects.gd").new()
	var workshop = preload("res://scripts/workshop_state.gd").new()
	var items = preload("res://scripts/ore_state.gd").new()
	var needs = preload("res://scripts/needs_state.gd").new()
	var skills = preload("res://scripts/progression_state.gd").new()
	var day = preload("res://scripts/day_state.gd").new()
	var economy = preload("res://scripts/customer_state.gd").new()
	var transport = preload("res://scripts/transport_state.gd").new()
	var actors := {1: Actor.new(), 2: Actor.new()}
	for id in actors:
		needs.add(id)
		skills.add(id)
	economy.coins = 1000
	controller.attach_world(world)
	controller.bind(workshop, items, needs, day, func(_at: Vector2) -> int: return -1)
	controller.bind_workers(actors, {}, skills, {}, true)
	controller.bind_placement(transport, economy)
	controller.build_changed.connect(func(): builds += 1)
	controller.transport_changed.connect(func(): transports += 1)
	movable.bind(world, actors, items, transport, true)
	controller.purchase(1, "anvil")
	check(economy.coins == 980 and builds == 1 and workshop.pending.has(1), "Purchase reserves cost and emits build synchronization")
	check(controller.update_preview(1, Vector2(456, 216), true) and controller.preview.texture == controller.STATION_VIEW.TEXTURES.anvil, "Controller owns textured placement preview")
	controller.place(1, Vector2(56, 216))
	check(workshop.pending.has(1) and workshop.stations.is_empty(), "Blocked placement retains paid kit")
	controller.place(1, Vector2(456, 216))
	controller.refresh_stations()
	var station: int = workshop.nearest(Vector2(456, 216))
	check(controller.views.has(station) and not controller.update_preview(1, Vector2.ZERO, true), "Valid placement creates view and removes preview")
	workshop.stations[station].job.worker = 1
	controller.pack(1)
	check(workshop.stations.has(station), "Busy stations cannot be packed")
	workshop.stations[station].job.worker = 0
	controller.pack(1)
	controller.refresh_stations()
	check(controller.views.is_empty() and workshop.pending[1].id == station, "Packing removes view and retains kit identity")
	controller.place(1, Vector2(456, 136))
	controller.refresh_stations()
	check(controller.views[station].position == Vector2(456, 136), "Repositioning rebuilds stationary geometry at new location")
	actors[1].position = Vector2(456, 136)
	controller.pack(1)
	day.phase = "summary"
	controller.release_build(1)
	controller.release_build(1)
	check(economy.coins == 1000 and economy.refunds == 20 and workshop.pending.is_empty(), "Disconnect refunds exactly once even during summary")
	day.phase = "morning"
	controller.buy_transport(1, "lift", 2)
	check(transport.upgrades == 0 and economy.coins == 1000, "Cannot skip an elevator upgrade")
	controller.buy_transport(1, "lift", 1)
	controller.refresh_transport_views()
	check(transport.upgrades == 1 and controller.lift_node.visible and controller.rail_nodes.size() == 4 and actors[1].mine_ladder_top == 448, "Upgrade creates shaft, starter rails and ladder boundary")
	controller.buy_transport(1, "rail", 0)
	var paid: int = economy.coins
	controller.purchase(1, "anvil")
	check(not workshop.pending.has(1) and economy.coins == paid, "Rail kit blocks simultaneous workstation purchase")
	controller.place_rail(1, Vector2(262, 288))
	check(transport.pending.has(1), "Disconnected rail placement retains kit")
	controller.place_rail(1, Vector2(326, 288))
	check(not transport.pending.has(1) and Vector2(326, 288) in transport.tracks, "Rail extends adjacent starter track")
	actors[1].position = Vector2(390, 288)
	actors[2].position = Vector2(380, 288)
	# A cart on the platform remains owned by movable simulation.
	var cart: int = transport.buy_cart(Vector2(390, 288), economy)
	transport.carts[cart].driver = 1
	controller.use_lift(1, 1)
	check(controller.lift_riders.size() == 2 and actors[1].transport_locked, "Lift locks every rider on the platform")
	var previous: Dictionary = movable.cart_positions()
	var riders: Dictionary = controller.step_lift(1)
	movable.step_carts(1, previous, controller.lift_riders, riders)
	check(transport.lift_y == 368 and actors[1].position.y == 368 and actors[2].position.y == 368 and transport.carts[cart].at.y == 368, "Elevator then cart step moves driver exactly once")
	previous = movable.cart_positions()
	riders = controller.step_lift(1)
	movable.step_carts(1, previous, controller.lift_riders, riders)
	check(not transport.moving and controller.lift_riders.is_empty() and actors[1].position.y == 448, "Arrival clears lift ownership without doubling cart displacement")
	controller.step_lift(0)
	check(not actors[2].transport_locked, "Independent rider unlocks on next tick")
	controller.lift_riders[2] = true
	controller.forget_actor(2)
	check(not controller.lift_riders.has(2), "Disconnect releases rider bookkeeping")
	controller.authoritative = false
	paid = economy.coins
	controller.purchase(1, "anvil")
	controller.buy_transport(1, "lift", 2)
	controller.use_lift(1, -1)
	controller.step_lift(1)
	check(economy.coins == paid and transport.upgrades == 1 and transport.lift_y == 448, "Replica cannot purchase, place or move elevator")
	controller.clear()
	check(controller.views.is_empty() and controller.rail_nodes.is_empty() and controller.shaft_nodes.is_empty() and not controller.preview.visible and not controller.lift_node.visible and world.get_child_count() == 2, "Clear frees stationary views and keeps only reusable preview and lift scaffold")
	check(not actors[1].transport_locked and not controller.authoritative, "Clear releases character locks and disables simulation")
	movable.clear()
	world.free()
	print("PLACEMENT CONTROLLER RESULT: ", failures, " failures")
	quit(1 if failures else 0)
