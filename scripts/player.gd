extends CharacterBody3D

@export var move_speed := 7.0
@export var acceleration := 20.0
@export var air_acceleration := 4.0
@export var friction := 8.0
@export var air_friction := 0.1
@export var jump_charge_rate := 6.0    # velocidade de "carregamento" do pulo
@export var max_jump_force := 8.0
@export var gravity := 24.0
@export var camera_sensitivity := 0.2
@export var shoulder_offset := Vector3(0.5, 1.6, -3.5)

@onready var cam_pivot := $Pivot
@onready var cam := $Pivot/Camera3D
@onready var ground_check := $RayCast3D

var input_dir := Vector3.ZERO
var move_dir := Vector3.ZERO
var jump_charge := 0.0
var yaw := 0.0
var pitch := 0.0

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		yaw -= event.relative.x * camera_sensitivity * 0.01
		pitch -= event.relative.y * camera_sensitivity * 0.01
		pitch = clamp(pitch, deg_to_rad(-70), deg_to_rad(70))
		cam_pivot.rotation = Vector3(pitch, 0, 0)
		rotation.y = yaw

func _process(_delta: float) -> void:
	# Mantém a câmera posicionada sobre o ombro
	cam.transform.origin = shoulder_offset

func _physics_process(delta: float) -> void:
	handle_input()
	move_player(delta)
	handle_jump(delta)

func handle_input() -> void:
	var input_vec = Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_backward") - Input.get_action_strength("move_forward")
	)
	input_vec = input_vec.normalized()
	
	var forward = -transform.basis.z
	var right = transform.basis.x
	input_dir = (forward * input_vec.y + right * input_vec.x).normalized()

func move_player(delta: float) -> void:
	var accel = acceleration if is_on_floor() else air_acceleration
	var fric = friction if is_on_floor() else air_friction

	# aplica aceleração no plano XZ
	var target_vel = input_dir * move_speed
	var diff = target_vel - velocity
	diff.y = 0.0
	velocity += diff * accel * delta

	# aplica atrito quando sem input
	if input_dir == Vector3.ZERO:
		velocity.x = lerp(velocity.x, 0.0, fric * delta)
		velocity.z = lerp(velocity.z, 0.0, fric * delta)

	# gravidade
	if not is_on_floor():
		velocity.y -= gravity * delta

	move_and_slide()

func handle_jump(delta: float) -> void:
	if Input.is_action_pressed("jump") and is_on_floor():
		jump_charge = clamp(jump_charge + jump_charge_rate * delta, 0, max_jump_force)
	elif Input.is_action_just_released("jump") and is_on_floor():
		velocity.y = jump_charge
		jump_charge = 0.0
	elif not is_on_floor():
		jump_charge = 0.0
