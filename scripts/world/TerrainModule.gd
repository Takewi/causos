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
		var rng = RandomNumberGenerator.new()
		rng.randomize()
		noise.seed = rng.randi_range(10000, 99999999)
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


## Precomputes the 2D height grid (segments+1 x segments+1) for a chunk.
## Can be called safely on background threads.
func generate_chunk_height_grid(chunk_coord: Vector2i, config: ForestConfig) -> Array:
	var segments: int = config.terrain_segments if config else 32
	var chunk_size: float = config.chunk_size if config else 100.0
	var half_size: float = chunk_size * 0.5
	var step: float = chunk_size / float(segments)

	var world_origin_x: float = float(chunk_coord.x) * chunk_size
	var world_origin_z: float = float(chunk_coord.y) * chunk_size

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
	return heights


## Performs fast local bilinear interpolation using the chunk's precomputed height grid.
## Local coordinates (local_x, local_z) range from -chunk_size*0.5 to +chunk_size*0.5.
## Requires 0 noise queries, running >2.5x faster than continuous get_mesh_height.
func get_grid_mesh_height(height_grid: Array, local_x: float, local_z: float, config: ForestConfig) -> float:
	var segments: int = config.terrain_segments if config else 32
	var chunk_size: float = config.chunk_size if config else 100.0
	var half_size: float = chunk_size * 0.5
	var step: float = chunk_size / float(segments)
	var inv_step: float = 1.0 / step

	var gx: float = (local_x + half_size) * inv_step
	var gz: float = (local_z + half_size) * inv_step
	var ix: int = int(floor(gx))
	var iz: int = int(floor(gz))
	if ix < 0:
		ix = 0
	elif ix >= segments:
		ix = segments - 1
	if iz < 0:
		iz = 0
	elif iz >= segments:
		iz = segments - 1

	var u: float = gx - float(ix)
	var v: float = gz - float(iz)

	var h00: float = height_grid[iz][ix]
	var h10: float = height_grid[iz][ix + 1]
	var h01: float = height_grid[iz + 1][ix]
	var h11: float = height_grid[iz + 1][ix + 1]

	if u + v <= 1.0:
		return h00 + u * (h10 - h00) + v * (h01 - h00)
	else:
		return h11 + (1.0 - u) * (h01 - h11) + (1.0 - v) * (h10 - h11)


## Builds raw ArrayMesh mesh arrays (vertices, normals, uvs) from precomputed height grid.
## Pure data manipulation (no RenderingServer / SceneTree dependency), 100% thread-safe.
func build_mesh_arrays(chunk_coord: Vector2i, config: ForestConfig, height_grid: Array) -> Array:
	var segments: int = config.terrain_segments if config else 32
	var chunk_size: float = config.chunk_size if config else 100.0
	var half_size: float = chunk_size * 0.5
	var step: float = chunk_size / float(segments)

	var world_origin_x: float = float(chunk_coord.x) * chunk_size
	var world_origin_z: float = float(chunk_coord.y) * chunk_size

	var num_quads: int = segments * segments
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()

	vertices.resize(num_quads * 6)
	normals.resize(num_quads * 6)
	uvs.resize(num_quads * 6)

	var v_idx: int = 0
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

			var p00 = Vector3(x0, height_grid[iz][ix], z0)
			var p10 = Vector3(x1, height_grid[iz][ix + 1], z0)
			var p01 = Vector3(x0, height_grid[iz + 1][ix], z1)
			var p11 = Vector3(x1, height_grid[iz + 1][ix + 1], z1)

			# Tri 1: p00, p10, p01
			var n1 = (p10 - p00).cross(p01 - p00).normalized()
			var uv00 = Vector2(wx0 * 0.25, wz0 * 0.25)
			var uv10 = Vector2(wx1 * 0.25, wz0 * 0.25)
			var uv01 = Vector2(wx0 * 0.25, wz1 * 0.25)

			normals[v_idx] = n1; uvs[v_idx] = uv00; vertices[v_idx] = p00; v_idx += 1
			normals[v_idx] = n1; uvs[v_idx] = uv10; vertices[v_idx] = p10; v_idx += 1
			normals[v_idx] = n1; uvs[v_idx] = uv01; vertices[v_idx] = p01; v_idx += 1

			# Tri 2: p10, p11, p01
			var n2 = (p11 - p10).cross(p01 - p10).normalized()
			var uv11 = Vector2(wx1 * 0.25, wz1 * 0.25)

			normals[v_idx] = n2; uvs[v_idx] = uv10; vertices[v_idx] = p10; v_idx += 1
			normals[v_idx] = n2; uvs[v_idx] = uv11; vertices[v_idx] = p11; v_idx += 1
			normals[v_idx] = n2; uvs[v_idx] = uv01; vertices[v_idx] = p01; v_idx += 1

	var mesh_arrays = []
	mesh_arrays.resize(Mesh.ARRAY_MAX)
	mesh_arrays[Mesh.ARRAY_VERTEX] = vertices
	mesh_arrays[Mesh.ARRAY_NORMAL] = normals
	mesh_arrays[Mesh.ARRAY_TEX_UV] = uvs
	return mesh_arrays


## Generates a 32x32 segmented flat-shaded terrain mesh for a chunk
func generate_terrain_mesh(chunk_coord: Vector2i, config: ForestConfig, height_grid: Array = []) -> ArrayMesh:
	if height_grid.is_empty():
		height_grid = generate_chunk_height_grid(chunk_coord, config)

	var mesh_arrays = build_mesh_arrays(chunk_coord, config, height_grid)
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh_arrays)
	mesh.surface_set_material(0, ground_material)
	return mesh


## Creates an exact concave collision shape matching the terrain geometry
func generate_collision_shape(terrain_mesh: ArrayMesh) -> ConcavePolygonShape3D:
	return terrain_mesh.create_trimesh_shape()
