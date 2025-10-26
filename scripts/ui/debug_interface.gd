extends CanvasLayer
class_name DebugInterface

@export var player_path: NodePath = NodePath("../CharacterBody3D")
@export var auto_show := true

@onready var class_selector: OptionButton = %ClassSelector
@onready var ability_list: VBoxContainer = %AbilityList
@onready var effect_list: VBoxContainer = %EffectList
@onready var health_label: Label = %HealthLabel
@onready var feedback_label: Label = %FeedbackLabel
@onready var passive_label: Label = %PassiveLabel
@onready var passive_description: Label = %PassiveDescription

const TOGGLE_ACTION: StringName = "toggle_debug_overlay"

var player
var roster
var ability_entries: Dictionary = {}
var effect_refresh_timer := 0.0

func configure_roster(roster_node) -> void:
	if roster_node == null:
		_detach_roster()
		return
	if roster_node == roster:
		return
	var required := [
		"get_character_names",
		"get_current_character",
		"get_current_character_index",
		"set_character_by_index",
		"get_character_count"
	]
	for method_name in required:
		if not roster_node.has_method(method_name):
			push_warning("DebugInterface requires roster method '%s'" % method_name)
			return
	_detach_roster()
	roster = roster_node
	if roster.has_signal("character_switched"):
		var signal_obj = roster.character_switched
		if not signal_obj.is_connected(_on_roster_character_switched):
			signal_obj.connect(_on_roster_character_switched)
	_populate_class_selector()
	var current = roster.get_current_character()
	if current:
		set_player(current)

func _detach_roster() -> void:
	if roster and roster.has_signal("character_switched"):
		var signal_obj = roster.character_switched
		if signal_obj.is_connected(_on_roster_character_switched):
			signal_obj.disconnect(_on_roster_character_switched)
	roster = null

func _on_roster_character_switched(character, index: int) -> void:
	if character:
		set_player(character)
	_sync_class_selector(index)

func _sync_class_selector(index: int) -> void:
	if index < 0 or index >= class_selector.item_count:
		return
	class_selector.set_block_signals(true)
	class_selector.select(index)
	class_selector.set_block_signals(false)

func _ready() -> void:
	class_selector.item_selected.connect(_on_class_selected)
	_ensure_toggle_action()
	var parent_roster := get_parent()
	if parent_roster and parent_roster.has_method("get_character_names"):
		configure_roster(parent_roster)
	if player == null:
		_set_player_from_path()
	visible = auto_show

func _process(delta: float) -> void:
	if Input.is_action_just_pressed(TOGGLE_ACTION):
		visible = not visible
	if not visible:
		return
	if player == null:
		return
	_update_health_label()
	_update_ability_entries()
	effect_refresh_timer += delta
	if effect_refresh_timer >= 0.2:
		effect_refresh_timer = 0.0
		_update_effect_list()
	feedback_label.text = "Last ability: %s" % player.get_last_feedback()

func _set_player_from_path() -> void:
	var candidate := get_node_or_null(player_path)
	if candidate == null:
		return
	if candidate.has_method("get_available_classes"):
		set_player(candidate)

func set_player(controller) -> void:
	if controller == null or not controller.has_method("get_available_classes"):
		return
	var required := [
		"get_available_classes",
		"get_current_class",
		"get_current_class_index",
		"set_class_by_index",
		"get_health_state",
		"get_active_effects",
		"get_last_feedback",
		"get_ability_cooldown_remaining",
		"request_ability_use",
		"get_passive_info",
		"get_ability_slot_metadata",
		"set_ability_variant",
		"get_ability_variant_index",
		"get_ability_options"
	]
	for method_name in required:
		if not controller.has_method(method_name):
			push_warning("DebugInterface requires controller method '%s'" % method_name)
			return
	if player == controller:
		return
	if player:
		_disconnect_player_signals()
	player = controller
	if player:
		_connect_player_signals()
		_rebuild_ui()
	else:
		ability_entries.clear()
		_clear_container(ability_list)
		_clear_container(effect_list)
		_update_passive_info()

func _connect_player_signals() -> void:
	if player.has_signal("class_changed"):
		player.class_changed.connect(_on_player_class_changed)
	if player.has_signal("ability_triggered"):
		player.ability_triggered.connect(_on_player_ability_triggered)

func _disconnect_player_signals() -> void:
	if player.has_signal("class_changed") and player.class_changed.is_connected(_on_player_class_changed):
		player.class_changed.disconnect(_on_player_class_changed)
	if player.has_signal("ability_triggered") and player.ability_triggered.is_connected(_on_player_ability_triggered):
		player.ability_triggered.disconnect(_on_player_ability_triggered)

func _rebuild_ui() -> void:
	_populate_class_selector()
	_rebuild_ability_entries()
	_update_effect_list()
	_update_passive_info()

func _populate_class_selector() -> void:
	class_selector.set_block_signals(true)
	class_selector.clear()
	class_selector.disabled = false
	if roster:
		var names: Array = roster.get_character_names()
		var count: int = roster.get_character_count()
		for i in range(count):
			var label := "Class %d" % (i + 1)
			if i < names.size():
				label = str(names[i])
			class_selector.add_item(label, i)
		_sync_class_selector(roster.get_current_character_index())
	elif player:
		var classes: Array = player.get_available_classes()
		for i in classes.size():
			class_selector.add_item(classes[i].display_name, i)
		var current_idx: int = player.get_current_class_index()
		if current_idx >= 0 and current_idx < class_selector.item_count:
			class_selector.select(current_idx)
	else:
		class_selector.disabled = true
	class_selector.set_block_signals(false)

