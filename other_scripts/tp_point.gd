extends AnimatedSprite2D

## --- Battle Identity ---
@export var battle_id: String = ""
@export var battle_name: String = ""

## --- Visual / Scene Setup ---
@export var background_scene: PackedScene
@export var music_track: AudioStream

## --- AI Enemy Configuration ---
@export var ai_cooldown_min: float = 2.0
@export var ai_cooldown_max: float = 5.0

## --- Player Constraints ---
@export var starting_elixir: float = 5.0

## --- Tower Stats ---
@export var player_tower_hp: int = 1000
@export var enemy_tower_hp: int = 1000

## --- Reward Configuration (Victory only) ---
@export var exp_reward_victory: int = 100
@export var crystal_reward_victory: int = 50

func _on_area_2d_body_entered(_body: Node2D) -> void:
	BattleTransitionManager.start_battle(_build_config())

func _build_config() -> Dictionary:
	return {
		"battle_id": battle_id,
		"battle_name": battle_name,
		"background_scene": background_scene,
		"music_track": music_track,
		"ai_cooldown_min": ai_cooldown_min,
		"ai_cooldown_max": ai_cooldown_max,
		"starting_elixir": starting_elixir,
		"player_tower_hp": player_tower_hp,
		"enemy_tower_hp": enemy_tower_hp,
		"exp_reward_victory": exp_reward_victory,
		"crystal_reward_victory": crystal_reward_victory,
	}
