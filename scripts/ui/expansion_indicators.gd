extends Control
## Owns marker controls and screen projection; emits purchase intent only.
signal room_requested(mine: bool, cell: Vector2i)
const ROOMS = preload("res://scripts/room_state.gd")
var buttons: Dictionary = {}
var targets: Dictionary = {}
var entrance_button: Button

func refresh(at: Vector2, rooms: RefCounted, progression: RefCounted, id: int, coins: int) -> void:
	# Keep controls alive when only prices/funds change; replace them after layout changes.
	var proposed: Dictionary = rooms.expansion_targets(at)
	if rooms.can_open_mine() and rooms.current_room(at) == Vector3i(ROOMS.SHAFT_COLUMN, 1, 0):
		proposed[Vector3i(1, 0, 1)] = {"at": Vector2(390, 242), "direction": Vector2i.ZERO}
	if proposed != targets:
		for button in buttons.values(): button.queue_free()
		buttons.clear()
		targets = proposed
		for key in targets:
			var button := Button.new()
			button.name = "Expansion_%s_%s_%s" % [key.x, key.y, key.z]
			button.focus_mode = Control.FOCUS_NONE
			button.custom_minimum_size = Vector2(64, 32)
			button.icon = preload("res://assets/textures/expand_room.svg")
			button.expand_icon = true
			button.add_theme_constant_override("icon_max_width", 20)
			button.pressed.connect(func(): room_requested.emit(key.z == 1, Vector2i(key.x, key.y)))
			add_child(button)
			buttons[key] = button
	entrance_button = buttons.get(Vector3i(1, 0, 1))
	for key in buttons:
		var entrance: bool = key == Vector3i(1, 0, 1)
		var base: int = ROOMS.ENTRANCE_PRICE if entrance else (ROOMS.DEPTH_PRICES[key.y] if key.z == 1 else ROOMS.PRICES[key.y])
		var cost: int = progression.purchase_price(id, base)
		var button: Button = buttons[key]
		var direction: Vector2i = targets[key].direction
		var arrow: String = "⛏" if entrance else ("←" if direction.x < 0 else ("→" if direction.x > 0 else ("↑" if direction.y < 0 else "↓")))
		button.text = "%s %s" % [arrow, cost]
		button.disabled = coins < cost
		button.tooltip_text = "%s · %s coins" % ["Open mine + first chamber" if entrance else ("Mine level %s" % key.y if key.z == 1 else ROOMS.NAMES[key.y]), cost]

func project(transform: Transform2D, viewport_rect: Rect2, obstacles: Array[Rect2], shown: bool) -> void:
	visible = shown
	viewport_rect = viewport_rect.grow(-20)
	for key in buttons:
		var button: Button = buttons[key]
		var target: Dictionary = targets[key]
		var point: Vector2 = transform * target.at
		# Slide top/bottom markers along the same outside edge to keep the HUD clear.
		if target.direction.y != 0:
			var room: Rect2 = target.room
			var left: float = (transform * room.position).x + button.size.x / 2 + 8
			var right: float = (transform * room.end).x - button.size.x / 2 - 8
			for occupied in obstacles:
				if occupied.intersects(Rect2(point - button.size / 2, button.size)):
					var beside: float = occupied.end.x + button.size.x / 2 + 8
					if beside <= right and beside >= left: point.x = beside
					else:
						beside = occupied.position.x - button.size.x / 2 - 8
						if beside >= left and beside <= right: point.x = beside
		button.position = (point - button.size / 2).round()
		button.visible = viewport_rect.has_point(point)

