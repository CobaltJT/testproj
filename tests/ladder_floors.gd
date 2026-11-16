extends SceneTree
var failures := 0
var player: CharacterBody2D
func check(ok: bool, message: String) -> void:
	if ok: print("PASS ladder floors: ", message)
	else:
		failures += 1
		push_error(message)
func frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame
func stand(at: Vector2) -> void:
	player.position = at
	player.velocity = Vector2.ZERO
	player.climbing = false
	await frames(4)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var world = preload("res://scenes/smithy.tscn").instantiate()
	root.add_child(world)
	var layout = preload("res://scripts/room_state.gd").new()
	preload("res://tests/world_fixture.gd").fill(layout)
	world.configure(layout)
	player = world.get_node("Player")
	await stand(Vector2(296, 216))
	Input.action_press("move_right")
	await frames(35)
	Input.action_release("move_right")
	check(player.position.x > 336 and player.is_on_floor() and absf(player.position.y - 216) < 1, "Walking over building ladder stays on continuous floor")
	await stand(Vector2(320, 216))
	Input.action_press("climb_down")
	await frames(12)
	Input.action_release("climb_down")
	check(player.climbing and player.position.y > 220, "Down enters ladder through closed floor")
	await frames(10)
	var paused: float = player.position.y
	await frames(10)
	check(absf(player.position.y - paused) < 0.1, "Releasing Down holds position inside crossing")
	# Leave ladder after the upper floor clears; lower floor must still catch us.
	Input.action_press("move_right")
	await frames(22)
	Input.action_release("move_right")
	await frames(65)
	check(player.is_on_floor() and absf(player.position.y - 288) < 1, "Dropping past one floor preserves collision with lower floor")
	await stand(Vector2(320, 288))
	Input.action_press("climb_up")
	await frames(100)
	Input.action_release("climb_up")
	check(player.climbing and player.position.y < 216, "Climbing upward passes through closed ceiling and intermediate floor")
	await stand(Vector2(280, 216))
	Input.action_press("climb_down")
	await frames(35)
	Input.action_release("climb_down")
	check(player.is_on_floor() and absf(player.position.y - 216) < 1 and not player.climbing, "Down away from ladder cannot bypass floor")
	await stand(Vector2(366, 448))
	Input.action_press("move_right")
	await frames(35)
	Input.action_release("move_right")
	check(player.position.x > 406 and absf(player.position.y - 448) < 1 and player.is_on_floor(), "Walking across mine ladder stays on mine floor")
	await stand(Vector2(390, 448))
	Input.action_press("climb_down")
	await frames(80)
	Input.action_release("climb_down")
	check(player.position.y > 510 and player.climbing, "Down traverses closed mine floor")
	world.free()
	print("LADDER FLOORS RESULT: ", failures, " failures")
	quit(1 if failures else 0)
