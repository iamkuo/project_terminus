extends Node

signal game_state_changed(state: String)

enum Team { PLAYER = 0, OPPONENT = 1 }

const SPAWN_LANES: int = 3
var ai_cooldown_min: float = 2.0
var ai_cooldown_max: float = 5.0
const AI_SPAWN_CHANCE: float = 1.0
var time : float = 0.0
var minutes: int =0
var seconds: int = 0
var curr: Node
var spawn_points: Node2D
var allies_container: Node2D
var opponents_container: Node2D
var elixir: Control
var enemy_killed: int = 0
var damage_dealt: float = 0.0
var battle_time: float = 0.0
var local_team: Team = Team.PLAYER
var game_state: String = "idle"
var unit_stats_registry: Dictionary = {}
var ai_enabled: bool = true
var ai_cooldown: float = 0.0
var current_config: Dictionary = {}
var background_instance: Node

func _ready() -> void:
	SceneSwitcher.scene_transition_finished.connect(_on_scene_transition_finished)
	BattleTransitionManager.battle_started.connect(_on_battle_started)
	game_state = "idle"

func _on_battle_started(config: Dictionary) -> void:
	current_config = config
	
	# Only load enemy stats for AI spawning when battle starts
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

func _on_scene_transition_finished(scene_name: String) -> void:
	if scene_name == "battle_scene":
		_initialize_battle()
	elif scene_name != "battle_scene" and game_state != "idle":
		_cleanup_battle()

func _initialize_battle() -> void:
	curr = get_tree().current_scene
	if curr:
		spawn_points = curr.get_node_or_null("SpawnPoints")
		allies_container = curr.get_node_or_null("AlliesContainer")
		opponents_container = curr.get_node_or_null("EnemiesContainer")
		elixir = curr.get_node_or_null("UI/SpawnUI")
		
		if current_config.has("background_scene") and current_config.background_scene:
			var bg_node = curr.get_node_or_null("Background")
			if bg_node:
				background_instance = current_config.background_scene.instantiate()
				bg_node.add_child(background_instance)
				
		if current_config.has("ai_cooldown_min") and current_config.has("ai_cooldown_max"):
			ai_cooldown_min = current_config.ai_cooldown_min
			ai_cooldown_max = current_config.ai_cooldown_max
			
	# Reset state
	time = 0.0
	minutes = 0
	seconds = 0
	enemy_killed = 0
	damage_dealt = 0.0
	battle_time = 0.0
	ai_enabled = true
	ai_cooldown = randf_range(ai_cooldown_min, ai_cooldown_max)
	
	game_state = "ready"
	game_state_changed.emit(game_state)

func _cleanup_battle() -> void:
	game_state = "idle"
	game_state_changed.emit(game_state)
	
	if is_instance_valid(background_instance):
		background_instance.queue_free()
	background_instance = null
	
	curr = null
	spawn_points = null
	allies_container = null
	opponents_container = null
	elixir = null
	ai_enabled = false
	current_config.clear()

func _process(delta) -> void:
	time+= delta
	seconds = fmod(time, 60)
	minutes = fmod(time, 3600) / 60
	if not ai_enabled:
		return
	ai_cooldown -= delta
	if ai_cooldown > 0:
		return
	ai_cooldown = randf_range(ai_cooldown_min, ai_cooldown_max)
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


func show_ending_screen(winning_team: int) -> void:
	get_tree().paused = true
	var root := get_tree().current_scene
	if not root:
		return
	var es: Node = root.get_node_or_null("UI/EndingScreen")
	if es and es.has_method("show_result"):
		es.call("show_result", winning_team)
		print("min:"+str(minutes) + "sec:" + str(seconds))
@warning_ignore("unused_parameter")
func on_unit_damage_dealt(source_unit: UnitBase, amount: float, target: Node):
	damage_dealt += amount
	print(damage_dealt)

@warning_ignore("unused_parameter")
func on_unit_enemy_killed(source_unit: UnitBase, target: Node):
	enemy_killed += 1
	print(enemy_killed)
