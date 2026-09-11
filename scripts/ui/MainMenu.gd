extends Control

## Main Menu controller for Causos
## Manages Title screen, Map Creation modal, and Settings Menu navigation.

# Header
@onready var title_label: Label = $HeaderContainer/Title
@onready var subtitle_label: Label = $HeaderContainer/Subtitle

# Panels & Containers
@onready var main_buttons_container: VBoxContainer = $CenterContainer/MainButtons
@onready var map_panel: PanelContainer = $CenterContainer/MapCreationPanel
@onready var settings_menu: Control = $CenterContainer/SettingsMenu

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

var _gm_cache: Node = null


func _get_gm() -> Node:
	if _gm_cache == null and is_inside_tree():
		_gm_cache = get_node_or_null("/root/GameManager")
	return _gm_cache


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_show_main_view()
	_populate_map_ui()
	_update_localized_texts()
	_setup_focus_behavior()
	_style_option_popups()

	if settings_menu and not settings_menu.back_pressed.is_connected(_on_settings_back_pressed):
		settings_menu.back_pressed.connect(_on_settings_back_pressed)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		if is_node_ready():
			_update_localized_texts()


func _show_main_view() -> void:
	main_buttons_container.visible = true
	map_panel.visible = false
	settings_menu.visible = false
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

	_refresh_relief_options()
	_refresh_density_options()


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


func _setup_focus_behavior() -> void:
	var interactive_nodes: Array[Control] = [
		play_btn, settings_btn, quit_btn,
		seed_input, random_seed_btn, relief_option, density_option,
		map_back_btn, start_forest_btn
	]
	for node in interactive_nodes:
		if is_instance_valid(node):
			node.mouse_entered.connect(_on_control_mouse_entered.bind(node))


func _on_control_mouse_entered(node: Control) -> void:
	if is_instance_valid(node) and node.is_visible_in_tree():
		node.grab_focus()


func _style_option_popups() -> void:
	var option_buttons = [relief_option, density_option]
	for opt in option_buttons:
		if is_instance_valid(opt):
			opt.add_theme_font_size_override("font_size", 28)
			var popup = opt.get_popup()
			if popup:
				popup.add_theme_font_size_override("font_size", 28)
				popup.add_theme_constant_override("v_separation", 12)
				popup.add_theme_constant_override("item_start_padding", 16)
				popup.add_theme_constant_override("item_end_padding", 16)


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


# --- Main Button Handlers ---

func _on_play_button_pressed() -> void:
	main_buttons_container.visible = false
	settings_menu.visible = false
	map_panel.visible = true
	if is_inside_tree():
		start_forest_btn.call_deferred("grab_focus")


func _on_settings_button_pressed() -> void:
	main_buttons_container.visible = false
	map_panel.visible = false
	settings_menu.visible = true
	settings_menu.grab_initial_focus()


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
		elif settings_menu.visible:
			_show_main_view()
			if is_inside_tree():
				settings_btn.call_deferred("grab_focus")
			get_viewport().set_input_as_handled()
