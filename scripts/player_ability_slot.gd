extends Resource
class_name PlayerAbilitySlot

@export var action_name: StringName
@export var slot_display_name := ""
@export var description := ""
@export var default_index := 0
@export var abilities: Array[PlayerAbility] = []
