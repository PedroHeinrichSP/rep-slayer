extends CharacterBody3D
class_name TPSController

signal class_changed(class_data: PlayerClassData)
signal ability_triggered(ability: PlayerAbility, remaining_cooldown: float)

const DEFAULT_CLASS_PATHS: Array[String] = [
	"res://data/classes/tank_class.tres",
	"res://data/classes/dps_class.tres",
	"res://data/classes/support_class.tres",
	"res://data/classes/runner_class.tres",
	"res://data/classes/summoner_class.tres"
]

const ABILITY_ACTIONS: Array[StringName] = [
	"ability_primary",
	"ability_secondary",
	"ability_utility",
	"ability_special"
]


const EFFECT_TAG_NEGATIVE := "negative"
const PLAYER_ABILITY_SLOT_SCRIPT := preload("res://scripts/player_ability_slot.gd")

@export var class_presets: Array[PlayerClassData] = []
@export var default_class_index := 0

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
@export var camera_pivot_offset := Vector3(0.4, 1.55, 0.0)
@export var camera_orbit_distance := 3.75
@export_range(0.0, 1.0, 0.05) var camera_orbit_height_scale := 0.55
@export var camera_smooth_speed := 10.0

var current_class: PlayerClassData
var current_class_index := -1
var max_health := 100.0
var health := 100.0
var base_speed_multiplier := 1.0
var ability_lookup: Dictionary = {}
var ability_timers: Dictionary = {}
var ability_variants: Dictionary = {}
var ability_selection: Dictionary = {}
var ability_slots: Dictionary = {}
var ability_slot_order: Array[StringName] = []
var active_effects: Dictionary = {}
var last_ability_feedback := "--"
var passive_info := {
	"name": "",
	"description": "",
	"method": ""
}

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
		_snap_camera_to_orbit()
	yaw = rotation.y
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_ensure_ability_actions()
	_ensure_class_presets()
	set_class_by_index(default_class_index)

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
	_update_camera_orbit(delta)
	_handle_ability_input(delta)

	move_and_slide()
	_update_ability_cooldowns(delta)
	_update_effects(delta)

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
	var base_speed := max_ground_speed if on_floor else max_air_speed
	var max_speed := base_speed * _get_total_speed_multiplier()
	var accel := ground_acceleration if on_floor else air_acceleration
	var current_speed := vel.dot(wish_dir)
	var add_speed := max_speed - current_speed
	if add_speed <= 0.0:
		return vel
	var accel_speed := accel * max_speed * delta
	if not on_floor:
		var alignment := 0.0
		var speed_sq := vel.length_squared()
		if speed_sq > 0.0:
			alignment = clamp(wish_dir.dot(vel / sqrt(speed_sq)), 0.0, 1.0)
		accel_speed *= lerp(air_control, 1.0, alignment)
	accel_speed = min(accel_speed, add_speed)
	var new_vel := vel + wish_dir * accel_speed
	var new_speed_sq := new_vel.length_squared()
	var max_speed_sq := max_speed * max_speed
	if new_speed_sq > max_speed_sq:
		new_vel = new_vel.normalized() * max_speed
	return new_vel

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

func _update_camera_orbit(delta: float) -> void:
	if camera == null:
		return

	camera.rotation.x = pitch

	var target_local_position := _get_camera_orbit_target()

	var lerp_weight := 1.0
	if camera_smooth_speed > 0.0:
		lerp_weight = clamp(camera_smooth_speed * delta, 0.0, 1.0)

	camera.position = camera.position.lerp(target_local_position, lerp_weight)

func _get_camera_orbit_target() -> Vector3:
	var radius := camera_orbit_distance
	var height_scale := camera_orbit_height_scale
	var vertical_offset := sin(-pitch) * radius * height_scale
	var depth_offset := cos(pitch) * radius

	return Vector3(
		camera_pivot_offset.x,
		camera_pivot_offset.y + vertical_offset,
		camera_pivot_offset.z - depth_offset
	)

func _snap_camera_to_orbit() -> void:
	camera.position = _get_camera_orbit_target()

func _handle_ability_input(_delta: float) -> void:
	if ability_lookup.is_empty():
		return
	for action in ability_lookup.keys():
		if Input.is_action_just_pressed(action):
			request_ability_use(action)

func request_ability_use(action: StringName) -> void:
	if not ability_lookup.has(action):
		return
	var ability: PlayerAbility = ability_lookup[action]
	if ability == null:
		return
	var remaining: float = ability_timers.get(action, 0.0)
	if remaining > 0.0:
		return
	_trigger_ability(ability)

