extends Resource
class_name PlayerClassData

@export var id: StringName
@export var display_name := ""
@export var description := ""
@export var passive_display_name := ""
@export_multiline var passive_description := ""
@export var passive_method := ""
@export var max_health := 100.0
@export var move_speed_multiplier := 1.0
@export var ability_slots: Array[Resource] = []
