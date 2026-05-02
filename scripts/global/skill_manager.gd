extends Node
## SkillManager.gd - Centralized system for skill bonuses using directly accessible variables.

# Direct access variables
var player_speed_mult: float = 1.0
var tower_health_mult: float = 1.0
var allies_mult: float = 1.0
var elixir_recovery_mult: float = 1.0
var max_elixir_bonus: int = 0

func _ready() -> void:
	# Initial calculation - deferred to ensure ProgressManager has loaded resources
	call_deferred("update_bonuses")
	
	# Automatically update when skills are upgraded
	if ProgressManager.has_signal("data_updated"):
		ProgressManager.data_updated.connect(update_bonuses)

func update_bonuses() -> void:
	# Recalculate all multipliers based on ProgressManager levels
	player_speed_mult = 1.0 + (ProgressManager.get_player_skill_level("player_speed") - 1) * 0.1
	tower_health_mult = 1.0 + (ProgressManager.get_player_skill_level("tower_health") - 1) * 0.2
	allies_mult = 1.0 + (ProgressManager.get_player_skill_level("allies_multiplier") - 1) * 0.05
	elixir_recovery_mult = 1.0 + (ProgressManager.get_player_skill_level("elixir_recovery") - 1) * 0.15
	max_elixir_bonus = (ProgressManager.get_player_skill_level("max_elixir") - 1) * 20
	
	print("[SkillManager] Bonuses updated: Speed x%.2f, Tower HP x%.2f, Allies x%.2f, Elixir Recovery x%.2f, Max Elixir +%d" % 
		[player_speed_mult, tower_health_mult, allies_mult, elixir_recovery_mult, max_elixir_bonus])

func get_bonus_text(skill_id: String, level: int) -> String:
	match skill_id:
		"player_speed":
			return "+%d%% 移動速度" % [int((level - 1) * 10)]
		"tower_health":
			return "+%d%% 防禦塔生命值" % [int((level - 1) * 20)]
		"allies_multiplier":
			return "+%d%% 盟軍全屬性" % [int((level - 1) * 5)]
		"elixir_recovery":
			return "+%d%% 聖水恢復率" % [int((level - 1) * 15)]
		"max_elixir":
			return "+%d 聖水上限" % [(level - 1) * 20]
		_:
			return ""
