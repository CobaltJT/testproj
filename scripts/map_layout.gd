extends RefCounted
## Shared smithy-local geometry; rendering/physics use a 2x world scale.
const WIDTH := 640.0
const HEIGHT := 560.0
const SCALE := 2.0
const RIGHT_WALL := 592.0
const FLOORS := [136.0, 216.0, 288.0]
const LADDERS: Array[Rect2] = [Rect2(352, 136, 32, 80), Rect2(96, 216, 32, 72), Rect2(374, 288, 32, 240)]
const MINE_FLOORS := [368.0, 448.0, 528.0]
const VEINS: Array[Vector2] = [Vector2(240, 368), Vector2(500, 368), Vector2(240, 448), Vector2(500, 448), Vector2(240, 528), Vector2(500, 528)]
const CAMERA_HEIGHT := 160.0 # Two standard 80-pixel floors.
const CAMERA_ABOVE_FEET := 32.0
