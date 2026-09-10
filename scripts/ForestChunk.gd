class_name ForestChunk
extends Node3D

## Pure container for chunk MultiMeshes, ground terrain, and trunk colliders.
## Consumes external modules (TerrainModule, TreeMeshFactory, ForestConfig).

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


## Initializes chunk geometry, terrain, foliage, and trees.
## Can run safely offline (before being added to the SceneTree), allowing Jolt Physics
## to build the compound collider hierarchy in a single pass (35x faster).
func initialize(coord: Vector2i, config: ForestConfig, terrain_module: TerrainModule, tree_factory: TreeMeshFactory) -> void:
	chunk_coordinate = coord
	is_initialized = true
	_ensure_references()

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
	for child in foliage_container.get_children():
		child.queue_free()

	var foliage_mesh_res = load("res://assets/models/lowpoly_foliage.tres") as Mesh
	if foliage_mesh_res == null:
		return
	var mesh_aabb = foliage_mesh_res.get_aabb()

	# Spatial partition: 4x4 grid of 25x25m sub-cells per 100m chunk
	# Eliminates chunk-wide popping by giving each sub-cell its own tight AABB.
	# Any sub-cell culling happens at >42m, hidden completely behind the 45m opaque fog wall.
	var num_cells = 4
	var cell_size = config.chunk_size / float(num_cells)
	var half_chunk = config.chunk_size * 0.5

	var world_origin_x = float(chunk_coordinate.x) * config.chunk_size
	var world_origin_z = float(chunk_coordinate.y) * config.chunk_size

	for cz in range(num_cells):
		var z_min = -half_chunk + float(cz) * cell_size
		var z_max = z_min + cell_size
		for cx in range(num_cells):
			var x_min = -half_chunk + float(cx) * cell_size
			var x_max = x_min + cell_size

			var cell_transforms: Array[Transform3D] = []

			# 1. Stratified baseline coverage: 8x8 micro-grid (~3.1m spacing with jitter)
			# Eliminates empty voids / barren gaps so grass is consistently present
			var micro_grid = 8
			var micro_step = cell_size / float(micro_grid)
			for mz in range(micro_grid):
				var mz_base = z_min + float(mz) * micro_step
				for mx in range(micro_grid):
					var mx_base = x_min + float(mx) * micro_step
					var tuft_count = 1 if rng.randf() > 0.45 else 2
					for _t in range(tuft_count):
						var fx = mx_base + rng.randf_range(0.15, micro_step - 0.15)
						var fz = mz_base + rng.randf_range(0.15, micro_step - 0.15)
						var wx = world_origin_x + fx
						var wz = world_origin_z + fz
						# Exact polygon surface height prevents grass from being submerged under terrain
						var h = terrain_module.get_mesh_height(wx, wz, config) + 0.02

						var rot_y = rng.randf_range(0.0, TAU)
						var tilt_x = rng.randf_range(-0.04, 0.04)
						var tilt_z = rng.randf_range(-0.04, 0.04)
						var s = rng.randf_range(0.85, 1.35)

						var b = Basis.from_euler(Vector3(tilt_x, rot_y, tilt_z))
						cell_transforms.append(Transform3D(b.scaled(Vector3(s, s, s)), Vector3(fx, h, fz)))

			# 2. Organic clustered clumps / touceiras (8 to 12 natural clumps per 25x25m cell)
			var num_clumps = rng.randi_range(8, 12)
			for _c in range(num_clumps):
				var clump_cx = rng.randf_range(x_min + 1.5, x_max - 1.5)
				var clump_cz = rng.randf_range(z_min + 1.5, z_max - 1.5)
				var clump_tufts = rng.randi_range(3, 5)
				var clump_scale_base = rng.randf_range(0.95, 1.45)

				for _t in range(clump_tufts):
					var offset_ang = rng.randf_range(0.0, TAU)
					var offset_dist = rng.randf_range(0.15, 0.85)
					var fx = clump_cx + cos(offset_ang) * offset_dist
					var fz = clump_cz + sin(offset_ang) * offset_dist
					var wx = world_origin_x + fx
					var wz = world_origin_z + fz
					var h = terrain_module.get_mesh_height(wx, wz, config) + 0.02

					var rot_y = rng.randf_range(0.0, TAU)
					var tilt_x = rng.randf_range(-0.05, 0.05)
					var tilt_z = rng.randf_range(-0.05, 0.05)
					var s = clump_scale_base * rng.randf_range(0.85, 1.15)

					var b = Basis.from_euler(Vector3(tilt_x, rot_y, tilt_z))
					cell_transforms.append(Transform3D(b.scaled(Vector3(s, s, s)), Vector3(fx, h, fz)))

			if cell_transforms.is_empty():
				continue

			# Build MultiMesh for this 25x25m cell
			var mm = MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = foliage_mesh_res
			mm.instance_count = cell_transforms.size()
			for i in range(cell_transforms.size()):
				mm.set_instance_transform(i, cell_transforms[i])

			# Tight merged AABB for precise frustum and distance culling
			var combined_aabb = cell_transforms[0] * mesh_aabb
			for i in range(1, cell_transforms.size()):
				combined_aabb = combined_aabb.merge(cell_transforms[i] * mesh_aabb)
			mm.custom_aabb = combined_aabb

			var mm_inst = MultiMeshInstance3D.new()
			mm_inst.name = "Foliage_C%d_%d" % [cx + 1, cz + 1]
			mm_inst.multimesh = mm
			mm_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mm_inst.extra_cull_margin = 2.0

			if config:
				mm_inst.visibility_range_end = config.foliage_visibility_range_end
				mm_inst.visibility_range_end_margin = config.foliage_fade_margin
				mm_inst.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED

			foliage_container.add_child(mm_inst)


