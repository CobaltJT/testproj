extends RefCounted
## Host-created snapshot for one input dispatch. Never supplied by a client.
var player_id: int
var action: StringName
var position: Vector2
var carried_item: int
var _queries: Dictionary = {}

func _init(id: int, input: StringName, at: Vector2, carried: int = -1) -> void:
	player_id = id
	action = input
	position = at
	carried_item = carried

func query(key: StringName, find: Callable) -> int:
	if not _queries.has(key): _queries[key] = find.call(position)
	return _queries[key]
