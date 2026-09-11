extends CanvasLayer

## In-Game Pause Menu & Settings Controller
## Manages game pause state, cursor capture, scene navigation, and delegates settings to SettingsMenu.

@onready var backdrop: ColorRect = $Backdrop
@onready var main_pause_container: VBoxContainer = $CenterContainer/MainPauseVBox
@onready var settings_menu: Control = $CenterContainer/SettingsMenu

# Main Pause Controls
@onready var pause_title: Label = $CenterContainer/MainPauseVBox/PauseTitle
@onready var resume_btn: Button = $CenterContainer/MainPauseVBox/ResumeBtn
@onready var settings_btn: Button = $CenterContainer/MainPauseVBox/SettingsBtn
@onready var main_menu_btn: Button = $CenterContainer/MainPauseVBox/MainMenuBtn
@onready var quit_btn: Button = $CenterContainer/MainPauseVBox/QuitBtn

var _is_paused: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_update_localized_texts()
	_setup_focus_behavior()

	if settings_menu and not settings_menu.back_pressed.is_connected(_on_settings_back_pressed):
		settings_menu.back_pressed.connect(_on_settings_back_pressed)


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
			if settings_menu.visible:
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
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _show_main_pause_view() -> void:
	main_pause_container.visible = true
	settings_menu.visible = false
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


func _setup_focus_behavior() -> void:
	var interactive_nodes: Array[Control] = [
		resume_btn, settings_btn, main_menu_btn, quit_btn
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
	settings_menu.visible = true
	settings_menu.grab_initial_focus()


func _on_main_menu_pressed() -> void:
	# Always unpause before changing scenes so next scene runs normally
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_settings_back_pressed() -> void:
	_show_main_pause_view()
	if is_inside_tree():
		settings_btn.call_deferred("grab_focus")
