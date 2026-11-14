extends RefCounted
## Shared smithy-local geometry; rendering/physics use a 2x world scale.
const WIDTH := 1136.0
const HEIGHT := 640.0
const SCALE := 2.0
const RIGHT_WALL := 1088.0
const FLOORS := [56.0, 136.0, 216.0, 288.0]
const MINE_GAP := 80.0
const MINE_FLOORS := [448.0, 528.0, 608.0]
const VEINS: Array[Vector2] = [Vector2(320, 448), Vector2(528, 448), Vector2(320, 528), Vector2(528, 528), Vector2(320, 608), Vector2(528, 608), Vector2(144, 448), Vector2(144, 528), Vector2(144, 608), Vector2(720, 448), Vector2(720, 528), Vector2(720, 608), Vector2(912, 448), Vector2(912, 528), Vector2(912, 608)]
const CAMERA_HEIGHT := 160.0 # Two standard 80-pixel floors.
const CAMERA_ABOVE_FEET := 32.0
