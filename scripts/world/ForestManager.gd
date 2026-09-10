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
var generating_tasks: Dictionary = {} # Vector2i -> int (WorkerThreadPool task_id)
var completed_chunk_data: Dictionary = {} # Vector2i -> Dictionary
var unloading_queue: Array[ForestChunk] = [] # Queue for staggered time-sliced freeing
var last_player_chunk: Vector2i = Vector2i(999999, 999999)

const MAX_CONCURRENT_WORKER_TASKS: int = 4


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

	# Synchronize lighting and fog atmosphere with config
	var world_env = get_node_or_null("../WorldEnvironment") as WorldEnvironment
	if world_env and world_env.environment and config:
		world_env.environment.fog_light_color = config.fog_color
		world_env.environment.fog_depth_begin = config.fog_depth_begin
		world_env.environment.fog_depth_end = config.fog_depth_end
		world_env.environment.fog_density = config.fog_density
		world_env.environment.background_color = config.fog_color
		world_env.environment.ambient_light_color = config.ambient_light_color
		world_env.environment.ambient_light_energy = config.ambient_light_energy

	var dir_light = get_node_or_null("../DirectionalLight3D") as DirectionalLight3D
	if dir_light and config:
		dir_light.directional_shadow_max_distance = config.max_shadow_distance
		dir_light.light_energy = config.sun_light_energy
		dir_light.light_color = config.sun_light_color

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

	# Position player on the ground surface immediately so they don't fall from the sky or spawn below ground
	if player:
		_position_player_on_ground()


func _exit_tree() -> void:
	# Ensure all active background tasks finish cleanly before exit
	for coord in generating_tasks.keys():
		var tid = generating_tasks[coord]
		WorkerThreadPool.wait_for_task_completion(tid)
	generating_tasks.clear()
	completed_chunk_data.clear()

	for chunk_node in unloading_queue:
		if is_instance_valid(chunk_node):
			chunk_node.queue_free()
	unloading_queue.clear()


func _process(_delta: float) -> void:
	# 1. Process at most 1 completed background task per frame (budget: ~2.8 ms)
	var chunk_assembled = _process_completed_tasks()

	# 2. Dispatch pending chunks from spawn_queue to WorkerThreadPool
	_dispatch_worker_tasks()

	# 3. Time-sliced chunk unloading: only free if we didn't assemble a chunk on this frame
	if not chunk_assembled:
		_process_unloading_queue()

	# 4. Check player movement across chunk boundaries
	if player == null:
		player = _find_player_in_tree()
		if player == null:
			return

	var p_pos = player.global_position if player.is_inside_tree() else player.position
	var current_chunk = world_to_chunk_coord(p_pos)
	if current_chunk != last_player_chunk:
		last_player_chunk = current_chunk
		_update_streaming(current_chunk)


func _process_completed_tasks() -> bool:
	var completed_coord: Vector2i = Vector2i(999999, 999999)
	for coord in generating_tasks.keys():
		var tid = generating_tasks[coord]
		if WorkerThreadPool.is_task_completed(tid):
			WorkerThreadPool.wait_for_task_completion(tid)
			completed_coord = coord
			break

	if completed_coord != Vector2i(999999, 999999):
		generating_tasks.erase(completed_coord)
		if completed_chunk_data.has(completed_coord):
			var data = completed_chunk_data[completed_coord]
			completed_chunk_data.erase(completed_coord)

			# Verify chunk is still within active streaming distance (player didn't walk away)
			var radius = config.active_radius if config else 1
			var dist = (completed_coord - last_player_chunk).abs()
			if dist.x <= radius and dist.y <= radius and is_coord_in_grid(completed_coord) and not loaded_chunks.has(completed_coord):
				var chunk = chunk_scene.instantiate() as ForestChunk
				chunk.name = "Chunk_%d_%d" % [completed_coord.x, completed_coord.y]
				chunk.position = chunk_coord_to_world(completed_coord)
				chunk.apply_chunk_data(data, config, terrain_module, tree_factory)
				add_child(chunk)
				loaded_chunks[completed_coord] = chunk
				return true
	return false


func _dispatch_worker_tasks() -> void:
	while not spawn_queue.is_empty() and generating_tasks.size() < MAX_CONCURRENT_WORKER_TASKS:
		var next_coord = spawn_queue.pop_front()
		if not is_coord_in_grid(next_coord) or loaded_chunks.has(next_coord) or generating_tasks.has(next_coord):
			continue

		var num_variations = tree_factory.get_living_tree_variations().size()
		var c = next_coord
		var tid = WorkerThreadPool.add_task(func():
			var data = ForestChunk.generate_chunk_data(c, config, terrain_module, num_variations)
			completed_chunk_data[c] = data
		)
		generating_tasks[next_coord] = tid


func _process_unloading_queue() -> void:
	if not unloading_queue.is_empty():
		var chunk_node = unloading_queue.pop_front()
		if is_instance_valid(chunk_node):
			chunk_node.queue_free()


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

	# 1. Unload distant chunks outside active window (staggered via unloading_queue)
	var coords_to_unload: Array[Vector2i] = []
	for coord in loaded_chunks.keys():
		if coord not in active_coords:
			coords_to_unload.append(coord)

	for coord in coords_to_unload:
		var chunk_node = loaded_chunks[coord]
		loaded_chunks.erase(coord)
		if is_instance_valid(chunk_node):
			unloading_queue.append(chunk_node)

	# Remove pending coords that are no longer in active radius
	var filtered_queue: Array[Vector2i] = []
	for queued in spawn_queue:
		if queued in active_coords:
			filtered_queue.append(queued)
	spawn_queue = filtered_queue

	# 2. Enqueue new chunks (sorted by proximity to center)
	for coord in active_coords:
		if not loaded_chunks.has(coord) and not generating_tasks.has(coord) and coord not in spawn_queue:
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


## Positions player at the exact terrain mesh height at their current X/Z coordinates
func _position_player_on_ground() -> void:
	if player == null or terrain_module == null:
		return

	var px: float = player.global_position.x if player.is_inside_tree() else player.position.x
	var pz: float = player.global_position.z if player.is_inside_tree() else player.position.z
	var ground_y: float = terrain_module.get_mesh_height(px, pz, config)

	# Place player capsule base right at ground level (with a 0.05m clearance)
	var spawn_y = ground_y + 0.05
	if player.is_inside_tree():
		player.global_position.y = spawn_y
	else:
		player.position.y = spawn_y

	if player is CharacterBody3D:
		player.velocity = Vector3.ZERO
