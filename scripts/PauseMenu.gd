extends CanvasLayer

## In-Game Pause Menu & Settings Controller
## Manages game pause state, cursor capture, FPS limits, and scene navigation.

@onready var backdrop: ColorRect = $Backdrop
@onready var main_pause_container: VBoxContainer = $CenterContainer/MainPauseVBox
@onready var settings_panel: PanelContainer = $CenterContainer/SettingsPanel

# Settings Controls
@onready var fps_option: OptionButton = $CenterContainer/SettingsPanel/VBox/FPSHBox/FPSOption
@onready var vsync_check: CheckBox = $CenterContainer/SettingsPanel/VBox/VSyncCheck
@onready var fps_counter_check: CheckBox = $CenterContainer/SettingsPanel/VBox/FPSCounterCheck

var _is_paused: bool = false
var _gm_cache: Node = null


func _get_gm() -> Node:
	if _gm_cache == null:
		_gm_cache = get_node_or_null("/root/GameManager")
	return _gm_cache


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_populate_settings()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
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


func _populate_settings() -> void:
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
		vsync_check.button_pressed = gm.vsync_enabled
		fps_counter_check.button_pressed = gm.show_fps_counter


# --- Pause Button Actions ---

func _on_resume_pressed() -> void:
	set_paused(false)


func _on_settings_pressed() -> void:
	main_pause_container.visible = false
	settings_panel.visible = true


func _on_main_menu_pressed() -> void:
	# Always unpause before changing scenes so next scene runs normally
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")


func _on_quit_pressed() -> void:
	get_tree().quit()


# --- Settings Actions ---

func _on_fps_selected(index: int) -> void:
	var selected_id = fps_option.get_item_id(index)
	var gm = _get_gm()
	if gm:
		gm.set_fps_limit(selected_id)


func _on_vsync_toggled(toggled_on: bool) -> void:
	var gm = _get_gm()
	if gm:
		gm.set_vsync(toggled_on)


func _on_fps_counter_toggled(toggled_on: bool) -> void:
	var gm = _get_gm()
	if gm:
		gm.set_show_fps_counter(toggled_on)


func _on_settings_back_pressed() -> void:
	_show_main_pause_view()
