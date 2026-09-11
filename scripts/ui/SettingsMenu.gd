class_name SettingsMenu
extends PanelContainer

## Unified Settings Menu Component for Causos
## Manages 3 tabs: Geral (Language), Gráficos (Display/FPS), Controles (KBM Rebind & Xbox Layout)

signal back_pressed

const LANGUAGES: Array[Dictionary] = [
	{"code": "pt_BR", "label": "Português (Brasil)"},
	{"code": "en", "label": "English"},
	{"code": "es", "label": "Español"}
]

const REBINDABLE_ACTIONS: Array[Dictionary] = [
	{"action": "move_forward", "label_key": "ACTION_MOVE_FORWARD"},
	{"action": "move_back", "label_key": "ACTION_MOVE_BACK"},
	{"action": "move_left", "label_key": "ACTION_MOVE_LEFT"},
	{"action": "move_right", "label_key": "ACTION_MOVE_RIGHT"},
	{"action": "sprint", "label_key": "ACTION_SPRINT"},
]

const XBOX_GAMEPAD_BINDINGS: Array[Dictionary] = [
	{"button": "LS", "desc_key": "XB_MOVE"},
	{"button": "RS", "desc_key": "XB_LOOK"},
	{"button": "L3 / RB", "desc_key": "XB_SPRINT"},
	{"button": "A", "desc_key": "XB_CONFIRM"},
	{"button": "B", "desc_key": "XB_BACK"},
	{"button": "Menu", "desc_key": "XB_PAUSE"},
	{"button": "D-Pad", "desc_key": "XB_NAVIGATE"},
]

# Tab navigation
@onready var tab_general_btn: Button = $VBox/TabBar/GeneralTabBtn
@onready var tab_graphics_btn: Button = $VBox/TabBar/GraphicsTabBtn
@onready var tab_controls_btn: Button = $VBox/TabBar/ControlsTabBtn

# Tab containers
@onready var general_panel: VBoxContainer = $VBox/TabContent/GeneralPanel
@onready var graphics_panel: VBoxContainer = $VBox/TabContent/GraphicsPanel
@onready var controls_panel: VBoxContainer = $VBox/TabContent/ControlsPanel

# General Tab
@onready var language_label: Label = $VBox/TabContent/GeneralPanel/LanguageLabel
@onready var language_option: OptionButton = $VBox/TabContent/GeneralPanel/LanguageHBox/LanguageOption

# Graphics Tab
@onready var resolution_label: Label = $VBox/TabContent/GraphicsPanel/ResolutionLabel
@onready var resolution_option: OptionButton = $VBox/TabContent/GraphicsPanel/ResolutionHBox/ResolutionOption
@onready var fps_label: Label = $VBox/TabContent/GraphicsPanel/FPSLabel
@onready var fps_option: OptionButton = $VBox/TabContent/GraphicsPanel/FPSHBox/FPSOption
@onready var fullscreen_check: CheckBox = $VBox/TabContent/GraphicsPanel/FullscreenCheck
@onready var vsync_check: CheckBox = $VBox/TabContent/GraphicsPanel/VSyncCheck
@onready var fps_counter_check: CheckBox = $VBox/TabContent/GraphicsPanel/FPSCounterCheck

# Controls Tab - Sub-navigation
@onready var subtab_kbm_btn: Button = $VBox/TabContent/ControlsPanel/SubTabBar/KbmSubTabBtn
@onready var subtab_pad_btn: Button = $VBox/TabContent/ControlsPanel/SubTabBar/GamepadSubTabBtn
@onready var kbm_panel: VBoxContainer = $VBox/TabContent/ControlsPanel/KbmPanel
@onready var pad_panel: VBoxContainer = $VBox/TabContent/ControlsPanel/GamepadPanel

# Controls Tab - KBM elements
@onready var mouse_sens_label: Label = $VBox/TabContent/ControlsPanel/KbmPanel/MouseSensHBox/Label
@onready var mouse_sens_slider: HSlider = $VBox/TabContent/ControlsPanel/KbmPanel/MouseSensHBox/Slider
@onready var mouse_sens_value: Label = $VBox/TabContent/ControlsPanel/KbmPanel/MouseSensHBox/Value
@onready var toggle_sprint_kbm_check: CheckBox = $VBox/TabContent/ControlsPanel/KbmPanel/ToggleSprintKbmCheck
@onready var keybinds_list: VBoxContainer = $VBox/TabContent/ControlsPanel/KbmPanel/KeybindsList
@onready var reset_defaults_btn: Button = $VBox/TabContent/ControlsPanel/KbmPanel/ResetDefaultsBtn