func _trigger_ability(ability: PlayerAbility) -> void:
	var action := ability.action_name
	if ability.cooldown > 0.0:
		ability_timers[action] = ability.cooldown
	else:
		ability_timers[action] = 0.0
	if ability.method != "" and has_method(ability.method):
		call(ability.method, ability)
		_record_feedback("%s activated" % ability.display_name)
	else:
		_record_feedback("%s triggered (no handler)" % ability.display_name)
	emit_signal("ability_triggered", ability, ability_timers[action])

func _update_ability_cooldowns(delta: float) -> void:
	for action in ability_timers.keys():
		var remaining: float = ability_timers[action]
		if remaining <= 0.0:
			continue
		remaining = max(remaining - delta, 0.0)
		ability_timers[action] = remaining

func _ensure_ability_actions() -> void:
	for action in ABILITY_ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var events := InputMap.action_get_events(action)
		if events.is_empty():
			var setting_path := "input/%s" % action
			if ProjectSettings.has_setting(setting_path):
				var entry_variant: Variant = ProjectSettings.get_setting(setting_path)
				if entry_variant is Dictionary:
					var entry: Dictionary = entry_variant
					var entry_events: Variant = entry.get("events", [])
					if entry_events is Array:
						for event in entry_events:
							if event is InputEvent:
								InputMap.action_add_event(action, event)

func _ensure_class_presets() -> void:
	if not class_presets.is_empty():
		return
	for path in DEFAULT_CLASS_PATHS:
		if not ResourceLoader.exists(path):
			continue
		var resource := load(path)
		if resource is PlayerClassData:
			class_presets.append(resource)
	if class_presets.is_empty():
		push_warning("No class presets available. Configure class_presets on the controller.")

func set_class_by_index(index: int) -> void:
	if class_presets.is_empty():
		push_warning("Cannot set class because class_presets is empty.")
		return
	var clamped: int = clamp(index, 0, class_presets.size() - 1)
	current_class_index = clamped
	_set_class(class_presets[clamped])

func _set_class(class_data: PlayerClassData) -> void:
	if class_data == null:
		return
	current_class = class_data
	base_speed_multiplier = class_data.move_speed_multiplier
	max_health = class_data.max_health
	if health <= 0.0 or health > max_health:
		health = max_health
	_remove_all_effects()
	passive_info = {
		"name": class_data.passive_display_name,
		"description": class_data.passive_description,
		"method": class_data.passive_method
	}
	_register_abilities(class_data)
	_apply_passive()
	emit_signal("class_changed", class_data)
	_record_feedback("Class switched to %s" % class_data.display_name)

func _register_abilities(class_data: PlayerClassData) -> void:
	ability_lookup.clear()
	ability_timers.clear()
	ability_variants.clear()
	ability_selection.clear()
	ability_slots.clear()
	ability_slot_order.clear()
	if class_data == null:
		return
	for slot_res in class_data.ability_slots:
		if slot_res == null:
			continue
		if not slot_res is Resource:
			continue
		if slot_res.get_script() != PLAYER_ABILITY_SLOT_SCRIPT:
			continue
		var slot_data := slot_res
		if slot_data.action_name == StringName():
			continue
		var options: Array = slot_data.abilities.duplicate()
		if options.is_empty():
			continue
		ability_slot_order.append(slot_data.action_name)
		ability_slots[slot_data.action_name] = slot_data
		ability_variants[slot_data.action_name] = options
		var selected_index: int = clamp(slot_data.default_index, 0, options.size() - 1)
		_bind_ability_variant(slot_data.action_name, selected_index)
		ability_timers[slot_data.action_name] = 0.0
	# ensure timers exist for all default actions even if slot missing
	for action in ABILITY_ACTIONS:
		if not ability_timers.has(action):
			ability_timers[action] = 0.0

func _bind_ability_variant(action: StringName, index: int) -> void:
	if not ability_variants.has(action):
		return
	var options: Array = ability_variants[action]
	if options.is_empty():
		ability_selection[action] = -1
		ability_lookup.erase(action)
		ability_timers[action] = 0.0
		return
	var clamped: int = clamp(index, 0, options.size() - 1)
	ability_selection[action] = clamped
	var ability: PlayerAbility = options[clamped]
	ability_lookup[action] = ability
	ability_timers[action] = 0.0

func _apply_passive() -> void:
	var method: String = passive_info.get("method", "")
	if method == "":
		return
	if has_method(method):
		call(method)

func get_passive_info() -> Dictionary:
	return passive_info.duplicate(true)

func get_ability_slot_metadata() -> Array:
	var slots: Array = []
	for action in ability_slot_order:
		if not ability_slots.has(action):
			continue
		var slot: Resource = ability_slots[action]
		var slot_name: String = slot.slot_display_name if slot.slot_display_name != "" else _format_action_label(action)
		var options: Array = ability_variants.get(action, [])
		var entry := {
			"action": action,
			"slot_name": slot_name,
			"description": slot.description,
			"selected_index": ability_selection.get(action, 0),
			"abilities": options.duplicate()
		}
		slots.append(entry)
	return slots

