extends "res://other_scripts/tp_point.gd"

func _init() -> void:
	battle_id = "test_battle"
	battle_name = "測試戰鬥 (Test Battle)"
	ai_cooldown_min = 3.0
	ai_cooldown_max = 6.0
	starting_elixir = 10.0
	exp_reward_victory = 50
	crystal_reward_victory = 10
	# background_scene can be set in the inspector or here if we have a default test bg