# Controls Tab - Gamepad elements
@onready var pad_sens_label: Label = $VBox/TabContent/ControlsPanel/GamepadPanel/PadSensHBox/Label
@onready var pad_sens_slider: HSlider = $VBox/TabContent/ControlsPanel/GamepadPanel/PadSensHBox/Slider
@onready var pad_sens_value: Label = $VBox/TabContent/ControlsPanel/GamepadPanel/PadSensHBox/Value
@onready var toggle_sprint_pad_check: CheckBox = $VBox/TabContent/ControlsPanel/GamepadPanel/ToggleSprintPadCheck
@onready var pad_legend_grid: GridContainer = $VBox/TabContent/ControlsPanel/GamepadPanel/LegendGrid

# Bottom
@onready var settings_title: Label = $VBox/SettingsTitle
@onready var back_btn: Button = $VBox/SettingsBackBtn

var _active_tab: int = 0
var _active_controls_subtab: int = 0
var _listening_action: String = ""
var _listening_btn: Button = null
var _rebind_buttons: Dictionary = {}
var _gm_cache: Node = null


func _get_gm() -> Node:
	if _gm_cache == null and is_inside_tree():
		_gm_cache = get_node_or_null("/root/GameManager")
	return _gm_cache


func _ready() -> void:
	_connect_signals()
	_populate_keybinds_ui()
	_populate_gamepad_legend_ui()
	_populate_settings_ui()
	_update_localized_texts()
	_set_active_tab(0)
	_set_active_controls_subtab(0)

	var gm = _get_gm()
	if gm and gm.has_signal("settings_changed"):
		gm.settings_changed.connect(_on_settings_changed)

	_style_option_popups()
	_setup_focus_hover()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		if is_node_ready():
			_update_localized_texts()


func grab_initial_focus() -> void:
	if is_inside_tree():
		tab_general_btn.call_deferred("grab_focus")


func _connect_signals() -> void:
	tab_general_btn.pressed.connect(func(): _set_active_tab(0))
	tab_graphics_btn.pressed.connect(func(): _set_active_tab(1))
	tab_controls_btn.pressed.connect(func(): _set_active_tab(2))

	subtab_kbm_btn.pressed.connect(func(): _set_active_controls_subtab(0))
	subtab_pad_btn.pressed.connect(func(): _set_active_controls_subtab(1))

	language_option.item_selected.connect(_on_language_selected)
	resolution_option.item_selected.connect(_on_resolution_selected)
	fps_option.item_selected.connect(_on_fps_selected)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	vsync_check.toggled.connect(_on_vsync_toggled)
	fps_counter_check.toggled.connect(_on_fps_counter_toggled)

	mouse_sens_slider.value_changed.connect(_on_mouse_sens_changed)
	pad_sens_slider.value_changed.connect(_on_pad_sens_changed)

	toggle_sprint_kbm_check.toggled.connect(_on_toggle_sprint_toggled)
	toggle_sprint_pad_check.toggled.connect(_on_toggle_sprint_toggled)

	reset_defaults_btn.pressed.connect(_on_reset_defaults_pressed)
	back_btn.pressed.connect(_on_back_pressed)


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return

	if not _listening_action.is_empty():
		return

	# Gamepad bumper navigation for top tabs
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_LEFT_SHOULDER:
			_switch_tab_relative(-1)
			get_viewport().set_input_as_handled()
			return
		elif event.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			_switch_tab_relative(1)
			get_viewport().set_input_as_handled()
			return

	if event.is_action_pressed("ui_page_up"):
		_switch_tab_relative(-1)
		get_viewport().set_input_as_handled()
		return
	elif event.is_action_pressed("ui_page_down"):
		_switch_tab_relative(1)
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
		get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if _listening_action.is_empty():
		return

	if event is InputEventKey and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		if event.keycode == KEY_ESCAPE:
			_cancel_key_listening()
			return

		var code = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		var action = _listening_action
		var gm = _get_gm()
		if gm:
			gm.rebind_key(action, code)

		_cancel_key_listening()
		_refresh_keybind_buttons()


func _switch_tab_relative(delta_tab: int) -> void:
	var next_tab = wrapi(_active_tab + delta_tab, 0, 3)
	_set_active_tab(next_tab)
	match next_tab:
		0: tab_general_btn.grab_focus()
		1: tab_graphics_btn.grab_focus()
		2: tab_controls_btn.grab_focus()


func _set_active_tab(tab_idx: int) -> void:
	_active_tab = tab_idx
	general_panel.visible = (tab_idx == 0)
	graphics_panel.visible = (tab_idx == 1)
	controls_panel.visible = (tab_idx == 2)

	_update_tab_button_styles()


func _set_active_controls_subtab(subtab_idx: int) -> void:
	_active_controls_subtab = subtab_idx
	kbm_panel.visible = (subtab_idx == 0)
	pad_panel.visible = (subtab_idx == 1)

	_update_subtab_button_styles()


