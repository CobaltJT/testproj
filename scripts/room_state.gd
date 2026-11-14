extends RefCounted
## Owned cells are the source of truth for world geometry and accessible space.
const MAP = preload("res://scripts/map_layout.gd")
const LEFT := 48.0
const ROOM_WIDTH := 208.0
const COLUMNS := 5
const FLOOR_Y := {-2: 56.0, -1: 136.0, 0: 216.0, 1: 288.0}
const NAMES := {-2: "Second floor", -1: "First floor", 0: "Ground floor", 1: "Basement"}
const PRICES := {-2: 70, -1: 45, 0: 25, 1: 15}
const DEPTH_PRICES := {1: 25, 2: 40, 3: 60}
const ENTRANCE_PRICE := 30
const SHAFT_COLUMN := 1
var building: Dictionary = {Vector2i(0, 0): true, Vector2i(1, 0): true}
var underground: Dictionary = {}
var mine_open := false

func column(x: float) -> int:
	return floori((x - LEFT) / ROOM_WIDTH)

func floor_y(mine: bool, row: int) -> float:
	return MAP.MINE_FLOORS[row - 1] if mine and row in DEPTH_PRICES else FLOOR_Y.get(row, -9999)

func owned(mine: bool, cell: Vector2i) -> bool:
	return (underground if mine else building).has(cell)

func depth() -> int:
	var result := 0
	for row in range(1, 4):
		if underground.has(Vector2i(SHAFT_COLUMN, row)): result = row
	return result

func can_buy(mine: bool, cell: Vector2i) -> bool:
	if cell.x < 0 or cell.x >= COLUMNS or owned(mine, cell): return false
	if mine:
		if not mine_open or cell.y not in DEPTH_PRICES: return false
		if underground.has(cell + Vector2i.LEFT) or underground.has(cell + Vector2i.RIGHT): return true
		return cell.x == SHAFT_COLUMN and cell.y > 1 and underground.has(cell + Vector2i.UP)
	if cell.y not in FLOOR_Y: return false
	for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if building.has(cell + offset): return true
	return false

func buy(mine: bool, cell: Vector2i, economy: RefCounted, multiplier: float = 1.0) -> bool:
	if not can_buy(mine, cell): return false
	var cost := maxi(1, ceili((DEPTH_PRICES[cell.y] if mine else PRICES[cell.y]) * multiplier - 0.000001))
	if economy.coins < cost: return false
	economy.coins -= cost
	economy.spent += cost
	(underground if mine else building)[cell] = true
	return true

func can_open_mine() -> bool:
	return not mine_open and building.has(Vector2i(SHAFT_COLUMN, 1))

func buy_entrance(economy: RefCounted, multiplier: float = 1.0) -> bool:
	var cost := maxi(1, ceili(ENTRANCE_PRICE * multiplier - 0.000001))
	if not can_open_mine() or economy.coins < cost: return false
	economy.coins -= cost
	economy.spent += cost
	mine_open = true
	underground[Vector2i(SHAFT_COLUMN, 1)] = true
	return true

func room_rect(mine: bool, cell: Vector2i) -> Rect2:
	var height := 72.0 if not mine and cell.y == 1 else 80.0
	return Rect2(LEFT + cell.x * ROOM_WIDTH, floor_y(mine, cell.y) - height, ROOM_WIDTH, height)

func bounds() -> Rect2:
	var rect := room_rect(false, Vector2i.ZERO)
	for cell in building: rect = rect.merge(room_rect(false, cell))
	for cell in underground: rect = rect.merge(room_rect(true, cell))
	return rect

func contains_floor(at: Vector2, mine: bool = false) -> bool:
	if not at.is_finite(): return false
	var cells: Dictionary = underground if mine else building
	for cell in cells:
		if absf(floor_y(mine, cell.y) - at.y) < 0.1 and column(at.x) == cell.x: return true
	return false

func supports_station(at: Vector2, footprint: Rect2) -> bool:
	if not contains_floor(Vector2(footprint.position.x - 4, at.y)) or not contains_floor(Vector2(footprint.end.x + 4, at.y)): return false
	return true

func ladder_x(col: int) -> float:
	return LEFT + col * ROOM_WIDTH + (64 if col < 2 else 160)

func ladders() -> Array[Rect2]:
	var result: Array[Rect2] = []
	for col in range(COLUMNS):
		var start := -9999.0
		var end := -9999.0
		for row in [-2, -1, 0]:
			if building.has(Vector2i(col, row)) and building.has(Vector2i(col, row + 1)):
				if start == -9999: start = FLOOR_Y[row]
				end = FLOOR_Y[row + 1]
			elif start != -9999:
				result.append(Rect2(ladder_x(col) - 16, start, 32, end - start))
				start = -9999
		if start != -9999: result.append(Rect2(ladder_x(col) - 16, start, 32, end - start))
	if mine_open: result.append(Rect2(374, 288, 32, MAP.MINE_GAP + depth() * 80))
	return result

func floor_hole(mine: bool, cell: Vector2i) -> float:
	if mine:
		return 390.0 if cell.x == SHAFT_COLUMN and underground.has(cell + Vector2i.DOWN) else -1
	if cell.y == 1: return 390.0 if cell.x == SHAFT_COLUMN and mine_open else -1
	return ladder_x(cell.x) if building.has(cell + Vector2i.DOWN) else -1

func snapshot() -> Dictionary:
	return {"building": building.duplicate(), "underground": underground.duplicate(), "mine_open": mine_open}

func restore(state: Dictionary) -> void:
	building = state.building.duplicate()
	underground = state.underground.duplicate()
	mine_open = state.mine_open

func current_room(at: Vector2) -> Vector3i:
	# Feet rest on the bottom edge, which Rect2 normally excludes.
	for mine in [false, true]:
		var cells: Dictionary = underground if mine else building
		for cell in cells:
			if room_rect(mine, cell).has_point(at - Vector2(0, 1)):
				return Vector3i(cell.x, cell.y, int(mine))
	return Vector3i(-1, -99, -1)

func expansion_targets(at: Vector2) -> Dictionary:
	var result: Dictionary = {}
	var current := current_room(at)
	if current.z == -1: return result
	var mine := current.z == 1
	var cell := Vector2i(current.x, current.y)
	var rect := room_rect(mine, cell)
	for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var target: Vector2i = cell + offset
		if not can_buy(mine, target): continue
		var point := rect.get_center()
		if offset.x != 0: point.x = rect.end.x + 20 if offset.x > 0 else rect.position.x - 20
		else: point.y = rect.end.y + 20 if offset.y > 0 else rect.position.y - 20
		result[Vector3i(target.x, target.y, int(mine))] = {"at": point, "direction": offset, "room": rect}
	return result