func get_ability_options(action: StringName) -> Array:
	if not ability_variants.has(action):
		return []
	return ability_variants[action].duplicate()

func get_ability_variant_index(action: StringName) -> int:
	return ability_selection.get(action, 0)

func set_ability_variant(action: StringName, index: int) -> void:
	if not ability_variants.has(action):
		return
	_bind_ability_variant(action, index)
	var ability: PlayerAbility = ability_lookup.get(action, null)
	if ability:
		_record_feedback("Equipped %s" % ability.display_name)

func _format_action_label(action: StringName) -> String:
	var text := String(action)
	text = text.replace("ability_", "")
	var parts := text.split("_")
	for i in range(parts.size()):
		var part := parts[i]
		if part.is_empty():
			continue
		parts[i] = part.substr(0, 1).to_upper() + part.substr(1).to_lower()
	return " ".join(parts)

func get_available_classes() -> Array[PlayerClassData]:
	return class_presets.duplicate()

func get_current_class_index() -> int:
	return current_class_index

func get_current_class() -> PlayerClassData:
	return current_class

func get_ability_cooldown_remaining(action: StringName) -> float:
	return ability_timers.get(action, 0.0)

func get_active_effects() -> Dictionary:
	return active_effects.duplicate(true)

func get_health_state() -> Dictionary:
	return {
		"current": health,
		"max": max_health
	}

func get_last_feedback() -> String:
	return last_ability_feedback

func _record_feedback(message: String) -> void:
	last_ability_feedback = message

func _add_effect(effect_id: StringName, duration: float, properties: Dictionary = {}) -> void:
	if duration <= 0.0:
		return
	var entry: Dictionary = {"time": duration}
	for key in properties.keys():
		entry[key] = properties[key]
	active_effects[effect_id] = entry

func _remove_effect(effect_id: StringName) -> void:
	active_effects.erase(effect_id)

func _remove_all_effects() -> void:
	active_effects.clear()

func _clear_effects_by_tag(tag: StringName) -> void:
	var to_remove: Array[StringName] = []
	for effect_id in active_effects.keys():
		var entry: Dictionary = active_effects[effect_id]
		var tags_variant: Variant = entry.get("tags", [])
		var tags: Array = tags_variant if tags_variant is Array else []
		if tag in tags:
			to_remove.append(effect_id)
	for effect_id in to_remove:
		active_effects.erase(effect_id)

func _update_effects(delta: float) -> void:
	if active_effects.is_empty():
		return
	var to_remove: Array[StringName] = []
	for effect_id in active_effects.keys():
		var entry: Dictionary = active_effects[effect_id]
		var remaining := float(entry.get("time", 0.0)) - delta
		if entry.has("regen"):
			_apply_regen(float(entry["regen"]), delta)
		entry["time"] = remaining
		active_effects[effect_id] = entry
		if remaining <= 0.0:
			to_remove.append(effect_id)
	for effect_id in to_remove:
		active_effects.erase(effect_id)

func _apply_regen(rate: float, delta: float) -> void:
	if rate == 0.0:
		return
	health = clamp(health + rate * delta, 0.0, max_health)

func _get_total_speed_multiplier() -> float:
	var multiplier := base_speed_multiplier
	for entry in active_effects.values():
		if entry.has("speed_multiplier"):
			multiplier *= float(entry["speed_multiplier"])
	return multiplier

func _perform_directional_dash(magnitude: float) -> void:
	var forward := -global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() == 0.0:
		return
	forward = forward.normalized()
	velocity += forward * magnitude

func _phase_teleport(distance: float) -> void:
	var direction := -global_transform.basis.z
	direction.y = 0.0
	if direction.length_squared() == 0.0:
		return
	direction = direction.normalized()
	global_position += direction * distance

func _pulse_nearby_enemies(radius: float, push_force: float) -> void:
	var space_state := get_world_3d().direct_space_state
	if space_state == null:
		return
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = sphere
	params.transform = Transform3D(Basis.IDENTITY, global_transform.origin)
	params.collide_with_bodies = true
	var results := space_state.intersect_shape(params, 32)
	for result in results:
		var collider: Object = result.get("collider")
		if collider == null or collider == self:
			continue
		if collider is CharacterBody3D:
			var dir: Vector3 = collider.global_transform.origin - global_transform.origin
			dir.y = 0.0
			if dir.length_squared() == 0.0:
				continue
			dir = dir.normalized()
			collider.velocity += dir * push_force + Vector3.UP * (push_force * 0.25)
