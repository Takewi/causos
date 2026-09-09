class_name TreeMeshFactory
extends RefCounted

## Compiles and provides static, low-poly tree mesh variations with optimized GPU materials
var cached_variations: Array[Mesh] = []


func get_tree_variations() -> Array[Mesh]:
	if not cached_variations.is_empty():
		return cached_variations

	# Try loading pre-compiled resources first
	var paths = [
		"res://assets/models/tree_variation_1.tres",
		"res://assets/models/tree_variation_2.tres",
		"res://assets/models/tree_variation_3.tres"
	]

	var loaded_all = true
	var loaded_meshes: Array[Mesh] = []
	for p in paths:
		if ResourceLoader.exists(p):
			var m = load(p) as Mesh
			if m != null:
				loaded_meshes.append(m)
			else:
				loaded_all = false
		else:
			loaded_all = false

	if loaded_all and loaded_meshes.size() == 3:
		cached_variations = loaded_meshes
		return cached_variations

	# Otherwise compile them freshly
	return compile_and_cache_variations()


## Compiles the 3 distinct base tree variations with Per-Vertex Alpha Scissor and 6-8 canopy planes
func compile_and_cache_variations() -> Array[Mesh]:
	cached_variations.clear()

	# Variation 1: Wide Spreading Native Canopy (11.5m, broad horizontal reach)
	var v1_params = {
		"seed": 101,
		"total_height": 11.5,
		"clear_trunk_height": 4.0,
		"sides": 5,
		"spread_angle": 1.1,
		"main_branches": 4,
		"max_canopy_planes": 7,
		"canopy_plane_size": 3.8,
		"trunk_radius_base": 0.40,
		"bark_color": Color(0.25, 0.17, 0.11),
	}
	var m1 = _build_optimized_tree_mesh(v1_params)
	ResourceSaver.save(m1, "res://assets/models/tree_variation_1.tres")
	cached_variations.append(m1)

	# Variation 2: Tall Intertwining Native Tree (13.5m, organic upward curve)
	var v2_params = {
		"seed": 202,
		"total_height": 13.5,
		"clear_trunk_height": 4.3,
		"sides": 5,
		"spread_angle": 0.85,
		"main_branches": 4,
		"max_canopy_planes": 8,
		"canopy_plane_size": 3.5,
		"trunk_radius_base": 0.44,
		"bark_color": Color(0.21, 0.15, 0.10),
	}
	var m2 = _build_optimized_tree_mesh(v2_params)
	ResourceSaver.save(m2, "res://assets/models/tree_variation_2.tres")
	cached_variations.append(m2)

	# Variation 3: Gnarled / Angular Dense Native Tree (10.8m, sharp twists)
	var v3_params = {
		"seed": 303,
		"total_height": 10.8,
		"clear_trunk_height": 4.0,
		"sides": 5,
		"spread_angle": 1.05,
		"main_branches": 4,
		"max_canopy_planes": 6,
		"canopy_plane_size": 4.2,
		"trunk_radius_base": 0.42,
		"bark_color": Color(0.19, 0.14, 0.09),
	}
	var m3 = _build_optimized_tree_mesh(v3_params)
	ResourceSaver.save(m3, "res://assets/models/tree_variation_3.tres")
	cached_variations.append(m3)

	# Also update default lowpoly_tree.tres
	ResourceSaver.save(m1, "res://assets/models/lowpoly_tree.tres")

	return cached_variations


