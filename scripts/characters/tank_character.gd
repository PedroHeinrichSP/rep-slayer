extends TPSController
class_name TankCharacter

const CLASS_DATA := preload("res://data/classes/tank_class.tres")

func _ready() -> void:
	class_presets = [CLASS_DATA]
	default_class_index = 0
	super._ready()

func passive_tank_stoneguard() -> void:
	_add_effect("passive_stoneguard", INF, {
		"notes": "Sturdy stance",
		"speed_multiplier": 0.95
	})

func use_tank_primary(_ability: PlayerAbility) -> void:
	velocity.y = max(velocity.y, _jump_initial_velocity() * 0.6)
	_add_effect("Fortified", 2.5, {
		"speed_multiplier": 0.75,
		"notes": "Bracing for impact"
	})

func use_tank_primary_shield_bash(_ability: PlayerAbility) -> void:
	_perform_directional_dash(8.0)
	_add_effect("Shield Bash", 2.5, {
		"speed_multiplier": 0.8,
		"notes": "Armored shove"
	})

func use_tank_secondary(_ability: PlayerAbility) -> void:
	_add_effect("Bastion Call", 6.0, {
		"notes": "Taunting presence"
	})

func use_tank_secondary_rampart(_ability: PlayerAbility) -> void:
	_pulse_nearby_enemies(4.0, 5.0)
	_add_effect("Rampart Surge", 6.0, {
		"notes": "Cone slow"
	})

func use_tank_utility(_ability: PlayerAbility) -> void:
	_add_effect("Bulwark", 8.0, {
		"notes": "Damage reduction"
	})

func use_tank_utility_guardian_march(_ability: PlayerAbility) -> void:
	_perform_directional_dash(4.0)
	_add_effect("Guardian March", 6.0, {
		"speed_multiplier": 0.9,
		"notes": "Moving cover"
	})

func use_tank_special(_ability: PlayerAbility) -> void:
	_pulse_nearby_enemies(6.0, 9.0)
	_add_effect("Guardian Nova", 4.0, {
		"notes": "Stagger aura"
	})

func use_tank_special_citadel_breaker(_ability: PlayerAbility) -> void:
	velocity.y = max(velocity.y, _jump_initial_velocity())
	_pulse_nearby_enemies(7.0, 11.0)
	_add_effect("Citadel Breaker", 5.0, {
		"notes": "Crashing slam"
	})
