class_name ForestManager
extends Node3D

## World Streaming Manager: Monitors target coordinates and manages instantiating/unloading chunks.
@export var player: Node3D
@export var config: ForestConfig = preload("res://scenes/forest_config.tres")
@export var chunk_scene: PackedScene = preload("res://scenes/ForestChunk.tscn")

var terrain_module: TerrainModule
var tree_factory: TreeMeshFactory

var loaded_chunks: Dictionary = {} # Vector2i -> ForestChunk
var spawn_queue: Array[Vector2i] = []
var last_player_chunk: Vector2i = Vector2i(999999, 999999)


func _ready() -> void:
	if config != null:
		config = config.duplicate()
	else:
		config = ForestConfig.new()

	# Apply dynamic map configuration from GameManager
	var gm = get_node_or_null("/root/GameManager")
	if gm != null:
		config.world_seed = gm.world_seed
		config.terrain_amplitude = gm.terrain_amplitude
		config.min_tree_distance = gm.min_tree_distance

	# Initialize shared singletons for terrain calculation and tree meshes
	terrain_module = TerrainModule.new(config)
	tree_factory = TreeMeshFactory.new()
	tree_factory.get_living_tree_variations()

	if player == null:
		player = _find_player_in_tree()

	var start_pos = Vector3.ZERO
	if player:
		start_pos = player.global_position if player.is_inside_tree() else player.position
	else:
		start_pos = global_position if is_inside_tree() else position

	last_player_chunk = world_to_chunk_coord(start_pos)
	_update_streaming(last_player_chunk)

	# Spawn the immediate center chunk synchronously on startup so player stands on ground
	if not spawn_queue.is_empty():
		var center_chunk = spawn_queue.pop_front()
		_spawn_chunk(center_chunk)


func _process(_delta: float) -> void:
	# Process 1 chunk per frame from spawn queue to prevent frame drops
	if not spawn_queue.is_empty():
		var next_coord = spawn_queue.pop_front()
		if is_coord_in_grid(next_coord) and not loaded_chunks.has(next_coord):
			_spawn_chunk(next_coord)

	if player == null:
		player = _find_player_in_tree()
		if player == null:
			return

	var p_pos = player.global_position if player.is_inside_tree() else player.position
	var current_chunk = world_to_chunk_coord(p_pos)
	if current_chunk != last_player_chunk:
		last_player_chunk = current_chunk
		_update_streaming(current_chunk)


## Converts a 3D world position into a chunk 2D grid coordinate.
func world_to_chunk_coord(world_pos: Vector3) -> Vector2i:
	var c_size = config.chunk_size if config else 100.0
	var cx = int(floor((world_pos.x + c_size * 0.5) / c_size))
	var cz = int(floor((world_pos.z + c_size * 0.5) / c_size))
	return Vector2i(cx, cz)


## Converts a chunk 2D grid coordinate into world space center position.
func chunk_coord_to_world(coord: Vector2i) -> Vector3:
	var c_size = config.chunk_size if config else 100.0
	return Vector3(float(coord.x) * c_size, 0.0, float(coord.y) * c_size)


## Checks whether the coordinate falls within the configured bounded forest grid
func is_coord_in_grid(coord: Vector2i) -> bool:
	var g_size = config.grid_size if config else Vector2i(16, 16)
	var min_x = -g_size.x / 2
	var max_x = min_x + g_size.x - 1
	var min_z = -g_size.y / 2
	var max_z = min_z + g_size.y - 1
	return coord.x >= min_x and coord.x <= max_x and coord.y >= min_z and coord.y <= max_z


## Updates the active grid around the target, instantiating new chunks and freeing distant ones
func _update_streaming(center_coord: Vector2i) -> void:
	var active_coords: Array[Vector2i] = []
	var radius = config.active_radius if config else 1

	for dx in range(-radius, radius + 1):
		for dz in range(-radius, radius + 1):
			var coord = Vector2i(center_coord.x + dx, center_coord.y + dz)
			if is_coord_in_grid(coord):
				active_coords.append(coord)

	# 1. Unload distant chunks outside active window
	var coords_to_unload: Array[Vector2i] = []
	for coord in loaded_chunks.keys():
		if coord not in active_coords:
			coords_to_unload.append(coord)

	for coord in coords_to_unload:
		var chunk_node = loaded_chunks[coord]
		loaded_chunks.erase(coord)
		if is_instance_valid(chunk_node):
			chunk_node.queue_free()

	# Remove pending coords that are no longer in active radius
	var filtered_queue: Array[Vector2i] = []
	for queued in spawn_queue:
		if queued in active_coords:
			filtered_queue.append(queued)
	spawn_queue = filtered_queue

	# 2. Enqueue new chunks (sorted by proximity to center)
	for coord in active_coords:
		if not loaded_chunks.has(coord) and coord not in spawn_queue:
			spawn_queue.append(coord)

	spawn_queue.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var dist_a = (a - center_coord).length_squared()
		var dist_b = (b - center_coord).length_squared()
		return dist_a < dist_b
	)


func _spawn_chunk(coord: Vector2i) -> void:
	var chunk = chunk_scene.instantiate() as ForestChunk
	chunk.name = "Chunk_%d_%d" % [coord.x, coord.y]
	chunk.position = chunk_coord_to_world(coord)

	# Initialize offline so Jolt builds compound physics shapes in a single fast pass
	chunk.initialize(coord, config, terrain_module, tree_factory)
	add_child(chunk)
	loaded_chunks[coord] = chunk


func _find_player_in_tree() -> Node3D:
	var tree = get_tree()
	if tree == null:
		return null
	var nodes_in_group = tree.get_nodes_in_group("player")
	if not nodes_in_group.is_empty():
		return nodes_in_group[0] as Node3D
	var parent_node = get_parent()
	if parent_node:
		var candidate = parent_node.find_child("Player", true, false)
		if candidate is Node3D:
			return candidate
	return null
