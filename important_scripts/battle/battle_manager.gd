extends Node

@onready var player = get_tree().current_scene.get_node("Player")
signal game_state_changed(state: String)

enum Team { PLAYER = 0, OPPONENT = 1 }

const SPAWN_LANES: int = 3
const AI_COOLDOWN_MIN: float = 2.0
const AI_COOLDOWN_MAX: float = 5.0
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
func _ready() -> void:
	curr = get_tree().current_scene
	if curr:
		spawn_points = get_tree().root.get_node("Main/SpawnPoints")
		allies_container = get_tree().root.get_node("Main/AlliesContainer")
		opponents_container = get_tree().root.get_node("Main/EnemiesContainer")
		elixir = get_tree().root.get_node("Main/UI/SpawnUI")
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

func _process(delta) -> void:
	time+= delta
	seconds = fmod(time, 60)
	minutes = fmod(time, 3600) / 60
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
