extends CharacterBody2D
## Positions and ladder bounds are in shared smithy-local coordinates.
## Velocity uses global physics pixels, independent of camera zoom (world scale 2x).
const SPEED := 170.0
const JUMP_SPEED := -300.0
const GRAVITY := 1000.0
const CLIMB_SPEED := 110.0
const MAP = preload("res://scripts/map_layout.gd")
const LADDERS: Array[Rect2] = MAP.LADDERS
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
	hit_stun = maxf(0, hit_stun - delta)
	var horizontal := controls.x if networked else Input.get_axis("move_left", "move_right")
	var vertical := controls.y if networked else Input.get_axis("climb_up", "climb_down")
	var jump_pressed := (jump_held and not previous_jump) if networked else Input.is_action_just_pressed("jump")
	previous_jump = jump_held
	var holding_climb := climb_held if networked else (Input.is_action_pressed("climb_up") or Input.is_action_pressed("climb_down"))
	if not holding_climb:
		ladder_jump_locked = false
	# A held Up can catch the ladder as an upward jump reaches its apex.
	if ladder_jump_locked and vertical < 0 and velocity.y < 0 and velocity.y + GRAVITY * delta >= 0:
		ladder_jump_locked = false
	if hit_stun == 0 and not climbing and not ladder_jump_locked and not jump_pressed and not is_zero_approx(vertical):
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
		velocity.x = horizontal * SPEED
		if not is_on_floor():
			velocity.y += GRAVITY * delta
		if jump_pressed and is_on_floor():
			velocity.y = JUMP_SPEED
	if not is_zero_approx(horizontal):
		sprite.flip_h = horizontal < 0
	velocity.x += knockback_x
	knockback_x = move_toward(knockback_x, 0, 700 * delta)
	move_and_slide()
	if is_on_floor():
		ladder_jump_locked = false

	if climbing:
		var ladder := LADDERS[active_ladder]
		if position.x < ladder.position.x or position.x > ladder.end.x:
			climbing = false

func apply_ore_hit(impulse: Vector2) -> void:
	climbing = false
	ladder_jump_locked = true
	hit_stun = 0.25
	knockback_x = clampf(impulse.x, -260, 260)
	velocity.y = minf(velocity.y, -100.0)
