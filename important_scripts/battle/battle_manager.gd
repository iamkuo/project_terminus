extends Node

@onready var player = get_tree().current_scene.get_node("Player")
signal game_state_changed(state: String)

enum Team { PLAYER = 0, OPPONENT = 1 }

const SPAWN_LANES: int = 3
var AI_COOLDOWN_MIN: float = 2.0
var AI_COOLDOWN_MAX: float = 5.0
var AI_SPAWN_CHANCE: float = 1.0

var curr: Node
var spawn_points: Node2D
var allies_container: Node2D
var opponents_container: Node2D
var elixir: Control

var local_team: Team = Team.PLAYER
var game_state: String = "idle"
var unit_stats_registry: Dictionary = {}

var ai_enabled: bool = true
var ai_cooldown: float = 0.0

func _ready() -> void:
	curr = get_tree().current_scene
	_apply_battle_config()
	_connect_tower_signals()
	if curr:
		spawn_points = curr.get_node("SpawnPoints")
		allies_container = curr.get_node_or_null("AlliesContainer")
		opponents_container = curr.get_node_or_null("EnemiesContainer")
		elixir = curr.get_node_or_null("UI/SpawnUI")
	else:
		print("DEBUG: FAIL - curr is null in _ready!")
		
	# Only load enemy stats for AI spawning
	unit_stats_registry.clear()
	var dir = DirAccess.open("res://resources/unit_stats/")
	if dir:
		var files = dir.get_files()
		for file_name in files:
			file_name = file_name.trim_suffix(".remap")
			if file_name.ends_with(".tres") or file_name.ends_with(".res"):
				var resource = load("res://resources/unit_stats/" + file_name)
				if resource and "cost" in resource and resource.team == Team.OPPONENT:
					unit_stats_registry[file_name.replace(".tres", "")] = resource
	
	game_state = "ready"
	game_state_changed.emit(game_state)

func _process(delta: float) -> void:
	if not ai_enabled:
		return
	ai_cooldown -= delta
	if ai_cooldown > 0:
		return
	ai_cooldown = randf_range(AI_COOLDOWN_MIN, AI_COOLDOWN_MAX)
	if randf() >= AI_SPAWN_CHANCE:
		return
		
	var stats_ids = unit_stats_registry.keys()
	if stats_ids.is_empty():
		return
		
	var random_stat = unit_stats_registry[stats_ids[randi() % stats_ids.size()]]
	var lane = randi() % SPAWN_LANES
	spawn_enemy(random_stat, lane)

func get_spawn_point(team: int, lane: int) -> Vector2:
	if team == Team.PLAYER:
		var p_node = get_tree().get_first_node_in_group("player")
		if is_instance_valid(p_node):
			return p_node.global_position
		return Vector2.ZERO
		
	var suffix = ["Top", "Middle", "Bottom"][lane] if lane >= 0 and lane < 3 else "Middle"
	if spawn_points and spawn_points.has_node("R_" + suffix):
		return spawn_points.get_node("R_" + suffix).global_position
	return Vector2.ZERO

func spawn_ally(stats: UnitStats, lane: int) -> void:
	if not stats or not allies_container:
		return
	if elixir and not elixir.try_consume(stats.cost):
		MessageManager.show_message("Not enough elixir!")
		return
	var pos = get_spawn_point(Team.PLAYER, lane)
	allies_container.spawn_unit(stats, pos, lane)

func spawn_enemy(stats: UnitStats, lane: int) -> void:
	if not stats or not opponents_container:
		return
	var pos = get_spawn_point(Team.OPPONENT, lane)
	opponents_container.spawn_unit(stats, pos, lane)

func can_spawn(team: int, cost: int) -> bool:
	if team == 0 and elixir:
		return elixir.get_current_int() >= cost
	return true

func on_tower_destroyed(tower: Node) -> void:
	var win_team = Team.PLAYER if tower.team == Team.OPPONENT else Team.OPPONENT
	MessageManager.show_message("Team %d won!" % win_team, 5.0)
	game_state = "game_over"
	game_state_changed.emit(game_state)
	get_tree().paused = true

