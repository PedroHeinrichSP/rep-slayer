extends TPSController
class_name RunnerCharacter

const CLASS_DATA := preload("res://data/classes/runner_class.tres")

func _ready() -> void:
	class_presets = [CLASS_DATA]
	default_class_index = 0
	super._ready()

func passive_runner_momentum() -> void:
	_add_effect("passive_momentum", INF, {
		"notes": "Stacking haste",
		"speed_multiplier": 1.1
	})

func use_runner_primary(_ability: PlayerAbility) -> void:
	_add_effect("Quick Slash", 1.5, {
		"speed_multiplier": 1.15,
		"notes": "Burst acceleration"
	})

func use_runner_primary_twin_blades(_ability: PlayerAbility) -> void:
	_perform_directional_dash(6.0)
	_add_effect("Twin Blades", 2.0, {
		"notes": "Spinning bleed"
	})

func use_runner_secondary(_ability: PlayerAbility) -> void:
	_add_effect("Sprint Burst", 4.0, {
		"speed_multiplier": 1.25,
		"notes": "Sprint engaged"
	})

func use_runner_secondary_hookshot(_ability: PlayerAbility) -> void:
	_phase_teleport(8.0)
	_add_effect("Hookshot", 3.0, {
		"notes": "Rapid pull"
	})

func use_runner_utility(_ability: PlayerAbility) -> void:
	_phase_teleport(4.5)
	_add_effect("Phase Momentum", 2.0, {
		"speed_multiplier": 1.1,
		"notes": "Afterimage trail"
	})

func use_runner_utility_sky_flip(_ability: PlayerAbility) -> void:
	velocity.y = max(velocity.y, jump_vel)
	_add_effect("Sky Flip", 2.5, {
		"notes": "Aerial pirouette"
	})

func use_runner_special(_ability: PlayerAbility) -> void:
	_add_effect("Time Warp", 6.0, {
		"speed_multiplier": 1.5,
		"notes": "Temporal distortion"
	})

func use_runner_special_afterimage_storm(_ability: PlayerAbility) -> void:
	_add_effect("Afterimage Storm", 7.0, {
		"speed_multiplier": 1.4,
		"notes": "Cascading doubles"
	})