func _update_tab_button_styles() -> void:
	var tabs = [tab_general_btn, tab_graphics_btn, tab_controls_btn]
	for i in range(tabs.size()):
		var btn = tabs[i]
		if i == _active_tab:
			btn.modulate = Color(1.0, 0.95, 0.7)
		else:
			btn.modulate = Color(0.7, 0.7, 0.7)


func _update_subtab_button_styles() -> void:
	var subtabs = [subtab_kbm_btn, subtab_pad_btn]
	for i in range(subtabs.size()):
		var btn = subtabs[i]
		if i == _active_controls_subtab:
			btn.modulate = Color(1.0, 0.95, 0.7)
		else:
			btn.modulate = Color(0.7, 0.7, 0.7)


func _populate_keybinds_ui() -> void:
	for child in keybinds_list.get_children():
		child.queue_free()
	_rebind_buttons.clear()

	var gm = _get_gm()

	for item in REBINDABLE_ACTIONS:
		var action = item["action"]
		var label_key = item["label_key"]

		var row = HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, 46)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var label = Label.new()
		label.text = tr(label_key)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_font_size_override("font_size", 24)
		label.add_theme_color_override("font_color", Color(0.85, 0.8, 0.7, 1))
		row.add_child(label)

		var btn = Button.new()
		btn.custom_minimum_size = Vector2(180, 44)
		btn.add_theme_font_size_override("font_size", 24)
		var current_key = gm.get_action_key_name(action) if gm else "---"
		btn.text = current_key
		btn.pressed.connect(_on_rebind_btn_pressed.bind(action, btn))
		btn.mouse_entered.connect(_on_mouse_entered_control.bind(btn))
		row.add_child(btn)

		_rebind_buttons[action] = {"button": btn, "label_node": label, "label_key": label_key}
		keybinds_list.add_child(row)


func _refresh_keybind_buttons() -> void:
	var gm = _get_gm()
	for action in _rebind_buttons.keys():
		var data = _rebind_buttons[action]
		var btn: Button = data["button"]
		if is_instance_valid(btn):
			var current_key = gm.get_action_key_name(action) if gm else "---"
			btn.text = current_key


func _on_rebind_btn_pressed(action: String, btn: Button) -> void:
	if not _listening_action.is_empty():
		_cancel_key_listening()

	_listening_action = action
	_listening_btn = btn
	btn.text = tr("BTN_PRESS_KEY")


func _cancel_key_listening() -> void:
	if _listening_btn and is_instance_valid(_listening_btn):
		var gm = _get_gm()
		var key_text = gm.get_action_key_name(_listening_action) if gm else "---"
		_listening_btn.text = key_text
		_listening_btn.grab_focus()

	_listening_action = ""
	_listening_btn = null


func _populate_gamepad_legend_ui() -> void:
	for child in pad_legend_grid.get_children():
		child.queue_free()

	for item in XBOX_GAMEPAD_BINDINGS:
		var btn_badge = Label.new()
		btn_badge.text = "[ %s ]" % item["button"]
		btn_badge.custom_minimum_size = Vector2(120, 36)
		btn_badge.add_theme_font_size_override("font_size", 22)
		btn_badge.add_theme_color_override("font_color", Color(0.95, 0.82, 0.48, 1))

		var desc_lbl = Label.new()
		desc_lbl.text = tr(item["desc_key"])
		desc_lbl.add_theme_font_size_override("font_size", 22)
		desc_lbl.add_theme_color_override("font_color", Color(0.85, 0.8, 0.7, 1))
		desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		pad_legend_grid.add_child(btn_badge)
		pad_legend_grid.add_child(desc_lbl)


func _populate_settings_ui() -> void:
	_refresh_language_options()
	_refresh_resolution_options()
	_refresh_fps_options()

	var gm = _get_gm()
	if gm:
		fullscreen_check.set_pressed_no_signal(gm.fullscreen_enabled)
		vsync_check.set_pressed_no_signal(gm.vsync_enabled)
		fps_counter_check.set_pressed_no_signal(gm.show_fps_counter)

		var mouse_mult = gm.mouse_sensitivity / 0.003
		mouse_sens_slider.set_value_no_signal(mouse_mult)
		mouse_sens_value.text = "%0.1fx" % mouse_mult

		var pad_mult = gm.gamepad_sensitivity / 2.5
		pad_sens_slider.set_value_no_signal(pad_mult)
		pad_sens_value.text = "%0.1fx" % pad_mult

		toggle_sprint_kbm_check.set_pressed_no_signal(gm.toggle_sprint)
		toggle_sprint_pad_check.set_pressed_no_signal(gm.toggle_sprint)


