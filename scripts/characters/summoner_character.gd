extends TPSController
class_name SummonerCharacter

const CLASS_DATA := preload("res://data/classes/summoner_class.tres")

func _ready() -> void:
	class_presets = [CLASS_DATA]
	default_class_index = 0
	super._ready()

func passive_summoner_bond() -> void:
	_add_effect("passive_soul_bond", INF, {
		"notes": "Summon feedback",
		"regen": 1.5
	})

func use_summoner_primary(_ability: PlayerAbility) -> void:
	_add_effect("Spirit Charge", 4.0, {
		"notes": "Empowers next summon"
	})

func use_summoner_primary_spectral_chain(_ability: PlayerAbility) -> void:
	_add_effect("Spectral Chain", 5.0, {
		"notes": "Binding debuff"
	})

func use_summoner_secondary(_ability: PlayerAbility) -> void:
	_add_effect("Acolyte", 12.0, {
		"notes": "Spectral ally fighting",
		"speed_multiplier": 0.95
	})

func use_summoner_secondary_obsidian_totem(_ability: PlayerAbility) -> void:
	_add_effect("Obsidian Totem", 10.0, {
		"notes": "Fortifying siphon"
	})

func use_summoner_utility(_ability: PlayerAbility) -> void:
	_add_effect("Commanding Wave", 6.0, {
		"notes": "Summons strengthened"
	})

func use_summoner_utility_void_sigil(_ability: PlayerAbility) -> void:
	_add_effect("Void Sigil", 8.0, {
		"notes": "Lingering slow"
	})

func use_summoner_special(_ability: PlayerAbility) -> void:
	_add_effect("Obelisk Rite", 10.0, {
		"notes": "Area control aura"
	})

func use_summoner_special_rat_beam(_ability: PlayerAbility) -> void:
	_add_effect("Rat Beam", 6.0, {
		"notes": "Focused summon beam"
	})