## Generates trees using Poisson Disc Sampling (Bridson algorithm)
## Completely eliminates Cartesian corridors and creates natural organic clearings.
func _populate_trees_poisson(rng: RandomNumberGenerator, config: ForestConfig, terrain_module: TerrainModule, tree_factory: TreeMeshFactory) -> void:
	for child in tree_colliders_body.get_children():
		child.queue_free()
	for child in trees_container.get_children():
		child.queue_free()

	var live_variations = tree_factory.get_living_tree_variations()

	var half_size = config.chunk_size * 0.5
	var world_origin_x = float(chunk_coordinate.x) * config.chunk_size
	var world_origin_z = float(chunk_coordinate.y) * config.chunk_size

	var span_min = -half_size + config.tree_margin
	var span_max = half_size - config.tree_margin

	# Sample tree positions purely through Poisson disc sampling (no matrix or rows/columns)
	var tree_points = _generate_poisson_disc_points(rng, span_min, span_max, config.min_tree_distance)

	# Partition trees into 4 spatial quadrants per chunk (50x50m each)
	# This allows the GPU to cull far quadrants within neighboring chunks,
	# eliminating ~40% more unnecessary geometry beyond the fog distance.
	var live_transforms: Array = []
	for _q in range(4):
		var q_list: Array = []
		for _v in range(live_variations.size()):
			q_list.append([])
		live_transforms.append(q_list)

	# Dynamic collision shapes tailored per vegetation stratum
	var trunk_shape_tall = CylinderShape3D.new()
	trunk_shape_tall.radius = 0.28
	trunk_shape_tall.height = 4.5

	var trunk_shape_med = CylinderShape3D.new()
	trunk_shape_med.radius = 0.20
	trunk_shape_med.height = 2.8

	var trunk_shape_low = CylinderShape3D.new()
	trunk_shape_low.radius = 0.14
	trunk_shape_low.height = 1.8

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

		var q_idx = (0 if tx < 0.0 else 1) + (0 if tz < 0.0 else 2)
		var l_idx = rng.randi() % live_variations.size()
		live_transforms[q_idx][l_idx].append(t)

		# Trunk collider at base tailored to vegetation stratum (pass readable_name=false to avoid string formatting overhead)
		var col = CollisionShape3D.new()
		if l_idx < 5:
			col.shape = trunk_shape_tall
			col.position = Vector3(tx, h + 1.8 * scale_y, tz)
		elif l_idx < 10:
			col.shape = trunk_shape_med
			col.position = Vector3(tx, h + 1.2 * scale_y, tz)
		else:
			col.shape = trunk_shape_low
			col.position = Vector3(tx, h + 0.8 * scale_y, tz)
		tree_colliders_body.add_child(col, false)

	for q in range(4):
		for v in range(live_variations.size()):
			_create_tree_multimesh(live_variations[v], live_transforms[q][v], "Trees_Q%d_%d" % [q + 1, v + 1], config)


