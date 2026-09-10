class_name TerrainModule
extends RefCounted

## Manages continuous procedural terrain noise, mesh generation, and physics collision.
var noise: FastNoiseLite
var ground_material: StandardMaterial3D
var amplitude: float = 5.0


func _init(config: ForestConfig = null) -> void:
	noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM

	if config != null:
		noise.seed = config.world_seed
		noise.frequency = config.noise_frequency
		noise.fractal_octaves = config.noise_octaves
		amplitude = config.terrain_amplitude
	else:
		noise.seed = 1337
		noise.frequency = 0.011
		noise.fractal_octaves = 3
		amplitude = 5.0

	noise.fractal_lacunarity = 2.0
	noise.fractal_gain = 0.5

	# Cache ground material (Flat shaded, nearest filter, warm reflective albedo)
	ground_material = StandardMaterial3D.new()
	var tex = load("res://assets/textures/ground.png")
	if tex != null:
		ground_material.albedo_texture = tex
	ground_material.albedo_color = Color(1.10, 1.08, 1.02) # Boosts light reflection in shade and sunlight
	ground_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	ground_material.texture_repeat = true
	ground_material.roughness = 0.9
	ground_material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	ground_material.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT


## Continuous height calculation sampled in global world space
func get_height(world_x: float, world_z: float) -> float:
	return noise.get_noise_2d(world_x, world_z) * amplitude


## Exact interpolated height on the triangulated terrain polygon mesh
func get_mesh_height(world_x: float, world_z: float, config: ForestConfig = null) -> float:
	var chunk_size = config.chunk_size if config else 100.0
	var segments = config.terrain_segments if config else 32
	var step = chunk_size / float(segments)

	var gx = world_x / step
	var gz = world_z / step
	var ix = int(floor(gx))
	var iz = int(floor(gz))
	var u = gx - float(ix)
	var v = gz - float(iz)

	var x0 = float(ix) * step
	var z0 = float(iz) * step
	var x1 = x0 + step
	var z1 = z0 + step

	var h00 = get_height(x0, z0)
	var h10 = get_height(x1, z0)
	var h01 = get_height(x0, z1)
	var h11 = get_height(x1, z1)

	if u + v <= 1.0:
		return h00 + u * (h10 - h00) + v * (h01 - h00)
	else:
		return h11 + (1.0 - u) * (h01 - h11) + (1.0 - v) * (h10 - h11)


## Generates a 32x32 segmented flat-shaded terrain mesh for a chunk
func generate_terrain_mesh(chunk_coord: Vector2i, config: ForestConfig) -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var segments: int = config.terrain_segments if config else 32
	var chunk_size: float = config.chunk_size if config else 100.0
	var half_size: float = chunk_size * 0.5
	var step: float = chunk_size / float(segments)

	var world_origin_x: float = float(chunk_coord.x) * chunk_size
	var world_origin_z: float = float(chunk_coord.y) * chunk_size

	# Sample height grid in global coordinates for seamless boundaries
	var heights: Array = []
	for iz in range(segments + 1):
		var row: Array[float] = []
		var lz: float = -half_size + float(iz) * step
		var wz: float = world_origin_z + lz
		for ix in range(segments + 1):
			var lx: float = -half_size + float(ix) * step
			var wx: float = world_origin_x + lx
			row.append(get_height(wx, wz))
		heights.append(row)

	# Generate flat-shaded triangular faces with face normals
	for iz in range(segments):
		var z0: float = -half_size + float(iz) * step
		var z1: float = z0 + step
		var wz0: float = world_origin_z + z0
		var wz1: float = world_origin_z + z1

		for ix in range(segments):
			var x0: float = -half_size + float(ix) * step
			var x1: float = x0 + step
			var wx0: float = world_origin_x + x0
			var wx1: float = world_origin_x + x1

			var p00 = Vector3(x0, heights[iz][ix], z0)
			var p10 = Vector3(x1, heights[iz][ix + 1], z0)
			var p01 = Vector3(x0, heights[iz + 1][ix], z1)
			var p11 = Vector3(x1, heights[iz + 1][ix + 1], z1)

			# Tri 1: p00, p10, p01
			var n1 = (p10 - p00).cross(p01 - p00).normalized()
			st.set_normal(n1)
			st.set_uv(Vector2(wx0 * 0.25, wz0 * 0.25))
			st.add_vertex(p00)
			st.set_normal(n1)
			st.set_uv(Vector2(wx1 * 0.25, wz0 * 0.25))
			st.add_vertex(p10)
			st.set_normal(n1)
			st.set_uv(Vector2(wx0 * 0.25, wz1 * 0.25))
			st.add_vertex(p01)

			# Tri 2: p10, p11, p01
			var n2 = (p11 - p10).cross(p01 - p10).normalized()
			st.set_normal(n2)
			st.set_uv(Vector2(wx1 * 0.25, wz0 * 0.25))
			st.add_vertex(p10)
			st.set_normal(n2)
			st.set_uv(Vector2(wx1 * 0.25, wz1 * 0.25))
			st.add_vertex(p11)
			st.set_normal(n2)
			st.set_uv(Vector2(wx0 * 0.25, wz1 * 0.25))
			st.add_vertex(p01)

	st.set_material(ground_material)
	return st.commit()


## Creates an exact concave collision shape matching the terrain geometry
func generate_collision_shape(terrain_mesh: ArrayMesh) -> ConcavePolygonShape3D:
	return terrain_mesh.create_trimesh_shape()
