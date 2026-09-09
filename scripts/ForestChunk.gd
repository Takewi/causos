class_name ForestChunk
extends Node3D

## Pure container for chunk MultiMeshes, ground terrain, and trunk colliders.
## Consumes external modules (TerrainModule, TreeMeshFactory, ForestConfig).

@onready var ground_body: StaticBody3D = $Ground
@onready var ground_collision: CollisionShape3D = $Ground/GroundCollision
@onready var ground_mesh: MeshInstance3D = $Ground/GroundMesh
@onready var foliage_multimesh: MultiMeshInstance3D = $Foliage
@onready var trees_container: Node3D = $Trees
@onready var tree_colliders_body: StaticBody3D = $TreeColliders

var chunk_coordinate: Vector2i = Vector2i.ZERO
var is_initialized: bool = false


func initialize(coord: Vector2i, config: ForestConfig, terrain_module: TerrainModule, tree_factory: TreeMeshFactory) -> void:
	chunk_coordinate = coord
	is_initialized = true

	if not is_node_ready():
		await ready

	var rng = RandomNumberGenerator.new()
	var hash_x = int(coord.x) * 73856093
	var hash_y = int(coord.y) * 19349663
	rng.seed = config.world_seed ^ hash_x ^ hash_y

	# 1. Setup Ground Terrain & Physics via TerrainModule
	var terrain_mesh = terrain_module.generate_terrain_mesh(coord, config)
	ground_mesh.mesh = terrain_mesh
	ground_collision.shape = terrain_module.generate_collision_shape(terrain_mesh)
	ground_collision.position = Vector3.ZERO

	# 2. Setup Foliage MultiMesh with GPU Distance Visibility Culling
	_populate_foliage(rng, config, terrain_module)

	# 3. Setup Tree MultiMeshes & Colliders via Poisson Disc Sampling (Organic, non-grid)
	_populate_trees_poisson(rng, config, terrain_module, tree_factory)


func _populate_foliage(rng: RandomNumberGenerator, config: ForestConfig, terrain_module: TerrainModule) -> void:
	foliage_multimesh.visibility_range_end = config.foliage_visibility_range_end
	foliage_multimesh.visibility_range_end_margin = config.foliage_fade_margin
	foliage_multimesh.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF

	var foliage_mesh_res = load("res://assets/models/lowpoly_foliage.tres") as Mesh
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = foliage_mesh_res
	mm.instance_count = config.foliage_count

	var half_size = config.chunk_size * 0.5
	var world_origin_x = float(chunk_coordinate.x) * config.chunk_size
	var world_origin_z = float(chunk_coordinate.y) * config.chunk_size

	for i in range(config.foliage_count):
		var fx = rng.randf_range(-half_size, half_size)
		var fz = rng.randf_range(-half_size, half_size)
		var wx = world_origin_x + fx
		var wz = world_origin_z + fz
		var h = terrain_module.get_height(wx, wz)

		var rot_y = rng.randf_range(0.0, TAU)
		var s = rng.randf_range(0.8, 1.4)

		var b = Basis.from_euler(Vector3(0.0, rot_y, 0.0))
		var t = Transform3D(b.scaled(Vector3(s, s, s)), Vector3(fx, h, fz))

		mm.set_instance_transform(i, t)

	foliage_multimesh.multimesh = mm