func _update_localized_texts() -> void:
	if not is_node_ready():
		return

	settings_title.text = tr("PANEL_SETTINGS_TITLE")
	tab_general_btn.text = tr("TAB_GENERAL")
	tab_graphics_btn.text = tr("TAB_GRAPHICS")
	tab_controls_btn.text = tr("TAB_CONTROLS")

	subtab_kbm_btn.text = tr("SEC_KEYBOARD_MOUSE")
	subtab_pad_btn.text = tr("SEC_GAMEPAD_XBOX")

	language_label.text = tr("LABEL_LANGUAGE")
	resolution_label.text = tr("LABEL_RESOLUTION")
	fps_label.text = tr("LABEL_FPS")
	fullscreen_check.text = tr("CHECK_FULLSCREEN")
	vsync_check.text = tr("CHECK_VSYNC")
	fps_counter_check.text = tr("CHECK_FPS_COUNTER")

	mouse_sens_label.text = tr("LABEL_MOUSE_SENSITIVITY")
	pad_sens_label.text = tr("LABEL_GAMEPAD_SENSITIVITY")
	toggle_sprint_kbm_check.text = tr("CHECK_TOGGLE_SPRINT")
	toggle_sprint_pad_check.text = tr("CHECK_TOGGLE_SPRINT")
	reset_defaults_btn.text = tr("BTN_RESET_DEFAULTS")
	back_btn.text = tr("BTN_SAVE_BACK")

	# Refresh rebindable row labels
	for action in _rebind_buttons.keys():
		var data = _rebind_buttons[action]
		var label_node: Label = data["label_node"]
		var label_key: String = data["label_key"]
		if is_instance_valid(label_node):
			label_node.text = tr(label_key)

	# Refresh Gamepad legend descriptions
	_populate_gamepad_legend_ui()

	_refresh_language_options()
	_refresh_resolution_options()
	_refresh_fps_options()
	_refresh_keybind_buttons()


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


func _style_option_popups() -> void:
	var option_buttons = [language_option, resolution_option, fps_option]
	for opt in option_buttons:
		if is_instance_valid(opt):
			opt.add_theme_font_size_override("font_size", 28)
			var popup = opt.get_popup()
			if popup:
				popup.add_theme_font_size_override("font_size", 28)
				popup.add_theme_constant_override("v_separation", 12)
				popup.add_theme_constant_override("item_start_padding", 16)
				popup.add_theme_constant_override("item_end_padding", 16)


func _setup_focus_hover() -> void:
	var interactive_controls: Array[Control] = [
		tab_general_btn, tab_graphics_btn, tab_controls_btn,
		subtab_kbm_btn, subtab_pad_btn,
		language_option, resolution_option, fps_option,
		fullscreen_check, vsync_check, fps_counter_check,
		mouse_sens_slider, pad_sens_slider,
		toggle_sprint_kbm_check, toggle_sprint_pad_check,
		reset_defaults_btn, back_btn
	]
	for ctrl in interactive_controls:
		if is_instance_valid(ctrl):
			ctrl.mouse_entered.connect(_on_mouse_entered_control.bind(ctrl))


func _on_mouse_entered_control(ctrl: Control) -> void:
	if is_instance_valid(ctrl) and ctrl.is_visible_in_tree() and _listening_action.is_empty():
		ctrl.grab_focus()


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


func _on_mouse_sens_changed(val: float) -> void:
	mouse_sens_value.text = "%0.1fx" % val
	var gm = _get_gm()
	if gm:
		gm.set_mouse_sensitivity(val * 0.003)


func _on_pad_sens_changed(val: float) -> void:
	pad_sens_value.text = "%0.1fx" % val
	var gm = _get_gm()
	if gm:
		gm.set_gamepad_sensitivity(val * 2.5)


func _on_toggle_sprint_toggled(toggled_on: bool) -> void:
	var gm = _get_gm()
	if gm:
		gm.set_toggle_sprint(toggled_on)
	toggle_sprint_kbm_check.set_pressed_no_signal(toggled_on)
	toggle_sprint_pad_check.set_pressed_no_signal(toggled_on)


func _on_reset_defaults_pressed() -> void:
	var gm = _get_gm()
	if gm:
		gm.reset_default_keybinds()
	_refresh_keybind_buttons()


func _on_settings_changed() -> void:
	var gm = _get_gm()
	if gm:
		fullscreen_check.set_pressed_no_signal(gm.fullscreen_enabled)
		vsync_check.set_pressed_no_signal(gm.vsync_enabled)
		fps_counter_check.set_pressed_no_signal(gm.show_fps_counter)
		toggle_sprint_kbm_check.set_pressed_no_signal(gm.toggle_sprint)
		toggle_sprint_pad_check.set_pressed_no_signal(gm.toggle_sprint)
	_refresh_resolution_options()
	_refresh_keybind_buttons()
	_update_localized_texts()


func _on_back_pressed() -> void:
	if not _listening_action.is_empty():
		_cancel_key_listening()
		return
	back_pressed.emit()
