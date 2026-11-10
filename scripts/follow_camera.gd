extends Camera2D
## Only the local dwarf enables this camera; camera state is never replicated.
const MAP = preload("res://scripts/map_layout.gd")
func _ready() -> void:
	limit_left = 0
	limit_top = 0
	limit_right = int(MAP.WIDTH * MAP.SCALE)
	limit_bottom = int(MAP.HEIGHT * MAP.SCALE)
	get_viewport().size_changed.connect(update_zoom)
	update_zoom()

func update_zoom() -> void:
	var factor := get_viewport_rect().size.y / (MAP.CAMERA_HEIGHT * MAP.SCALE)
	zoom = Vector2.ONE * maxf(factor, 0.01)

func follow_now(reset: bool = false) -> void:
	global_position = get_parent().global_position - Vector2(0, MAP.CAMERA_ABOVE_FEET * MAP.SCALE)
	if reset:
		reset_smoothing()
	force_update_scroll()

func _process(_delta: float) -> void:
	if enabled:
		follow_now()
