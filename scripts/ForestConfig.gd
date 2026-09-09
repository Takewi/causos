class_name ForestConfig
extends Resource

## World & Chunk Geometry
@export_group("Chunk Settings")
@export var chunk_size: float = 100.0
@export var terrain_segments: int = 32
@export var world_seed: int = 1337
@export var grid_size: Vector2i = Vector2i(16, 16) # 16x16 chunks = 1600x1600m (~2.56 km²)
@export var active_radius: int = 1 # 1 = 3x3 active grid (9 chunks)

## Terrain Generation
@export_group("Terrain")
@export var terrain_amplitude: float = 5.0 # ~4 to 6m relief (-5m to +5m)
@export var noise_frequency: float = 0.011
@export var noise_octaves: int = 3

## Tree Spacing & Organic Placement (Poisson Disc Sampling)
@export_group("Trees")
@export var min_tree_distance: float = 3.0 # Poisson minimum distance (reduces density by ~30%, opens clearings)
@export var tree_margin: float = 3.0
@export var max_canopy_planes_per_tree: int = 7 # 6 to 8 large planes for minimal overdraw

## Ground Foliage
@export_group("Foliage")
@export var foliage_count: int = 1200
@export var foliage_visibility_range_end: float = 35.0 # Culling distance for GPU
@export var foliage_fade_margin: float = 6.0

## Lighting & Atmosphere (Sunny Afternoon Forest)
@export_group("Atmosphere & Lighting")
@export var max_shadow_distance: float = 50.0 # Focused shadow cascades around player
@export var sun_light_energy: float = 2.2 # Strong sun energy for vivid sunlit ground patches
@export var sun_light_color: Color = Color(1.0, 0.85, 0.55) # Warm golden sunset
@export var ambient_light_color: Color = Color(0.42, 0.46, 0.34) # Light olive-green ambient penumbra
@export var ambient_light_energy: float = 0.85 # High ambient energy (no pitch black)
@export var fog_color: Color = Color(0.72, 0.64, 0.50) # Luminous golden/beige haze
@export var fog_depth_begin: float = 20.0 # Pushed forward for crystal clear foreground (20m)
@export var fog_depth_end: float = 55.0 # Soft progressive cutoff (55m)
@export var fog_density: float = 0.02 # Reduced density
