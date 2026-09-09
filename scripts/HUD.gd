extends CanvasLayer

## In-Game HUD
## Displays optional performance metrics (FPS) and subtle center crosshair reticle.

@onready var fps_badge: PanelContainer = $FPSBadge
@onready var fps_label: Label = $FPSBadge/FPSLabel
@onready var reticle: CenterContainer = $Reticle

var _update_timer: float = 0.0
const UPDATE_INTERVAL: float = 0.25 # update FPS text 4 times per second


func _ready() -> void:
	layer = 10
	_update_visibility()
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.has_signal("settings_changed"):
		gm.settings_changed.connect(_on_settings_changed)


func _process(delta: float) -> void:
	if not fps_badge.visible:
		return

	_update_timer += delta
	if _update_timer >= UPDATE_INTERVAL:
		_update_timer = 0.0
		var current_fps = Engine.get_frames_per_second()
		fps_label.text = "%d FPS" % current_fps


func _on_settings_changed() -> void:
	_update_visibility()


func _update_visibility() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		fps_badge.visible = gm.show_fps_counter
	else:
		fps_badge.visible = false
