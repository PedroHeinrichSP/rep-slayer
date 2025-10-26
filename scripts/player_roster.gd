extends Node3D
class_name PlayerRoster

signal character_switched(character: TPSController, index: int)

const DEFAULT_SCENE_PATHS := [
    "res://scenes/characters/tank_character.tscn",
    "res://scenes/characters/dps_character.tscn",
    "res://scenes/characters/support_character.tscn",
    "res://scenes/characters/runner_character.tscn",
    "res://scenes/characters/summoner_character.tscn"
]

@export var character_scenes: Array[PackedScene] = []
@export var character_names: Array[String] = []
@export var default_character_index := 0

var current_character: TPSController
var current_index := -1

@onready var debug_interface: DebugInterface = get_node_or_null("DebugInterface")

func _ready() -> void:
    if character_scenes.is_empty():
        _populate_default_roster()
    if debug_interface:
        debug_interface.call_deferred("configure_roster", self)
    set_character_by_index(default_character_index)

func _populate_default_roster() -> void:
    for path in DEFAULT_SCENE_PATHS:
        if not ResourceLoader.exists(path):
            continue
        var packed := load(path)
        if packed is PackedScene:
            character_scenes.append(packed)

func get_character_names() -> Array[String]:
    var names: Array[String] = []
    if character_names.size() == character_scenes.size():
        names = character_names.duplicate()
    else:
        for scene in character_scenes:
            if scene == null:
                names.append("Missing")
            else:
                var path := scene.resource_path
                if path == "":
                    names.append("Character")
                else:
                    names.append(path.get_file().get_basename())
    return names

func get_current_character() -> TPSController:
    return current_character

func get_current_character_index() -> int:
    return current_index

func get_character_count() -> int:
    return character_scenes.size()

func set_character_by_index(index: int) -> void:
    if character_scenes.is_empty():
        push_warning("PlayerRoster has no character scenes configured.")
        return
    var clamped: int = clamp(index, 0, character_scenes.size() - 1)
    if clamped == current_index and is_instance_valid(current_character):
        return
    _spawn_character(clamped)

func _spawn_character(index: int) -> void:
    var packed: PackedScene = character_scenes[index]
    if packed == null:
        push_warning("PlayerRoster attempted to spawn a null PackedScene at index %d" % index)
        return
    var previous_transform := Transform3D()
    if is_instance_valid(current_character):
        previous_transform = current_character.global_transform
        _remove_current_character()
    var instance := packed.instantiate()
    if not instance is TPSController:
        push_warning("Spawned character does not extend TPSController.")
        instance.queue_free()
        return
    add_child(instance)
    if previous_transform != Transform3D():
        instance.global_transform = previous_transform
    current_character = instance
    current_index = index
    if debug_interface:
        debug_interface.set_player(current_character)
    character_switched.emit(current_character, current_index)

func _remove_current_character() -> void:
    if not is_instance_valid(current_character):
        return
    current_character.queue_free()
    current_character = null
    current_index = -1
