class_name ForestConfig
extends Resource

## World & Chunk Geometry
@export_group("Chunk Settings")
@export var chunk_size: float = 100.0
@export var terrain_segments: int = 32
@export var world_seed: int = 0
@export var grid_size: Vector2i = Vector2i(16, 16) # 16x16 chunks = 1600x1600m (~2.56 km²)
@export var active_radius: int = 1 # 1 = 3x3 active grid (9 chunks)


func _init() -> void:
	if world_seed == 0:
		var rng = RandomNumberGenerator.new()
		rng.randomize()
		world_seed = rng.randi_range(10000, 99999999)


## Terrain Generation
@export_group("Terrain")
@export var terrain_amplitude: float = 5.0 # ~4 to 6m relief (-5m to +5m)
@export var noise_frequency: float = 0.011
@export var noise_octaves: int = 3

## Tree Spacing & Organic Placement (Poisson Disc Sampling)
@export_group("Trees")
@export var min_tree_distance: float = 3.0 # Poisson minimum distance (reduces density by ~30%, opens clearings)
@export var tree_margin: float = 0.0 # Zero margin so trees spawn right up to chunk borders, eliminating corridors
@export var tree_visibility_range_end: float = 75.0 # Extended beyond fog (45m) so no tree popping is ever visible
@export var tree_fade_margin: float = 0.0 # Disabled fade margin to eliminate any semi-transparent trees

## Ground Foliage
@export_group("Foliage")
@export var foliage_count: int = 2400 # Rich stratified ground cover & natural clusters (150 per 25x25m cell)
@export var foliage_visibility_range_end: float = 60.0 # Beyond 45m opaque fog limit so sub-cells never pop into view
@export var foliage_fade_margin: float = 0.0

## Lighting & Atmosphere (Atmospheric Green Mist Forest)
@export_group("Atmosphere & Lighting")
@export var max_shadow_distance: float = 45.0 # Focused shadow cascades covering up to opaque fog limit
@export var sun_light_energy: float = 2.0 # Vivid sun light penetrating canopy
@export var sun_light_color: Color = Color(1.0, 0.88, 0.65) # Warm sun rays
@export var ambient_light_color: Color = Color(0.32, 0.40, 0.28) # Canopy green ambient penumbra
@export var ambient_light_energy: float = 0.85 # High ambient energy (no pitch black)
@export var fog_color: Color = Color(0.24, 0.35, 0.22) # Atmospheric greenish mist
@export var fog_depth_begin: float = 8.0 # Soft progressive beginning near player (8m)
@export var fog_depth_end: float = 45.0 # 100% opaque wall of mist at 45m
@export var fog_density: float = 1.0 # 1.0 = 100% opaque at fog_depth_end in Depth Fog mode
