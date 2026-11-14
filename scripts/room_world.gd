extends Node2D
const ROOMS = preload("res://scripts/room_state.gd")
const BRICK = preload("res://assets/textures/room_brick.svg")
const ROCK = preload("res://assets/textures/room_rock.svg")
const WOOD = preload("res://assets/textures/room_floor.svg")
const STONE = preload("res://assets/textures/room_stone.svg")
const LADDER = preload("res://assets/textures/room_ladder.svg")
var generated: Node2D
var collision: StaticBody2D
var entrance: Node2D

func _enter_tree() -> void:
	entrance = Node2D.new()
	entrance.name = "MineEntrance"
	entrance.position = Vector2(390, 288)
	entrance.z_index = -8
	add_child(entrance)

func _ready() -> void:
	configure(ROOMS.new())

func picture(parent: Node, texture: Texture2D, at: Vector2, size: Vector2 = Vector2.ZERO) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = false
	sprite.position = at
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if size != Vector2.ZERO: sprite.scale = size / texture.get_size()
	parent.add_child(sprite)
	return sprite

func solid(rect: Rect2) -> void:
	if rect.size.x <= 0 or rect.size.y <= 0: return
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	shape.position = rect.get_center()
	collision.add_child(shape)

func floor_piece(x: float, y: float, width: float, mine: bool) -> void:
	if width <= 0: return
	solid(Rect2(x, y, width, 8))
	var at := x
	while at < x + width - 0.01:
		picture(generated, STONE if mine else WOOD, Vector2(at, y), Vector2(minf(16, x + width - at), 8))
		at += 16

func configure(layout: RefCounted) -> void:
	if generated != null: generated.free()
	if collision != null: collision.free()
	generated = Node2D.new()
	generated.name = "Building"
	generated.z_index = -10
	add_child(generated)
	collision = StaticBody2D.new()
	collision.name = "Collision"
	add_child(collision)
	for mine in [false, true]:
		var cells: Dictionary = layout.underground if mine else layout.building
		for cell in cells:
			var rect: Rect2 = layout.room_rect(mine, cell)
			picture(generated, ROCK if mine else BRICK, rect.position, rect.size).z_index = -1
			var hole: float = layout.floor_hole(mine, cell)
			if hole < 0: floor_piece(rect.position.x, rect.end.y, rect.size.x, mine)
			else:
				floor_piece(rect.position.x, rect.end.y, hole - 16 - rect.position.x, mine)
				floor_piece(hole + 16, rect.end.y, rect.end.x - hole - 16, mine)
			if not cells.has(cell + Vector2i.LEFT):
				solid(Rect2(rect.position.x - 4, rect.position.y, 8, rect.size.y + 8))
				picture(generated, STONE, rect.position - Vector2(4, 0), Vector2(8, rect.size.y + 8))
			if not cells.has(cell + Vector2i.RIGHT):
				solid(Rect2(rect.end.x - 4, rect.position.y, 8, rect.size.y + 8))
				picture(generated, STONE, Vector2(rect.end.x - 4, rect.position.y), Vector2(8, rect.size.y + 8))
			var above: bool = cells.has(cell + Vector2i.UP)
			if mine and cell.y == 1: above = layout.building.has(Vector2i(cell.x, 1))
			if not above:
				solid(Rect2(rect.position.x, rect.position.y - 4, rect.size.x, 4))
				picture(generated, STONE, rect.position - Vector2(0, 4), Vector2(rect.size.x, 4))
	# Earth separates the basement from the first chamber; only the shaft is open.
	for cell in layout.underground:
		if cell.y != 1: continue
		var rect: Rect2 = layout.room_rect(true, cell)
		var band := Rect2(rect.position.x, 288, rect.size.x, ROOMS.MAP.MINE_GAP)
		picture(generated, ROCK, band.position, band.size).z_index = -1
		if cell.x == ROOMS.SHAFT_COLUMN:
			solid(Rect2(band.position, Vector2(374 - band.position.x, band.size.y)))
			solid(Rect2(406, band.position.y, band.end.x - 406, band.size.y))
			picture(generated, preload("res://assets/textures/mine_shaft.svg"), Vector2(374, 288), Vector2(32, ROOMS.MAP.MINE_GAP))
		else: solid(band)
	for child in entrance.get_children(): child.free()
	entrance.visible = layout.mine_open or layout.can_open_mine()
	picture(entrance, preload("res://assets/textures/mine_entrance.svg") if layout.mine_open else preload("res://assets/textures/mine_sign.svg"), Vector2(-22, -36))
	for ladder in layout.ladders():
		var y: float = ladder.position.y
		while y < ladder.end.y:
			picture(generated, LADDER, Vector2(ladder.get_center().x - 8, y), Vector2(16, minf(8, ladder.end.y - y)))
			y += 8
	picture(generated, preload("res://assets/textures/room_counter.svg"), Vector2(132, 192))
	picture(generated, preload("res://assets/textures/room_door.svg"), Vector2(60, 180))
	if has_node("Player"):
		$Player.set_ladders(layout.ladders())
