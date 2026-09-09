extends Control

## Main Menu controller for Causos
## Manages Title screen, Map Creation modal, and Performance/FPS Settings modal.

@onready var main_buttons_container: VBoxContainer = $CenterContainer/MainButtons
@onready var map_panel: PanelContainer = $CenterContainer/MapCreationPanel
@onready var settings_panel: PanelContainer = $CenterContainer/SettingsPanel

# Map Creation Controls
@onready var seed_input: LineEdit = $CenterContainer/MapCreationPanel/VBox/SeedHBox/SeedInput
@onready var random_seed_btn: Button = $CenterContainer/MapCreationPanel/VBox/SeedHBox/RandomSeedBtn
@onready var relief_option: OptionButton = $CenterContainer/MapCreationPanel/VBox/ReliefHBox/ReliefOption
@onready var density_option: OptionButton = $CenterContainer/MapCreationPanel/VBox/DensityHBox/DensityOption

# Settings Controls
@onready var fps_option: OptionButton = $CenterContainer/SettingsPanel/VBox/FPSHBox/FPSOption
@onready var fullscreen_check: CheckBox = $CenterContainer/SettingsPanel/VBox/FullscreenCheck
@onready var vsync_check: CheckBox = $CenterContainer/SettingsPanel/VBox/VSyncCheck
@onready var fps_counter_check: CheckBox = $CenterContainer/SettingsPanel/VBox/FPSCounterCheck

var _gm_cache: Node = null

func _get_gm() -> Node:
	if _gm_cache == null:
		_gm_cache = get_node_or_null("/root/GameManager")
	return _gm_cache


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_show_main_view()
	_populate_settings_ui()
	_populate_map_ui()
	var gm = _get_gm()
	if gm and gm.has_signal("settings_changed"):
		gm.settings_changed.connect(_on_settings_changed)


func _show_main_view() -> void:
	main_buttons_container.visible = true
	map_panel.visible = false
	settings_panel.visible = false


func _populate_map_ui() -> void:
	var gm = _get_gm()
	if gm:
		seed_input.text = gm.seed_string
	else:
		seed_input.text = "1337"

	relief_option.clear()
	relief_option.add_item("Suave (Colinas Baixas - 3.5m)", 0)
	relief_option.add_item("Normal (Equilibrado - 5.0m)", 1)
	relief_option.add_item("Montanhoso (Vales Profundos - 7.5m)", 2)
	relief_option.select(1) # Default: 5.0m

	density_option.clear()
	density_option.add_item("Aberta (Mais Clareiras - 3.8m)", 0)
	density_option.add_item("Normal (Equilibrada - 3.0m)", 1)
	density_option.add_item("Densa (Fechada e Sombria - 2.5m)", 2)
	density_option.select(1) # Default: 3.0m


func _populate_settings_ui() -> void:
	fps_option.clear()
	fps_option.add_item("30 FPS (Econômico)", 30)
	fps_option.add_item("60 FPS (Recomendado)", 60)
	fps_option.add_item("120 FPS (Alto Desempenho)", 120)
	fps_option.add_item("144 FPS", 144)
	fps_option.add_item("Ilimitado (Sem Trava)", 0)

	var gm = _get_gm()
	var current_fps = gm.fps_limit if gm else 60
	match current_fps:
		30: fps_option.select(0)
		60: fps_option.select(1)
		120: fps_option.select(2)
		144: fps_option.select(3)
		0: fps_option.select(4)
		_:
			fps_option.add_item("%d FPS" % current_fps, current_fps)
			fps_option.select(fps_option.item_count - 1)

	if gm:
		fullscreen_check.button_pressed = gm.fullscreen_enabled
		vsync_check.button_pressed = gm.vsync_enabled
		fps_counter_check.button_pressed = gm.show_fps_counter


# --- Main Button Handlers ---

func _on_play_button_pressed() -> void:
	main_buttons_container.visible = false
	settings_panel.visible = false
	map_panel.visible = true


func _on_settings_button_pressed() -> void:
	main_buttons_container.visible = false
	map_panel.visible = false
	settings_panel.visible = true


func _on_quit_button_pressed() -> void:
	get_tree().quit()


# --- Map Creation Handlers ---

func _on_random_seed_pressed() -> void:
	var gm = _get_gm()
	if gm:
		var new_seed = gm.randomize_seed()
		seed_input.text = new_seed


func _on_start_forest_pressed() -> void:
	var gm = _get_gm()
	if gm:
		gm.set_seed_from_string(seed_input.text)

		# Set relief amplitude
		match relief_option.selected:
			0: gm.terrain_amplitude = 3.5
			1: gm.terrain_amplitude = 5.0
			2: gm.terrain_amplitude = 7.5

		# Set tree density
		match density_option.selected:
			0: gm.min_tree_distance = 3.8
			1: gm.min_tree_distance = 3.0
			2: gm.min_tree_distance = 2.5

	get_tree().change_scene_to_file("res://scenes/Main.tscn")


func _on_map_back_pressed() -> void:
	_show_main_view()


# --- Settings Handlers ---

func _on_fps_selected(index: int) -> void:
	var selected_id = fps_option.get_item_id(index)
	var gm = _get_gm()
	if gm:
		gm.set_fps_limit(selected_id)


func _on_fullscreen_toggled(toggled_on: bool) -> void:
	var gm = _get_gm()
	if gm:
		gm.set_fullscreen(toggled_on)


func _on_vsync_toggled(toggled_on: bool) -> void:
	var gm = _get_gm()
	if gm:
		gm.set_vsync(toggled_on)


func _on_fps_counter_toggled(toggled_on: bool) -> void:
	var gm = _get_gm()
	if gm:
		gm.set_show_fps_counter(toggled_on)


func _on_settings_changed() -> void:
	var gm = _get_gm()
	if gm and is_instance_valid(fullscreen_check):
		fullscreen_check.set_pressed_no_signal(gm.fullscreen_enabled)
		vsync_check.set_pressed_no_signal(gm.vsync_enabled)
		fps_counter_check.set_pressed_no_signal(gm.show_fps_counter)


func _on_settings_back_pressed() -> void:
	_show_main_view()
