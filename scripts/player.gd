extends CharacterBody2D
## Positions and ladder bounds are in shared smithy-local coordinates.
## Velocity uses global physics pixels, independent of camera zoom (world scale 2x).
const SPEED := 170.0
const JUMP_SPEED := -300.0
const GRAVITY := 1000.0
const CLIMB_SPEED := 110.0
const MAP = preload("res://scripts/map_layout.gd")
var ladders: Array[Rect2] = []
var mine_ladder_index := -1
var mine_ladder_bottom := MAP.MINE_FLOORS[-1]
var transport_locked := false
var mine_ladder_top := 288.0
var walking_multiplier := 1.0
var knockback_x := 0.0
var hit_stun := 0.0
var networked := false
var controls := Vector2.ZERO
var jump_held := false
var previous_jump := false
var climb_held := false
var climbing := false
var active_ladder := -1
var ladder_jump_locked := false
var descending_floors: Array[PhysicsBody2D] = []
@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	set_camera_active(not networked)

func set_camera_active(local: bool) -> void:
	$FollowCamera.enabled = local
	if local:
		$FollowCamera.make_current()
		$FollowCamera.follow_now(true)

func _physics_process(delta: float) -> void:
	if networked and not multiplayer.is_server():
		return
	if transport_locked:
		velocity = Vector2.ZERO
		return
	clear_crossed_floors()
	hit_stun = maxf(0, hit_stun - delta)
	var horizontal := controls.x if networked else Input.get_axis("move_left", "move_right")
	var vertical := controls.y if networked else Input.get_axis("climb_up", "climb_down")
	var jump_pressed := (jump_held and not previous_jump) if networked else Input.is_action_just_pressed("jump")
	previous_jump = jump_held
	var holding_climb := climb_held if networked else (Input.is_action_pressed("climb_up") or Input.is_action_pressed("climb_down"))
	if climbing and active_ladder == mine_ladder_index and (mine_ladder_top >= mine_ladder_bottom or position.y < mine_ladder_top - 2): climbing = false
	if not holding_climb:
		ladder_jump_locked = false
	# A held Up can catch the ladder as an upward jump reaches its apex.
	if ladder_jump_locked and vertical < 0 and velocity.y < 0 and velocity.y + GRAVITY * delta >= 0:
		ladder_jump_locked = false
	if hit_stun == 0 and not climbing and not ladder_jump_locked and not jump_pressed and not is_zero_approx(vertical):
		for i in range(ladders.size()):
			var ladder := ladders[i]
			if i == mine_ladder_index:
				if mine_ladder_top >= mine_ladder_bottom: continue
				ladder = Rect2(374, mine_ladder_top, 32, mine_ladder_bottom - mine_ladder_top)
			if position.x >= ladder.position.x and position.x <= ladder.end.x and position.y >= ladder.position.y - 3 and position.y <= ladder.end.y + 1:
				if vertical < 0 and position.y <= ladder.position.y:
					continue
				active_ladder = i
				climbing = true
				break
	if climbing:
		var ladder := ladders[active_ladder]
		if active_ladder == mine_ladder_index: ladder = Rect2(374, mine_ladder_top, 32, mine_ladder_bottom - mine_ladder_top)
		velocity = Vector2(horizontal * SPEED * walking_multiplier, vertical * CLIMB_SPEED)
		if jump_pressed:
			climbing = false
			ladder_jump_locked = true
			velocity.y = CLIMB_SPEED if vertical > 0 else JUMP_SPEED
		else:
			# Limit vertical travel without snapping; clear the floor collision margin
			# at the top so horizontal movement can reach the landing.
			var pixels_per_unit := global_scale.y
			velocity.y = clampf(velocity.y,
				(ladder.position.y - 0.25 - position.y) * pixels_per_unit / delta,
				(ladder.end.y - position.y) * pixels_per_unit / delta)

	else:
		velocity.x = horizontal * SPEED * walking_multiplier
		if not is_on_floor():
			velocity.y += GRAVITY * delta
		if jump_pressed and is_on_floor():
			velocity.y = JUMP_SPEED
	if not is_zero_approx(horizontal):
		sprite.flip_h = horizontal < 0
	velocity.x += knockback_x
	knockback_x = move_toward(knockback_x, 0, 700 * delta)
	set_collision_mask_value(5, not (climbing and active_ladder == mine_ladder_index and vertical > 0))
	if climbing and vertical > 0: descend_through_floor()
	move_and_slide()
	if is_on_floor():
		ladder_jump_locked = false

	if climbing:
		var ladder := ladders[active_ladder]
		if position.x < ladder.position.x or position.x > ladder.end.x:
			climbing = false

func apply_ore_hit(impulse: Vector2) -> void:
	climbing = false
	ladder_jump_locked = true
	hit_stun = 0.25
	knockback_x = clampf(impulse.x, -260, 260)
	velocity.y = minf(velocity.y, -100.0)

func set_ladders(value: Array) -> void:
	var old_x: float = ladders[active_ladder].get_center().x if climbing and active_ladder >= 0 and active_ladder < ladders.size() else -9999
	ladders.assign(value)
	mine_ladder_index = -1
	for i in range(ladders.size()):
		if ladders[i].position == Vector2(374, 288):
			mine_ladder_index = i
			mine_ladder_bottom = ladders[i].end.y
	climbing = false
	active_ladder = -1
	for i in range(ladders.size()):
		if ladders[i].get_center().x == old_x and position.y >= ladders[i].position.y - 1 and position.y <= ladders[i].end.y + 1:
			active_ladder = i
			climbing = true
			break

func clear_crossed_floors() -> void:
	for index in range(descending_floors.size() - 1, -1, -1):
		var floor_body := descending_floors[index]
		if not is_instance_valid(floor_body):
			descending_floors.remove_at(index)
			continue
		var feet_y: float = floor_body.to_local(global_position).y
		# Keep this one exception until the entire character clears the eight-pixel floor.
		if feet_y > 4 + 23 + 1 or feet_y < -5:
			remove_collision_exception_with(floor_body)
			descending_floors.remove_at(index)

func descend_through_floor() -> void:
	var ladder := ladders[active_ladder]
	if active_ladder == mine_ladder_index:
		ladder = Rect2(374, mine_ladder_top, 32, mine_ladder_bottom - mine_ladder_top)
	var query := PhysicsRayQueryParameters2D.create(to_global(Vector2(0, -1)), to_global(Vector2(0, 2)), 1, [get_rid()])
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty(): return
	var floor_body = hit.collider
	if not floor_body.has_meta("floor_y") or floor_body.get_meta("floor_y") >= ladder.end.y - 0.5: return
	if floor_body not in descending_floors:
		add_collision_exception_with(floor_body)
		descending_floors.append(floor_body)
