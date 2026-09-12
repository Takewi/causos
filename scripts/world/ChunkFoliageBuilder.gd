class_name ChunkFoliageBuilder
extends RefCounted

## Handles generation, distribution, and MultiMesh instantiation for all 9 foliage and ground clutter archetypes.
## Pure data calculations are static and thread-safe for WorkerThreadPool execution.

const FOLIAGE_MESH_PATHS: Array[String] = [
	"res://assets/models/lowpoly_foliage.tres",
	"res://assets/models/foliage_grass_tall.tres",
	"res://assets/models/foliage_fern.tres",
	"res://assets/models/foliage_bush.tres",
	"res://assets/models/foliage_dry.tres",
	"res://assets/models/foliage_leaves_dry.tres",
	"res://assets/models/foliage_leaves_green.tres",
	"res://assets/models/foliage_twigs.tres",
	"res://assets/models/foliage_flower.tres"
]


## Pure data generation for foliage in a chunk. Thread-safe.
static func generate_foliage_data(rng: RandomNumberGenerator, config: ForestConfig, terrain_module: TerrainModule, height_grid: Array) -> Array:
	var foliage_data: Array = []
	var num_cells = 4
	var cell_size = config.chunk_size / float(num_cells)
	var half_chunk = config.chunk_size * 0.5

	for cz in range(num_cells):
		var z_min = -half_chunk + float(cz) * cell_size
		for cx in range(num_cells):
			var x_min = -half_chunk + float(cx) * cell_size
			# 9 archetypes:
			# 0=Grass, 1=TallGrass, 2=Fern, 3=Bush, 4=DryGrass,
			# 5=LeavesDry, 6=LeavesGreen, 7=Twigs, 8=Flowers
			var type_transforms: Array = [[], [], [], [], [], [], [], [], []]

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

						# Categorized distribution for baseline
						var roll = rng.randf()
						var t_idx = 0
						if roll < 0.24:
							t_idx = 0 # Common grass
						elif roll < 0.35:
							t_idx = 1 # Tall grass
							s *= 0.95
						elif roll < 0.46:
							t_idx = 2 # Native fern
							s *= 1.05
						elif roll < 0.52:
							t_idx = 3 # Leafy shrub / bush
							s *= 0.90
						elif roll < 0.56:
							t_idx = 4 # Dry straw grass
						elif roll < 0.72:
							t_idx = 5 # Fallen dry leaves on ground (~16%)
							s *= 1.25
						elif roll < 0.84:
							t_idx = 6 # Fresh fallen green leaves (~12%)
							s *= 1.20
						elif roll < 0.93:
							t_idx = 7 # Fallen dry twigs and branches (~9%)
							s *= 1.30
						else:
							t_idx = 8 # Forest wildflowers (~7%)
							s *= 1.15

						var b = Basis.from_euler(Vector3(tilt_x, rot_y, tilt_z))
						type_transforms[t_idx].append(Transform3D(b.scaled(Vector3(s, s, s)), Vector3(fx, h, fz)))

			# 2. Organic clustered clumps / touceiras (8 to 12 natural clumps per 25x25m cell)
			var num_clumps = rng.randi_range(8, 12)
			for _c in range(num_clumps):
				var clump_cx = rng.randf_range(x_min + 1.5, x_min + cell_size - 1.5)
				var clump_cz = rng.randf_range(z_min + 1.5, z_min + cell_size - 1.5)
				var clump_tufts = rng.randi_range(3, 5)
				var clump_scale_base = rng.randf_range(0.95, 1.45)

				# Species theme for this clump
				var clump_roll = rng.randf()
				var clump_type = 0
				if clump_roll < 0.20:
					clump_type = 0 # Dense grass clump
				elif clump_roll < 0.35:
					clump_type = 2 # Shaded fern grove
				elif clump_roll < 0.48:
					clump_type = 3 # Shrub / bush cluster
				elif clump_roll < 0.56:
					clump_type = 4 # Dry straw patch
				elif clump_roll < 0.74:
					clump_type = 5 # Fallen dry leaves / forest litter cluster (18%)
				elif clump_roll < 0.88:
					clump_type = 6 # Canopy leaf drop cluster (14%)
				else:
					clump_type = 8 # Wildflower garden patch (12%)

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

					var actual_type = clump_type
					if clump_type == 0 and rng.randf() > 0.60:
						actual_type = 1 # Tall grass
					elif clump_type == 3 and rng.randf() > 0.50:
						actual_type = 0 # Understory grass beneath bush
					elif clump_type == 5 and rng.randf() > 0.50:
						actual_type = 7 # Mix dry twigs into fallen leaf patches
					elif clump_type == 8 and rng.randf() > 0.75:
						actual_type = 6 # Mix fresh fallen leaves around flowers

					var b = Basis.from_euler(Vector3(tilt_x, rot_y, tilt_z))
					type_transforms[actual_type].append(Transform3D(b.scaled(Vector3(s, s, s)), Vector3(fx, h, fz)))

			var has_any = false
			for arr in type_transforms:
				if not arr.is_empty():
					has_any = true
					break

			if has_any:
				foliage_data.append({
					"cx": cx,
					"cz": cz,
					"type_transforms": type_transforms
				})

	return foliage_data


## Mounts all foliage MultiMesh instances into the foliage container node
static func build_foliage_multimeshes(container: Node3D, foliage_data: Array, config: ForestConfig) -> void:
	var foliage_meshes: Array[Mesh] = []
	var foliage_aabbs: Array[AABB] = []
	for p in FOLIAGE_MESH_PATHS:
		var m = load(p) as Mesh
		foliage_meshes.append(m)
		foliage_aabbs.append(m.get_aabb() if m != null else AABB())

	for cell in foliage_data:
		var type_transforms: Array = cell.get("type_transforms", [])
		if type_transforms.is_empty() and cell.has("transforms"):
			type_transforms = [cell["transforms"]]

		for t_idx in range(type_transforms.size()):
			var transforms: Array = type_transforms[t_idx]
			if transforms.is_empty():
				continue

			var mesh = foliage_meshes[t_idx] if t_idx < foliage_meshes.size() else foliage_meshes[0]
			if mesh == null:
				continue
			var mesh_aabb = foliage_aabbs[t_idx] if t_idx < foliage_aabbs.size() else foliage_aabbs[0]

			var mm = MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = mesh
			mm.instance_count = transforms.size()
			for i in range(transforms.size()):
				mm.set_instance_transform(i, transforms[i])

			var combined_aabb = transforms[0] * mesh_aabb
			for i in range(1, transforms.size()):
				combined_aabb = combined_aabb.merge(transforms[i] * mesh_aabb)
			mm.custom_aabb = combined_aabb

			var mm_inst = MultiMeshInstance3D.new()
			mm_inst.name = "Foliage_T%d_C%d_%d" % [t_idx, cell["cx"] + 1, cell["cz"] + 1]
			mm_inst.multimesh = mm
			mm_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mm_inst.extra_cull_margin = 2.0

			if config:
				mm_inst.visibility_range_end = config.foliage_visibility_range_end
				mm_inst.visibility_range_end_margin = config.foliage_fade_margin
				mm_inst.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED

			container.add_child(mm_inst)