func _rebuild_ability_entries() -> void:
	ability_entries.clear()
	_clear_container(ability_list)
	if player == null:
		return
	var slots: Array = player.get_ability_slot_metadata()
	for slot_entry in slots:
		var data: Dictionary = slot_entry
		var container := _create_ability_entry(data)
		ability_list.add_child(container)

func _create_ability_entry(slot_data: Dictionary) -> VBoxContainer:
	var container := VBoxContainer.new()
	container.add_theme_constant_override("separation", 2)
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var header := HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var slot_label := Label.new()
	slot_label.text = slot_data.get("slot_name", "Slot")
	slot_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(slot_label)

	var option_button := OptionButton.new()
	option_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var abilities: Array = slot_data.get("abilities", [])
	for i in range(abilities.size()):
		var ability: PlayerAbility = abilities[i]
		var item_text: String = ability.display_name
		option_button.add_item(item_text, i)
		option_button.set_item_tooltip(i, ability.description)
	option_button.select(slot_data.get("selected_index", 0))
	header.add_child(option_button)

	var cooldown_label := Label.new()
	cooldown_label.text = "Ready"
	cooldown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cooldown_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(cooldown_label)

	var action: StringName = slot_data.get("action", StringName())
	var trigger_button := Button.new()
	trigger_button.text = "Use"
	trigger_button.pressed.connect(_on_ability_button_pressed.bind(action))
	header.add_child(trigger_button)

	container.add_child(header)

	var description_label := Label.new()
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	description_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if abilities.size() > 0:
		var selected: int = clamp(slot_data.get("selected_index", 0), 0, abilities.size() - 1)
		description_label.text = abilities[selected].description
	else:
		description_label.text = ""
	container.add_child(description_label)

	option_button.item_selected.connect(_on_ability_variant_selected.bind(action, option_button, description_label))

	ability_entries[action] = {
		"cooldown_label": cooldown_label,
		"button": trigger_button,
		"option": option_button,
		"description": description_label
	}
	return container

func _update_health_label() -> void:
	var stats: Dictionary = player.get_health_state()
	health_label.text = "Health: %.0f / %.0f" % [stats["current"], stats["max"]]

func _update_ability_entries() -> void:
	for action in ability_entries.keys():
		var entry: Dictionary = ability_entries[action]
		var remaining: float = player.get_ability_cooldown_remaining(action)
		var label: Label = entry["cooldown_label"]
		var button: Button = entry["button"]
		if remaining <= 0.01:
			label.text = "Ready"
			button.disabled = false
		else:
			label.text = "CD: %.1fs" % remaining
			button.disabled = true
		var option_button: OptionButton = entry["option"]
		var selected_index: int = player.get_ability_variant_index(action)
		if option_button.selected != selected_index:
			option_button.set_block_signals(true)
			option_button.select(selected_index)
			option_button.set_block_signals(false)
		var description_label: Label = entry["description"]
		var options: Array = player.get_ability_options(action)
		if selected_index >= 0 and selected_index < options.size():
			var ability: PlayerAbility = options[selected_index]
			description_label.text = ability.description
		else:
			description_label.text = ""

func _update_effect_list() -> void:
	_clear_container(effect_list)
	if player == null:
		return
	var effects: Dictionary = player.get_active_effects()
	if effects.is_empty():
		var label := Label.new()
		label.text = "None"
		effect_list.add_child(label)
		return
	for effect_id in effects.keys():
		var data: Dictionary = effects[effect_id]
		var duration: float = data.get("time", 0.0)
		var notes: String = data.get("notes", "")
		var label := Label.new()
		var text := "%s (%.1fs)" % [str(effect_id), duration]
		if notes != "":
			text += " - %s" % notes
		label.text = text
		effect_list.add_child(label)

func _on_ability_button_pressed(action: StringName) -> void:
	if player and player.has_method("request_ability_use"):
		player.request_ability_use(action)

func _on_ability_variant_selected(index: int, action: StringName, option_button: OptionButton, description_label: Label) -> void:
	if player == null:
		return
	player.set_ability_variant(action, index)
	var options: Array = player.get_ability_options(action)
	if index >= 0 and index < options.size():
		var ability: PlayerAbility = options[index]
		description_label.text = ability.description
		option_button.set_item_tooltip(index, ability.description)
	_update_ability_entries()

func _on_class_selected(index: int) -> void:
	if roster and roster.has_method("set_character_by_index"):
		roster.set_character_by_index(index)
		return
	if player and player.has_method("set_class_by_index"):
		player.set_class_by_index(index)

func _on_player_class_changed(_class: PlayerClassData) -> void:
	_rebuild_ui()

func _on_player_ability_triggered(ability: PlayerAbility, _cooldown: float) -> void:
	if ability == null:
		return
	feedback_label.text = "Last ability: %s" % ability.display_name

func _clear_container(container: VBoxContainer) -> void:
	for child in container.get_children():
		child.queue_free()

func _update_passive_info() -> void:
	if player == null:
		passive_label.text = "Passive: --"
		passive_description.text = ""
		return
	var info: Dictionary = player.get_passive_info()
	var passive_name: String = info.get("name", "")
	var passive_desc: String = info.get("description", "")
	if passive_name == "":
		passive_label.text = "Passive: --"
	else:
		passive_label.text = "Passive: %s" % passive_name
	passive_description.text = passive_desc

func _ensure_toggle_action() -> void:
	if InputMap.has_action(TOGGLE_ACTION):
		return
	InputMap.add_action(TOGGLE_ACTION)
	var key_event := InputEventKey.new()
	key_event.physical_keycode = KEY_F1
	InputMap.action_add_event(TOGGLE_ACTION, key_event)

func _set_visibility_from_input() -> void:
	pass