# --- Integration: Config Application ---

func _apply_battle_config() -> void:
	var cfg = BattleTransitionManager.current_config
	if cfg.is_empty():
		push_warning("No battle config set — using defaults")
		return
	
	# Apply AI settings
	AI_COOLDOWN_MIN = cfg.get("ai_cooldown_min", 2.0)
	AI_COOLDOWN_MAX = cfg.get("ai_cooldown_max", 5.0)
	AI_SPAWN_CHANCE = cfg.get("ai_spawn_chance", 1.0)
	
	# Apply tower HP
	_configure_towers(cfg)
	
	# Apply elixir settings
	if elixir:
		elixir.max_elixir = cfg.get("max_elixir", 10)
		elixir.current = cfg.get("starting_elixir", 5.0)
		elixir.regen_per_sec = cfg.get("elixir_regen_rate", 1.0)
	
	# Filter available cards
	var allowed: Array = cfg.get("allowed_unit_ids", [])
	if not allowed.is_empty():
		_filter_cards(allowed)
	
	# Apply background
	var bg_scene = cfg.get("background_scene")
	if bg_scene:
		_load_background(bg_scene)

func _configure_towers(cfg: Dictionary) -> void:
	for tower in get_tree().get_nodes_in_group("towers"):
		if tower.team == Team.PLAYER:
			tower.max_health = cfg.get("player_tower_hp", 1000)
			tower.current_health = tower.max_health
		else:
			tower.max_health = cfg.get("enemy_tower_hp", 1000)
			tower.current_health = tower.max_health

func _filter_cards(allowed_ids: Array) -> void:
	if elixir and elixir.has_method("filter_cards"):
		elixir.filter_cards(allowed_ids)

func _load_background(scene: PackedScene) -> void:
	var bg_container = curr.get_node_or_null("Background")
	if bg_container:
		for child in bg_container.get_children():
			child.queue_free()
		bg_container.add_child(scene.instantiate())

func _connect_tower_signals() -> void:
	var tm = curr.get_node_or_null("Towers") if curr else null
	if tm and tm.has_signal("all_towers_destroyed"):
		tm.all_towers_destroyed.connect(_on_game_over)

func _on_game_over(winning_team: int) -> void:
	get_tree().paused = true
	var cfg = BattleTransitionManager.current_config
	var is_victory = (winning_team == Team.PLAYER)
	
	# Calculate rewards here
	var exp_earned: int = 0
	var crystals_earned: int = 0
	
	if is_victory:
		exp_earned = cfg.get("exp_reward_victory", 100)
		crystals_earned = cfg.get("crystal_reward_victory", 50)
	else:
		exp_earned = cfg.get("exp_reward_defeat", 20)
		crystals_earned = cfg.get("crystal_reward_defeat", 5)
	
	# Bonuses
	crystals_earned += _count_player_towers() * cfg.get("bonus_crystal_per_tower_alive", 10)
	exp_earned += _count_enemy_units_killed() * cfg.get("bonus_exp_per_unit_killed", 5)
	
	# Pass to ending screen
	_show_ending_with_rewards(is_victory, exp_earned, crystals_earned)

func _show_ending_with_rewards(is_victory: bool, exp: int, crystals: int) -> void:
	var es = curr.get_node_or_null("UI/EndingScreen")
	if es and es.has_method("show_result_with_rewards"):
		es.show_result_with_rewards(is_victory, exp, crystals)

func _count_player_towers() -> int:
	var count = 0
	for t in get_tree().get_nodes_in_group("towers"):
		if t.team == Team.PLAYER and not t.is_destroyed:
			count += 1
	return count

func _count_enemy_units_killed() -> int:
	# Count by checking how many enemy units have been freed
	# Simple approach: track via AlliesManager signal or group delta
	return 0  # TODO: wire up kill counter