## Fast Bridson Poisson Disc Sampling in 2D bounded space with O(1) swap-and-pop
## Supports optional exclusion_zones for future POIs, cabins, and paths
func _generate_poisson_disc_points(rng: RandomNumberGenerator, span_min: float, span_max: float, min_dist: float, k: int = 10, exclusion_zones: Array[Rect2] = []) -> Array[Vector2]:
	var cell_size = min_dist * 0.70710678
	var inv_cell = 1.0 / cell_size
	var span = span_max - span_min
	var grid_w = int(ceil(span * inv_cell)) + 1
	var grid_h = grid_w

	var grid: PackedInt32Array = PackedInt32Array()
	grid.resize(grid_w * grid_h)
	grid.fill(-1)

	var points: Array[Vector2] = []
	var active: PackedInt32Array = PackedInt32Array()

	# Initial point chosen uniformly at random
	var p0 = Vector2(rng.randf_range(span_min, span_max), rng.randf_range(span_min, span_max))
	points.append(p0)
	active.append(0)
	var g0x = int((p0.x - span_min) * inv_cell)
	var g0y = int((p0.y - span_min) * inv_cell)
	grid[g0y * grid_w + g0x] = 0

	var min_dist_sq = min_dist * min_dist

	while not active.is_empty():
		var rand_idx = rng.randi_range(0, active.size() - 1)
		var p = points[active[rand_idx]]
		var found = false

		for attempt in range(k):
			var angle = rng.randf_range(0.0, TAU)
			var radius = rng.randf_range(min_dist, 2.0 * min_dist)
			var candidate = p + Vector2(cos(angle), sin(angle)) * radius

			if candidate.x < span_min or candidate.x > span_max or candidate.y < span_min or candidate.y > span_max:
				continue

			# Exclusion zone check for upcoming POIs / cabins / clearings
			var in_exclusion = false
			for zone in exclusion_zones:
				if zone.has_point(candidate):
					in_exclusion = true
					break
			if in_exclusion:
				continue

			var gx = int((candidate.x - span_min) * inv_cell)
			var gy = int((candidate.y - span_min) * inv_cell)

			var too_close = false
			var min_gx = max(0, gx - 2)
			var max_gx = min(grid_w - 1, gx + 2)
			var min_gy = max(0, gy - 2)
			var max_gy = min(grid_h - 1, gy + 2)

			for cy in range(min_gy, max_gy + 1):
				var row_offset = cy * grid_w
				for cx in range(min_gx, max_gx + 1):
					var neighbor_idx = grid[row_offset + cx]
					if neighbor_idx != -1:
						if candidate.distance_squared_to(points[neighbor_idx]) < min_dist_sq:
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
			var last_idx = active.size() - 1
			active[rand_idx] = active[last_idx]
			active.resize(last_idx)

	return points


func _create_tree_multimesh(mesh: Mesh, transforms: Array, node_name: String, config: ForestConfig = null) -> void:
	if transforms.is_empty():
		return
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in range(transforms.size()):
		mm.set_instance_transform(i, transforms[i])

	# Compute exact combined AABB for accurate frustum and shadow culling
	var mesh_aabb = mesh.get_aabb()
	var combined_aabb = (transforms[0] as Transform3D) * mesh_aabb
	for i in range(1, transforms.size()):
		combined_aabb = combined_aabb.merge((transforms[i] as Transform3D) * mesh_aabb)
	mm.custom_aabb = combined_aabb

	var mm_inst = MultiMeshInstance3D.new()
	mm_inst.name = node_name
	mm_inst.multimesh = mm
	# Expand cull margin so trees outside camera view continue casting shadows into view (prevents shadow popping)
	mm_inst.extra_cull_margin = 16.0

	if config:
		mm_inst.visibility_range_end = config.tree_visibility_range_end
		mm_inst.visibility_range_end_margin = config.tree_fade_margin
		mm_inst.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	trees_container.add_child(mm_inst)
