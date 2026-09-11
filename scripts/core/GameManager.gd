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

# Controls settings
var mouse_sensitivity: float = 0.003
var gamepad_sensitivity: float = 2.5
var toggle_sprint: bool = false
var custom_keybinds: Dictionary = {}

const CONFIG_PATH: String = "user://settings.cfg"

const DEFAULT_KEYBINDS: Dictionary = {
	"move_forward": KEY_W,
	"move_back": KEY_S,
	"move_left": KEY_A,
	"move_right": KEY_D,
	"sprint": KEY_SHIFT,
}


func _init() -> void:
	randomize_seed()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if seed_string.is_empty():
		randomize_seed()
	var has_saved = load_settings()
	if not has_saved:
		_detect_initial_resolution()
	TranslationServer.set_locale(current_locale)
	apply_display_settings()


func _detect_initial_resolution() -> void:
	var current_size = DisplayServer.window_get_size()
	for i in range(RESOLUTIONS.size()):
		if RESOLUTIONS[i] == current_size:
			current_resolution_index = i
			return
	var screen = DisplayServer.window_get_current_screen()
	var screen_size = DisplayServer.screen_get_size(screen)
	if screen_size.y >= 1080 or screen_size.y == 0:
		current_resolution_index = 3
	else:
		current_resolution_index = 0


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
	save_settings()
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
		save_settings()
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
	save_settings()
	settings_changed.emit()


## Toggles VSync
func set_vsync(enabled: bool) -> void:
	vsync_enabled = enabled
	var mode = DisplayServer.VSYNC_ENABLED if vsync_enabled else DisplayServer.VSYNC_DISABLED
	DisplayServer.window_set_vsync_mode(mode)
	save_settings()
	settings_changed.emit()


## Toggles FPS counter on HUD
func set_show_fps_counter(enabled: bool) -> void:
	show_fps_counter = enabled
	save_settings()
	settings_changed.emit()


## Sets current locale (e.g. "pt_BR", "en", "es")
func set_locale(code: String) -> void:
	current_locale = code
	TranslationServer.set_locale(code)
	save_settings()
	settings_changed.emit()


## Sets mouse sensitivity
func set_mouse_sensitivity(val: float) -> void:
	mouse_sensitivity = clamp(val, 0.0005, 0.015)
	save_settings()
	settings_changed.emit()


## Sets gamepad camera look sensitivity
func set_gamepad_sensitivity(val: float) -> void:
	gamepad_sensitivity = clamp(val, 0.5, 6.0)
	save_settings()
	settings_changed.emit()


## Toggles sprint click mode (hold vs 1-click toggle)
func set_toggle_sprint(enabled: bool) -> void:
	toggle_sprint = enabled
	save_settings()
	settings_changed.emit()


## Remaps an action's keyboard key in InputMap and persists it
func rebind_key(action_name: String, keycode: int) -> void:
	custom_keybinds[action_name] = keycode
	_apply_key_to_input_map(action_name, keycode)
	save_settings()
	settings_changed.emit()


## Resets all keyboard keybinds to default WASD + Shift
func reset_default_keybinds() -> void:
	custom_keybinds.clear()
	for action in DEFAULT_KEYBINDS.keys():
		_apply_key_to_input_map(action, DEFAULT_KEYBINDS[action])
	save_settings()
	settings_changed.emit()


## Returns the display name of the key assigned to an action
func get_action_key_name(action_name: String) -> String:
	if custom_keybinds.has(action_name):
		return OS.get_keycode_string(custom_keybinds[action_name])
	if DEFAULT_KEYBINDS.has(action_name):
		return OS.get_keycode_string(DEFAULT_KEYBINDS[action_name])
	if InputMap.has_action(action_name):
		for event in InputMap.action_get_events(action_name):
			if event is InputEventKey:
				var code = event.physical_keycode if event.physical_keycode != 0 else event.keycode
				if code != 0:
					return OS.get_keycode_string(code)
	return "---"


func _apply_all_keybinds() -> void:
	for action in custom_keybinds.keys():
		_apply_key_to_input_map(action, custom_keybinds[action])


func _apply_key_to_input_map(action_name: String, keycode: int) -> void:
	if not InputMap.has_action(action_name):
		return
	# Remove previous keyboard events for this action
	var events_to_remove: Array[InputEvent] = []
	for event in InputMap.action_get_events(action_name):
		if event is InputEventKey:
			events_to_remove.append(event)
	for event in events_to_remove:
		InputMap.action_erase_event(action_name, event)

	# Add new primary key event
	var new_event = InputEventKey.new()
	new_event.physical_keycode = keycode
	InputMap.action_add_event(action_name, new_event)


## Saves user preferences to user://settings.cfg
func save_settings() -> void:
	var cfg = ConfigFile.new()
	cfg.set_value("general", "locale", current_locale)
	cfg.set_value("graphics", "resolution_index", current_resolution_index)
	cfg.set_value("graphics", "fullscreen", fullscreen_enabled)
	cfg.set_value("graphics", "vsync", vsync_enabled)
	cfg.set_value("graphics", "fps_limit", fps_limit)
	cfg.set_value("graphics", "show_fps_counter", show_fps_counter)
	cfg.set_value("controls", "mouse_sensitivity", mouse_sensitivity)
	cfg.set_value("controls", "gamepad_sensitivity", gamepad_sensitivity)
	cfg.set_value("controls", "toggle_sprint", toggle_sprint)
	cfg.set_value("controls", "custom_keybinds", custom_keybinds)
	cfg.save(CONFIG_PATH)


## Loads user preferences from user://settings.cfg. Returns true if file was loaded, false otherwise.
func load_settings() -> bool:
	var cfg = ConfigFile.new()
	var err = cfg.load(CONFIG_PATH)
	if err != OK:
		return false
	current_locale = cfg.get_value("general", "locale", current_locale)
	var loaded_res = cfg.get_value("graphics", "resolution_index", current_resolution_index)
	current_resolution_index = clamp(loaded_res, 0, RESOLUTIONS.size() - 1)
	fullscreen_enabled = cfg.get_value("graphics", "fullscreen", fullscreen_enabled)
	vsync_enabled = cfg.get_value("graphics", "vsync", vsync_enabled)
	fps_limit = cfg.get_value("graphics", "fps_limit", fps_limit)
	show_fps_counter = cfg.get_value("graphics", "show_fps_counter", show_fps_counter)
	mouse_sensitivity = cfg.get_value("controls", "mouse_sensitivity", mouse_sensitivity)
	gamepad_sensitivity = cfg.get_value("controls", "gamepad_sensitivity", gamepad_sensitivity)
	toggle_sprint = cfg.get_value("controls", "toggle_sprint", toggle_sprint)
	custom_keybinds = cfg.get_value("controls", "custom_keybinds", {})
	_apply_all_keybinds()
	return true


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
