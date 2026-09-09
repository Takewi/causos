extends Node

## Global Game Manager & Settings Singleton
## Handles world generation seed, graphical settings (FPS, VSync), and session state.

signal settings_changed

var world_seed: int = 1337
var seed_string: String = "1337"

var terrain_amplitude: float = 5.0
var min_tree_distance: float = 3.0

var fps_limit: int = 60
var vsync_enabled: bool = true
var show_fps_counter: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	apply_display_settings()


## Applies current graphical settings to the engine
func apply_display_settings() -> void:
	Engine.max_fps = fps_limit
	var mode = DisplayServer.VSYNC_ENABLED if vsync_enabled else DisplayServer.VSYNC_DISABLED
	DisplayServer.window_set_vsync_mode(mode)


## Sets FPS limit: 30, 60, 120, 144, 0 (uncapped)
func set_fps_limit(limit: int) -> void:
	fps_limit = max(0, limit)
	Engine.max_fps = fps_limit
	settings_changed.emit()


## Toggles VSync
func set_vsync(enabled: bool) -> void:
	vsync_enabled = enabled
	var mode = DisplayServer.VSYNC_ENABLED if vsync_enabled else DisplayServer.VSYNC_DISABLED
	DisplayServer.window_set_vsync_mode(mode)
	settings_changed.emit()


## Toggles FPS counter on HUD
func set_show_fps_counter(enabled: bool) -> void:
	show_fps_counter = enabled
	settings_changed.emit()


## Parses custom string seed into integer world seed
func set_seed_from_string(text: String) -> void:
	var trimmed = text.strip_edges()
	if trimmed.is_empty():
		randomize_seed()
		return

	seed_string = trimmed
	if trimmed.is_valid_int():
		world_seed = int(trimmed.to_int())
	else:
		var h = trimmed.hash()
		if h >= 0x80000000:
			h -= 0x100000000
		world_seed = h


## Generates a new random seed and returns its string representation
func randomize_seed() -> String:
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	world_seed = rng.randi_range(10000, 99999999)
	seed_string = str(world_seed)
	return seed_string
