extends SceneTree
const MAP = preload("res://scripts/map_layout.gd")
var session: Node
var failures := 0
func check(ok: bool, message: String) -> void:
	if ok: print("PASS camera: ", message)
	else:
		failures += 1
		push_error(message)
func frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame
func height_in_world() -> float:
	var transform: Transform2D = session.world.get_global_transform_with_canvas().affine_inverse()
	return ((transform * Vector2(0, root.get_visible_rect().size.y)) - (transform * Vector2.ZERO)).y
func _initialize() -> void: call_deferred("run")
func run() -> void:
	session = load("res://scenes/session.tscn").instantiate()
	root.add_child(session)
	await frames(3)
	check(root.get_camera_2d() == session.overview_camera, "Menu shows building overview")
	session.host_game()
	await frames(10)
	var dwarf = session.players[1]
	var camera: Camera2D = dwarf.get_node("FollowCamera")
	check(root.get_camera_2d() == camera and camera.enabled, "Local dwarf owns active gameplay camera")
	check(absf(height_in_world() - MAP.CAMERA_HEIGHT) < 0.1, "Actual camera canvas shows 96 world pixels: 1.2 floors")
	var hud: Vector2 = session.order_label.get_global_transform_with_canvas().origin
	dwarf.position = Vector2(500, 216)
	dwarf.velocity = Vector2.ZERO
	await frames(60)
	check(camera.get_screen_center_position().distance_to(dwarf.global_position - Vector2(0, 64)) < 2, "Camera follows horizontal movement into new wing")
	check(dwarf.is_on_floor(), "Expanded ground floor supports dwarf in new wing")
	check(session.order_label.get_global_transform_with_canvas().origin == hud, "HUD stays fixed while camera moves")
	dwarf.position = Vector2(500, 136)
	dwarf.velocity = Vector2.ZERO
	await frames(60)
	check(camera.get_screen_center_position().distance_to(dwarf.global_position - Vector2(0, 64)) < 2 and dwarf.is_on_floor(), "Camera follows to expanded upper floor")
	session.spawn_player(2, Vector2(80, 288))
	await frames(5)
	check(not session.players[2].get_node("FollowCamera").enabled and root.get_camera_2d() == camera, "Remote camera stays disabled")
	var center := camera.get_screen_center_position()
	session.players[2].position = Vector2(550, 216)
	await frames(20)
	check(camera.get_screen_center_position().distance_to(center) < 1, "Remote movement cannot redirect local view")
	# Verify placement uses current camera transform, not old overview coordinates.
	session.purchase_for(1, "anvil")
	await frames(5)
	var at := Vector2(512, 136)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = session.world.get_global_transform_with_canvas() * at
	session._unhandled_input(event)
	await frames(5)
	check(session.workshop.stations.size() == 1 and session.workshop.stations.values()[0].at == at, "Zoomed placement click reaches correct new-wing grid position")
	for y in [136, 216, 288]:
		dwarf.position = Vector2(582, y)
		dwarf.velocity = Vector2.ZERO
		await frames(60)
		var screen_center := camera.get_screen_center_position()
		var half := root.get_visible_rect().size / camera.zoom / 2
		check(screen_center.x - half.x >= -0.1 and screen_center.x + half.x <= MAP.WIDTH * 2 + 0.1 and screen_center.y + half.y <= MAP.HEIGHT * 2 + 0.1, "Camera respects world bounds on floor %s" % y)
		check(dwarf.is_on_floor(), "Expanded floor %s supports right-edge dwarf" % y)
	var old_size := root.size
	root.size = Vector2i(1280, 800)
	await frames(10)
	check(absf(height_in_world() - MAP.CAMERA_HEIGHT) < 0.1, "Window resize preserves floor-height camera view")
	root.size = old_size
	session.disconnect_game("Done")
	await frames(5)
	check(root.get_camera_2d() == session.overview_camera, "Leaving restores overview camera")
	print("CAMERA RESULT: ", failures, " failures")
	quit(1 if failures else 0)
