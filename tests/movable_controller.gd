extends SceneTree
## Exercise the movable-object owner without a Session or multiplayer peer.
const MOVABLE = preload("res://scripts/controllers/movable_objects.gd")
const ITEMS = preload("res://scripts/ore_state.gd")
const TRANSPORT = preload("res://scripts/transport_state.gd")
const CONTEXT = preload("res://scripts/interaction/context.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if ok: print("PASS movable controller: ", message)
	else:
		failures += 1
		push_error(message)
func frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var world = preload("res://scenes/smithy.tscn").instantiate()
	root.add_child(world)
	var dwarf = world.get_node("Player")
	dwarf.networked = true
	var actors := {1: dwarf}
	var items = ITEMS.new()
	var transport = TRANSPORT.new()
	var movable = MOVABLE.new()
	movable.bind(world, actors, items, transport, true)
	movable.items_changed.connect(movable.refresh)
	movable.spawn_initial_items()
	await frames(5)
	check(movable.bodies.size() == 8 and movable.bodies[0].get_parent() == world and not movable.bodies[0].freeze, "Controller owns and simulates initial bodies without the session")
	items.pickup(1, 0)
	movable.refresh()
	check(movable.bodies[0].freeze and not movable.bodies[0].visible and dwarf.get_node("CarriedOre").visible, "Inventory ownership drives body and carried-item presentation")
	check(movable.release(1, false) and items.is_loose(0) and movable.bodies[0].linear_velocity.x > 250 and movable.throw_grace.has(0), "Throwing updates physics, ownership and thrower grace")
	var motion: Array = movable.motion_snapshot()
	check(motion.size() == 8 and motion[0][0] == 0 and motion[0][1] == movable.bodies[0].global_position, "Motion snapshots retain original network shape")
	# Receiver dispatch is explicit and preserves descending-only catches.
	var observed: Array = []
	movable.catch_stationary = func(piece: int, _body: RigidBody2D):
		observed.append(piece)
		if piece != 0: return false
		items.pieces[piece].processing = true
		return true
	movable.position_body(movable.bodies[0], Vector2(350, 180), Vector2(0, -100))
	movable.step_loose()
	check(0 not in observed and items.is_loose(0), "Rising items do not enter stationary receivers")
	movable.position_body(movable.bodies[0], Vector2(350, 180), Vector2(0, 100))
	movable.step_loose()
	check(0 in observed and items.pieces[0].processing and not movable.bodies[0].visible, "Descending items use the injected stationary receiver and hide after capture")
	# Cart movement is owned here; the elevator supplies passenger coordination.
	transport.upgrades = 1
	transport.tracks = [Vector2(358, 288), Vector2(326, 288)]
	transport.carts[1] = {"at": Vector2(358, 288), "items": [], "driver": 1}
	movable.refresh_carts()
	dwarf.position = Vector2(358, 288)
	dwarf.controls = Vector2(-1, 0)
	var previous: Dictionary = movable.cart_positions()
	movable.step_carts(0.1, previous, {}, {})
	check(transport.carts[1].at.x < 358 and dwarf.position.x == 358 and dwarf.transport_locked, "Cart moves across its driver without snapping them")
	dwarf.jump_held = true
	movable.step_carts(0.1, movable.cart_positions(), {}, {})
	check(transport.carts[1].driver == 0, "Jump releases a driven cart")
	dwarf.jump_held = false
	transport.carts[1].driver = 1
	movable.hit_cooldowns[Vector2i(0, 1)] = Time.get_ticks_msec() + 400
	movable.forget_actor(1)
	check(not movable.throw_grace.has(0) and movable.hit_cooldowns.is_empty() and transport.carts[1].driver == 0, "Actor cleanup clears hit history, grace and cart ownership")
	var old_body: Node = movable.bodies[0]
	var old_cart: Node = movable.cart_nodes[1]
	movable.clear()
	check(not is_instance_valid(old_body) and not is_instance_valid(old_cart) and movable.bodies.is_empty() and movable.cart_nodes.is_empty() and not movable.authoritative, "Reset frees owned nodes and disables simulation")
	var replica_items = ITEMS.new()
	var replica_transport = TRANSPORT.new()
	movable.bind(world, actors, replica_items, replica_transport, false)
	movable.spawn_initial_items()
	check(movable.bodies[0].freeze and movable.bodies[0].collision_layer == 0, "Replica bodies are frozen and non-colliding")
	replica_items.pickup(1, 0)
	movable.refresh()
	check(not movable.release(1, false) and replica_items.carried_by(1) == 0, "Replica controller cannot execute authoritative throws")
	movable.apply_motion([[0, Vector2(600, 300), 0.5, Vector2.ZERO]])
	check(movable.bodies[0].global_position == Vector2(600, 300) and movable.bodies[0].freeze, "Replica applies host motion without enabling local simulation")
	var extra: int = replica_items.add_material("food")
	var replica_body := movable.create_body(extra, true, Vector2(320, 208))
	movable.position_body(replica_body, Vector2(320, 208), Vector2(100, 0))
	check(replica_body.freeze and replica_body.collision_layer == 0 and replica_body.get_node("Sprite2D").texture == movable.material_texture("food"), "Factory selects item texture and preserves replica authority")
	movable.clear()
	world.free()
	print("MOVABLE CONTROLLER RESULT: ", failures, " failures")
	quit(1 if failures else 0)
