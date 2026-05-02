extends Node
## Centralized Battle Configuration Manager - Singleton
## 
## TP Points store config locally, but pass it here when battle starts.
## All other scripts reference this manager's public variables directly.

# ============================================================================
# PUBLIC VARIABLES - Direct access for all other scripts
# ============================================================================

var battle_id: String = ""
var battle_name: String = ""
var background_scene: PackedScene
var music_track: AudioStream

var ai_cooldown_min: float = 2.0
var ai_cooldown_max: float = 5.0

var starting_elixir: float = 5.0

var player_tower_hp: int = 1000
var enemy_tower_hp: int = 1000

var exp_reward_victory: int = 100
var crystal_reward_victory: int = 50
var exp_per_kill: int = 10
var exp_per_damage: float = 0.05
var crystals_per_kill: int = 2
var enemy_multiplyer: float = 1.0
var allies_multiplyer: float = 1.0

var unit_stats_registry: Dictionary = {}

# ============================================================================
# SIGNALS
# ============================================================================

signal config_loaded

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	name = "BattleConfigManager"

# ============================================================================
# PUBLIC API
# ============================================================================

## Load configuration from TP Point
func load_config(config: Dictionary) -> void:
	battle_id = config.get("battle_id", "")
	battle_name = config.get("battle_name", "")
	background_scene = config.get("background_scene", null)
	music_track = config.get("music_track", null)
	
	ai_cooldown_min = config.get("ai_cooldown_min", 2.0)
	ai_cooldown_max = config.get("ai_cooldown_max", 5.0)
	
	starting_elixir = config.get("starting_elixir", 5.0)
	
	player_tower_hp = config.get("player_tower_hp", 1000)
	enemy_tower_hp = config.get("enemy_tower_hp", 1000)
	
	exp_reward_victory = config.get("exp_reward_victory", 100)
	crystal_reward_victory = config.get("crystal_reward_victory", 50)
	exp_per_kill = config.get("exp_per_kill", 10)
	exp_per_damage = config.get("exp_per_damage", 0.05)
	crystals_per_kill = config.get("crystals_per_kill", 2)
	enemy_multiplyer = config.get("enemy_multiplyer", 1.0)
	allies_multiplyer = config.get("allies_multiplyer", 1.0)
	
	config_loaded.emit()

## Clear all configuration
func clear() -> void:
	battle_id = ""
	battle_name = ""
	background_scene = null
	music_track = null
	
	ai_cooldown_min = 2.0
	ai_cooldown_max = 5.0
	
	starting_elixir = 5.0
	
	player_tower_hp = 1000
	enemy_tower_hp = 1000
	
	exp_reward_victory = 100
	crystal_reward_victory = 50
	exp_per_kill = 10
	exp_per_damage = 0.05
	crystals_per_kill = 2
	enemy_multiplyer = 1.0
	allies_multiplyer = 1.0
	
	unit_stats_registry.clear()

## Load unit stats into registry
func load_unit_stats(unit_stats_path: String = "res://resources/unit_stats/") -> void:
	unit_stats_registry.clear()
	var dir = DirAccess.open(unit_stats_path)
	
	if not dir:
		push_error("Failed to open unit stats directory: " + unit_stats_path)
		return
	
	var files = dir.get_files()
	for file_name in files:
		file_name = file_name.trim_suffix(".remap")
		
		if not (file_name.ends_with(".tres") or file_name.ends_with(".res")):
			continue
		
		var resource = load(unit_stats_path + file_name)
		if not resource or not "cost" in resource:
			continue
		
		var stats_id = file_name.replace(".tres", "").replace(".res", "")
		unit_stats_registry[stats_id] = resource
