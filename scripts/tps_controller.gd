extends CharacterBody3D

@export var max_ground_speed := 12.0
@export var max_air_speed := 14.0
@export var ground_acceleration := 32.0
@export var air_acceleration := 18.0
@export_range(0.0, 1.0, 0.05) var air_control := 0.4
@export var ground_friction := 12.0
@export var jump_height := 3.5
@export var extra_jump_height := 2.0
@export var jump_hold_time := 0.18
@export var mouse_sensitivity := Vector2(0.0035, 0.0035)
@export var min_pitch := deg_to_rad(-60.0)
@export var max_pitch := deg_to_rad(45.0)

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var yaw := 0.0
var pitch := 0.0
var jump_timer := 0.0
var jump_active := false

@onready var camera: Camera3D = get_node_or_null("Camera3D")

func _ready() -> void:
    if camera == null:
        push_warning("TPS controller requires a Camera3D child.")
    else:
        pitch = clamp(camera.rotation.x, min_pitch, max_pitch)
        camera.rotation.x = pitch
    yaw = rotation.y
    Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
        yaw -= event.relative.x * mouse_sensitivity.x
        pitch -= event.relative.y * mouse_sensitivity.y
        pitch = clamp(pitch, min_pitch, max_pitch)
        rotation.y = yaw
        if camera:
            camera.rotation.x = pitch
    elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
        Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
    elif event is InputEventMouseButton and event.pressed:
        Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta: float) -> void:
    var on_floor := is_on_floor()
    var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
    var wish_dir := _get_wish_direction(input_dir)

    var horizontal_velocity := velocity
    horizontal_velocity.y = 0.0

    if on_floor:
        horizontal_velocity = _apply_ground_friction(horizontal_velocity, input_dir, delta)

    if wish_dir != Vector3.ZERO:
        horizontal_velocity = _accelerate(horizontal_velocity, wish_dir, delta, on_floor)

    velocity.x = horizontal_velocity.x
    velocity.z = horizontal_velocity.z

    _apply_gravity(delta, on_floor)
    _handle_jump(delta, on_floor)

    move_and_slide()

func _get_wish_direction(input_dir: Vector2) -> Vector3:
    if input_dir == Vector2.ZERO:
        return Vector3.ZERO
    var reference_basis := camera.global_transform.basis if camera else global_transform.basis
    var forward := -reference_basis.z
    forward.y = 0.0
    forward = forward.normalized()
    var right := reference_basis.x
    right.y = 0.0
    right = right.normalized()
    var wish_dir := (right * input_dir.x) + (forward * -input_dir.y)
    return wish_dir.normalized()

func _apply_ground_friction(vel: Vector3, input_dir: Vector2, delta: float) -> Vector3:
    if input_dir.length_squared() > 0.0:
        return vel
    var speed := vel.length()
    if speed <= 0.0:
        return Vector3.ZERO
    var drop := speed * ground_friction * delta
    var new_speed: float = max(speed - drop, 0.0)
    if new_speed <= 0.0:
        return Vector3.ZERO
    return vel.normalized() * new_speed

func _accelerate(vel: Vector3, wish_dir: Vector3, delta: float, on_floor: bool) -> Vector3:
    var max_speed := max_ground_speed if on_floor else max_air_speed
    var accel := ground_acceleration if on_floor else air_acceleration
    var current_speed := vel.dot(wish_dir)
    var add_speed := max_speed - current_speed
    if add_speed <= 0.0:
        return vel
    var accel_speed := accel * max_speed * delta
    if not on_floor:
        accel_speed *= lerp(air_control, 1.0, clamp(wish_dir.dot(vel.normalized()), -1.0, 1.0))
    accel_speed = min(accel_speed, add_speed)
    return vel + wish_dir * accel_speed

func _apply_gravity(delta: float, on_floor: bool) -> void:
    if on_floor:
        if velocity.y < 0.0:
            velocity.y = 0.0
        return
    velocity.y -= gravity * delta

func _handle_jump(delta: float, on_floor: bool) -> void:
    if Input.is_action_just_pressed("jump") and on_floor:
        velocity.y = _jump_initial_velocity()
        jump_active = true
        jump_timer = 0.0
    elif on_floor:
        jump_active = false
        jump_timer = 0.0

    if not jump_active:
        return

    if Input.is_action_pressed("jump") and jump_timer < jump_hold_time:
        velocity.y += _jump_boost_accel() * delta
        jump_timer += delta
    else:
        jump_active = false

func _jump_initial_velocity() -> float:
    return sqrt(2.0 * gravity * jump_height)

func _jump_boost_accel() -> float:
    if jump_hold_time <= 0.0:
        return 0.0
    var base_speed := _jump_initial_velocity()
    var target_speed := sqrt(2.0 * gravity * (jump_height + extra_jump_height))
    var extra_speed: float = max(target_speed - base_speed, 0.0)
    return extra_speed / jump_hold_time
