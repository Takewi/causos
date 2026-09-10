extends CanvasLayer

## In-Game Pause Menu & Settings Controller
## Manages game pause state, cursor capture, FPS limits, scene navigation, and Language Selection.

const LANGUAGES: Array[Dictionary] = [
	{"code": "pt_BR", "label": "Português (Brasil)"},
	{"code": "en", "label": "English"},
	{"code": "es", "label": "Español"}
]

@onready var backdrop: ColorRect = $Backdrop
@onready var main_pause_container: VBoxContainer = $CenterContainer/MainPauseVBox
@onready var settings_panel: PanelContainer = $CenterContainer/SettingsPanel

# Main Pause Controls
@onready var pause_title: Label = $CenterContainer/MainPauseVBox/PauseTitle
@onready var resume_btn: Button = $CenterContainer/MainPauseVBox/ResumeBtn
@onready var settings_btn: Button = $CenterContainer/MainPauseVBox/SettingsBtn
@onready var main_menu_btn: Button = $CenterContainer/MainPauseVBox/MainMenuBtn
@onready var quit_btn: Button = $CenterContainer/MainPauseVBox/QuitBtn

# Settings Controls
@onready var settings_title: Label = $CenterContainer/SettingsPanel/VBox/SettingsTitle
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

var _is_paused: bool = false
var _gm_cache: Node = null


func _get_gm() -> Node:
	if _gm_cache == null and is_inside_tree():
		_gm_cache = get_node_or_null("/root/GameManager")
	return _gm_cache


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_populate_settings()
	_update_localized_texts()
	var gm = _get_gm()
	if gm and gm.has_signal("settings_changed"):
		gm.settings_changed.connect(_on_settings_changed)
	_setup_focus_behavior()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		if is_node_ready():
			_update_localized_texts()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		if not _is_paused:
			toggle_pause()
			get_viewport().set_input_as_handled()
		else:
			if settings_panel.visible:
				_show_main_pause_view()
				settings_btn.grab_focus()
				get_viewport().set_input_as_handled()
			else:
				toggle_pause()
				get_viewport().set_input_as_handled()


func toggle_pause() -> void:
	set_paused(not _is_paused)


func set_paused(paused: bool) -> void:
	_is_paused = paused
	get_tree().paused = _is_paused
	visible = _is_paused

	if _is_paused:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		_show_main_pause_view()
		_populate_settings()
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _show_main_pause_view() -> void:
	main_pause_container.visible = true
	settings_panel.visible = false
	if is_inside_tree():
		resume_btn.call_deferred("grab_focus")


func _update_localized_texts() -> void:
	if not is_node_ready():
		return

	# Main Pause Controls
	pause_title.text = tr("PAUSE_TITLE")
	resume_btn.text = tr("BTN_RESUME")
	settings_btn.text = tr("BTN_SETTINGS")
	main_menu_btn.text = tr("BTN_MAIN_MENU")
	quit_btn.text = tr("BTN_QUIT_GAME")

	# Settings Panel
	settings_title.text = tr("PANEL_SETTINGS_TITLE")
	language_label.text = tr("LABEL_LANGUAGE")
	resolution_label.text = tr("LABEL_RESOLUTION")
	fps_label.text = tr("LABEL_FPS")
	fullscreen_check.text = tr("CHECK_FULLSCREEN")
	vsync_check.text = tr("CHECK_VSYNC")
	fps_counter_check.text = tr("CHECK_FPS_COUNTER")
	settings_back_btn.text = tr("BTN_BACK")

	_refresh_fps_options()
	_refresh_language_options()
	_refresh_resolution_options()


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


func _populate_settings() -> void:
	_refresh_fps_options()
	_refresh_language_options()
	_refresh_resolution_options()

	var gm = _get_gm()
	if gm:
		fullscreen_check.button_pressed = gm.fullscreen_enabled
		vsync_check.button_pressed = gm.vsync_enabled
		fps_counter_check.button_pressed = gm.show_fps_counter


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
	resolution_option.disabled = false


func _setup_focus_behavior() -> void:
	var interactive_nodes: Array[Control] = [
		resume_btn, settings_btn, main_menu_btn, quit_btn,
		language_option, resolution_option, fps_option,
		fullscreen_check, vsync_check, fps_counter_check, settings_back_btn
	]
	for node in interactive_nodes:
		if is_instance_valid(node):
			node.mouse_entered.connect(_on_control_mouse_entered.bind(node))


func _on_control_mouse_entered(node: Control) -> void:
	if is_instance_valid(node) and node.is_visible_in_tree():
		node.grab_focus()


# --- Pause Button Actions ---

func _on_resume_pressed() -> void:
	set_paused(false)


func _on_settings_pressed() -> void:
	main_pause_container.visible = false
	settings_panel.visible = true
	if is_inside_tree():
		language_option.call_deferred("grab_focus")


func _on_main_menu_pressed() -> void:
	# Always unpause before changing scenes so next scene runs normally
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")


func _on_quit_pressed() -> void:
	get_tree().quit()


# --- Settings Actions ---

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
	_show_main_pause_view()
	if is_inside_tree():
		settings_btn.call_deferred("grab_focus")
