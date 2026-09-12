class_name ForestChunk
extends Node3D

## Chunk coordinator node for terrain, foliage, and trees.
## Delegates pure-data generation and instantiation to specialized builders:
## - TerrainModule: Height grid and terrain mesh arrays
## - ChunkFoliageBuilder: Foliage and ground clutter distribution and MultiMeshes
## - ChunkTreeBuilder: Poisson sampling, tree distribution, colliders, and MultiMeshes

var ground_body: StaticBody3D
var ground_collision: CollisionShape3D
var ground_mesh: MeshInstance3D
var foliage_container: Node3D
var trees_container: Node3D
var tree_colliders_body: StaticBody3D

var chunk_coordinate: Vector2i = Vector2i.ZERO
var is_initialized: bool = false


func _ready() -> void:
	_ensure_references()


func _ensure_references() -> void:
	if ground_body == null:
		ground_body = $Ground
		ground_collision = $Ground/GroundCollision
		ground_mesh = $Ground/GroundMesh
		foliage_container = $Foliage
		trees_container = $Trees
		tree_colliders_body = $TreeColliders


## Initializes chunk geometry, terrain, foliage, and trees synchronously.
## Kept for startup center chunk or standalone test instances.
func initialize(coord: Vector2i, config: ForestConfig, terrain_module: TerrainModule, tree_factory: TreeMeshFactory) -> void:
	var live_variations = tree_factory.get_living_tree_variations()
	var data = generate_chunk_data(coord, config, terrain_module, live_variations.size())
	apply_chunk_data(data, config, terrain_module, tree_factory)


## Pure data generation for a chunk. Thread-safe (zero SceneTree or RenderingServer calls).
## Computes the height grid, raw mesh arrays, foliage transforms, tree Poisson points,
## tree transforms, and collider positions. Executes on WorkerThreadPool.
static func generate_chunk_data(coord: Vector2i, config: ForestConfig, terrain_module: TerrainModule, num_tree_variations: int) -> Dictionary:
	var rng = RandomNumberGenerator.new()
	var hash_x = int(coord.x) * 73856093
	var hash_y = int(coord.y) * 19349663
	rng.seed = config.world_seed ^ hash_x ^ hash_y

	# 1. Height grid and raw terrain mesh arrays
	var height_grid = terrain_module.generate_chunk_height_grid(coord, config)
	var mesh_arrays = terrain_module.build_mesh_arrays(coord, config, height_grid)

	# 2. Foliage and ground clutter transforms (16 sub-cells) via ChunkFoliageBuilder
	var foliage_data = ChunkFoliageBuilder.generate_foliage_data(rng, config, terrain_module, height_grid)

	# 3. Tree transforms and colliders (Poisson sampling) via ChunkTreeBuilder
	var tree_data = ChunkTreeBuilder.generate_trees_data(rng, coord, config, terrain_module, height_grid, num_tree_variations)

	return {
		"coord": coord,
		"mesh_arrays": mesh_arrays,
		"foliage_data": foliage_data,
		"live_transforms": tree_data["live_transforms"],
		"tree_colliders": tree_data["tree_colliders"]
	}


## Applies precomputed chunk data on the main thread. Takes ~2.8 ms (vs 41 ms previously).
func apply_chunk_data(data: Dictionary, config: ForestConfig, terrain_module: TerrainModule, tree_factory: TreeMeshFactory) -> void:
	chunk_coordinate = data["coord"]
	is_initialized = true
	_ensure_references()

	# Clear any previous nodes if reusing
	for child in foliage_container.get_children():
		child.queue_free()
	for child in tree_colliders_body.get_children():
		child.queue_free()
	for child in trees_container.get_children():
		child.queue_free()

	# 1. Setup Ground Terrain & Physics via ArrayMesh
	var terrain_mesh = ArrayMesh.new()
	terrain_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, data["mesh_arrays"])
	terrain_mesh.surface_set_material(0, terrain_module.ground_material)
	ground_mesh.mesh = terrain_mesh
	ground_collision.shape = terrain_mesh.create_trimesh_shape()
	ground_collision.position = Vector3.ZERO

	# 2. Setup Foliage MultiMeshes (9 archetypes) via ChunkFoliageBuilder
	ChunkFoliageBuilder.build_foliage_multimeshes(foliage_container, data["foliage_data"], config)

	# 3. Setup Tree Colliders via ChunkTreeBuilder
	ChunkTreeBuilder.build_tree_colliders(data["tree_colliders"], tree_colliders_body)

	# 4. Setup Tree MultiMeshes via ChunkTreeBuilder
	var live_variations = tree_factory.get_living_tree_variations()
	ChunkTreeBuilder.build_tree_multimeshes(trees_container, live_variations, data["live_transforms"], config)
