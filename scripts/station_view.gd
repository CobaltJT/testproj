extends Node2D
const TEXTURES = {"anvil": preload("res://assets/textures/station_anvil.svg"), "grinder": preload("res://assets/textures/station_grinder.svg"), "woodbench": preload("res://assets/textures/station_woodbench.svg")}
func update_view(entry: Dictionary) -> void:
	position = entry.at
	$Sprite.texture = TEXTURES[entry.kind]
	$Progress.value = entry.job.progress
	var needed: Array = []
	for ingredient in entry.job.INPUTS[entry.job.recipe]:
		if not entry.job.slots.has(ingredient):
			needed.append(ingredient.replace("_", " "))
	$Label.text = entry.job.recipe.replace("_", " ").to_upper()
	if not needed.is_empty():
		$Label.text += "\nE: " + ", ".join(needed)
	else:
		$Label.text += "\n%s %.1f/5s" % ["WORK" if entry.job.worker else "PAUSED", entry.job.progress]
