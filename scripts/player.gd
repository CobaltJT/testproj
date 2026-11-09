extends CharacterBody2D
## Positions and ladder bounds are in the smithy's 480 x 320 local coordinates.
## Velocity is in viewport pixels per second (the building is scaled by two).
const SPEED := 170.0
const JUMP_SPEED := -300.0
const GRAVITY := 1000.0
const CLIMB_SPEED := 110.0
const LADDERS: Array[Rect2] = [Rect2(352, 136, 32, 80), Rect2(96, 216, 32, 72)]
var climbing := false
var active_ladder := -1
var ladder_jump_locked := false
@onready var sprite: Sprite2D = $Sprite2D

func _physics_process(delta: float) -> void:
	var horizontal := Input.get_axis("move_left", "move_right")
	var vertical := Input.get_axis("climb_up", "climb_down")
	if not Input.is_action_pressed("climb_up") and not Input.is_action_pressed("climb_down"):
		ladder_jump_locked = false
	# A held Up can catch the ladder as an upward jump reaches its apex.
	if ladder_jump_locked and vertical < 0 and velocity.y < 0 and velocity.y + GRAVITY * delta >= 0:
		ladder_jump_locked = false
	if not climbing and not ladder_jump_locked and not Input.is_action_just_pressed("jump") and not is_zero_approx(vertical):
		for i in range(LADDERS.size()):
			var ladder := LADDERS[i]
			if position.x >= ladder.position.x and position.x <= ladder.end.x and position.y >= ladder.position.y - 3 and position.y <= ladder.end.y + 1:
				if vertical < 0 and position.y <= ladder.position.y:
					continue
				active_ladder = i
				climbing = true
				break
	if climbing:
		var ladder := LADDERS[active_ladder]
		velocity = Vector2(horizontal * SPEED, vertical * CLIMB_SPEED)
		if Input.is_action_just_pressed("jump"):
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
		velocity.x = horizontal * SPEED
		if not is_on_floor():
			velocity.y += GRAVITY * delta
		if Input.is_action_just_pressed("jump") and is_on_floor():
			velocity.y = JUMP_SPEED
	if not is_zero_approx(horizontal):
		sprite.flip_h = horizontal < 0
	move_and_slide()
	if is_on_floor():
		ladder_jump_locked = false

	if climbing:
		var ladder := LADDERS[active_ladder]
		if position.x < ladder.position.x or position.x > ladder.end.x:
			climbing = false
