class_name TreeMeshFactory
extends RefCounted

## Loads and caches static, low-poly tree mesh variations across 3 vertical strata:
## - ESTRATO ALTO (Dossel / Altas, ~10m - 14m): Variações 1 a 5
## - ESTRATO MÉDIO (Sub-bosque / Médias, ~5m - 6m): Variações 6 a 10
## - ESTRATO BAIXO (Arbustos / Baixas, ~3m - 4m): Variações 11 a 15

const VARIATION_COUNT: int = 15
const MODEL_PATH_PATTERN: String = "res://assets/models/tree_variation_%d.tres"

var cached_living_variations: Array[Mesh] = []


func get_living_tree_variations() -> Array[Mesh]:
	if not cached_living_variations.is_empty():
		return cached_living_variations
	_load_all()
	return cached_living_variations


func get_tree_variations() -> Array[Mesh]:
	return get_living_tree_variations()


func get_tall_tree_variations() -> Array[Mesh]:
	var all = get_living_tree_variations()
	return all.slice(0, 5)


func get_medium_tree_variations() -> Array[Mesh]:
	var all = get_living_tree_variations()
	return all.slice(5, 10)


func get_short_tree_variations() -> Array[Mesh]:
	var all = get_living_tree_variations()
	return all.slice(10, 15)


func _load_all() -> void:
	cached_living_variations.clear()
	for i in range(1, VARIATION_COUNT + 1):
		var path = MODEL_PATH_PATTERN % i
		var m = load(path) as Mesh
		if m != null:
			cached_living_variations.append(m)
		else:
			push_error("TreeMeshFactory: Failed to load tree variation mesh at: %s" % path)
