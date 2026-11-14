extends RefCounted
## Ordering belongs here, ownership belongs to controllers. True stops propagation.
const CONTEXT = preload("res://scripts/interaction/context.gd")
var handlers: Array[Callable] = []

func route(context: CONTEXT) -> bool:
	# Registration changes take effect on the next dispatch.
	for handler in handlers.duplicate():
		if handler.call(context): return true
	return false
