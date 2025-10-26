extends CharacterBody3D


@export var speed := 4.0
@export var acceleration := 12.0
@export var climb_impulse := 6.5
@export var separation_push := 3.0
@export var separation_margin := 0.08
@export var player_path: NodePath
@export var snap_length := 1.0

var player: Node3D
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready() -> void:
	player = get_node_or_null(player_path)
	floor_snap_length = snap_length

func _physics_process(delta: float) -> void:
	if player == null:
		return

	var to_player := player.global_transform.origin - global_transform.origin
	var horizontal := Vector3(to_player.x, 0.0, to_player.z)
	var target_velocity := Vector3.ZERO
	if horizontal.length() >= 0.1:
		target_velocity = horizontal.normalized() * speed

	_apply_gravity(delta, is_on_floor())
	velocity.x = move_toward(velocity.x, target_velocity.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, acceleration * delta)

	move_and_slide()
	_handle_character_collisions(delta)

func _handle_character_collisions(_delta: float) -> void:
	var separation := Vector3.ZERO
	for i in range(get_slide_collision_count()):
		var collision := get_slide_collision(i)
		var collider := collision.get_collider()
		if collider == null:
			continue
		if collider is CharacterBody3D:
			var normal := collision.get_normal()
			if normal.y < -0.4:
				velocity.y = max(velocity.y, climb_impulse)
			elif normal.y > 0.4:
				velocity.y = max(velocity.y, 0.0)
			else:
				velocity += -normal * separation_push
				var depth := collision.get_depth()
				var push_dir := -normal
				separation += push_dir * (depth + separation_margin)
	if separation != Vector3.ZERO:
		global_position += separation


func _apply_gravity(delta: float, on_floor: bool) -> void:
	if on_floor:
		if velocity.y < 0.0:
			velocity.y = 0.0
		return
	velocity.y -= gravity * delta
