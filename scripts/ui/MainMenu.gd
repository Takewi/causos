extends Control

## Main Menu controller for Causos
## Manages Title screen, Map Creation modal, Performance/FPS Settings, and Language Selection.

const LANGUAGES: Array[Dictionary] = [
	{"code": "pt_BR", "label": "Português (Brasil)"},
	{"code": "en", "label": "English"},
	{"code": "es", "label": "Español"}
]

# Header
@onready var title_label: Label = $HeaderContainer/Title
@onready var subtitle_label: Label = $HeaderContainer/Subtitle

# Panels & Containers
@onready var main_buttons_container: VBoxContainer = $CenterContainer/MainButtons
@onready var map_panel: PanelContainer = $CenterContainer/MapCreationPanel
@onready var settings_panel: PanelContainer = $CenterContainer/SettingsPanel

# Main Buttons
@onready var play_btn: Button = $CenterContainer/MainButtons/PlayBtn
@onready var settings_btn: Button = $CenterContainer/MainButtons/SettingsBtn
@onready var quit_btn: Button = $CenterContainer/MainButtons/QuitBtn

# Map Creation Controls
@onready var map_panel_title: Label = $CenterContainer/MapCreationPanel/VBox/PanelTitle
@onready var seed_label: Label = $CenterContainer/MapCreationPanel/VBox/SeedLabel
@onready var seed_input: LineEdit = $CenterContainer/MapCreationPanel/VBox/SeedHBox/SeedInput
@onready var random_seed_btn: Button = $CenterContainer/MapCreationPanel/VBox/SeedHBox/RandomSeedBtn
@onready var relief_label: Label = $CenterContainer/MapCreationPanel/VBox/ReliefLabel
@onready var relief_option: OptionButton = $CenterContainer/MapCreationPanel/VBox/ReliefHBox/ReliefOption
@onready var density_label: Label = $CenterContainer/MapCreationPanel/VBox/DensityLabel
@onready var density_option: OptionButton = $CenterContainer/MapCreationPanel/VBox/DensityHBox/DensityOption
@onready var map_back_btn: Button = $CenterContainer/MapCreationPanel/VBox/ActionHBox/MapBackBtn
@onready var start_forest_btn: Button = $CenterContainer/MapCreationPanel/VBox/ActionHBox/StartForestBtn

# Settings Controls
@onready var settings_panel_title: Label = $CenterContainer/SettingsPanel/VBox/SettingsTitle
@onready var language_label: Label = $CenterContainer/SettingsPanel/VBox/LanguageLabel
@onready var language_option: OptionButton = $CenterContainer/SettingsPanel/VBox/LanguageHBox/LanguageOption
@onready var resolution_label: Label = $CenterContainer/SettingsPanel/VBox/ResolutionLabel
@onready var resolution_option: OptionButton = $CenterContainer/SettingsPanel/VBox/ResolutionHBox/ResolutionOption
@onready var fps_label: Label = $CenterContainer/SettingsPanel/VBox/FPSLabel
@onready var fps_option: OptionButton = $CenterContainer/SettingsPanel/VBox/FPSHBox/FPSOption
@onready var fullscreen_check: CheckBox = $CenterContainer/SettingsPanel/VBox/FullscreenCheck
@onready var vsync_check: CheckBox = $CenterContainer/SettingsPanel/VBox/VSyncCheck
@onready var fps_counter_check: CheckBox = $CenterContainer/SettingsPanel/VBox/FPSCounterCheck
@onready var settings_back_btn: Button = $CenterContainer/SettingsPanel/VBox/SettingsBackBtn

var _gm_cache: Node = null

func _get_gm() -> Node:
	if _gm_cache == null and is_inside_tree():
		_gm_cache = get_node_or_null("/root/GameManager")
	return _gm_cache


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_show_main_view()
	_populate_map_ui()
	_populate_settings_ui()
	_update_localized_texts()
	var gm = _get_gm()
	if gm and gm.has_signal("settings_changed"):
		gm.settings_changed.connect(_on_settings_changed)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		if is_node_ready():
			_update_localized_texts()


func _show_main_view() -> void:
	main_buttons_container.visible = true
	map_panel.visible = false
	settings_panel.visible = false
	if is_inside_tree():
		play_btn.call_deferred("grab_focus")


func _update_localized_texts() -> void:
	if not is_node_ready():
		return

	# Header
	title_label.text = tr("MENU_TITLE")
	subtitle_label.text = tr("MENU_SUBTITLE")

	# Main Buttons
	play_btn.text = tr("BTN_PLAY")
	settings_btn.text = tr("BTN_SETTINGS")
	quit_btn.text = tr("BTN_QUIT")

	# Map Creation Panel
	map_panel_title.text = tr("PANEL_MAP_TITLE")
	seed_label.text = tr("LABEL_SEED")
	seed_input.placeholder_text = tr("INPUT_SEED_PLACEHOLDER")
	random_seed_btn.text = tr("BTN_RANDOM_SEED")
	relief_label.text = tr("LABEL_RELIEF")
	density_label.text = tr("LABEL_DENSITY")
	map_back_btn.text = tr("BTN_BACK")
	start_forest_btn.text = tr("BTN_START_FOREST")

	# Settings Panel
	settings_panel_title.text = tr("PANEL_SETTINGS_TITLE")
	language_label.text = tr("LABEL_LANGUAGE")
	resolution_label.text = tr("LABEL_RESOLUTION")
	fps_label.text = tr("LABEL_FPS")
	fullscreen_check.text = tr("CHECK_FULLSCREEN")
	vsync_check.text = tr("CHECK_VSYNC")
	fps_counter_check.text = tr("CHECK_FPS_COUNTER")
	settings_back_btn.text = tr("BTN_SAVE_BACK")

	# Refresh Options with localized strings
	_refresh_relief_options()
	_refresh_density_options()
	_refresh_fps_options()
	_refresh_language_options()
	_refresh_resolution_options()


