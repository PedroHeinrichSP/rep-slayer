extends TPSController
class_name DPSCharacter

const CLASS_DATA := preload("res://data/classes/dps_class.tres")

func _ready() -> void:
	class_presets = [CLASS_DATA]
	default_class_index = 0
	super._ready()

func passive_dps_overdrive() -> void:
	_add_effect("passive_overdrive", INF, {
		"notes": "Overclocked core",
		"speed_multiplier": 1.05,
		"regen": -1.0
	})

func use_dps_primary(_ability: PlayerAbility) -> void:
	_add_effect("Arc Surge", 1.5, {
		"speed_multiplier": 1.1,
		"notes": "Momentum boost"
	})

func use_dps_primary_arc_burst(_ability: PlayerAbility) -> void:
	_add_effect("Arc Burst", 2.5, {
		"speed_multiplier": 1.15,
		"notes": "Piercing focus"
	})

func use_dps_secondary(_ability: PlayerAbility) -> void:
	_add_effect("Overclock", 5.0, {
		"speed_multiplier": 1.2,
		"notes": "Power spike"
	})
	_add_effect("Overheat", 6.0, {
		"regen": -4.0,
		"notes": "Burning out",
		"tags": [EFFECT_TAG_NEGATIVE]
	})

func use_dps_secondary_glass_shatter(_ability: PlayerAbility) -> void:
	_add_effect("Glass Shatter", 6.0, {
		"notes": "Bleeding shards"
	})
	_add_effect("Glass Fragments", 4.0, {
		"regen": -2.0,
		"notes": "Self-shard backlash",
		"tags": [EFFECT_TAG_NEGATIVE]
	})

func use_dps_utility(_ability: PlayerAbility) -> void:
	_perform_directional_dash(12.0)

func use_dps_utility_shadowstep(_ability: PlayerAbility) -> void:
	_phase_teleport(6.0)
	_add_effect("Shadowstep", 2.5, {
		"speed_multiplier": 1.1,
		"notes": "Phase reposition"
	})

func use_dps_special(_ability: PlayerAbility) -> void:
	_add_effect("Storm Barrage", 8.0, {
		"speed_multiplier": 1.05,
		"notes": "Sustained fire"
	})

func use_dps_special_storm_barrage(_ability: PlayerAbility) -> void:
	_add_effect("Storm Barrage Prime", 10.0, {
		"speed_multiplier": 1.1,
		"notes": "Escalating salvo"
	})