func _build_optimized_tree_mesh(params: Dictionary) -> ArrayMesh:
	var seed_val: int = params.get("seed", 1337)
	var total_height: float = params.get("total_height", 12.0)
	var clear_trunk_height: float = params.get("clear_trunk_height", 4.2)
	var sides: int = params.get("sides", 5)
	var spread_angle: float = params.get("spread_angle", 0.95)
	var trunk_radius_base: float = params.get("trunk_radius_base", 0.40)
	var max_canopy_planes: int = params.get("max_canopy_planes", 7)
	var canopy_plane_size: float = params.get("canopy_plane_size", 3.8)
	var bark_color: Color = params.get("bark_color", Color(0.24, 0.16, 0.10))

	var rng = RandomNumberGenerator.new()
	rng.seed = seed_val

	var st_bark = SurfaceTool.new()
	st_bark.begin(Mesh.PRIMITIVE_TRIANGLES)

	var st_foliage = SurfaceTool.new()
	st_foliage.begin(Mesh.PRIMITIVE_TRIANGLES)

	# 1. Unobstructed lower trunk (0.0 to clear_trunk_height)
	var p0 = Vector3.ZERO
	var p1 = Vector3(rng.randf_range(-0.15, 0.15), clear_trunk_height * 0.5, rng.randf_range(-0.15, 0.15))
	var p2 = Vector3(rng.randf_range(-0.3, 0.3), clear_trunk_height, rng.randf_range(-0.3, 0.3))

	var r0 = trunk_radius_base
	var r1 = trunk_radius_base * 0.88
	var r2 = trunk_radius_base * 0.76

	_build_cylinder_segment(st_bark, p0, p1, r0, r1, sides)
	_build_cylinder_segment(st_bark, p1, p2, r1, r2, sides)

	# 2. Trunk continuation up to branching height (~6.5 - 7.5m)
	var mid_height = clear_trunk_height + (total_height - clear_trunk_height) * 0.35
	var p3 = p2 + Vector3(rng.randf_range(-0.35, 0.35), mid_height - clear_trunk_height, rng.randf_range(-0.35, 0.35))
	var r3 = r2 * 0.82
	_build_cylinder_segment(st_bark, p2, p3, r2, r3, sides)

	# 3. Main spreading branches reaching 10-14m and spreading horizontally
	var main_branches_count = params.get("main_branches", 4)
	var canopy_points: Array[Vector3] = []

	for b in range(main_branches_count):
		var angle = (float(b) / float(main_branches_count)) * TAU + rng.randf_range(-0.25, 0.25)
		var tilt = spread_angle + rng.randf_range(-0.1, 0.15)
		var dir = Vector3(cos(angle) * sin(tilt), cos(tilt), sin(angle) * sin(tilt)).normalized()
		var branch_len = (total_height - mid_height) * rng.randf_range(0.48, 0.65)
		var branch_end = p3 + dir * branch_len
		_build_cylinder_segment(st_bark, p3, branch_end, r3, r3 * 0.62, sides)

		# Sub-branch 1
		var sub_dir1 = (dir + Vector3(rng.randf_range(-0.4, 0.4), rng.randf_range(0.1, 0.3), rng.randf_range(-0.4, 0.4))).normalized()
		var sub_end1 = branch_end + sub_dir1 * (branch_len * 0.6)
		_build_cylinder_segment(st_bark, branch_end, sub_end1, r3 * 0.62, r3 * 0.35, sides)
		canopy_points.append(sub_end1)

		# Sub-branch 2
		var sub_dir2 = (dir + Vector3(rng.randf_range(-0.4, 0.4), rng.randf_range(0.1, 0.3), rng.randf_range(-0.4, 0.4))).normalized()
		var sub_end2 = branch_end + sub_dir2 * (branch_len * 0.55)
		_build_cylinder_segment(st_bark, branch_end, sub_end2, r3 * 0.62, r3 * 0.35, sides)
		canopy_points.append(sub_end2)

	# Central leader
	var leader_dir = Vector3(rng.randf_range(-0.1, 0.1), 1.0, rng.randf_range(-0.1, 0.1)).normalized()
	var leader_end = p3 + leader_dir * ((total_height - mid_height) * 0.75)
	_build_cylinder_segment(st_bark, p3, leader_end, r3 * 0.75, r3 * 0.4, sides)
	canopy_points.append(leader_end)

	# 4. Foliage Planes - Strictly limited to 6 to 8 larger intersecting 2D planes to eliminate GPU overdraw
	var num_planes = min(max_canopy_planes, canopy_points.size())
	for i in range(num_planes):
		var center = canopy_points[i]
		var plane_angle = float(i) * (TAU / float(num_planes)) + rng.randf_range(-0.2, 0.2)
		var tilt_y = rng.randf_range(-0.2, 0.2)
		var s = canopy_plane_size * rng.randf_range(0.9, 1.15)
		_add_single_canopy_quad(st_foliage, center, s, plane_angle, tilt_y)

	# GPU Optimized Materials
	# Bark: Per-Vertex Shading, Lambert diffuse, no specular
	var bark_mat = StandardMaterial3D.new()
	bark_mat.albedo_color = bark_color
	bark_mat.roughness = 1.0
	bark_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	bark_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	bark_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT
	bark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX

	# Foliage: Alpha Scissor, Per-Vertex Shading (drastically reduces fragment shader cost!), Cull Disabled
	var foliage_mat = StandardMaterial3D.new()
	var tex = load("res://assets/textures/canopy_leaves.png")
	if tex == null:
		tex = load("res://assets/textures/foliage.png")
	foliage_mat.albedo_texture = tex
	foliage_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	foliage_mat.alpha_scissor_threshold = 0.5
	foliage_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	foliage_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	foliage_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	foliage_mat.roughness = 1.0
	foliage_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	foliage_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT

	st_bark.set_material(bark_mat)
	var mesh = st_bark.commit()

	st_foliage.set_material(foliage_mat)
	mesh = st_foliage.commit(mesh)

	return mesh