func _refresh_relief_options() -> void:
	var sel = relief_option.selected if relief_option.item_count > 0 else 1
	relief_option.clear()
	relief_option.add_item(tr("OPT_RELIEF_GENTLE"), 0)
	relief_option.add_item(tr("OPT_RELIEF_NORMAL"), 1)
	relief_option.add_item(tr("OPT_RELIEF_MOUNTAIN"), 2)
	relief_option.select(clamp(sel, 0, 2))


func _refresh_density_options() -> void:
	var sel = density_option.selected if density_option.item_count > 0 else 1
	density_option.clear()
	density_option.add_item(tr("OPT_DENSITY_OPEN"), 0)
	density_option.add_item(tr("OPT_DENSITY_NORMAL"), 1)
	density_option.add_item(tr("OPT_DENSITY_DENSE"), 2)
	density_option.select(clamp(sel, 0, 2))


func _refresh_fps_options() -> void:
	var gm = _get_gm()
	var current_fps = gm.fps_limit if gm else 60

	fps_option.clear()
	fps_option.add_item(tr("OPT_FPS_30"), 30)
	fps_option.add_item(tr("OPT_FPS_60"), 60)
	fps_option.add_item(tr("OPT_FPS_120"), 120)
	fps_option.add_item(tr("OPT_FPS_144"), 144)
	fps_option.add_item(tr("OPT_FPS_UNCAPPED"), 0)

	match current_fps:
		30: fps_option.select(0)
		60: fps_option.select(1)
		120: fps_option.select(2)
		144: fps_option.select(3)
		0: fps_option.select(4)
		_:
			fps_option.add_item("%d FPS" % current_fps, current_fps)
			fps_option.select(fps_option.item_count - 1)


func _refresh_language_options() -> void:
	var gm = _get_gm()
	var cur_code = gm.current_locale if gm else TranslationServer.get_locale()

	language_option.clear()
	var selected_idx = 0
	for i in range(LANGUAGES.size()):
		var lang = LANGUAGES[i]
		language_option.add_item(lang["label"], i)
		if cur_code == lang["code"] or (cur_code.begins_with("pt") and lang["code"] == "pt_BR") or (cur_code.begins_with("es") and lang["code"] == "es") or (cur_code.begins_with("en") and lang["code"] == "en"):
			selected_idx = i
	language_option.select(selected_idx)


func _refresh_resolution_options() -> void:
	var gm = _get_gm()
	var cur_idx = gm.current_resolution_index if gm else 0
	var is_fs = gm.fullscreen_enabled if gm else false
	var res_list = gm.RESOLUTIONS if (gm and "RESOLUTIONS" in gm) else [
		Vector2i(1280, 720),
		Vector2i(1366, 768),
		Vector2i(1600, 900),
		Vector2i(1920, 1080),
		Vector2i(2560, 1440),
		Vector2i(3840, 2160)
	]

	resolution_option.clear()
	for i in range(res_list.size()):
		var label = gm.get_resolution_label(i) if (gm and gm.has_method("get_resolution_label")) else "%d x %d" % [res_list[i].x, res_list[i].y]
		resolution_option.add_item(label, i)
	resolution_option.select(cur_idx)
	resolution_option.disabled = is_fs


func _populate_map_ui() -> void:
	var gm = _get_gm()
	if gm:
		seed_input.text = gm.seed_string
	else:
		var rng = RandomNumberGenerator.new()
		rng.randomize()
		seed_input.text = str(rng.randi_range(10000, 99999999))
	_refresh_relief_options()
	_refresh_density_options()


func _populate_settings_ui() -> void:
	_refresh_fps_options()
	_refresh_language_options()
	_refresh_resolution_options()

	var gm = _get_gm()
	if gm:
		fullscreen_check.button_pressed = gm.fullscreen_enabled
		vsync_check.button_pressed = gm.vsync_enabled
		fps_counter_check.button_pressed = gm.show_fps_counter


# --- Main Button Handlers ---

func _on_play_button_pressed() -> void:
	main_buttons_container.visible = false
	settings_panel.visible = false
	map_panel.visible = true
	if is_inside_tree():
		start_forest_btn.call_deferred("grab_focus")


func _on_settings_button_pressed() -> void:
	main_buttons_container.visible = false
	map_panel.visible = false
	settings_panel.visible = true
	if is_inside_tree():
		language_option.call_deferred("grab_focus")


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

func _on_language_selected(index: int) -> void:
	if index >= 0 and index < LANGUAGES.size():
		var code = LANGUAGES[index]["code"]
		var gm = _get_gm()
		if gm:
			gm.set_locale(code)
		else:
			TranslationServer.set_locale(code)
		_update_localized_texts()


func _on_resolution_selected(index: int) -> void:
	var gm = _get_gm()
	if gm:
		gm.set_resolution_index(index)


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
	_refresh_resolution_options()
	_update_localized_texts()


func _on_settings_back_pressed() -> void:
	_show_main_view()
	if is_inside_tree():
		settings_btn.call_deferred("grab_focus")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if map_panel.visible:
			_show_main_view()
			if is_inside_tree():
				play_btn.call_deferred("grab_focus")
			get_viewport().set_input_as_handled()
		elif settings_panel.visible:
			_show_main_view()
			if is_inside_tree():
				settings_btn.call_deferred("grab_focus")
			get_viewport().set_input_as_handled()
