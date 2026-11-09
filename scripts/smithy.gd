@tool
extends Node2D
## Static cutaway blockout. Coordinates use a 480 x 320 pixel art canvas.
## Gameplay, collisions, and network authority arrive in later milestones.

const INK = Color("171b26")
const STONE = Color("434552")
const MORTAR = Color("30313e")
const WOOD = Color("79543c")
const EDGE = Color("bc8750")
const TEXT = Color("ead7b0")

func _ready() -> void:
	scale = Vector2(2, 2)

func box(x: float, y: float, w: float, h: float, color: Color) -> void:
	draw_rect(Rect2(x, y, w, h), color)

func label_at(text: String, x: float, y: float, color: Color = TEXT, size: int = 8) -> void:
	draw_string(ThemeDB.fallback_font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func floor_at(y: int, gap_x: int) -> void:
	for x in range(48, 432, 16):
		if x >= gap_x and x < gap_x + 32:
			continue
		box(x, y, 16, 8, WOOD)
		box(x, y, 15, 2, EDGE)
		box(x + 2, y + 5, 2, 1, INK)

func ladder(x: int, top: int, bottom: int) -> void:
	box(x, top, 3, bottom - top, EDGE)
	box(x + 23, top, 3, bottom - top, EDGE)
	for y in range(top + 5, bottom, 9):
		box(x, y, 26, 2, WOOD)

func crate(x: int, y: int) -> void:
	box(x, y, 22, 20, WOOD)
	box(x + 2, y + 2, 18, 16, EDGE)
	box(x + 4, y + 4, 14, 12, WOOD)
	draw_line(Vector2(x + 3, y + 3), Vector2(x + 19, y + 17), EDGE, 2)

func _draw() -> void:
	box(0, 0, 480, 320, Color("141c29"))
	label_at("HEARTH & HAMMER", 24, 25, TEXT, 16)
	label_at("A DWARVEN SMITHY  /  BUILDING STUDY", 25, 39, Color("8b9aaa"))
	box(48, 66, 384, 224, MORTAR)
	for row in range(14):
		for col in range(13):
			var x := 48 + col * 32 - (16 if row % 2 else 0)
			box(maxi(x, 48), 66 + row * 16, mini(30, 432 - maxi(x, 48)), 14, STONE if row < 9 else Color("383a47"))
	# Roof silhouette and structural beams.
	draw_colored_polygon(PackedVector2Array([Vector2(36, 66), Vector2(80, 48), Vector2(400, 48), Vector2(444, 66)]), Color("583b36"))
	box(46, 66, 388, 5, EDGE)
	for x in [44, 428]:
		box(x, 66, 8, 224, WOOD)
	floor_at(136, 352)
	floor_at(216, 96)
	floor_at(288, -100)
	ladder(355, 115, 216)
	ladder(99, 196, 288)
	# Upstairs: workbench, storage, and cool daylight.
	label_at("WORKSHOP & STORAGE", 64, 84)
	for x in [80, 224]:
		box(x, 92, 32, 28, INK)
		box(x + 3, 95, 26, 22, Color("749ba3"))
		box(x + 15, 93, 2, 26, EDGE)
		box(x + 2, 105, 28, 2, EDGE)
	crate(285, 116)
	crate(310, 116)
	box(148, 120, 54, 5, EDGE)
	box(152, 125, 4, 11, WOOD)
	box(194, 125, 4, 11, WOOD)
	# Ground floor: customer entrance, counter, anvil, and forge.
	label_at("CUSTOMERS", 64, 157)
	box(58, 172, 25, 44, INK)
	box(60, 174, 21, 42, WOOD)
	box(76, 194, 2, 2, TEXT)
	box(142, 197, 59, 19, WOOD)
	box(138, 193, 67, 5, EDGE)
	label_at("ORDERS", 149, 189)
	box(244, 194, 33, 6, Color("9ba7ad"))
	box(252, 200, 13, 9, Color("687582"))
	box(246, 209, 26, 7, Color("687582"))
	box(376, 158, 34, 58, MORTAR)
	box(372, 182, 42, 34, Color("90604a"))
	box(378, 187, 30, 23, INK)
	box(382, 195, 22, 15, Color("d56c37"))
	box(387, 191, 7, 17, Color("f4b95d"))
	box(395, 199, 5, 9, TEXT)
	label_at("FORGE", 377, 177)
	# Basement: ore stockpile and a closed mine entrance.
	label_at("CELLAR / MINE ACCESS", 144, 237)
	crate(150, 268)
	crate(175, 268)
	for i in range(5):
		box(218 + i * 7, 282 - (i % 2) * 5, 8, 6, Color("90a4ad"))
	box(335, 247, 62, 41, INK)
	box(331, 243, 70, 6, WOOD)
	box(332, 249, 6, 39, WOOD)
	box(394, 249, 6, 39, WOOD)
	for x in range(344, 394, 12):
		box(x, 250, 3, 38, Color("51535d"))
	label_at("MINES", 352, 266)
	box(24, 303, 432, 1, Color("394452"))
	label_at("STAGE 01  /  Layout preview - movement and LAN co-op come next", 24, 315, Color("9aa7b2"))
