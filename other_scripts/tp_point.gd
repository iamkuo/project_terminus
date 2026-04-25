extends AnimatedSprite2D

## --- Battle Identity ---
@export var battle_id: String = ""
@export var battle_name: String = ""

## --- Visual / Scene Setup ---
@export var background_scene: PackedScene
@export var background_color: Color = Color(0.15, 0.15, 0.2)
@export var music_track: AudioStream

## --- AI Enemy Configuration ---
@export var ai_cooldown_min: float = 2.0
@export var ai_cooldown_max: float = 5.0
@export var ai_spawn_chance: float = 1.0

## --- Player Constraints ---
@export var starting_elixir: float = 5.0
@export var max_elixir: int = 10
@export var elixir_regen_rate: float = 1.0
@export var allowed_unit_ids: Array[String] = []

## --- Tower Stats ---
@export var player_tower_hp: int = 1000
@export var enemy_tower_hp: int = 1000

## --- Reward Configuration ---
@export var exp_reward_victory: int = 100
@export var exp_reward_defeat: int = 20
@export var crystal_reward_victory: int = 50
@export var crystal_reward_defeat: int = 5
@export var bonus_crystal_per_tower_alive: int = 10
@export var bonus_exp_per_unit_killed: int = 5

func _on_area_2d_body_entered(_body: Node2D) -> void:
	BattleTransitionManager.start_battle(_build_config())

func _build_config() -> Dictionary:
	return {
		"battle_id": battle_id,
		"battle_name": battle_name,
		"background_scene": background_scene,
		"background_color": background_color,
		"music_track": music_track,
		"ai_cooldown_min": ai_cooldown_min,
		"ai_cooldown_max": ai_cooldown_max,
		"ai_spawn_chance": ai_spawn_chance,
		"starting_elixir": starting_elixir,
		"max_elixir": max_elixir,
		"elixir_regen_rate": elixir_regen_rate,
		"allowed_unit_ids": allowed_unit_ids,
		"player_tower_hp": player_tower_hp,
		"enemy_tower_hp": enemy_tower_hp,
		"exp_reward_victory": exp_reward_victory,
		"exp_reward_defeat": exp_reward_defeat,
		"crystal_reward_victory": crystal_reward_victory,
		"crystal_reward_defeat": crystal_reward_defeat,
		"bonus_crystal_per_tower_alive": bonus_crystal_per_tower_alive,
		"bonus_exp_per_unit_killed": bonus_exp_per_unit_killed,
	}
