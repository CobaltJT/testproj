extends RefCounted
## Shared smithy-local geometry; rendering/physics use a 2x world scale.
const WIDTH := 640.0
const HEIGHT := 320.0
const SCALE := 2.0
const RIGHT_WALL := 592.0
const FLOORS := [136.0, 216.0, 288.0]
const LADDERS: Array[Rect2] = [Rect2(352, 136, 32, 80), Rect2(96, 216, 32, 72)]
const CAMERA_HEIGHT := 160.0 # Two standard 80-pixel floors.
const CAMERA_ABOVE_FEET := 32.0
