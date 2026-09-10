extends Node

## Global Game Manager & Settings Singleton
## Handles world generation seed, graphical settings (FPS, VSync), and session state.

signal settings_changed

const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1366, 768),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160)
]

var world_seed: int = 0
var seed_string: String = ""

var terrain_amplitude: float = 5.0
var min_tree_distance: float = 3.0

var fps_limit: int = 60
var vsync_enabled: bool = true
var fullscreen_enabled: bool = false
var current_resolution_index: int = 3
var show_fps_counter: bool = false
var current_locale: String = "pt_BR"


func _init() -> void:
	randomize_seed()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if seed_string.is_empty():
		randomize_seed()
	var current_size = DisplayServer.window_get_size()
	var matched = false
	for i in range(RESOLUTIONS.size()):
		if RESOLUTIONS[i] == current_size:
			current_resolution_index = i
			matched = true
			break
	if not matched:
		var screen = DisplayServer.window_get_current_screen()
		var screen_size = DisplayServer.screen_get_size(screen)
		if screen_size.y >= 1080 or screen_size.y == 0:
			current_resolution_index = 3
		else:
			current_resolution_index = 0
	TranslationServer.set_locale(current_locale)
	apply_display_settings()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_F11 or (event.keycode == KEY_ENTER and event.alt_pressed):
			set_fullscreen(not fullscreen_enabled)
			get_viewport().set_input_as_handled()


## Applies current graphical settings to the engine
func apply_display_settings() -> void:
	Engine.max_fps = fps_limit
	var vsync_mode = DisplayServer.VSYNC_ENABLED if vsync_enabled else DisplayServer.VSYNC_DISABLED
	DisplayServer.window_set_vsync_mode(vsync_mode)
	if fullscreen_enabled:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	apply_resolution()


## Sets Fullscreen mode
func set_fullscreen(enabled: bool) -> void:
	fullscreen_enabled = enabled
	if enabled:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	apply_resolution()
	settings_changed.emit()


## Applies the current resolution to the viewport content scale and window
func apply_resolution() -> void:
	if current_resolution_index >= 0 and current_resolution_index < RESOLUTIONS.size():
		var res = RESOLUTIONS[current_resolution_index]
		var root_win = get_tree().root
		if root_win:
			root_win.content_scale_size = res
		if not fullscreen_enabled:
			DisplayServer.window_set_size(res)
			center_window(res)


## Centers the window on the current screen
func center_window(target_size: Vector2i) -> void:
	var screen = DisplayServer.window_get_current_screen()
	var screen_rect = DisplayServer.screen_get_usable_rect(screen)
	var pos = screen_rect.position + (screen_rect.size - target_size) / 2
	DisplayServer.window_set_position(pos)


## Sets resolution by index from RESOLUTIONS array
func set_resolution_index(index: int) -> void:
	if index >= 0 and index < RESOLUTIONS.size():
		current_resolution_index = index
		apply_resolution()
		settings_changed.emit()


## Returns a display string for the resolution at given index
static func get_resolution_label(index: int) -> String:
	if index >= 0 and index < RESOLUTIONS.size():
		var res = RESOLUTIONS[index]
		match res:
			Vector2i(1280, 720):
				return "1280 x 720 (720p)"
			Vector2i(1366, 768):
				return "1366 x 768"
			Vector2i(1600, 900):
				return "1600 x 900 (900p)"
			Vector2i(1920, 1080):
				return "1920 x 1080 (1080p)"
			Vector2i(2560, 1440):
				return "2560 x 1440 (2K)"
			Vector2i(3840, 2160):
				return "3840 x 2160 (4K)"
			_:
				return "%d x %d" % [res.x, res.y]
	return ""


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


## Sets current locale (e.g. "pt_BR", "en", "es")
func set_locale(code: String) -> void:
	current_locale = code
	TranslationServer.set_locale(code)
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
