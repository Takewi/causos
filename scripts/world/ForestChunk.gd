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


## Initializes chunk geometry, terrain, foliage, and trees synchronously.
## Kept for startup center chunk or standalone instances.
func initialize(coord: Vector2i, config: ForestConfig, terrain_module: TerrainModule, tree_factory: TreeMeshFactory) -> void:
	var live_variations = tree_factory.get_living_tree_variations()
	var data = generate_chunk_data(coord, config, terrain_module, live_variations.size())
	apply_chunk_data(data, config, terrain_module, tree_factory)


## Pure data generation for a chunk. Thread-safe (zero SceneTree or RenderingServer calls).
## Computes the height grid, raw mesh arrays, foliage transforms, tree Poisson points,
## tree transforms, and collider positions. Can run on WorkerThreadPool.
static func generate_chunk_data(coord: Vector2i, config: ForestConfig, terrain_module: TerrainModule, num_tree_variations: int) -> Dictionary:
	var rng = RandomNumberGenerator.new()
	var hash_x = int(coord.x) * 73856093
	var hash_y = int(coord.y) * 19349663
	rng.seed = config.world_seed ^ hash_x ^ hash_y

	# 1. Height grid and raw terrain mesh arrays
	var height_grid = terrain_module.generate_chunk_height_grid(coord, config)
	var mesh_arrays = terrain_module.build_mesh_arrays(coord, config, height_grid)

	# 2. Foliage transforms data (16 sub-cells) using fast local height grid queries
	var foliage_data = _generate_foliage_data(rng, config, terrain_module, height_grid)

	# 3. Tree transforms and colliders data (Poisson sampling) using fast local height grid queries
	var tree_data = _generate_trees_data(rng, coord, config, terrain_module, height_grid, num_tree_variations)

	return {
		"coord": coord,
		"mesh_arrays": mesh_arrays,
		"foliage_data": foliage_data,
		"live_transforms": tree_data["live_transforms"],
		"tree_colliders": tree_data["tree_colliders"]
	}


static func _generate_foliage_data(rng: RandomNumberGenerator, config: ForestConfig, terrain_module: TerrainModule, height_grid: Array) -> Array:
	var foliage_data: Array = []
	var num_cells = 4
	var cell_size = config.chunk_size / float(num_cells)
	var half_chunk = config.chunk_size * 0.5

	for cz in range(num_cells):
		var z_min = -half_chunk + float(cz) * cell_size
		for cx in range(num_cells):
			var x_min = -half_chunk + float(cx) * cell_size
			var cell_transforms: Array[Transform3D] = []

			# 1. Stratified baseline coverage: 8x8 micro-grid (~3.1m spacing with jitter)
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
						var h = terrain_module.get_grid_mesh_height(height_grid, fx, fz, config) + 0.02

						var rot_y = rng.randf_range(0.0, TAU)
						var tilt_x = rng.randf_range(-0.04, 0.04)
						var tilt_z = rng.randf_range(-0.04, 0.04)
						var s = rng.randf_range(0.85, 1.35)

						var b = Basis.from_euler(Vector3(tilt_x, rot_y, tilt_z))
						cell_transforms.append(Transform3D(b.scaled(Vector3(s, s, s)), Vector3(fx, h, fz)))

			# 2. Organic clustered clumps / touceiras (8 to 12 natural clumps per 25x25m cell)
			var num_clumps = rng.randi_range(8, 12)
			for _c in range(num_clumps):
				var clump_cx = rng.randf_range(x_min + 1.5, x_min + cell_size - 1.5)
				var clump_cz = rng.randf_range(z_min + 1.5, z_min + cell_size - 1.5)
				var clump_tufts = rng.randi_range(3, 5)
				var clump_scale_base = rng.randf_range(0.95, 1.45)

				for _t in range(clump_tufts):
					var offset_ang = rng.randf_range(0.0, TAU)
					var offset_dist = rng.randf_range(0.15, 0.85)
					var fx = clump_cx + cos(offset_ang) * offset_dist
					var fz = clump_cz + sin(offset_ang) * offset_dist
					var h = terrain_module.get_grid_mesh_height(height_grid, fx, fz, config) + 0.02

					var rot_y = rng.randf_range(0.0, TAU)
					var tilt_x = rng.randf_range(-0.05, 0.05)
					var tilt_z = rng.randf_range(-0.05, 0.05)
					var s = clump_scale_base * rng.randf_range(0.85, 1.15)

					var b = Basis.from_euler(Vector3(tilt_x, rot_y, tilt_z))
					cell_transforms.append(Transform3D(b.scaled(Vector3(s, s, s)), Vector3(fx, h, fz)))

			if not cell_transforms.is_empty():
				foliage_data.append({
					"cx": cx,
					"cz": cz,
					"transforms": cell_transforms
				})

	return foliage_data


