@tool
class_name TreeGenerator
extends RefCounted

## Generates a tall, native retro-90s low-poly tree mesh with faceted branches and crossed quad foliage.
static func build_tree_mesh(params: Dictionary = {}) -> ArrayMesh:
	var seed_val: int = params.get("seed", 1337)
	var total_height: float = params.get("total_height", 12.0)
	var clear_trunk_height: float = params.get("clear_trunk_height", 4.2)
	var sides: int = params.get("sides", 5) # 5 to 6 sided cylinders
	var spread_angle: float = params.get("spread_angle", 0.85) # radians from vertical (~50 deg)
	var branch_depth: int = params.get("branch_depth", 3)
	var branch_spread_h: float = params.get("branch_spread_h", 4.5)
	var trunk_radius_base: float = params.get("trunk_radius_base", 0.38)
	var foliage_quad_size: float = params.get("foliage_quad_size", 2.6)
	var bark_color: Color = params.get("bark_color", Color(0.24, 0.16, 0.10))

	var rng = RandomNumberGenerator.new()
	rng.seed = seed_val

	var st_bark = SurfaceTool.new()
	st_bark.begin(Mesh.PRIMITIVE_TRIANGLES)

	var st_foliage = SurfaceTool.new()
	st_foliage.begin(Mesh.PRIMITIVE_TRIANGLES)

	# 1. First 4+ meters: clear unobstructed trunk
	var p0 = Vector3.ZERO
	var p1 = Vector3(rng.randf_range(-0.15, 0.15), clear_trunk_height * 0.5, rng.randf_range(-0.15, 0.15))
	var p2 = Vector3(rng.randf_range(-0.3, 0.3), clear_trunk_height, rng.randf_range(-0.3, 0.3))

	var r0 = trunk_radius_base
	var r1 = trunk_radius_base * 0.88
	var r2 = trunk_radius_base * 0.76

	_build_cylinder_segment(st_bark, p0, p1, r0, r1, sides)
	_build_cylinder_segment(st_bark, p1, p2, r1, r2, sides)

	# 2. Middle trunk up to lower branch canopy (~6.5 - 7.5m)
	var mid_height = clear_trunk_height + (total_height - clear_trunk_height) * 0.35
	var p3 = p2 + Vector3(rng.randf_range(-0.4, 0.4), mid_height - clear_trunk_height, rng.randf_range(-0.4, 0.4))
	var r3 = r2 * 0.85
	_build_cylinder_segment(st_bark, p2, p3, r2, r3, sides)

	# 3. Recursive branching from mid_height onwards to reach 10-14m and spread horizontally
	var main_branches_count = params.get("main_branches", 4)
	for b in range(main_branches_count):
		var angle = (float(b) / float(main_branches_count)) * TAU + rng.randf_range(-0.3, 0.3)
		# Direction tilted outward horizontally to intertwine with neighbors
		var tilt = spread_angle + rng.randf_range(-0.15, 0.2)
		var dir = Vector3(cos(angle) * sin(tilt), cos(tilt), sin(angle) * sin(tilt)).normalized()
		var branch_len = (total_height - mid_height) * rng.randf_range(0.45, 0.6)
		_grow_branch(st_bark, st_foliage, p3, dir, branch_len, r3, r3 * 0.65, 1, branch_depth, sides, foliage_quad_size, spread_angle, rng)

	# Add central top leader branch
	var leader_dir = Vector3(rng.randf_range(-0.1, 0.1), 1.0, rng.randf_range(-0.1, 0.1)).normalized()
	_grow_branch(st_bark, st_foliage, p3, leader_dir, (total_height - mid_height) * 0.55, r3 * 0.8, r3 * 0.5, 1, branch_depth, sides, foliage_quad_size, spread_angle * 0.7, rng)

	# Setup Materials
	var bark_mat = StandardMaterial3D.new()
	bark_mat.albedo_color = bark_color
	bark_mat.roughness = 1.0
	bark_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	bark_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	bark_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT

	var foliage_mat = StandardMaterial3D.new()
	var tex = load("res://assets/textures/canopy_leaves.png")
	if tex == null:
		tex = load("res://assets/textures/foliage.png")
	foliage_mat.albedo_texture = tex
	foliage_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	foliage_mat.alpha_scissor_threshold = 0.5
	foliage_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	foliage_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	foliage_mat.roughness = 1.0
	foliage_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	foliage_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT

	# Commit Surfaces into single ArrayMesh
	st_bark.set_material(bark_mat)
	var mesh = st_bark.commit()

	st_foliage.set_material(foliage_mat)
	mesh = st_foliage.commit(mesh)

	return mesh


