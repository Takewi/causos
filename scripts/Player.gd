class_name Player
extends CharacterBody3D

@export var move_speed: float = 6.0
@export var sprint_speed: float = 12.0
@export var mouse_sensitivity: float = 0.003
@export var gravity: float = 20.0

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D

var camera_pitch: float = 0.0


func _ready() -> void:
	add_to_group("player")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera_pitch = clamp(camera_pitch - event.relative.y * mouse_sensitivity, -deg_to_rad(85), deg_to_rad(85))
		head.rotation.x = camera_pitch

	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			else:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _physics_process(delta: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	var current_speed = sprint_speed if _is_sprint_active() else move_speed
	var input_dir = _get_movement_input()
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if direction != Vector3.ZERO:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed * 8.0 * delta)
		velocity.z = move_toward(velocity.z, 0, current_speed * 8.0 * delta)

	move_and_slide()


## Movement vector querying with InputMap actions support and keyboard fallback
func _get_movement_input() -> Vector2:
	if InputMap.has_action("move_left") and InputMap.has_action("move_right") and InputMap.has_action("move_forward") and InputMap.has_action("move_back"):
		return Input.get_vector("move_left", "move_right", "move_forward", "move_back")

	var dir = Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		dir.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		dir.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir.x += 1.0
	return dir.normalized()


## Sprint status querying with InputMap action support and Shift fallback
func _is_sprint_active() -> bool:
	if InputMap.has_action("sprint"):
		return Input.is_action_pressed("sprint")
	return Input.is_key_pressed(KEY_SHIFT)
