class_name ChunkTreeBuilder
extends RefCounted

## Handles Poisson disc sampling, tree distribution, colliders, and MultiMesh generation.
## Pure data calculations are static and thread-safe for WorkerThreadPool execution.


## Pure data generation for trees in a chunk. Thread-safe.
static func generate_trees_data(rng: RandomNumberGenerator, coord: Vector2i, config: ForestConfig, terrain_module: TerrainModule, height_grid: Array, num_variations: int) -> Dictionary:
	var half_size = config.chunk_size * 0.5
	var world_origin_x = float(coord.x) * config.chunk_size
	var world_origin_z = float(coord.y) * config.chunk_size

	var span_min = -half_size + config.tree_margin
	var span_max = half_size - config.tree_margin

	var tree_points = generate_poisson_disc_points(rng, span_min, span_max, config.min_tree_distance)

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


## Fast Bridson Poisson Disc Sampling in 2D bounded space with O(1) swap-and-pop
## Supports optional exclusion_zones for future POIs, cabins, and paths
static func generate_poisson_disc_points(rng: RandomNumberGenerator, span_min: float, span_max: float, min_dist: float, k: int = 10, exclusion_zones: Array[Rect2] = []) -> Array[Vector2]:
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


## Mounts tree trunk collision shapes into the static body
static func build_tree_colliders(tree_colliders_data: Array, colliders_body: StaticBody3D) -> void:
	var trunk_shape_tall = CylinderShape3D.new()
	trunk_shape_tall.radius = 0.28
	trunk_shape_tall.height = 4.5

	var trunk_shape_med = CylinderShape3D.new()
	trunk_shape_med.radius = 0.20
	trunk_shape_med.height = 2.8

	var trunk_shape_low = CylinderShape3D.new()
	trunk_shape_low.radius = 0.14
	trunk_shape_low.height = 1.8

	for col_item in tree_colliders_data:
		var col = CollisionShape3D.new()
		var l_idx = col_item["l_idx"]
		if l_idx < 5:
			col.shape = trunk_shape_tall
		elif l_idx < 10:
			col.shape = trunk_shape_med
		else:
			col.shape = trunk_shape_low
		col.position = col_item["pos"]
		colliders_body.add_child(col, false)


## Mounts tree MultiMesh instances partitioned by quadrant for efficient culling
static func build_tree_multimeshes(container: Node3D, live_variations: Array, live_transforms: Array, config: ForestConfig) -> void:
	for q in range(4):
		for v in range(live_variations.size()):
			var transforms = live_transforms[q][v]
			if transforms.is_empty():
				continue

			var mesh = live_variations[v]
			var mm = MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = mesh
			mm.instance_count = transforms.size()
			for i in range(transforms.size()):
				mm.set_instance_transform(i, transforms[i])

			var mesh_aabb = mesh.get_aabb()
			var combined_aabb = (transforms[0] as Transform3D) * mesh_aabb
			for i in range(1, transforms.size()):
				combined_aabb = combined_aabb.merge((transforms[i] as Transform3D) * mesh_aabb)
			mm.custom_aabb = combined_aabb

			var mm_inst = MultiMeshInstance3D.new()
			mm_inst.name = "Trees_Q%d_%d" % [q + 1, v + 1]
			mm_inst.multimesh = mm
			# Tight cull margin prevents shadow popping without rendering excessive offscreen trees
			mm_inst.extra_cull_margin = 4.0

			if config:
				mm_inst.visibility_range_end = config.tree_visibility_range_end
				mm_inst.visibility_range_end_margin = config.tree_fade_margin
				mm_inst.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
			container.add_child(mm_inst)