static func _grow_branch(st_bark: SurfaceTool, st_foliage: SurfaceTool, start_pt: Vector3, dir: Vector3, length: float, r_start: float, r_end: float, depth: int, max_depth: int, sides: int, fol_size: float, base_spread: float, rng: RandomNumberGenerator) -> void:
	var end_pt = start_pt + dir * length
	_build_cylinder_segment(st_bark, start_pt, end_pt, r_start, r_end, sides)

	if depth >= max_depth:
		# Terminal tip: create crossed quads for dense canopy foliage
		_add_foliage_cross_quads(st_foliage, end_pt, fol_size, rng)
		# Also add intermediate foliage clump along the branch
		_add_foliage_cross_quads(st_foliage, (start_pt + end_pt) * 0.5, fol_size * 0.85, rng)
		return

	# Branch out recursively
	var sub_count = rng.randi_range(2, 3)
	for i in range(sub_count):
		# Create orthogonal tangent vector
		var up = Vector3.UP if abs(dir.dot(Vector3.UP)) < 0.85 else Vector3.RIGHT
		var side_vec = dir.cross(up).normalized()
		var norm_vec = side_vec.cross(dir).normalized()

		var angle = (float(i) / float(sub_count)) * TAU + rng.randf_range(-0.4, 0.4)
		var spread = base_spread * rng.randf_range(0.8, 1.25)
		# Blend current direction with outward radial direction
		var radial = (side_vec * cos(angle) + norm_vec * sin(angle)).normalized()
		var new_dir = (dir * cos(spread * 0.6) + radial * sin(spread * 0.6)).normalized()
		# Add slight upward lift
		new_dir = (new_dir + Vector3(0, 0.15, 0)).normalized()

		var new_len = length * rng.randf_range(0.72, 0.88)
		var new_r_start = r_end
		var new_r_end = max(0.06, r_end * 0.6)

		_grow_branch(st_bark, st_foliage, end_pt, new_dir, new_len, new_r_start, new_r_end, depth + 1, max_depth, sides, fol_size, base_spread, rng)


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

		# Tri 1: p0, p1, p2 (Strict Flat Face Normal)
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

		# Tri 2: p0, p2, p3 (Strict Flat Face Normal)
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


static func _add_foliage_cross_quads(st: SurfaceTool, center: Vector3, size: float, rng: RandomNumberGenerator) -> void:
	# 3 crossed quads at 0, 60, 120 degrees for full 3D canopy coverage
	var half_w = size * 0.5
	var h = size * 0.85
	var y_offset = -h * 0.35

	for q in range(3):
		var rot_angle = float(q) * (PI / 3.0) + rng.randf_range(-0.2, 0.2)
		var forward = Vector3(cos(rot_angle), 0, sin(rot_angle))
		var right = Vector3(-sin(rot_angle), 0, cos(rot_angle))

		var p0 = center + right * -half_w + Vector3(0, y_offset, 0)
		var p1 = center + right * half_w + Vector3(0, y_offset, 0)
		var p2 = center + right * half_w + Vector3(0, y_offset + h, 0)
		var p3 = center + right * -half_w + Vector3(0, y_offset + h, 0)

		# Tri 1
		var n1 = (p1 - p0).cross(p2 - p0).normalized()
		st.set_normal(n1)
		st.set_uv(Vector2(0, 1))
		st.add_vertex(p0)
		st.set_normal(n1)
		st.set_uv(Vector2(1, 1))
		st.add_vertex(p1)
		st.set_normal(n1)
		st.set_uv(Vector2(1, 0))
		st.add_vertex(p2)

		# Tri 2
		st.set_normal(n1)
		st.set_uv(Vector2(0, 1))
		st.add_vertex(p0)
		st.set_normal(n1)
		st.set_uv(Vector2(1, 0))
		st.add_vertex(p2)
		st.set_normal(n1)
		st.set_uv(Vector2(0, 0))
		st.add_vertex(p3)


## Generates and saves the 3 distinct base tree variations
static func generate_and_save_variations() -> Array[Mesh]:
	var variations: Array[Mesh] = []

	# Variation 1: Wide Spreading Native Canopy (Spans horizontally up to 5-6m)
	var v1_params = {
		"seed": 101,
		"total_height": 11.5,
		"clear_trunk_height": 4.0,
		"sides": 5,
		"spread_angle": 1.1, # ~63 degrees (wide horizontal spread)
		"main_branches": 4,
		"branch_depth": 3,
		"trunk_radius_base": 0.40,
		"foliage_quad_size": 2.8,
		"bark_color": Color(0.25, 0.17, 0.11),
	}
	var m1 = build_tree_mesh(v1_params)
	ResourceSaver.save(m1, "res://assets/models/tree_variation_1.tres")
	variations.append(m1)

	# Variation 2: Tall Intertwining Native Tree (13.5m tall with organic curves)
	var v2_params = {
		"seed": 202,
		"total_height": 13.5,
		"clear_trunk_height": 4.3,
		"sides": 5,
		"spread_angle": 0.85, # ~48 degrees (taller reach)
		"main_branches": 5,
		"branch_depth": 3,
		"trunk_radius_base": 0.44,
		"foliage_quad_size": 2.6,
		"bark_color": Color(0.21, 0.15, 0.10),
	}
	var m2 = build_tree_mesh(v2_params)
	ResourceSaver.save(m2, "res://assets/models/tree_variation_2.tres")
	variations.append(m2)

	# Variation 3: Gnarled / Angular Dense Native Tree (Sharp low-poly twists)
	var v3_params = {
		"seed": 303,
		"total_height": 10.8,
		"clear_trunk_height": 4.0,
		"sides": 5,
		"spread_angle": 1.0,
		"main_branches": 4,
		"branch_depth": 3,
		"trunk_radius_base": 0.42,
		"foliage_quad_size": 3.0,
		"bark_color": Color(0.19, 0.14, 0.09),
	}
	var m3 = build_tree_mesh(v3_params)
	ResourceSaver.save(m3, "res://assets/models/tree_variation_3.tres")
	variations.append(m3)

	# Also update default lowpoly_tree.tres with m1
	ResourceSaver.save(m1, "res://assets/models/lowpoly_tree.tres")

	return variations
