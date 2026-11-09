extends SceneTree
var failures := 0
var player: CharacterBody2D

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
	else:
		print("PASS: ", message)

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame

func hold(action: String, count: int) -> void:
	Input.action_press(action)
	await frames(count)
	Input.action_release(action)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world = load("res://scenes/smithy.tscn").instantiate()
	root.add_child(world)
	player = world.get_node("Player")
	await frames(10)
	check(player.is_on_floor() and absf(player.position.y - 216) < 1, "Spawn rests on ground floor")
	var start := player.position.x
	await hold("move_right", 20)
	check(player.position.x > start + 20, "Walk right")
	await hold("jump", 1)
	await frames(8)
	check(player.position.y < 205, "Jump leaves ground")
	await frames(80)
	check(player.is_on_floor(), "Jump lands on floor")
	await hold("move_right", 180)
	check(player.position.x <= 422.1, "Right wall contains dwarf")
	player.position = Vector2(70, 216)
	player.velocity = Vector2.ZERO
	await frames(5)
	await hold("move_left", 60)
	check(player.position.x >= 57.9, "Left wall contains dwarf")
	for entry in [[Vector2(368, 216), "climb_up", 136.0], [Vector2(368, 136), "climb_down", 216.0], [Vector2(112, 216), "climb_down", 288.0], [Vector2(112, 288), "climb_up", 216.0]]:
		player.position = entry[0]
		player.velocity = Vector2.ZERO
		player.climbing = false
		await hold(entry[1], 130)
		await frames(5)
		check(absf(player.position.y - entry[2]) < 2, "Ladder route %s to %s" % [entry[0], entry[2]])
	player.position = Vector2(368, 180)
	player.velocity = Vector2.ZERO
	player.climbing = false
	await hold("climb_up", 2)
	var stopped := player.position.y
	await frames(20)
	check(player.climbing and absf(player.position.y - stopped) < 1, "Release input holds position on ladder")
	await hold("jump", 1)
	check(not player.climbing and player.velocity.y < 0, "Jump detaches from ladder")
	player.position = Vector2(112, 260)
	player.velocity = Vector2.ZERO
	player.climbing = false
	await frames(60)
	check(player.is_on_floor() and absf(player.position.y - 288) < 1, "Cellar floor catches falling dwarf")
	print("Movement checks complete: ", failures, " failures")
	quit(1 if failures else 0)
