extends TPSController
class_name SupportCharacter

const CLASS_DATA := preload("res://data/classes/support_class.tres")

func _ready() -> void:
	class_presets = [CLASS_DATA]
	default_class_index = 0
	super._ready()

func passive_support_beacon() -> void:
	_add_effect("passive_beacon", INF, {
		"notes": "Ambient healing",
		"regen": 2.0
	})

func use_support_primary(_ability: PlayerAbility) -> void:
	_add_effect("Restoration", 3.0, {
		"regen": 6.0,
		"notes": "Self-regeneration"
	})

func use_support_primary_harmonic_echo(_ability: PlayerAbility) -> void:
	_add_effect("Harmonic Echo", 4.0, {
		"regen": 5.0,
		"notes": "Bouncing heals"
	})

func use_support_secondary(_ability: PlayerAbility) -> void:
	_clear_effects_by_tag(StringName(EFFECT_TAG_NEGATIVE))
	_record_feedback("Cleanse Field activated")

func use_support_secondary_aegis_bloom(_ability: PlayerAbility) -> void:
	_add_effect("Aegis Bloom", 7.0, {
		"notes": "Barrier blossom"
	})

func use_support_utility(_ability: PlayerAbility) -> void:
	_add_effect("Motivating Shout", 6.0, {
		"speed_multiplier": 1.05,
		"notes": "Team morale"
	})

func use_support_utility_safeguard_tether(_ability: PlayerAbility) -> void:
	_add_effect("Safeguard Tether", 8.0, {
		"notes": "Damage redistribution"
	})

func use_support_special(_ability: PlayerAbility) -> void:
	_add_effect("Sanctuary", 10.0, {
		"regen": 4.0,
		"notes": "Protective field"
	})

func use_support_special_radiant_tome(_ability: PlayerAbility) -> void:
	_add_effect("Radiant Tome", 9.0, {
		"regen": 3.0,
		"notes": "Hovering heals"
	})
