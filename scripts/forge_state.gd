extends RefCounted
## One shared job. Work time advances once per host tick, regardless of helpers.
const DURATION := 5.0
var output_kind := "ingot"
const RECIPES := ["hammer", "sword", "axe"]
var recipe := "hammer"
var wood_piece := -1
var piece := -1
var progress := 0.0
var worker := 0

func step(delta: float, eligible: Array[int], ore: RefCounted) -> Dictionary:
	var result := {"started": -1, "finished": -1}
	if worker not in eligible:
		worker = eligible[0] if not eligible.is_empty() else 0
	if worker == 0:
		return result
	if piece == -1:
		if output_kind != "ingot":
			worker = 0
			return result
		piece = ore.begin_smelting()
		if piece == -1:
			worker = 0
			return result
		result.started = piece
	if piece != -1 and (output_kind == "ingot" or recipe != "axe" or wood_piece != -1):
		progress = minf(DURATION, progress + delta)
		if progress >= DURATION - 0.00001:
			result.finished = piece
			if output_kind == "ingot":
				ore.finish_smelting(piece)
			else:
				ore.pieces[piece].processing = false
				ore.pieces[piece].kind = recipe
				if wood_piece != -1:
					ore.pieces[wood_piece].processing = false
					ore.pieces[wood_piece].consumed = true
					wood_piece = -1
			piece = -1
			progress = 0.0
			worker = 0
	return result

func snapshot() -> Dictionary:
	return {"piece": piece, "progress": progress, "worker": worker, "recipe": recipe, "wood_piece": wood_piece}

func restore(state: Dictionary) -> void:
	piece = state.piece
	progress = state.progress
	worker = state.worker
	recipe = state.recipe
	wood_piece = state.wood_piece

func select_recipe(choice: String) -> bool:
	if output_kind == "ingot" or choice not in RECIPES or piece != -1 or wood_piece != -1:
		return false
	recipe = choice
	return true

func load_ingot(player: int, ore: RefCounted) -> bool:
	return load_material(player, ore)

func load_material(player: int, ore: RefCounted) -> bool:
	if player <= 0 or output_kind == "ingot":
		return false
	var carried: int = ore.carried_by(player)
	if carried == -1:
		return false
	var kind: String = ore.pieces[carried].kind
	if kind == "ingot" and piece == -1:
		piece = carried
	elif kind == "wood" and recipe == "axe" and wood_piece == -1:
		wood_piece = carried
	else:
		return false
	ore.release_carrier(player)
	ore.pieces[carried].processing = true
	worker = 0
	return true
