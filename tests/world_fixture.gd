extends RefCounted
## Existing feature tests use a fully expanded workshop without spending their budgets.
static func fill(layout: RefCounted) -> void:
	for row in [-2, -1, 0, 1]:
		for col in range(5): layout.building[Vector2i(col, row)] = true
	layout.mine_open = true
	for row in [1, 2, 3]:
		for col in [1, 2]: layout.underground[Vector2i(col, row)] = true

static func prepare(session: Node) -> void:
	fill(session.rooms)
	session.apply_room_layout()
	for id in session.ore_bodies:
		if session.ore.is_loose(id):
			session.position_ore(session.ore_bodies[id], Vector2(210 + id * 8, 281 - (id % 2) * 3), Vector2.ZERO)
	session.broadcast_state("receive_rooms", [session.rooms.snapshot()])