## Generates trees using Poisson Disc Sampling (Bridson algorithm)
## Completely eliminates Cartesian corridors and creates natural organic clearings.
func _populate_trees_poisson(rng: RandomNumberGenerator, config: ForestConfig, terrain_module: TerrainModule, tree_factory: TreeMeshFactory) -> void:
	for child in tree_colliders_body.get_children():
		child.queue_free()
	for child in trees_container.get_children():
		child.queue_free()

	var variations = tree_factory.get_tree_variations()
	if variations.size() < 3:
		variations = tree_factory.compile_and_cache_variations()

	var half_size = config.chunk_size * 0.5
	var world_origin_x = float(chunk_coordinate.x) * config.chunk_size
	var world_origin_z = float(chunk_coordinate.y) * config.chunk_size

	var span_min = -half_size + config.tree_margin
	var span_max = half_size - config.tree_margin

	# Sample tree positions purely through Poisson disc sampling (no matrix or rows/columns)
	var tree_points = _generate_poisson_disc_points(rng, span_min, span_max, config.min_tree_distance)

	var transforms_by_var: Array[Array] = [[], [], []]

	var trunk_shape = CylinderShape3D.new()
	trunk_shape.radius = 0.25
	trunk_shape.height = 4.0

	for i in range(tree_points.size()):
		var pt = tree_points[i]
		var tx = pt.x
		var tz = pt.y

		var wx = world_origin_x + tx
		var wz = world_origin_z + tz
		var h = terrain_module.get_height(wx, wz)

		# 0 to 360 degree completely random Y rotation
		var rot_y = rng.randf_range(0.0, TAU)
		# Organic tilt on X and Z axes (breaking vertical uniformity)
		var tilt_x = rng.randf_range(-0.065, 0.065)
		var tilt_z = rng.randf_range(-0.065, 0.065)

		# Scale variations
		var scale_u = rng.randf_range(0.85, 1.25)
		var scale_y = scale_u * rng.randf_range(0.94, 1.12)

		var b = Basis.from_euler(Vector3(tilt_x, rot_y, tilt_z))
		var t = Transform3D(b.scaled(Vector3(scale_u, scale_y, scale_u)), Vector3(tx, h, tz))

		var var_idx = rng.randi() % 3
		transforms_by_var[var_idx].append(t)

		# Trunk collider at base
		var col = CollisionShape3D.new()
		col.name = "TrunkCol_%d" % i
		col.shape = trunk_shape
		col.position = Vector3(tx, h + 2.0, tz)
		tree_colliders_body.add_child(col)

	for v in range(3):
		_create_tree_multimesh(variations[v], transforms_by_var[v], "Trees_Var%d" % (v + 1))


## Fast Bridson Poisson Disc Sampling in 2D bounded space
func _generate_poisson_disc_points(rng: RandomNumberGenerator, span_min: float, span_max: float, min_dist: float, k: int = 20) -> Array[Vector2]:
	var cell_size = min_dist / 1.41421356
	var span = span_max - span_min
	var grid_w = int(ceil(span / cell_size)) + 1
	var grid_h = grid_w
	var grid_size = grid_w * grid_h

	var grid: Array[int] = []
	grid.resize(grid_size)
	grid.fill(-1)

	var points: Array[Vector2] = []
	var active: Array[int] = []

	# Initial point chosen uniformly at random
	var p0 = Vector2(rng.randf_range(span_min, span_max), rng.randf_range(span_min, span_max))
	points.append(p0)
	active.append(0)
	var g0x = int((p0.x - span_min) / cell_size)
	var g0y = int((p0.y - span_min) / cell_size)
	grid[g0y * grid_w + g0x] = 0

	while not active.is_empty():
		var rand_idx = rng.randi_range(0, active.size() - 1)
		var p_idx = active[rand_idx]
		var p = points[p_idx]
		var found = false

		for attempt in range(k):
			var angle = rng.randf_range(0.0, TAU)
			var radius = rng.randf_range(min_dist, 2.0 * min_dist)
			var candidate = p + Vector2(cos(angle), sin(angle)) * radius

			if candidate.x < span_min or candidate.x > span_max or candidate.y < span_min or candidate.y > span_max:
				continue

			var gx = int((candidate.x - span_min) / cell_size)
			var gy = int((candidate.y - span_min) / cell_size)

			var too_close = false
			var min_gx = max(0, gx - 2)
			var max_gx = min(grid_w - 1, gx + 2)
			var min_gy = max(0, gy - 2)
			var max_gy = min(grid_h - 1, gy + 2)

			for cy in range(min_gy, max_gy + 1):
				for cx in range(min_gx, max_gx + 1):
					var neighbor_idx = grid[cy * grid_w + cx]
					if neighbor_idx != -1:
						var neighbor = points[neighbor_idx]
						if candidate.distance_squared_to(neighbor) < min_dist * min_dist:
							too_close = true
							break
				if too_close:
					break

			if not too_close:
				var new_idx = points.size()
				points.append(candidate)
				active.append(new_idx)
				grid[gy * grid_w + gx] = new_idx
				found = true
				break

		if not found:
			active.remove_at(rand_idx)

	return points


func _create_tree_multimesh(mesh: Mesh, transforms: Array, node_name: String) -> void:
	if transforms.is_empty():
		return
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in range(transforms.size()):
		mm.set_instance_transform(i, transforms[i])

	var mm_inst = MultiMeshInstance3D.new()
	mm_inst.name = node_name
	mm_inst.multimesh = mm
	trees_container.add_child(mm_inst)
