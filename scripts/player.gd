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
@onready var sprite: Sprite2D = $Sprite2D

func _physics_process(delta: float) -> void:
	var horizontal := Input.get_axis("move_left", "move_right")
	var vertical := Input.get_axis("climb_up", "climb_down")
	if not climbing and not is_zero_approx(vertical):
		for i in range(LADDERS.size()):
			var ladder := LADDERS[i]
			if position.x >= ladder.position.x and position.x <= ladder.end.x and position.y >= ladder.position.y - 3 and position.y <= ladder.end.y + 1:
				if vertical < 0 and position.y <= ladder.position.y:
					continue
				active_ladder = i
				climbing = true
				position.x = ladder.get_center().x
				break
	if climbing:
		var ladder := LADDERS[active_ladder]
		velocity = Vector2(0, vertical * CLIMB_SPEED)
		if Input.is_action_just_pressed("jump") or not is_zero_approx(horizontal):
			climbing = false
			velocity = Vector2(horizontal * SPEED, JUMP_SPEED if Input.is_action_just_pressed("jump") else 0.0)
		else:
			# Move through the actual floor opening, then step onto its left lip.
			if vertical < 0 and position.y <= ladder.position.y:
				position = Vector2(ladder.position.x - 9, ladder.position.y)
				climbing = false
				velocity = Vector2.ZERO
			elif vertical > 0 and position.y >= ladder.end.y - 1:
				position.y = ladder.end.y
				climbing = false
				velocity = Vector2.ZERO
	else:
		velocity.x = horizontal * SPEED
		if not is_on_floor():
			velocity.y += GRAVITY * delta
		if Input.is_action_just_pressed("jump") and is_on_floor():
			velocity.y = JUMP_SPEED
	if not is_zero_approx(horizontal):
		sprite.flip_h = horizontal < 0
	move_and_slide()
