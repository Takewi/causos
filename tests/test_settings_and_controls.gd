extends SceneTree

func _initialize() -> void:
	print("--- STARTING SETTINGS AND CONTROLS VERIFICATION ---")

	var gm = root.get_node_or_null("GameManager")
	assert(gm != null, "GameManager autoload must exist")

	# Test 1: Check sensitivities and toggle sprint properties
	assert(gm.mouse_sensitivity > 0.0, "mouse_sensitivity should be positive")
	assert(gm.gamepad_sensitivity > 0.0, "gamepad_sensitivity should be positive")
	print("[PASS] GameManager defaults verified")

	# Test 2: Sensitivity updates and clamping
	gm.set_mouse_sensitivity(0.006)
	assert(is_equal_approx(gm.mouse_sensitivity, 0.006), "mouse_sensitivity should update to 0.006")
	gm.set_gamepad_sensitivity(4.0)
	assert(is_equal_approx(gm.gamepad_sensitivity, 4.0), "gamepad_sensitivity should update to 4.0")
	gm.set_toggle_sprint(true)
	assert(gm.toggle_sprint == true, "toggle_sprint should update to true")
	gm.set_toggle_sprint(false)
	assert(gm.toggle_sprint == false, "toggle_sprint should update to false")
	print("[PASS] GameManager sensitivity and toggle sprint setters verified")

	# Test 3: Key rebinding
	var orig_forward = gm.get_action_key_name("move_forward")
	gm.rebind_key("move_forward", KEY_UP)
	assert(gm.get_action_key_name("move_forward") == OS.get_keycode_string(KEY_UP), "move_forward key should be UP")
	gm.reset_default_keybinds()
	assert(gm.get_action_key_name("move_forward") == "W", "move_forward key should reset to W")
	print("[PASS] Key rebinding and reset to defaults verified")

	# Test 4: SettingsMenu scene instantiation and controls verification
	var settings_scene = preload("res://scenes/SettingsMenu.tscn")
	var settings_instance = settings_scene.instantiate()
	root.add_child(settings_instance)

	# Verify sub-nodes and font sizes
	assert(settings_instance.get_node("VBox/TabBar/GeneralTabBtn") != null, "GeneralTabBtn exists")
	assert(settings_instance.get_node("VBox/TabBar/GraphicsTabBtn") != null, "GraphicsTabBtn exists")
	assert(settings_instance.get_node("VBox/TabBar/ControlsTabBtn") != null, "ControlsTabBtn exists")
	assert(settings_instance.get_node("VBox/TabContent/ControlsPanel/KbmPanel") != null, "KbmPanel exists")
	assert(settings_instance.get_node("VBox/TabContent/ControlsPanel/GamepadPanel") != null, "GamepadPanel exists")

	# Test font sizes in controls submenus
	var kbm_subtab = settings_instance.get_node("VBox/TabContent/ControlsPanel/SubTabBar/KbmSubTabBtn")
	var pad_subtab = settings_instance.get_node("VBox/TabContent/ControlsPanel/SubTabBar/GamepadSubTabBtn")
	var reset_btn = settings_instance.get_node("VBox/TabContent/ControlsPanel/KbmPanel/ResetDefaultsBtn")
	var toggle_sprint_kbm = settings_instance.get_node("VBox/TabContent/ControlsPanel/KbmPanel/ToggleSprintKbmCheck")
	var toggle_sprint_pad = settings_instance.get_node("VBox/TabContent/ControlsPanel/GamepadPanel/ToggleSprintPadCheck")
	var legend_title = settings_instance.get_node("VBox/TabContent/ControlsPanel/GamepadPanel/LegendTitle")

	assert(kbm_subtab.get_theme_font_size("font_size") == 26, "KbmSubTabBtn font size must be 26")
	assert(pad_subtab.get_theme_font_size("font_size") == 26, "GamepadSubTabBtn font size must be 26")
	assert(reset_btn.get_theme_font_size("font_size") == 26, "ResetDefaultsBtn font size must be 26")
	assert(toggle_sprint_kbm.get_theme_font_size("font_size") == 26, "ToggleSprintKbmCheck font size must be 26")
	assert(toggle_sprint_pad.get_theme_font_size("font_size") == 26, "ToggleSprintPadCheck font size must be 26")
	assert(legend_title.get_theme_font_size("font_size") == 26, "LegendTitle font size must be 26")
	print("[PASS] Controls submenus font sizes verified (all 26px)")

	# Test 5: Verify CheckBox focus style in ui_theme
	var theme = preload("res://assets/ui_theme.tres")
	assert(theme.has_stylebox("focus", "CheckBox"), "CheckBox must have a focus StyleBox in ui_theme")
	var focus_box = theme.get_stylebox("focus", "CheckBox")
	assert(focus_box is StyleBoxFlat, "CheckBox focus style must be StyleBoxFlat")
	print("[PASS] CheckBox focus outline in ui_theme verified")

	# Test 6: Verify translations
	TranslationServer.set_locale("pt_BR")
	assert(tr("TAB_GENERAL") == "Geral", "pt_BR TAB_GENERAL")
	assert(tr("TAB_GRAPHICS") == "Gráficos", "pt_BR TAB_GRAPHICS")
	assert(tr("TAB_CONTROLS") == "Controles", "pt_BR TAB_CONTROLS")
	assert(tr("XB_MOVE") == "Movimentação do Personagem", "pt_BR XB_MOVE")

	TranslationServer.set_locale("en")
	assert(tr("TAB_GENERAL") == "General", "en TAB_GENERAL")
	assert(tr("TAB_GRAPHICS") == "Graphics", "en TAB_GRAPHICS")
	assert(tr("TAB_CONTROLS") == "Controls", "en TAB_CONTROLS")
	assert(tr("XB_MOVE") == "Character Movement", "en XB_MOVE")

	TranslationServer.set_locale("es")
	assert(tr("TAB_GENERAL") == "General", "es TAB_GENERAL")
	assert(tr("TAB_GRAPHICS") == "Gráficos", "es TAB_GRAPHICS")
	assert(tr("TAB_CONTROLS") == "Controles", "es TAB_CONTROLS")
	assert(tr("XB_MOVE") == "Movimiento del Personaje", "es XB_MOVE")
	print("[PASS] Localization across pt_BR, en, and es verified")

	# Cleanup
	settings_instance.queue_free()

	print("--- ALL TESTS PASSED SUCCESSFULLY ---")
	quit(0)