static func _build_cylinder_segment(st: SurfaceTool, start_pt: Vector3, end_pt: Vector3, r_start: float, r_end: float, sides: int) -> void:
	var dir = (end_pt - start_pt).normalized()
	if dir.length_squared() < 0.001:
		return
	var up = Vector3.UP if abs(dir.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT
	var right = dir.cross(up).normalized()
	var forward = right.cross(dir).normalized()

	var v_start: Array[Vector3] = []
	var v_end: Array[Vector3] = []
	for i in range(sides):
		var angle = float(i) * TAU / float(sides)
		var offset = right * cos(angle) + forward * sin(angle)
		v_start.append(start_pt + offset * r_start)
		v_end.append(end_pt + offset * r_end)

	for i in range(sides):
		var next = (i + 1) % sides
		var p0 = v_start[i]
		var p1 = v_start[next]
		var p2 = v_end[next]
		var p3 = v_end[i]

		var n1 = (p1 - p0).cross(p2 - p0).normalized()
		st.set_normal(n1)
		st.set_uv(Vector2(0, 0))
		st.add_vertex(p0)
		st.set_normal(n1)
		st.set_uv(Vector2(1, 0))
		st.add_vertex(p1)
		st.set_normal(n1)
		st.set_uv(Vector2(1, 1))
		st.add_vertex(p2)

		var n2 = (p2 - p0).cross(p3 - p0).normalized()
		st.set_normal(n2)
		st.set_uv(Vector2(0, 0))
		st.add_vertex(p0)
		st.set_normal(n2)
		st.set_uv(Vector2(1, 1))
		st.add_vertex(p2)
		st.set_normal(n2)
		st.set_uv(Vector2(0, 1))
		st.add_vertex(p3)


static func _add_single_canopy_quad(st: SurfaceTool, center: Vector3, size: float, angle_rad: float, tilt_y: float) -> void:
	var half_w = size * 0.5
	var h = size * 0.85

	var right = Vector3(cos(angle_rad), tilt_y, sin(angle_rad)).normalized()
	var up = Vector3.UP

	var p0 = center - right * half_w - up * (h * 0.3)
	var p1 = center + right * half_w - up * (h * 0.3)
	var p2 = center + right * half_w + up * (h * 0.7)
	var p3 = center - right * half_w + up * (h * 0.7)

	var n = (p1 - p0).cross(p2 - p0).normalized()

	st.set_normal(n)
	st.set_uv(Vector2(0, 1))
	st.add_vertex(p0)
	st.set_normal(n)
	st.set_uv(Vector2(1, 1))
	st.add_vertex(p1)
	st.set_normal(n)
	st.set_uv(Vector2(1, 0))
	st.add_vertex(p2)

	st.set_normal(n)
	st.set_uv(Vector2(0, 1))
	st.add_vertex(p0)
	st.set_normal(n)
	st.set_uv(Vector2(1, 0))
	st.add_vertex(p2)
	st.set_normal(n)
	st.set_uv(Vector2(0, 0))
	st.add_vertex(p3)