static func _generate_trees_data(rng: RandomNumberGenerator, coord: Vector2i, config: ForestConfig, terrain_module: TerrainModule, height_grid: Array, num_variations: int) -> Dictionary:
	var half_size = config.chunk_size * 0.5
	var world_origin_x = float(coord.x) * config.chunk_size
	var world_origin_z = float(coord.y) * config.chunk_size

	var span_min = -half_size + config.tree_margin
	var span_max = half_size - config.tree_margin

	var tree_points = _generate_poisson_disc_points(rng, span_min, span_max, config.min_tree_distance)

	var live_transforms: Array = []
	for _q in range(4):
		var q_list: Array = []
		for _v in range(num_variations):
			q_list.append([])
		live_transforms.append(q_list)

	var tree_colliders: Array = []

	for i in range(tree_points.size()):
		var pt = tree_points[i]
		var tx = pt.x
		var tz = pt.y

		# Keep player spawn clearing: prevent tree trunks from spawning right on the player
		if coord == Vector2i(0, 0) and Vector2(world_origin_x + tx, world_origin_z + tz).length() < 2.5:
			continue

		var h = terrain_module.get_grid_mesh_height(height_grid, tx, tz, config)

		var rot_y = rng.randf_range(0.0, TAU)
		var tilt_x = rng.randf_range(-0.065, 0.065)
		var tilt_z = rng.randf_range(-0.065, 0.065)

		var scale_u = rng.randf_range(0.85, 1.25)
		var scale_y = scale_u * rng.randf_range(0.94, 1.12)

		var b = Basis.from_euler(Vector3(tilt_x, rot_y, tilt_z))
		var t = Transform3D(b.scaled(Vector3(scale_u, scale_y, scale_u)), Vector3(tx, h, tz))

		var q_idx = (0 if tx < 0.0 else 1) + (0 if tz < 0.0 else 2)
		var l_idx = rng.randi() % num_variations
		live_transforms[q_idx][l_idx].append(t)

		var col_y_offset = (1.8 if l_idx < 5 else (1.2 if l_idx < 10 else 0.8)) * scale_y
		tree_colliders.append({
			"l_idx": l_idx,
			"pos": Vector3(tx, h + col_y_offset, tz)
		})

	return {
		"live_transforms": live_transforms,
		"tree_colliders": tree_colliders
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

	# 2. Setup Foliage MultiMeshes
	var foliage_mesh_res = load("res://assets/models/lowpoly_foliage.tres") as Mesh
	var mesh_aabb = foliage_mesh_res.get_aabb() if foliage_mesh_res != null else AABB()

	for cell in data["foliage_data"]:
		var cell_transforms: Array[Transform3D] = cell["transforms"]
		if cell_transforms.is_empty():
			continue

		var mm = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = foliage_mesh_res
		mm.instance_count = cell_transforms.size()
		for i in range(cell_transforms.size()):
			mm.set_instance_transform(i, cell_transforms[i])

		var combined_aabb = cell_transforms[0] * mesh_aabb
		for i in range(1, cell_transforms.size()):
			combined_aabb = combined_aabb.merge(cell_transforms[i] * mesh_aabb)
		mm.custom_aabb = combined_aabb

		var mm_inst = MultiMeshInstance3D.new()
		mm_inst.name = "Foliage_C%d_%d" % [cell["cx"] + 1, cell["cz"] + 1]
		mm_inst.multimesh = mm
		mm_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mm_inst.extra_cull_margin = 2.0

		if config:
			mm_inst.visibility_range_end = config.foliage_visibility_range_end
			mm_inst.visibility_range_end_margin = config.foliage_fade_margin
			mm_inst.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED

		foliage_container.add_child(mm_inst)

	# 3. Setup Tree Colliders
	var trunk_shape_tall = CylinderShape3D.new()
	trunk_shape_tall.radius = 0.28
	trunk_shape_tall.height = 4.5

	var trunk_shape_med = CylinderShape3D.new()
	trunk_shape_med.radius = 0.20
	trunk_shape_med.height = 2.8

	var trunk_shape_low = CylinderShape3D.new()
	trunk_shape_low.radius = 0.14
	trunk_shape_low.height = 1.8

	for col_item in data["tree_colliders"]:
		var col = CollisionShape3D.new()
		var l_idx = col_item["l_idx"]
		if l_idx < 5:
			col.shape = trunk_shape_tall
		elif l_idx < 10:
			col.shape = trunk_shape_med
		else:
			col.shape = trunk_shape_low
		col.position = col_item["pos"]
		tree_colliders_body.add_child(col, false)

	# 4. Setup Tree MultiMeshes
	var live_variations = tree_factory.get_living_tree_variations()
	var live_transforms = data["live_transforms"]
	for q in range(4):
		for v in range(live_variations.size()):
			_create_tree_multimesh(live_variations[v], live_transforms[q][v], "Trees_Q%d_%d" % [q + 1, v + 1], config)


## Fast Bridson Poisson Disc Sampling in 2D bounded space with O(1) swap-and-pop
## Supports optional exclusion_zones for future POIs, cabins, and paths
static func _generate_poisson_disc_points(rng: RandomNumberGenerator, span_min: float, span_max: float, min_dist: float, k: int = 10, exclusion_zones: Array[Rect2] = []) -> Array[Vector2]:
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
